# Project 11: PCIe Gen2 x2 XDMA Linux Integration

## Overview

This project integrates the Xilinx XDMA subsystem on the ALINX AX7015B (Zynq-7015) with a Linux host and exercises host↔card data transfers over **PCIe Gen2 x2**.

The work covers FPGA integration, Linux driver bring-up, host transfer testing, data verification, and benchmark debugging.

## What Was Demonstrated

- PCIe Gen2 x2 endpoint bring-up with Xilinx XDMA.
- Linux `/dev/xdma0_h2c_0` and `/dev/xdma0_c2h_0` transfer paths.
- Host-side transfer testing using 4 MB and 64 MB buffers.
- Read-back data verification in `scripts/test_throughput.py`.
- Debugging of an initially misleading benchmark caused by generating random test data inside the timed section.
- Project notes record a host-to-card result of **841 MB/s** and read performance above **590 MB/s**.

## Benchmark Method

The included Python script:

1. Generates the test buffer **before** starting the timer.
2. Writes the buffer through `/dev/xdma0_h2c_0`.
3. Reads it back through `/dev/xdma0_c2h_0`.
4. Calculates host-observed MB/s.
5. Compares the returned data with the original buffer.

```bash
sudo python3 scripts/test_throughput.py
```

### Evidence caveat

The benchmark script is source-controlled, but the raw terminal output from the original benchmark run is not stored as a separate artifact in this repository.

Accordingly, **841 MB/s H2C** and **>590 MB/s C2H** should be read as results recorded in the project notes and reproducible with the included workflow, not as independently archived lab measurements.

## DMA terminology

Earlier versions of this README called the path **zero-copy**. That wording was too strong.

The Python benchmark uses normal file `write()` and `read()` operations on the XDMA character devices. The XDMA engine offloads PCIe/AXI data movement, but this repository does not establish an end-to-end zero-copy userspace architecture.

Likewise, DMA reduces CPU involvement in moving the payload, but it should not be described as having literally **zero CPU overhead**.

## System Path

```text
Linux user process
        |
        v
/dev/xdma0_h2c_0  /  /dev/xdma0_c2h_0
        |
        v
Xilinx XDMA driver
        |
        v
PCIe Gen2 x2
        |
        v
XDMA IP / AXI fabric
        |
        v
Zynq memory / logic
```

## Debugging Highlight

The initial Python benchmark produced roughly 150 MB/s because random-data generation was included in the timed region. Moving data generation outside the timer materially changed the host-observed write result and exposed the benchmarking error.

That debugging episode is useful evidence of the project's emphasis on separating **system performance** from **measurement overhead**.

## Scope

This project demonstrates PCIe/XDMA integration and host-side validation. It does not claim:

- end-to-end zero-copy semantics;
- zero CPU overhead;
- a formally characterized maximum PCIe bandwidth;
- production-driver qualification.

The strongest evidence is successful Linux/XDMA integration, data round-trip verification, and the documented host-side transfer benchmark workflow.
