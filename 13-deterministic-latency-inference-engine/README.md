# Project 13: Integrated Packet-to-Compute FPGA Pipeline

## Overview

This project integrates the earlier RGMII, packet-processing, configuration, and systolic-compute work into one Zynq-7000 hardware pipeline.

On physical hardware, the project received host-generated Ethernet frames, matched the configured feature pattern, propagated data through the compute path, and drove the expected LED classification outputs.

The project is best read as **integration and hardware-validation evidence**, not as a production inference engine or a complete low-latency benchmark.

## Integrated Path

```text
Ethernet PHY
    |
    v
RGMII RX / MAC
    |
    v
Streaming pattern parser
    |
    v
8-stage MAC pipeline
    |
    v
Threshold comparison
    |
    v
LED / trigger output
```

The integrated data path operates in the **125 MHz Ethernet receive clock domain**.

## Hardware Bring-Up and Debugging

### Layer-2 packet injection

Normal host UDP transmission depended on ARP behavior that the receive-only FPGA design did not satisfy. The test workflow therefore used **Scapy raw Layer-2 injection** to send frames directly for hardware validation.

### RGMII regression

When the integrated design stopped recognizing valid Ethernet frames, ILA-based debugging traced the problem to receive-clock alignment. Restoring the working phase configuration recovered frame reception.

### Parser robustness

The parser moved away from relying on one absolute byte offset and instead uses a shift-register pattern match for the configured feature identifier before extracting the subsequent value.

### Configuration initialization

The compute result remained zero on hardware until weights and threshold values were explicitly supplied. VIO was used to inject those values during validation.

## Implementation Evidence

The Project 13 implementation notes record:

| Item | Recorded result |
| --- | ---: |
| LUTs | **1,165 (2.5%)** |
| FFs | **2,118 (2.3%)** |
| DSPs | **8 (5.0%)** |
| Integrated datapath clock | **125 MHz** |
| Core setup result | **WNS +1.175 ns** |

### Timing caveat

The timing status is **Mixed**. The core 125 MHz setup result was positive, but CDC paths remained flagged and require explicit constraint work.

That means this project should **not** be described as globally timing-clean.

## Hardware Validation

The project notes record successful:

- RTL simulation of the parser/compute behavior;
- synthesis and implementation;
- Scapy packet injection on physical hardware;
- feature-pattern detection;
- expected low/high classification LED behavior.

These tests demonstrate functional integration of the path.

## Latency: What the RTL Supports

The NPU module deliberately delays `result_valid` through a **16-cycle valid pipeline** to align it with the 8 processing elements.

At 125 MHz, 16 cycles correspond to **128 ns**. This is a **cycle-derived internal pipeline figure**.

The repository previously contained conflicting complete-path estimates of **168 ns** and **184 ns**. Those estimates mixed different assumptions about MAC, parser, output, and routing stages.

Until the complete packet-to-output path is measured or re-derived from one controlled definition, this project does **not** claim a verified end-to-end nanosecond latency number.

It also does not claim measured zero jitter or a performance advantage over a particular software networking stack.

## Relevant RTL

- `rtl/mac_rx.sv` — receive framing
- `rtl/udp_parser.sv` — streaming feature-pattern detection
- `rtl/npu_core.sv` — 8-stage compute pipeline and valid alignment
- `rtl/mac_pe.sv` — pipelined multiply-accumulate processing element
- `rtl/axi_weight_regs.sv` — configuration registers
- `rtl/top.sv` — system integration and LED outputs

## Reproducing the Workflow

```bash
make build
make program
make sim
make packet_test
make inference_sim
```

The hardware test scripts require the host network interface to be configured appropriately and raw-packet transmission privileges.

## Scope and Limitations

This project demonstrates:

- FPGA subsystem integration;
- physical Ethernet receive-path debugging;
- streaming parsing;
- pipelined compute integration;
- hardware configuration/debug with VIO;
- observable end-to-end functional behavior through the LED outputs.

It does **not** establish:

- an oscilloscope-measured end-to-end latency;
- zero timing jitter;
- globally clean CDC timing;
- production networking-stack behavior;
- a controlled FPGA-vs-CPU performance comparison.
