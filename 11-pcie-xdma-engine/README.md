# Project 11: PCIe Gen2 x2 XDMA Engine

## 1. Project Overview
This project implements a **high-performance PCIe-to-AXI4 bridge** using the Xilinx XDMA IP Core on the **Alinx AX7015B** (Zynq-7015). It demonstrates how to transfer data between a Linux Host PC and Zynq PS DDR3 Memory at speeds approaching the theoretical limit of the PCIe Gen2 x2 link.

**Key Features:**
- **High Throughput:** Achieves **>800 MB/s** Write and **>590 MB/s** Read speeds.
- **DMA Offload:** Uses the Scatter-Gather DMA engine to move data without CPU overhead.
- **Zero-Copy Architecture:** Writes directly to main system memory (DDR3) via the Zynq HP0 port.
- **Driver Integration:** Validated with the official Xilinx XDMA Linux Kernel Driver.

## 2. Background: DMA vs XDMA
**DMA (Direct Memory Access)** is a general concept in computer architecture. It refers to a specialized hardware module that can transfer data between memory locations without the CPU's constant intervention.

**XDMA (Xilinx DMA Subsystem for PCI Express)** is a specific, high-performance IP core provided by Xilinx. It combines a **PCIe Endpoint** (handling logical/phy layers) with a **DMA Engine** (handling data movement).

In short: **DMA** is the *concept* (moving memory), and **XDMA** is the *tool* (Xilinx IP) we use to achieve high-performance PCIe transfers.

## 3. System Architecture
The design connects the Host PC's PCIe bus directly to the FPGA's DDR3 memory via the XDMA engine and the Zynq Processing System (PS).

```text
+-----------------------------------------------------------+
|                  HOST PC (Linux Kernel 6.x)               |
|                                                           |
|  +-----------------------------------------------------+  |
|  |                User Space Application               |  |
|  |           (Python Script / C++ HFT Logic)           |  |
|  |                                                     |  |
|  |   [ Buffer A (Write) ]       [ Buffer B (Read) ]    |  |
|  +--------------------------+--------------------------+  |
|                             ^                             |
|                             | mmap()                      |
|                             v                             |
|  +-----------------------------------------------------+  |
|  |                 Kernel Space Drivers                |  |
|  |                                                     |  |
|  |      /dev/xdma0_h2c_0        /dev/xdma0_c2h_0       |  |
|  |             |                       ^               |  |
|  |             v                       |               |  |
|  |    [ XilinX XDMA Driver (xdma.ko) - SG-DMA ]        |  |
|  +--------------------------+--------------------------+  |
|                             |                             |
|                             v                             |
|                    [ PCIe Root Complex ]                  |
+-----------------------------+-----------------------------+
                              |
                              | PCIe Gen2 x2 (10 Gbps Raw)
                              | (Network Layer / TLP Packets)
                              |
+-----------------------------v-----------------------------+
|                     FPGA (Alinx AX7015)                   |
|                                                           |
|    +------------------------+                             |
|    |      PCIe Hard IP      | (GTP Transceivers)          |
|    +-----------+------------+                             |
|                |                                          |
|                v AXI4-Stream (Internal)                   |
|                |                                          |
|    +-----------+------------+                             |
|    |     XDMA IP Core       |                             |
|    |    (DMA Subsystem)     |                             |
|    |                        |                             |
|    |  [ Scatter-Gather  ]   |                             |
|    |  [    Engine       ]   |                             |
|    +-----------+------------+                             |
|                |                                          |
|                | AXI4 Memory Mapped                       |
|                | (128-bit @ 125 MHz)                      |
|                v                                          |
|    +-----------+------------+                             |
|    |    AXI SmartConnect    |                             |
|    |    (Interconnect)      |                             |
|    +-----------+------------+                             |
|                |                                          |
|                | AXI HP0 (High Performance)               |
|                | (64-bit Path)                            |
|                v                                          |
| +--------------+---------------+                          |
| |    Zynq Processing System    |                          |
| |          (PS - ARM)          |                          |
| |                              |                          |
| |   [ DDR3 Memory Controller ] |                          |
| +--------------+---------------+                          |
|                |                                          |
|                | DDR Interface                            |
|                v                                          |
|      +---------+---------+                                |
|      |    DDR3 SDRAM     |                                |
|      |      (1 GB)       |                                |
|      +-------------------+                                |
+-----------------------------------------------------------+
```

### Hardware Flow
1.  **Host-to-Card (H2C):** The Host defines a source buffer in RAM. The XDMA engine reads this data via PCIe and writes it to the Zynq PS DDR3 via the High-Performance (HP0) port.
2.  **Card-to-Host (C2H):** The XDMA engine reads data from Zynq PS DDR3 and writes it to the Host RAM via PCIe.

## 4. Hardware Setup
1.  Alinx AX7015B FPGA Board.
2.  Host PC running Linux (with free PCIe x4 or x16 slot).
3.  Xilinx XDMA Drivers installed on Host.

## 5. Directory Structure

*   `Makefile`: Main entry point for building, programming, and testing the project.
*   `constraints/`:
    *   `AX7015B.xdc`: Physical constraints for PCIe lanes and Reference Clock.
*   `scripts/`:
    *   `build.tcl`: Tcl script for Vivado to create the project, block design, and bitstream.
    *   `program_xsct.tcl`: XSCT script to program the FPGA and initialize the Zynq PS (DDR).
    *   `ps_config.tcl`: Helper script defining the Zynq Processing System configuration.
    *   `test_throughput.py`: Python script for host-side performance benchmarking.
*   `dma_ip_drivers/`: (Created during build) The official Xilinx XDMA driver repository.

## 6. Build Instructions
1.  **Generate Bitstream**:
    Run the Vivado build script to create the project, block design, and bitstream.
    ```bash
    make build
    ```

2.  **Program FPGA**:
    Use the provided script (via XSCT) to program the PL and initialize the PS (DDR controller).
    ```bash
    make program
    ```
    *Note: The `ps7_init.tcl` sequence is critical to wake up the DDR controller.*

## 7. Linux Driver Setup & Modifications (The Missing Piece)
The official Xilinx driver does not support custom boards out of the box. We had to modify the source code to recognize our Alinx AX7015B implementation.

### Step 1: Clone the Driver
We used the official Xilinx DMA driver repository:
```bash
git clone https://github.com/Xilinx/dma_ip_drivers
cd dma_ip_drivers/XDMA/linux-kernel/xdma
```

### Step 2: The Critical Modification (Device ID)
By default, the driver only looks for standard Xilinx evaluation boards (e.g., KC705, VCU118). Our project configured the PCIe Endpoint with **Device ID: `0x7015`**. We had to add this ID to the driver's lookup table.

**File:** `dma_ip_drivers/XDMA/linux-kernel/xdma/xdma_mod.c`  
**Change:** Added `{ PCI_DEVICE(0x10ee, 0x7015), },` to the `pci_ids` array.

```c
/* dma_ip_drivers/XDMA/linux-kernel/xdma/xdma_mod.c */
static const struct pci_device_id pci_ids[] = {
    { PCI_DEVICE(0x10ee, 0x9011), },
    { PCI_DEVICE(0x10ee, 0x9012), },
    // ... existing IDs ...
    { PCI_DEVICE(0x10ee, 0x7015), }, // <--- ADDED THIS LINE
    { 0, }
};
MODULE_DEVICE_TABLE(pci, pci_ids);
```

### Step 3: Compilation Fixes (The "Header Hell")
When we initially tried to compile the driver using `make`, it failed with missing header errors. The official repository structure separates the common library headers (`libxdma`) from the kernel module source, which confuses the Makefile on some modern kernel builds (v6.x).

**The Bug:**
```text
xdma_mod.c: fatal error: libxdma.h: No such file or directory
```

**The Fix:**
We had to flatten the include path by copying the required headers into the local source directory.

1.  Navigate to the kernel module source:
    ```bash
    cd dma_ip_drivers/XDMA/linux-kernel/xdma
    ```
2.  Copy the missing headers from the parent/common directories:
    ```bash
    # The driver expects libxdma.h to be in the include path
    cp ../include/libxdma.h .
    cp ../include/libxdma_api.h .
    ```
    *(Note: Depending on the specific repo version, you might also need to edit the `Makefile` to explicitly add `-I.` to the `ccflags-y`)*.

3.  **Compile:**
    ```bash
    make
    ```
    *   **Result:** Generates `xdma.ko` (Kernel Object) without errors.

### Step 4: Compiling the Validated Tools
In addition to the driver, we compiled the userspace tools to verify data transfer without writing custom code immediately.

1.  Navigate to the tools directory:
    ```bash
    cd ../tools
    ```
2.  Compile the tools:
    ```bash
    make
    ```
    *   **Result:** Generates binaries: `dma_to_device`, `dma_from_device`, `reg_rw`, `performance`.

### Step 5: Installation & Verification
Load the unmodified driver:
```bash
sudo insmod ../xdma/xdma.ko
```
Check if the device nodes are created:
```bash
ls -l /dev/xdma*
# Output should show:
# /dev/xdma0_c2h_0  (Card-to-Host DMA)
# /dev/xdma0_h2c_0  (Host-to-Card DMA)
# /dev/xdma0_control
# /dev/xdma0_user
```
*   If `/dev/xdma*` does not appear, check `sudo dmesg | grep xdma` for errors or verify the Device ID patch.

## 8. The Saga of the Bugs: A Story of Troubleshooting

This project was not built in a day. It was forged in the fires of segmentation faults, kernel panics, and silent failures. Here is the detailed history of the bugs we agonized over and how we fixed them.

### 1. The BRAM Trap (Architecture Failure)
*   **The Bug:** We initially designed the system to use Block RAM (BRAM) as the destination for PCIe transfers.
*   **The Agony:** The Zynq 7015 has very limited BRAM (~2.1Mbit). When we tried to transfer anything larger than a few kilobytes, the system would hang or the transfer would fail because we physically ran out of memory on the chip. We were trying to push a river through a straw.
*   **The Fix:** We pivoted the entire architecture to use the **Zynq Processing System (PS) DDR3 Memory** (1GB). We connected the XDMA AXI Master to the `S_AXI_HP0` (High Performance) port on the Zynq PS. This allowed us to use massive buffers (256MB+) and achieve true high-throughput DMA.

### 2. The Device ID Mismatch (Driver Invisibility)
*   **The Bug:** After compiling the standard Xilinx XDMA driver and loading it (`insmod xdma.ko`), no devices appeared in `/dev/`. `lspci` showed the device, but the driver ignored it.
*   **The Agony:** We spent hours checking kernel logs (`dmesg`) which were strangely silent. The driver loaded successfully but did nothing.
*   **The Fix:** We realized the default Xilinx driver source code did not include the specific PCIe Device ID for our board implementation (which we set to `0x7015` in Vivado). We had to manually patch the driver's `pci_ids.h` (or equivalent table) to recognize Device ID `0x7015` as a valid XDMA target.

### 3. The Zombie PCIe Link (Hotplug & Rescan)
*   **The Bug:** Every time we reprogrammed the FPGA using JTAG (`xsct scripts/program_xsct.tcl`), the Linux host would lose contact with the PCIe device. The `xdma` driver would crash or refuse to reload with "Device not found."
*   **The Agony:** We thought we had to reboot the entire computer every time we changed the Bitstream. This made iteration incredibly slow (5 minutes per test cycle).
*   **The Fix:** We mastered Linux PCI Hotplug commands. We learned to "remove" the device before programming and "rescan" the bus after programming:
    ```bash
    # Before programming
    echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove
    # ... Program FPGA ...
    # After programming
    echo 1 > /sys/bus/pci/rescan
    ```
    This allowed us to reload the driver without rebooting.

### 4. The "Heisenbug" Benchmark (Python Timing)
*   **The Bug:** Our throughput verification script (`scripts/test_throughput.py`) was reporting abysmal write speeds (150 MB/s), far below the theoretical max of Gen2 x2 (800-900 MB/s).
*   **The Agony:** We blamed the FPGA timing constraints, the AXI width, and the DDR3 controller. we tweaked the `AXI_DATA_WIDTH` to 128-bit, 64-bit, checked clock domain crossings, but nothing improved the speed.
*   **The Fix:** The bug was in the Python test script itself.
    *   *Bad Code:* We were generating random data (`os.urandom`) **inside** the timer loop.
    *   *Reality:* We were benchmarking the CPU's ability to generate random numbers, not the PCIe bus speed.
    *   *Correction:* We moved the data generation **outside** the timer.
    *   *Result:* Write speed instantly jumped to **841 MB/s**.

### 5. The DDR3 Initialization (The "hang")
*   **The Bug:** The XDMA core would stall indefinitely on the first transaction. The AXI bus would lock up.
*   **The Agony:** The ILA (Integrated Logic Analyzer) showed the XDMA issuing a write request, but the Zynq HP0 port never responded with `BRESP`.
*   **The Fix:** We realized the Zynq PS and DDR controller were not initialized. On a bare-metal FPGA running via JTAG, the PS is dormant. We had to run `ps7_init.tcl` (exported from Vivado) via the `xsct` shell to release the DDR reset lines and configure the timings before the PL could talk to memory.

### 6. The "Error 512" (PCIe Link Reset)
*   **The Bug:** After running `make program` to update the bitstream, the `test_throughput.py` script immediately fails with `[Errno 512] Unknown error 512` or `OSError: [Errno 5] Input/output error`.
*   **The Cause:** Reprogramming the FPGA via JTAG resets the PCIe Endpoint logic (the XDMA core). The Linux kernel loses sync with the hardware, rendering the existing `/dev/xdma*` handles stale or invalid. Simply reloading the driver often fails because the kernel doesn't realize the physical hardware has "changed."
*   **The Fix:** You must perform a full PCI device removal and rescan cycle to clean up the stale state.
    ```bash
    # 1. Unload the driver
    sudo rmmod xdma
    # 2. Tell Linux to "forget" the device (clears kernel state)
    echo 1 | sudo tee /sys/bus/pci/devices/0000:01:00.0/remove
    # 3. Rescan to find the "new" device
    echo 1 | sudo tee /sys/bus/pci/rescan
    # 4. Reload driver
    sudo insmod dma_ip_drivers/XDMA/linux-kernel/xdma/xdma.ko
    ```

## 9. Validation Matrix & KPIs

### Performance Metrics
The primary goal was maximizing throughput on the Gen2 x2 link.

| Metric | Target (Gen2 x2) | Measured / Actual | Status | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **Write Throughput (H2C)** | > 700 MB/s | **841.21 MB/s** | **PASS** | Python `test_throughput.py` (64MB blocks) |
| **Read Throughput (C2H)** | > 700 MB/s | **593.55 MB/s** | **PARTIAL** | Python `test_throughput.py` (64MB blocks) |
| **Data Integrity** | 100% Match | **100% Match** | **PASS** | SHA-256 / Full Buffer Compare |
| **Stability** | No Hangs | **Stable** | **PASS** | Multiple 1GB transfers |

### Throughput Analysis
*   **PCIe Theoretical Max:** 5.0 GT/s * 2 lanes * (8/10 encoding) = 8 Gbps = **1000 MB/s**.
*   **Overhead:** PCIe TLP Headers, DLLP, Physical Layer overhead typically consume 15-20%.
*   **Real-World Max:** ~800-850 MB/s.
*   **Asymmetry Explanation:**
    1.  **H2C (Write) @ 841 MB/s:** This saturates the Gen2 x2 link. The Host pushes data efficiently to the FPGA.
    2.  **C2H (Read) @ 593 MB/s:** This is lower due to the AXI Read latency on the Zynq HP0 port. The XDMA core (128-bit internal) must arbitrate down to the PS HP0 port (64-bit), and AXI Read channels have higher protocol overhead than posted Writes. Additionally, many consumer motherboard Root Complexes are optimized for H2C traffic (GPUs) rather than C2H.

### Resource Utilization (Zynq 7015)
The design fits comfortably within the modest Zynq 7015, leaving ample room for user logic (HFT strategies).

| Resource | Used | Available | Utilization % |
| :--- | :--- | :--- | :--- |
| **LUTs** | 12,579 | 46,200 | **27.23%** |
| **Registers** | 14,299 | 92,400 | **15.48%** |
| **Block RAM** | 20.5 | 95 | **21.58%** |
| **PCIe Hard IP** | 1 | 1 | **100%** |
| **GTP Transceivers** | 2 | 4 | **50%** |
| **DSP48** | 0 | 160 | **0.00%** |

### Timing Closure
*   **Status:** Met (Clean)
*   **Worst Negative Slack (WNS):** +4.259 ns (125 MHz Clock)
*   **Worst Hold Slack (WHS):** +0.100 ns
*   **Target Clock:** 125 MHz (for 128-bit AXI data path)

## 10. Testing
1.  **Reload Driver (Fix for Error 512)**:
    If the FPGA was re-programmed, use this sequence to fully reset the PCIe link and reload the driver.
    ```bash
    make reset_pcie
    ```
    *(This runs the `rmmod` -> `remove` -> `rescan` -> `insmod` cycle automatically)*.

2.  **Throughput Test:**
    Run the provided Python script to test 4MB and 64MB transfers.
    ```bash
    sudo python3 scripts/test_throughput.py
    ```

## 11. Learnings & Concepts Applied

This project bridged the gap between abstract FPGA logic and real-world high-performance computing. We moved beyond simple GPIO/UART to master the dominant interconnect of modern datacenters: **PCIe**.

### Core Concepts
1.  **PCIe Enumeration & Hotplug**:
    *   **Concept**: The PCI bus is enumerated at boot. FPGAs are unique because their hardware identity disappears when reprogrammed.
    *   **Application**: We learned to manually manipulate the Linux Kernel PCI subsystem (`/sys/bus/pci/rescan`) to hot-swap the FPGA logic without rebooting the host capability usually reserved for expensive enterprise chassis.

2.  **DMA Scatter-Gather (SG)**:
    *   **Concept**: Operating Systems rarely allocate large buffers (e.g., 64MB) in physically contiguous blocks. They scatter pages across RAM.
    *   **Application**: The XDMA engine handles "Scatter-Gather" descriptors, allowing us to present a virtually contiguous user-space buffer to the FPGA, while the hardware navigates the fragmented physical memory map automatically.

3.  **Zynq PS-PL Co-Design**:
    *   **Concept**: The Zynq SoC is not just an FPGA; it's an ARM processor with FPGA fabric attached.
    *   **Application**: We learned that the **Processing System (PS)** is the master of the board's resources (like DDR3). The **Programmable Logic (PL)** cannot access memory until the PS is initialized (`ps7_init.tcl`). This dependency is critical for any Zynq-based accelerator.

4.  **Hardware-Software co-debugging**:
    *   **Concept**: Bugs can hide in the Hardware (PL), the Driver (Kernel), or the Application (User Space).
    *   **Application**: We debugged across the full stack:
        *   *Hardware*: ILA to verify AXI handshakes.
        *   *Kernel*: `dmesg` to debug PCIe link training and BAR mapping.
        *   *Software*: Python scripts to verify data integrity and throughput.

5.  **Zero-Copy Architecture**:
    *   **Concept**: Traditional drivers copy data Kernel -> User Space (slow).
    *   **Application**: By using the XDMA driver's character device (`/dev/xdma*`), we map the DMA destination directly into user-space memory, achieving near wire-speed throughput (841 MB/s) by eliminating CPU copy operations.