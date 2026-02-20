
## Implementation Notes (Debug Log - Feb 2026)

### 1. System Architecture
The following diagram illustrates the data flow from the Ethernet source to the FPGA, detailing the RGMII (Reduced Gigabit Media Independent Interface) and the internal FPGA clocking structure.

```ascii
                                       +-------------------------------------------------------+
                                       |                 ZYNQ 7015 FPGA (PL)                   |
                                       |                                                       |
[Ethernet Source]                      |   [Clocking Infrastructure]                           |
       |                               |                                                       |
       | (Diff Pair)                   |   sys_clk (Y14) --> [PLLE2] --> 200MHz (IDELAY Ref)   |
       v                               |                                      |                |
 [RJ45 MagJack]                        |  eth_rxc (B4) ----------------+      v                |
       |                               |                               |   [IDELAYCTRL]        |
       | (MDI Signals)                 |                               v                       |
       v                               |                         [BUFG] --> gmii_rx_clk (125M) |
[RTL8211E PHY]                         |                                      |                |
       |                               |                                      +-------+        |
       | (RGMII Interface)             |                                              |        |
       | 125MHz DDR                    |   [RGMII Capture (rgmii_rx.sv)]              |        |
       |                               |                                              |        |
       +--- eth_rxc (125M) ----------> | --> [IBUF] ----------------------------------+        |
       |                               |                                      |                |
       +--- eth_rx_ctl (Valid) ------> | --> [IBUF] --> [IDELAY] --> [IDDR] --+                |
       |                               |                 (0 delay)      ^     |                |
       +--- eth_rxd[3:0] (Data) -----> | --> [IBUF] --> [IDELAY] --> [IDDR] --+                |
                                       |                                ^                      |
                                       |                                | (Inverted Clock)     |
                                       |                                | (~gmii_rx_clk)       |
                                       |                                |                      |
                                       |                    (GMII Interface: 125MHz SDR)       |
                                       |                     gmii_rx_dv, gmii_rxd[7:0]         |
                                       |                                |                      |
                                       |                                v                      |
                                       |   [MAC Checking (mac_rx.sv)]                          |
                                       |   - Detect Preamble (0x55)                            |
                                       |   - Detect SFD (0xD5)                                 |
                                       |   - CRC32 Calculation                                 |
                                       |                                |                      |
                                       |                                v                      |
                                       |   [Packet Counter] --> [LED Logic] --> leds[1]        |
                                       |                                                       |
                                       |   [ILA Debug Probe] <--- (Tapped GMII Signals)        |
                                       |                                                       |
                                       +-------------------------------------------------------+
```

### 2. Constraints & Pinout (Alinx AX7015B)
The design targets the Zynq 7015 (xc7z015clg485-2). The Ethernet PHY is a Realtek RTL8211E-VB-CG connected via RGMII.

| Signal Name      | FPGA Pin | Description                          |
| ---------------- | -------- | ------------------------------------ |
| `sys_clk`        | Y14      | 50 MHz On-board Oscillator           |
| `eth_rxc`        | B4       | 125 MHz RX Clock from PHY            |
| `eth_rx_ctl`     | B3       | RX Control (RX_DV)                   |
| `eth_rxd[0]`     | A2       | RX Data Bit 0                        |
| `eth_rxd[1]`     | A1       | RX Data Bit 1                        |
| `eth_rxd[2]`     | B2       | RX Data Bit 2                        |
| `eth_rxd[3]`     | B1       | RX Data Bit 3                        |
| `leds[0]`        | A5       | Heartbeat LED (Active Low, RX Clock) |
| `leds[1]`        | A7       | Packet Activity LED (Active Low)     |
| `leds[2]`        | A6       | Heartbeat LED (Active Low, Sys Clock)|

**Clocking Architecture & Constraints Nuance:**
*   **System Clock**: `sys_clk` (50 MHz) -> PLLE2_BASE -> `clk_200m` (200 MHz) for IDELAYCTRL reference.
*   **RX Clock**: `eth_rxc` (125 MHz) -> IDELAYE2 -> BUFG -> `gmii_rx_clk` (125 MHz Global Clock).
*   **Input Delay Constraints**:
    The constraints file sets a relaxed `set_input_delay` of 2.0ns max/0.0ns min relative to the clock. This defines a 2ns valid window around the rising edge.
    ```xdc
    create_clock -period 8.000 -name rgmii_rx_clk -waveform {0.000 4.000} [get_ports eth_rxc]
    set_input_delay -clock [get_clocks rgmii_rx_clk] -max 2.000 [get_ports {eth_rx_ctl eth_rxd[*]}]
    set_input_delay -clock [get_clocks rgmii_rx_clk] -min 0.000 [get_ports {eth_rx_ctl eth_rxd[*]}]
    ```
*   **AX7015B Specific Nuance (Clock Alignment)**: on the Alinx AX7015B, the trace lengths for clock and data are matched, and the Realtek PHY is (by default) not adding the standard 2ns RGMII delay (RGMII-ID). This results in the clock transition occurring aligned with the data transition (0-degree shift). For stable capture, the FPGA must sample in the middle of the data eye. We achieve this by **inverting the capture clock** at the IDDR primitive, effectively shifting the sampling edge by 180 degrees (4ns), placing it squarely in the stable data window.

### 3. Implementation Methodology
The core challenge was aligning the Source Synchronous RGMII DDR signals with the FPGA capture logic.
*   **Method**: Used Xilinx `IDDR` (Input Double Data Rate) primitives to capture data on both rising and falling edges of `rgmii_rxc`.
*   **Initial Constraint**: Set `IDELAY_VALUE` to 0, assuming trace lengths were matched or PHY added internal delay (RGMII-ID mode).

### 4. Debugging Process

#### A. Initial Failure (LED1 OFF)
*   **Symptom**: Connectivity LEDs (Link/Act on RJ45) were active, but FPGA logic `leds[1]` remained OFF.
*   **Test Command**: `sudo python3 scripts/test_eth.py` (Scapy packet generator).
*   **Hypothesis**: Timing skew between Clock and Data.
*   **Attempt 1**: Tuned `IDELAY_VALUE` to 15 (~1.2ns) and 26 (~2.0ns). Result: **Failed**.

#### B. Hardware Debugging (ILA)
To see *what* was happening, we inserted an Integrated Logic Analyzer (ILA).
*   **Command**: `vivado -mode batch -source scripts/debug_ila.tcl`
*   **Trigger**: `gmii_rx_dv == 1` (Packet Valid).
*   **Finding**: The ILA triggered, proving data *was* arriving.
*   **Data Analysis**:
    *   **Expected**: `0x55` (Preamble) -> `0xD5` (SFD) -> `0xFF...` (Dest MAC).
    *   **Observed**: `0x55` (Preamble) -> `0xFD` (Corrupted SFD).
*   **Conclusion**: Since `0xFD` is a shifted/inverted representation of `0xD5` in DDR latching, this indicated we were sampling on the **wrong clock edge** (180-degree phase shift), capturing transition data or the previous/next nibble.

#### C. The Fix
*   **Files Modified**: `rtl/rgmii_rx.sv`.
*   **Logical Fix**: Inverted the clock input to the `IDDR` primitives.
    ```verilog
    // rtl/rgmii_rx.sv
    IDDR #( ... ) iddr_d (
        .C(~gmii_rx_clk), // Invert Clock (180 deg shift)
        .D(rgmii_rxd[i]),
        ...
    );
    ```
*   **Why**: This shifted the capture window by half a clock cycle (4ns), aligning the `IDDR` latching edge with the stable "center eye" of the DDR data window.

### 5. Verification
*   **Re-run Command**: `make build && make program`.
*   **ILA Verification**: The captured waveform now shows a clean `0x55` -> `0xD5` transition.
*   **Visual Verification**: LED1 now blinks (slowly toggles) when the Python script runs, confirming valid packets are passing the CRC/SFD check in `rtl/mac_rx.sv`.

### 6. Testing & Verification Details

#### A. Identifying the Network Interface
Before sending packets, we needed to identify the correct Ethernet interface name on the Linux host machine connected to the FPGA.
*   **Command**: `ip link show`
*   **Result**: We identified the interface (e.g., `eno1`, `eth0`) that was physically connected to the FPGA board.
*   **Link Status**: The command `ethtool <interface>` allows verification that the link is **UP** and negotiated to **1000Mb/s (Gigabit)** Full Duplex.

#### B. The Test Script (`scripts/test_eth.py`)
Since the FPGA is implemented as a passive packet sniffer (it does not yet ARP or reply), we needed a way to trigger the logic with known-valid Ethernet frames.
*   **Tool**: We built a Python script using **Scapy**, a powerful packet manipulation library.
*   **Packet Structure**:
    *   **Destination MAC**: `ff:ff:ff:ff:ff:ff` (Broadcast) ensures the packet is transmitted even without ARP resolution.
    *   **Protocol**: standard UDP packet.
    *   **Payload**: Simple text ("Hello FPGA") to verify data integrity in the ILA if needed.
*   **Execution**:
    ```bash
    sudo python3 scripts/test_eth.py
    ```
    *Note: `sudo` is required because Scapy opens raw sockets to bypass the OS network stack.*

#### C. Final Results
1.  **LED Feedback**:
    *   **Activity LED (`leds[1]`)**: Blinks slowly when the script is running (toggles every ~6 seconds with the 10 pps test), confirming the `pkt_cnt` logic is incrementing.
    *   **Heartbeat LEDs**: Confirm `sys_clk` and `eth_rxc` (PHY Clock) are both running.
2.  **ILA Confirmation**:
    *   We captured a clean frame starting with Preamble (`0x55`) and SFD (`0xD5`).
    *   The `eth_rx_dv` signal asserted high exactly aligned with the data, confirming the timing fix.

### 7. Module & Interface Descriptions ("Black Boxes")
This section details the functional obligations of the key modules and primitives used in the design.

#### A. RTL Modules

**1. `rgmii_rx.sv` (RGMII to GMII Bridge)**
*   **Role**: The low-level physical layer interface. It acts as the "translator" between the external DDR signals and the internal FPGA logic.
*   **Inputs**:
    *   `rgmii_rxc`: 125 MHz Clock from PHY.
    *   `rgmii_rxd[3:0]` & `rgmii_rx_ctl`: DDR data/control signals.
*   **Outputs**:
    *   `gmii_rx_clk`: 125 MHz Global Buffered Clock (SDR).
    *   `gmii_rxd[7:0]` & `gmii_rx_dv`: 8-bit SDR data valid on the rising edge of `gmii_rx_clk`.
*   **Functional Obligations**:
    *   Instantiate `IDELAY` primitives to align signals.
    *   Instantiate `IDDR` primitives to deserialize 4-bit DDR inputs into 8-bit SDR outputs (Rising edge bit -> D1, Falling edge bit -> D2).
    *   **Critical**: Implements the clock inversion (~Clock) to center the sampling eye.

**2. `mac_rx.sv` (Simple MAC / Frame Parser)**
*   **Role**: A simplified Media Access controller that filters raw byte streams into packet structures.
*   **Inputs**:
    *   `gmii_rxd[7:0]`, `gmii_rx_dv`: Raw stream from `rgmii_rx.sv`.
*   **Outputs**:
    *   `m_axis_tdata`, `tvalid`, `tlast`: AXI-Stream standard interface for downstream processing.
*   **Functional Obligations**:
    *   **Preamble Detection**: Waits for the alternating `0x55` pattern.
    *   **SFD Detection**: Waits for `0xD5` to mark the start of meaningful data.
    *   **Framing**: Asserts `tvalid` only for the payload (Dest MAC onwards) and drops `tvalid`/asserts `tlast` when the packet ends.

#### B. Xilinx Primitives (The "Hard Silicon" Black Boxes)

**1. `IDDR` (Input Double Data Rate)**
*   **Input**: `D` (Data Pin), `C` (Clock), `CE`, `R`/`S`.
*   **Output**: `Q1` (Rising Edge Data), `Q2` (Falling Edge Data).
*   **Function**: A dedicated hard-block flip-flop pair located right at the I/O pin. It guarantees capturing data on both clock edges without the timing penalties of routing into the fabric first.

**2. `IDELAYE2` (Input Delay)**
*   **Input**: Signal from pin.
*   **Output**: Delayed signal.
*   **Function**: A 31-tap delay line. Each tap adds ~78ps of delay.
*   **Use Case**: Used to fine-tune the arrival time of the clock or data to ensure setup/hold times are met. In our case, RGMII-ID needs ~2ns (approx 26 taps), though we used the 180-degree clock shift instead.

**3. `BUFG` (Global Clock Buffer)**
*   **Function**: Takes a clock signal and drives it onto the dedicated global clock tree of the FPGA, ensuring low skew so all flip-flops receive the clock at nearly the same instant.

### 8. What We Learned & Concepts Applied

#### A. Source Synchronous Interfaces (RGMII)
RGMII is a "Source Synchronous" protocol, meaning the clock (`eth_rxc`) is sent *along with* the data by the transmitting device (the PHY). This contrasts with system-synchronous designs where a single central clock drives everything.
*   **Challenge**: The clock and data arrive at the FPGA pins with a specific phase relationship.
*   **Concept**: We must align our sampling window (when the flip-flop captures data) with the rigid "eye" of the data signal.

#### B. Double Data Rate (DDR) Sampling
RGMII transmits data on both the rising *and* falling edges of the 125MHz clock to achieve 1Gbps (125 MHz × 8 bits effectively) using only 4 data pins.
*   **Concept**: We used the Xilinx `IDDR` primitive. This dedicated silicon component separates the rising-edge data and falling-edge data into two separate bits (SDR) on a single clock edge, widening the bus from 4 bits (DDR) to 8 bits (SDR).

#### C. Phase Shifting & Clock Skew
The root cause of our failure was a phase mismatch.
*   **The Issue**: The `IDDR` primitive expects the clock edge to be in the middle of the data window. If the clock transitions exactly when the data is transitioning (0-degree shift), the setup/hold times are violated, and we capture garbage or the wrong bit.
*   **The Solution**: RGMII-ID (Internal Delay) PHYs usually add a 2ns delay to the clock to center it. However, our setup required a 180-degree shift (inverting the clock). This moved the sampling edge 4ns away, landing safely in the stable data region.

#### D. The Power of Integrated Logic Analyzers (ILA)
We spent time adjusting IDELAY taps blindly with no success.
*   **Lesson**: "Don't guess, verify."
*   **Application**: Inserting the ILA allowed us to see the *actual* bits arriving inside the FPGA. Seeing `0xFD` instead of `0xD5` was the "smoking gun" that proved the data integrity was fine, but the *alignment* was exactly half a clock cycle off. This turned a blind guessing game into a deterministic fix.
