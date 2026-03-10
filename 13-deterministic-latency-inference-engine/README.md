# Project 13: Wire-Speed Inference Subsystem

## 1. Project Overview
This project implements a **Hardware-Accelerated Inference Pipeline** on the Alinx AX7015B (Zynq-7015). It features a cut-through architecture that processes Gigabit Ethernet UDP packets, parses payloads in real-time, and executes a customized **Systolic Neural Processing Unit (NPU)**. This design moves the critical path of inference logic entirely into the FPGA fabric, eliminating OS jitter and achieving deterministic latency.

### Hardware Bring-Up & Debugging Spotlight
This debugging journey is the crown jewel of the project. It perfectly illustrates the gap between "it works in ModelSim" and "it works on physical silicon."

#### 1. The OS Bottleneck & Layer 2 Bypass (The `scapy` Fix)
*   **The Symptom:** Standard Python `socket` scripts sending UDP broadcast packets worked perfectly in simulation but failed to reach the physical FPGA.
*   **The Root Cause:** The host PC's Linux/Windows kernel network stack was hijacking the packets. Because the FPGA is a passive, RX-only receiver, it does not respond to ARP requests. Without an ARP reply, the host OS refused to forward packets.
*   **The Fix:** Transitioned from application-layer sockets to **raw sockets using `scapy`**. By dropping down to Layer 2, we bypassed the OS kernel and ARP cache entirely.

#### 2. The Deaf MAC (RGMII IDELAY Regression)
*   **The Symptom:** Despite `scapy` successfully flooding the link, the FPGA MAC never detected the preamble. The physical PHY was completely deaf.
*   **The Root Cause:** A regression in the `rgmii_rx.sv` clocking primitives. The project was using an `IDELAY_VALUE` of `28` with no clock inversion. This skewed the RGMII 125MHz clock relative to the incoming data (by over 2.2ns), causing the MAC to sample exactly on the target data transitions instead of the stable center of the data "eye".
*   **The Fix:** Restored the working phase delay parameters from a baseline project. Reverting to `IDELAY_VALUE(0)` with a 180-degree phase shift (`~gmii_rx_clk`) centered the capture window perfectly, instantly bringing the physical link back to life.

#### 3. Shift-Register Parsing vs. Absolute Byte Counting
*   **The Symptom:** After fixing the MAC, the NPU output remained zero. The RTL parser was designed to rigidly wait for `byte_counter == 50` to match the target Feature ID, but the physical hardware failed to match anything.
*   **The Root Cause:** Network environments are inherently messy. The Linux OS or NIC drivers often silently inject 802.1Q VLAN tags or Ethernet padding, shifting the arbitrary "byte 50" offset sideways.
*   **The Fix:** Abandoned explicit byte-offset counting. Implemented a **Continuous Signature Scanner** using a 32-bit shift register. The parser now continuously shifts in `s_axis_tdata`, searching for the hex signature `{current_feature_id[23:0], s_axis_tdata} == 32'h30303530` ("0050") anywhere in the stream, making the extraction bulletproof and immune to VLAN tags.

#### 4. The "Ghost Weights" (Hardware Initialization)
*   **The Symptom:** The NPU result was always 0, meaning the LED trigger threshold was never crossed, even with valid input.
*   **The Root Cause:** In simulation, the testbench explicitly wrote the AXI weights before sending packets. On silicon, the registers inside `axi_weight_regs` initialized to zero on power-up.
*   **The Fix:** Utilized a **Virtual Input/Output (VIO)** core to simulate the control plane, injecting weights and thresholds manually.

#### 5. Ethernet Zero-Padding Pulse Stretching
*   **The Symptom:** Sending small test packets (< 64 bytes) resulted in "washed out" inference values, causing false positive triggers.
*   **The Root Cause:** Ethernet mandates a minimum frame size of 64 bytes. When sending a 24-byte UDP packet, the OS/NIC zero-pads the frame. The parser held `valid` high as long as `s_axis_tvalid` asserted, flooding the NPU pipeline with trailing zeros.
*   **The Fix:** Hand-crafted a 1-cycle auto-clear logic trap to ensure the PE array only ingests exactly one valid byte per signature match, cleanly dropping the rest of the zero-padded frame.

## 2. Theory & Implementation
### Deterministic Latency Architecture
In ultra-low latency applications, speed is the differentiator. This project implements a **Cut-Through Architecture**:
1.  **Decode** headers as they stream across the wire (byte-by-byte).
2.  **Trigger** the NPU immediately upon the capture of the final byte of the relevant field (Feature Vector).
3.  **Execute** arithmetic logic in parallel using an unrolled hardware pipeline.

### System Diagram
```text
       [ Ethernet Cable ]
              |
              v
    +-----------------------+
    |    RGMII Interface    |  <-- PHY Interface (125 MHz)
    |  (top_wrapper + PLL)  |
    +---------+-------------+
              | (GMII Internal)
              v
    +-----------------------+
    |   RGMII / GMII MAC    |  <-- MAC Layer
    +---------+-------------+
              | (AXI-Stream 8-bit)
              v
    +-----------------------+
    |  Packet Inspection    |  <-- "The Gatekeeper"
    |  (FSM: Idle->IP->UDP) |      Filters for Feat. ID "0050"
    +---------+-------------+      Extracts Value @ Byte 46
              | (Value, Valid)
              v
    +-----------------------+      +--------------------+
    |     Systolic NPU      | <--- |  AXI-Lite Config   |
    |   (8 PE Stages)       |      | (VIO / Debug Core) |
    +---------+-------------+      +--------------------+
              | (Dot Product Score)
              v
    +-----------------------+
    |    Decision Logic     |  <-- "The Classifier"
    +---------+-------------+      Compare Score vs Threshold
              |
     +--------+--------+
     |        |        |
  [Class 0]   [Class 1]   [LEDs]
 (Low Value) (High Value)
```

## 3. RTL Modules: Detailed Architecture

### 1. Physical Layer & Wrapper (`rtl/top_wrapper.sv`, `rtl/rgmii_rx.sv`)
-   **Wrapper:** The true top-level entity. It instantiates the PLL for clock generation (200MHz Ref, 100MHz AXI, 50MHz User) and the VIO core for simulating the control plane.
-   **RGMII RX:** Uses Xilinx `IDELAY` and `IDDR` primitives to capture Double Data Rate (DDR) signals from the Ethernet PHY and convert them to a single-data-rate, 8-bit wide GMII bus at 125 MHz.

### 2. MAC & Parser (`rtl/mac_rx.sv`, `rtl/udp_parser.sv`)
-   **MAC:** Operates in the 125 MHz clock domain. Checks frame delimiters and signals valid data to the parser.
-   **Parser:** A Finite State Machine (FSM) tailored to a fixed packet structure. It monitors byte offsets to identify the **Feature ID** (Bytes 42-45) and **Value** (Bytes 46-49).
-   **Zero-Copy:** No buffering of the full packet. Processing happens *byte-by-byte*.

### 3. Neural Processing Unit (`rtl/npu_core.sv`)
-   **Architecture:** 8-stage 1D Systolic Array.
-   **Operation:** $Result = \sum_{i=0}^{7} (Weight_i \times Value)$.
-   **Latency:** The Array has a fixed latency of **16 clock cycles** (2 cycles per PE).
-   **Correction:** The `result_valid` signal is perfectly delay-matched to ensure we only sample the final accumulated value. This alignment is critical; reading one cycle early results in invalid partial sums.

### 4. Configuration Interface (`rtl/axi_weight_regs.sv`)
-   **Role:** Implements a memory-mapped AXI4-Lite Slave interface.
-   **Storage:** Maintains the 8 NPU weights (`slv_reg0`-`slv_reg7`) and the Decision Threshold (`slv_reg8`).
-   **Dynamic Updates:** Allows an external controller (VIO or ARM Processor) to update inference parameters in real-time without re-synthesizing the FPGA bitstream.

### 5. Top-Level Integration (`rtl/top.sv`)
This module is the "Motherboard" of the design, handling:
-   **Clock Domain Crossing (CDC):** Safely moving data between 125 MHz (Ethernet), 100 MHz (System), and 50 MHz (AXI-Lite).
-   **LED Logic:** Pulse stretchers ensure microsecond-long triggers are visible.
    *   **LED A5 (Class 0):** Active when `NPU Score < Threshold`.
    *   **LED A7 (Class 1):** Active when `NPU Score > Threshold`.
    *   **LED A6 (Activity):** Flashes on valid packet.
    *   **LED B8 (Idle):** 1Hz Heartbeat to confirm FPGA is alive.

## 4. Hardware Verification & Results

### Validation Matrix
| Verification Stage | Tool / Method | Status | Notes |
| :--- | :--- | :--- | :--- |
| **RTL Simulation** | Vivado XSim | **Passed** | Verified bit-accurate NPU math and Parser FSM state transitions. |
| **Synthesis** | Vivado 2025.1 | **Passed** | OOC Synthesis complete. |
| **Place & Route** | Vivado Implementation | **Passed** | 1165 LUTs (2.5%), 2118 FFs (2.3%), 8 DSPs (5.0%). |
| **Static Timing** | Report Timing Summary | **Mixed** | Core logic (125MHz) met setup (WNS +1.175ns). CDC paths flagged (need explicit false_path constraints). |
| **Loopback Test** | Python + Scapy | **Passed** | Validated packet reception and LED triggers on physical hardware. |

### Visual Indicators
| LED | Pin | Logic | Interpretation |
| :--- | :--- | :--- | :--- |
| **LED 1** | A5 | Result < Threshold | **Class 0** (Low Value) |
| **LED 2** | A7 | Result > Threshold | **Class 1** (High Value) |
| **LED 3** | A6 | Valid Pulse | **Input Activity** (Parsing Success) |
| **LED 4** | B8 | 1Hz Toggle | **System Idle** (Heartbeat) |

### Test Procedure
We use `sudo` to bypass the OS network stack and inject raw packets.

1.  **Class 0 Test (Low Value):** PC sends value `90-99` $\rightarrow$ LED A5 lights up.
2.  **Class 1 Test (High Value):** PC sends value `101-110` $\rightarrow$ LED A7 lights up.

## 5. Quick Start (Replication)

| Command | Description |
| :--- | :--- |
| `make build` | Synthesize and implement the RTL to generate `top.bit`. |
| `make program` | Program the AX7015B FPGA via JTAG. |
| `make sim` | Run the SystemVerilog testbench validating the Classification logic. |
| `make packet_test` | Floods the network with a single UDP test vector (Feature ID: 0050, Value: 100) at 1000 packets/sec to stress-test the parser. (Requires `sudo`). |
| `make inference_sim` | Sends a sequence of changing input values (Class 0 -> Class 1 -> Class 0) with 1.5s delay to demonstrate the inference logic and LED triggers. (Requires `sudo`). |

**Step-by-Step Demo:**
1.  **Hardware Setup:** Connect the AX7015B Ethernet port to your Linux PC (e.g., `eno1`).
2.  **Program FPGA:** Run `make program`. Verify the "Idle" LED (B8) starts blinking.
3.  **Prepare Test Script:** Edit `scripts/send_inference_vector.py` or `scripts/test_inference_classification.py` to match your PC's interface name (`INTERFACE = "eno1"`).
4.  **Run Traffic:**
    ```bash
    make inference_sim
    ```
5.  **Observe:** Watch the LEDs toggle between Class 0 and Class 1 actions as the "market" input moves.

## 6. Quantitative Latency Benchmark
Because this architecture bypasses standard CPU constraints (no interrupts, no context switching, no DDR memory accesses off-chip), the latency is completely deterministic and quantifiable down to the cycle. 

Operating at an Ethernet MAC frequency of **125 MHz** ($8\text{ns}$ per cycle), the latency profile is as follows:

| Stage | Operations | Cycles | Latency ($8\text{ns}$ clk) |
| :--- | :--- | :--- | :--- |
| **MAC Layer (RX)** | Preamble detect & byte framing | 1 | $8\text{ns}$ |
| **Shift Register Parser** | Byte capture & signature match (`"0050"`) | 4 | $32\text{ns}$ |
| **Systolic NPU Array** | $8\times$ PE Pipeline (Multiply-Accumulate) | 16 | $128\text{ns}$ |
| **Threshold Logic** | Result evaluation | 1 | $8\text{ns}$ |
| **Wiring & Fanout** | Routing delays (conservative estimate) | ~1 | $8\text{ns}$ |
| **Total Hardware Latency** | From payload value arriving to Classification out | **23 Cycles** | **$\approx 184\text{ns}$** |

Compared to a typical high-performance software network stack + user-space inference (which generally requires 5µs - 25µs), this NPU consistently classifies incoming ticks in **under 0.2 microseconds**, creating an enormous competitive advantage for line-rate evaluation.

## 7. Key Concepts Learned

1.  **Systolic Dataflow:** Design pipelines where data moves through processing units (Data-in-Motion) rather than units fetching from memory.
2.  **Network Stack Bypass:** Standard sockets fail in bare-metal FPGA comms; Raw Sockets (Scapy) are essential for Layer 2 verification.
3.  **Pipeline Synchronization:** The importance of matching pipeline depth (latency) with control signals (`valid`) to avoid sampling invalid transient data.
4.  **Hardware Debugging:** Using LEDs as "slow" logic analyzers for "fast" events when an ILA isn't available or practical.
5.  **CDC Discipline:** Managing multiple clock domains (125MHz Ethernet Rx, 100MHz Global, 50MHz AXI) requires careful handshake or FIFO boundaries.
