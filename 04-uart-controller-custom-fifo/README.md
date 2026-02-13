# UART Controller & Custom FIFO Buffer

This project implements a robust Universal Asynchronous Receiver/Transmitter (UART) with a custom Synchronous FIFO buffer on the Alinx AX7015B FPGA board.

## Overview
*   **Goal:** Establish a reliable high-speed communication link between a PC and the FPGA.
*   **Key Feature:** Custom 128-byte Synchronous FIFO functioning as a circular buffer to absorb data bursts.
*   **Target:** Xilinx Zynq-7000 (xc7z015clg485-2).

## Architecture

```text
       PC (HOST)                             FPGA (PL)
    (USB-TTL Adapter)                  (UART Controller)
   ___________________               _____________________
  |                   |    TX ->    |  [UART RX]          |
  |  [Python Script]  |  (Pin M1)   |      |              |
  |                   |             |      v              |
  |   (Verify Echo)   |             |  [ FIFO (128B) ]    |
  |___________________|             |      |              |
           ^               RX <-    |      v              |
           |             (Pin M2)   |  [UART TX]          |
           |________________________|                     |
                                    |_____________________|
```

The system acts as a **smart echo**. It doesn't just wire RX to TX; it captures the data, stores it in memory, and re-transmits it when the transmitter is ready. This validates the hardware's ability to handle asynchronous events and backpressure.

## RTL Modules: Detailed Architecture

### 1. UART Receiver (`rtl/uart_rx.sv`)
**Concept:**
Serial data arrives asynchronously (without a clock). The receiver must synchronize to the start bit and sample the data bits at the correct time.
**Mechanism:**
*   **Oversampling:** The logic runs at 50MHz, but calculates bit timing based on 115200 baud.
*   **Center Sampling:** It counts clock cycles to sample the "middle" of each bit period to maximize stability against noise.
*   **State Machine:** `IDLE` -> `Start Bit` -> `Data Bits (0-7)` -> `Stop Bit`.

### 2. Synchronous FIFO (`rtl/fifo.sv`)
**Concept:**
A First-In-First-Out buffer that acts as an elasticity buffer. The PC might send data faster than the FPGA processes it (or vice versa) in short bursts.
**Implementation:**
*   **Circular Buffer:** A memory array where write and read pointers wrap around infinitely.
*   **Depth:** 128 Bytes. This is critical for modern operating systems (Linux/Windows) which often buffer USB-UART data and release it in 64-byte chunks.
*   **Flags:** `Full` (Stop writing) and `Empty` (Stop reading) generation using pointer comparison.

### 3. UART Transmitter (`rtl/uart_tx.sv`)
**Concept:**
Takes a parallel byte (8 bits) and streams it out serially with correct framing.
**Mechanism:**
*   **Framing:** Automatically adds the Start Bit (0) and Stop Bit (1) around the data payload.
*   **Backpressure:** Only accepts new data when `tx_ready` is high.

### 4. Top Level (`rtl/top.sv`)
**Concept:**
Routes the signals to the physical pins and drives status LEDs.
**Key Logic:**
*   **Loopback:** Connects the FIFO Read port to the UART TX input.
*   **Inversion:** The Alinx AX7015B LEDs are Active Low (0=ON), so logic signals are inverted before driving the pins.

## Hardware Setup (Alinx AX7015B)

**Crucial:** This project runs in Programmable Logic (PL). You cannot use the onboard micro-USB port, as that is hardwired to the Processor System (PS).

| Signal | FPGA Pin | Connection Description |
| :--- | :--- | :--- |
| **RX** | **M1** | Connect to External Adapter **TX** |
| **TX** | **M2** | Connect to External Adapter **RX** |
| **GND** | **GND** | Connect to External Adapter **GND** |
| **5V** | **+5V** | Connect to External Adapter **5V** |
| `leds[0]` | **A5** | FIFO Full (On = Error) |
| `leds[1]` | **A7** | FIFO Empty (On = Idle) |
| `leds[2]` | **A6** | RX Monitor (On = Idle High) |
| `leds[3]` | **B8** | TX Monitor (On = Idle High) |

*Note: The External Adapter used was a CP2102.*

## Usage

### 1. Build & Program
Generate the bitstream and program the FPGA via JTAG:
```bash
make build program
```

### 2. Hardware Verification
Run the automated Python stress test. This script sends random data chunks and verifies the echo.
*   **Prerequisite:** Connect your USB-TTL adapter (e.g., `/dev/ttyUSB0`) to Pins M1/M2.
*   **Important:** Close any other terminals (like `minicom`) to prevent them from stealing data.

```bash
# Run 100 tests with 16-byte chunks
python3 scripts/uart_test.py --port /dev/ttyUSB0
```

### 3. Simulation
To verify the logic without hardware:
```bash
make sim
```

## Implementation Metrics
After running `make build`, the following timing and utilization results were achieved (based on `timing_summary.rpt` and `utilization.rpt`):

| Metric | Target | Actual | Description |
| :--- | :--- | :--- | :--- |
| **WNS (Worst Negative Slack)** | > 0ns | **+16.262 ns** | Timing margin (Setup time) |
| **Baud Rate Error** | < 2% | **0.0064%** | Clock Divider Accuracy |
| **LUT Utilization** | < 5% | **522 (1.13%)** | Logic usage (Slice LUTs) |
| **Register Utilization** | < 5% | **1102 (1.19%)** | Flip-Flop usage |

### Baud Rate Error Calculation
The system clock is 50MHz, and the target baud rate is 115200.
1. **Divider:** $50,000,000 / 115,200 \approx 434.027$ → Integer `434`.
2. **Actual Rate:** $50,000,000 / 434 \approx 115,207.37$ baud.
3. **Error:** $(115,207.37 - 115,200) / 115,200 \approx 0.0064\%$.
This is significantly below the standard UART tolerance of ~2%.

## Concepts, Learnings, and Bugs

### 1. The "Physical Layer" Trap
**Issue:** Our initial tests failed because we assumed the `uart_rx` port in RTL could connect to the onboard USB-UART chip.
**Learning:**
*   **PS vs PL:** The onboard CP2102 chip is hardwired to the Zynq Processing System (PS MIO pins). The Programmable Logic (PL) where our RTL lives cannot physically touch those pins without complex routing through the CPU.
*   **Solution:** We routed the signals to the **Expansion Header (Pins M1/M2)** and used an external USB-TTL adapter. This connects "PL Logic" directly to the outside world.

### 2. The "Minicom Contention" Bug
**Issue:** The hardware loopback test "failed" (Python reported timeouts) even though `minicom` showed received characters.
**Learning:**
*   UART is a shared resource. If `minicom` has the file descriptor (`/dev/ttyUSB0`) open, it drains the OS buffer.
*   When the Python script calls `ser.read()`, the buffer is empty because `minicom` already ate the bytes.
*   **Fix:** Always close other terminal emulators before running automated scripts.

### 3. FIFO Depth vs OS Buffering
**Issue:** The test failed with `Received 16 bytes, Expected 64` when using a small FIFO (32 bytes).
**Learning:**
*   Modern OS drivers (Linux `ftdi_sio`) process USB packets in bursts (often 64 bytes).
*   If the FPGA processes data slower than the burst arrival rate, the FIFO fills up instantly.
*   **Solution:** We increased the FIFO depth to **128 bytes** to handle the full standard USB packet burst + latency overhead.

### 4. Serial "Line Jitter" on Startup
**Issue:** The very first test run would sometimes fail or frame error.
**Learning:**
*   When a serial port opens, the DTR/RTS lines toggle, and the line voltage stabilizes. To the FPGA, glitches look like a "Start Bit" (0), injecting garbage into the FIFO.
*   **Fix:** We added a `time.sleep(0.5)` in the Python script after opening the port to let the line settle, and flush buffers before starting the test.


