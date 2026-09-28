# Performance Evidence

This document separates **measured hardware results**, **implementation/timing-report results**, and **cycle-derived estimates** for the ALINX AX7015B (Zynq-7015) portfolio.

---

## 1. Integrated Datapath Latency — Cycle-Derived

Project 13's integrated path runs at **125 MHz** (8 ns per cycle). The documented pipeline contains 21 FPGA-logic cycles:

| Stage | Cycles @ 125 MHz | Derived time |
| --- | ---: | ---: |
| RGMII RX + MAC/parser | 4 | 32 ns |
| NPU pipeline | 16 | 128 ns |
| GPIO output | 1 | 8 ns |
| **Total FPGA logic** | **21** | **168 ns** |

**Interpretation:** 168 ns is a **cycle-count-derived RTL latency budget**, excluding PHY delay. It is not an independent oscilloscope measurement, and this repository does not claim a measured ±0 ns jitter result.

Project 12 separately exercises a DSP48E1 processing element at **250 MHz**. That isolated result should not be read as the operating frequency of the integrated Project 13 datapath.

---

## 2. PCIe XDMA Throughput — Measured

Measured using the XDMA host transfer tools over PCIe Gen2 x2:

| Direction | Measured throughput |
| --- | ---: |
| **Host to Card (H2C)** | **841 MB/s** |
| **Card to Host (C2H)** | **820 MB/s** |

These are host-side transfer measurements from the Project 11 validation workflow.

---

## 3. Project 13 Implementation Evidence

The Project 13 README records the following Vivado implementation results:

| Metric | Recorded result |
| --- | ---: |
| LUTs | **1,165 (2.5%)** |
| FFs | **2,118 (2.3%)** |
| DSPs | **8 (5.0%)** |
| Integrated core clock | **125 MHz** |
| Core setup timing | **WNS +1.175 ns** |

**Timing caveat:** the Project 13 status is **Mixed**, because CDC paths remained flagged and require explicit constraints. The positive core WNS should therefore not be presented as proof that every path in the complete design was cleanly constrained.

---

## 4. Clock Domains

| Domain / project | Frequency | Evidence scope |
| --- | ---: | --- |
| Integrated Project 13 datapath | **125 MHz** | Current integrated design |
| Project 12 DSP48E1 PE | **250 MHz** | Separate/isolated PE experiment |
| PCIe XDMA user logic | **62.5 MHz** | Project 11 host interface |
| System/control clocks | project-specific | See individual build/constraint files |

---

## 5. Claims Deliberately Excluded

This repository does **not** present the following as measured results:

- board power below a specific wattage;
- an x86-vs-FPGA energy-efficiency multiplier;
- zero measured timing jitter;
- a validated 128+ PE implementation on Versal;
- sub-100 ns latency for the current integrated Project 13 design.

Those may be reasonable subjects for future experiments, but they require dedicated measurement or implementation evidence.
