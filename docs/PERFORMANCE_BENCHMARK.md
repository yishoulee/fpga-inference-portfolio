# Performance and Validation Evidence

This document separates **recorded host-side benchmarks**, **implementation/timing notes**, and **cycle-derived RTL quantities** for the ALINX AX7015B (Zynq-7015) portfolio.

## 1. RGMII Receive Path

Project 09 validates physical frame reception on the custom RGMII path using host packet injection and Vivado ILA.

The interface uses a 125 MHz, 4-bit, double-data-rate receive bus, corresponding to the standard Gigabit Ethernet line rate. This repository does **not** contain a sustained application-throughput benchmark or a formal BER/packet-loss test.

## 2. PCIe XDMA Host-Side Benchmark

Project 11 includes a Python benchmark that writes and reads buffers through the XDMA character devices and verifies returned data.

The project notes record:

| Direction | Recorded project result |
| --- | ---: |
| **Host to Card (H2C)** | **841 MB/s** |
| **Card to Host (C2H)** | **>590 MB/s** |

The benchmark script is source-controlled, but the original raw terminal output is not stored as a separate artifact. These values should therefore be read as **recorded project results**, not independently archived lab measurements.

The path is not described as end-to-end zero-copy; the benchmark uses ordinary file `write()` and `read()` operations on `/dev/xdma*`.

## 3. Project 13 Implementation Notes

The Project 13 README records:

| Metric | Recorded result |
| --- | ---: |
| LUTs | **1,165 (2.5%)** |
| FFs | **2,118 (2.3%)** |
| DSPs | **8 (5.0%)** |
| Integrated datapath clock | **125 MHz** |
| Core setup result | **WNS +1.175 ns** |

**Timing caveat:** the overall timing status is **Mixed** because CDC paths remained flagged and require explicit constraints.

## 4. Cycle-Derived Compute-Pipeline Quantity

The NPU RTL delays `result_valid` through a **16-cycle pipeline**.

At 125 MHz:

`16 cycles × 8 ns/cycle = 128 ns`

This is an internal **cycle-derived quantity**, not a measured end-to-end packet-to-output latency.

Earlier documentation contained conflicting complete-path totals of 168 ns and 184 ns. Those are no longer presented as portfolio benchmarks.

## 5. Separate 250 MHz Experiment

Project 12 separately exercises a DSP48E1 processing element at **250 MHz**. That result belongs to the isolated PE experiment and should not be read as the integrated Project 13 clock rate.

## 6. Claims Excluded

This repository does not present the following as measured results:

- zero BER or zero packet loss;
- certified sustained 1 Gbit/s application throughput;
- an 820 MB/s C2H benchmark;
- board power below a specific wattage;
- an FPGA-vs-CPU energy-efficiency multiplier;
- zero measured timing jitter;
- a validated 128+ PE implementation;
- a verified end-to-end nanosecond latency for Project 13.
