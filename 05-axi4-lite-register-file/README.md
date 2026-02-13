# AXI4-Lite Register File

This project implements an **AXI4-Lite Slave** peripheral that bridges the Zynq Processing System (ARM Cortex-A9) with custom FPGA logic. It serves as the fundamental control plane for hardware acceleration modules.

## Overview
*   **Goal:** Allow the Zynq ARM processor to control hardware (LEDs) and read status (Flags) via memory-mapped I/O.
*   **Key Feature:** Full AXI4-Lite Slave interface implementation with independent Read/Write channels and memory mapping.
*   **Target:** Xilinx Zynq-7000 (xc7z015clg485-2).

## Architecture

```text
       ZYNQ PS (ARM)                         FPGA PL (AXI Slave)
    (Software Domain)                       (Hardware Domain)
   ___________________                     _____________________
  |                   |                   |                     |
  |  [Linux / XSDB]   |  =============>   |  [AXI Write FSM]    |
  |                   |   AXI4-Lite       |          |          |
  | Write 0x43C00000  |   (Data Bus)      |          v          |
  |___________________|                   |    [Registers]      |
            |                             |     0x00: Ctrl      |---> [LEDs]
            |                             |     0x04: Status    |<--- [Hardwired Status]
            |                             |     0x08: Scratch   |
            |                             |          |          |
      [Read Response] <================   |  [AXI Read FSM]     |
                                          |_____________________|
```

The core of this project is the **AXI4-Lite Slave Interface**. Unlike simple signals (like buttons/LEDs), AXI is a transactional protocol. The CPU issues a "Write Command" to a specific address, and the FPGA must handshake, accept the data, route it to the correct internal register, and send a response.

## RTL Modules: Detailed Architecture

### 1. AXI4-Lite Slave (`rtl/axi_lite_slave.v`)
**Concept:**
The Advanced eXtensible Interface (AXI) is the standard bus protocol for ARM-based SoCs. "Lite" means it does not support burst transactions, making it ideal for low-speed configuration registers.
**Channels Implemented:** (5 Total)
1.  **Write Address (AW):** Handshakes valid address from Master.
2.  **Write Data (W):** Handshakes valid data from Master.
3.  **Write Response (B):** Sent by Slave to confirm write success.
4.  **Read Address (AR):** Master requests data from an address.
5.  **Read Data (R):** Slave returns requested data.

**State Machine Logic:**
*   **Write Path:** Uses a combined ready strategy. It asserts `awready` and `wready` only when **both** valid signals (`awvalid`, `wvalid`) are present. This simplifies logic by treating the address and data as a single atomic event.
*   **Read Path:** Latches the read address (`araddr`), looks up the register value in the next cycle, and drives `rdata` along with `rvalid`.

**Register Map (Base: 0x43C0_0000):**
| Offset | Name | Permissions | Function |
| :--- | :--- | :--- | :--- |
| `0x00` | **Control** | R/W | **Bit [3:0]**: Controls Board LEDs. |
| `0x04` | **Status** | Read-Only | Hardwired test value (`0xDEADBEEF`). |
| `0x08` | **Scratchpad** | R/W | General purpose storage to verify integrity. |

## Usage

This project uses a `Makefile` to automate the entire FPGA workflow, from simulation to hardware testing.

### 1. Simulation (Verify Logic)
Runs the SystemVerilog testbench (`tb/tb_axi_lite_slave.sv`) to verify the AXI handshake and register logic.
```bash
make sim
```

### 2. Build Hardware (Synthesize & Bitstream)
Generates the Zynq Block Design, synthesizes the RTL, implments the design, and generates the `.bit` file.
```bash
make build
```

### 3. Program FPGA
Loads the bitstream (`system_wrapper.bit`) onto the Zynq board via JTAG.
```bash
make program
```

### 4. Test on Hardware
Runs a Tcl script (`scripts/test_jtag.tcl`) via the Xilinx System Debugger (XSDB). This script acts as the "Master," issuing memory reads and writes to the AXI bus to verify the hardware is working.
```bash
make test
```
*Expected Output:*
```text
Turning LED 0 ON, others OFF (Active Low: Writing 0xE -> 1110)...
Read Back: 0x0000000E
RESULT: PASS
```

### 5. LED Demo (Visual)
Runs a script (`scripts/demo_leds.tcl`) that plays light patterns (scanner, binary counter) on the LEDs to serve as a physical confirmation of the AXI link.
```bash
make demo
```

## Implementation Metrics
After running `make build`, the following timing and utilization results were achieved (based on `system_wrapper_timing_summary_routed.rpt` and `system_wrapper_utilization_placed.rpt`):

| Metric | Target | Actual | Description |
| :--- | :--- | :--- | :--- |
| **WNS (50MHz)** | > 0ns | **+14.984 ns** | Worst Negative Slack (Positive = Timing Met) |
| **LUT Utilization** | < 1% | **390 (0.84%)** | Logic usage (Slice LUTs) |
| **Register Utilization** | < 1% | **535 (0.58%)** | Flip-Flop usage |
| **Read Latency** | Fixed | **1 Cycle** | Time from Address handshake to Data valid. |

## Setup & Implementation Details

### Zynq Block Design
In previous projects (Project 1-4), the design was "PL Only" (Programmable Logic). This project is a complete **Embedded System**:
1.  **Zynq Processing System (PS):** The "Brain" (ARM Core).
2.  **AXI Interconnect:** The "Nervous System" connecting Brain to FPGA.
3.  **AXI Slave:** The "Limb" (Our Custom IP).

### Constraints
*   **LEDs:** Mapped to physical pins `A5, A7, A6, B8`.
*   **Clocks:** The AXI clock is provided by the Zynq PS (`FCLK_CLK0`), so no external clock pin constraints are needed in the XDC file.

## Key Concepts Learned

1.  **Memory Mapped I/O (MMIO):**
    *   Hardware control is fundamentally just checking values at specific memory addresses. By writing to `0x43C00000`, the software "talks" to the hardware. All device driver development starts with this concept.

2.  **The AXI Handshake Protocol:**
    *   **Valid/Ready Handshake:** Data only transfers when both `VALID` (Source) and `READY` (Destination) are High in the same clock cycle.
    *   **Deadlock Prevention:** A master must not wait for `READY` to assert `VALID`, preventing circular dependencies where both sides wait for each other.
    *   **Independent Channels:** Write Address, Write Data, and Write Response are separate phases. Our implementation simplified this by waiting for both Address and Data to be valid, a common strategy for simple Slave peripherals.

3.  **Hardware/Software Co-Design:**
    *   The FPGA is no longer an isolated island (PL-only). It is an accelerator attached to a CPU (PS).
    *   The CPU handles complex, non-deterministic tasks (Linux, Networking, Logging).
    *   The FPGA handles high-speed, deterministic tasks (Trading Logic, Signal Processing).
    *   The Register File is the "glue" that allows these two domains to coordinate.

4.  **Debugging with XSDB (Xilinx System Debugger):**
    *   We learned to use JTAG not just for programming the bitstream, but for active debugging.
    *   By using `mwr` (Memory Write) and `mrd` (Memory Read) commands in the Tcl console, we could verify the hardware logic without needing to boot a full Linux OS or write a C driver.
    *   We learned how `memmap` or `-force` flags are sometimes needed to bypass tool safety checks when accessing raw addresses.

5.  **Tooling Nuances:**
    *   We discovered that Vivado's Block Diagram "Module Reference" flow can be picky about SystemVerilog (`.sv`) as the top-level file, sometimes requiring standard Verilog (`.v`) or careful wrapper generation.