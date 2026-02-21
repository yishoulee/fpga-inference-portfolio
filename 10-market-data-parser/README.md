# Project 10: Wire-Speed Market Data Parser (HFT)

## 1. Project Overview
This project implements a **zero-latency "Cut-Through" packet parser** designed for High-Frequency Trading (HFT) applications on the **Alinx AX7015B** (Zynq-7015) FPGA. The system processes incoming UDP market data packets directly on the AXI-Stream interface as they arrive from the MAC layer (Project 09), extracting financial payloads without buffering the entire packet.

**Key Features:**
- **Zero-Latency Trigger:** The decision logic asserts `price_valid` on the **exact clock cycle** the last byte of the price payload arrives with no pipeline delay.
- **Hardware-In-The-Loop:** Verified on real hardware using custom Python traffic generation and Integrated Logic Analyzers (ILA).
- **Localized Target:** Hardcoded to detect symbol **"0050"** (Taiwan Top 50 ETF) amidst noise traffic.
- **Visual Feedback:** Pulse-stretched LED indicators for human-visible confirmation of microsecond-scale events.

## 2. Theoretical Background
### Cut-Through vs. Store-and-Forward
Standard network stacks implementation (Linux/Windows) use **Store-and-Forward**: the NIC buffers the entire packet, DMA transfers it to RAM, and the OS parses headers sequentially. This incurs microseconds of latency.

**Cut-Through** processing, used in FPGA HFT, inspects the data *as it streams in*.
- **Mechanism:** A simple byte counter tracks the position within the frame.
- **Benefit:** The logic knows the value of the "Price" field before the Ethernet CRC has even arrived.
- **Result:** Trigger latency is effectively **0 ns** relative to the data availability.

## 3. System Architecture
The design sits immediately downstream of the MAC RX module.

```text
    [ External World ]
            |
    +-------v-------+
    | Python Script |
    |    (Scapy)    |
    +-------+-------+
            |
            | UDP Packets (Ethernet Cable)
            |
    +-------v-----------------------------------------+
    |                 FPGA (PL)                       |
    |                                                 |
    |   +-----------+                                 |
    |   | RGMII PHY |                                 |
    |   +-----+-----+                                 |
    |         | RGMII (DDR)                           |
    |         v                                       |
    |   +-----+-----+                                 |
    |   |   MAC RX  |  (Project 09)                   |
    |   +-----+-----+                                 |
    |         | AXI-Stream (8-bit)                    |
    |         v                                       |
    |   +-----+---------------------------+           |
    |   | Market Data Parser              |           |
    |   | (rtl/udp_parser.sv)             |           |
    |   |                                 |           |
    |   |    [ Byte Counter ]             |           |
    |   |           |                     |           |
    |   |           v                     |           |
    |   |    [ Symbol Shift Register ]    |           |
    |   |           |                     |           |
    |   |           v                     |           |
    |   |    [ Target Comparator ]        |           |
    |   |    ( == "0050" ? )              |           |
    |   |           |                     |           |
    |   +-----------+---------------------+           |
    |               |                                 |
    |               | Trigger Signal                  |
    |               v                                 |
    |      +--------+--------+                        |
    |      |                 |                        |
    |      v                 v                        |
    | +---------+       +---------+                   |
    | |   ILA   |       |   LEDs  |                   |
    | | (Debug) |       | (Visual)|                   |
    | +---------+       +---------+                   |
    |                                                 |
    +-------------------------------------------------+
```

### Hardware Flow
1.  **Traffic Source:** A Python script generates UDP packets with specific payloads (e.g., `Symbol="0050", Price=15200`).
2.  **MAC Layer:** Strips Preamble/SFD and outputs AXI-Stream data.
3.  **Parser Logic:**
    *   **Bytes 0-41:** Ignored (Header Bypass).
    *   **Bytes 42-45:** Shifted into `current_symbol`.
    *   **Bytes 46-49:** Shifted into `current_price`.
    *   **Byte 49 (Cycle N):** Comparator checks `current_symbol == "0050"`. If true, `price_valid` asserts **immediately**.

## 4. Implementation Hurdles & Solutions

| Challenge | Root Cause | Solution |
| :--- | :--- | :--- |
| **Verification Blindness** | Simulation passed, but hardware behavior was invisible. | Integrated an ILA core to capture internal states (`price_valid`, `data`) on real hardware. |
| **Human Visibility** | The trigger pulse (8ns at 125MHz) is too fast for the eye to see on an LED. | Implemented a **pulse stretcher** in `top.sv` to extend the 8ns pulse to ~100ms for the LED. |
| **Byte Ordering** | Network data is Big-Endian; x86/ARM CPUs are Little-Endian. | The shift register architecture naturally shifts in MSB-first, matching Network Byte Order without complex byte-swapping logic. |

## 5. RTL Modules: Detailed Architecture

### The UDP Parser (`rtl/udp_parser.sv`)
**Concept:**
A counter-based state machine that treats the packet as a linear stream of bytes.

**Logic States:**
*   **Idle:** Wait for `tvalid`.
*   **Count:** Increment on every valid byte.
*   **Capture Symbol (42-45):** `symbol <= {symbol[23:0], data}`.
*   **Capture Price (46-49):** `price <= {price[23:0], data}`.
*   **Trigger (49):** `if (symbol == target) -> valid = 1`.

### The Top Level (`rtl/top.sv`)
**Concept:**
Wraps the MAC, Parser, PLLs, and ILA into a synthesizable top module. It handles clock crossing and reset synchronization.

**Interface:**
| Signal | Direction | Description |
| :--- | :--- | :--- |
| `sys_clk` | Input | 50 MHz Oscillator (Pin Y14) |
| `eth_rx*` | Input | RGMII Physical Interface (Reused from Project 09) |
| `leds[2:0]` | Output | [2] Activity, [1] Trigger, [0] Heartbeat |

**Constraints:**
This project reuses the verified `AX7015B.xdc` from **Project 09 (Gigabit Ethernet RX)**.
*   **Clock:** `sys_clk` @ 50MHz (Pin Y14).
*   **Ethernet:** RGMII with 125 MHz RX Clock (Pin B4). Input delays (`set_input_delay`) are constrained to valid data windows.
*   **LEDs:** Mapped to board LEDs 0, 1, and 2.

**Clock Domain Checking:**
The critical datapath (MAC -> Parser -> Trigger) resides entirely within the `gmii_rx_clk` (125 MHz) domain to ensure zero-latency and avoid clock domain crossing (CDC) penalties. `sys_clk` is used solely for the IDELAYCTRL reference voltage generation.

## 6. Usage & Commands
This project relies on a `Makefile` to simplify complex Vivado and Tcl workflows.

### Simulation
Run the behavioral simulation to verify the RTL logic.
```bash
make sim
```
*   **Scenario:** Sends "0050" (Valid) and "2330" (Invalid). Verifies trigger logic.

### Build (Synthesis & Implementation)
Create the Vivado project, synthesize, and generate bitstream.
```bash
make build
```
*   **Output:** `top.bit` and `top.ltx` (Debug probes).
*   **Reports:** Generates `utilization.rpt` and `timing_summary.rpt`.

### Programming the FPGA
```bash
make program
```

### Hardware Verification
Launch the ILA monitor script. It will arm the trigger and wait for a specific packet pattern (Symbol="0050").
**Note:** This command will hang until a matching packet is received. You must run `make send_packet` in a separate terminal to trigger it.
```bash
make monitor
```

### Run Traffic Test
Inject UDP packets from your host machine to trigger the ILA.
**Critical Setup:** You must identify your Ethernet interface (e.g., `eth0`, `eno1`, `enp3s0`). The script defaults to `eno1` (found in Project 09), but you should verify yours using `ip link` or `ifconfig`.
```bash
# In a separate terminal
make send_packet
```
*   **Action:** Requires sudo/root privileges for raw socket access.
*   **Logic:** Sends interleaved valid ("0050") and invalid ("2330") packets to prove the filter works.

## 7. Validation Matrix & KPIs

### Performance Metrics
The primary goal was zero added latency for decision making.

| Metric | Target | Measured / Actual | Status | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **Trigger Latency** | 0 Cycles | **0 Cycles** (0 ns) | PASS | ILA Capture (Trigger at end of payload) |
| **Processing Delay** | < 1 us | **~392 ns** (49 bytes @ 125MHz) | PASS | Fixed counter delay |
| **Timing (WNS)** | > 0 ns | **+2.516 ns** | PASS | Vivado Timing Summary |
| **Symbol Match** | "0050" | **"0050"** (0x30303530) | PASS | ILA Data Inspection |
| **False Positives** | 0% | **0%** | PASS | Simulation with "2330" / "0050" |

### Resource Consumption (XC7Z015)
The parser logic is negligible compared to the FPGA capacity.

| Resource | Available | Used | Utilization % |
| :--- | :--- | :--- | :--- |
| **Slice LUTs** | 46,200 | ~1,350 | **~2.9%** |
| **Slice Registers** | 92,400 | ~2,500 | **~2.7%** |
| **Block RAM** | 95 | 6.5 | **6.84%** (Mostly ILA/FIFO) |

**Conclusion:** The module successfully implements HFT-grade parsing logic on the Alinx AX7015B, demonstrating the core value proposition of FPGAs in finance: deterministic, cycle-accurate data processing.
