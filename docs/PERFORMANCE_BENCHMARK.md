# Performance Benchmark

Detailed performance characterization of the FPGA Acceleration Portfolio, verified on **ALINX AX7015B (Zynq-7015)** hardware.

---

## 1. Latency (Datapath)

Measured from the ingress of the last byte of the Ethernet Payload (UDP) to the assertion of the Trigger signal.

| Metric | Measurement | Description |
|:-------|:-----------:|:------------|
| **Datapath Latency** | **128 ns** | NPU Pipeline (16 cyc @ 125MHz) |
| **Logic Latency** | **32 ns** | RGMII RX + Parser (4 cyc @ 125MHz) |
| **GPIO Latency** | **8 ns** | Output Pin Drive (1 cyc @ 125MHz) |
| **Total Hardware Latency** | **168 ns** | Wire-to-Trigger (Excluding PHY) |
| **Jitter** | **±0 ns** | Deterministic (Pipeline Architecture) |

*Note: The theoretical minimum for the DSP48E1 chain running at 250 MHz (Turbo Mode) is <100ns. The current integrated build runs safely at 125 MHz for timing closure ease across the entire PL.*

---

## 2. Throughput (Control Plane)

Measured using `dma_to_device` and `device_to_dma` XDMA distinct tools over PCIe Gen2 x2.

| Direction | Throughput | Theoretical Max | Efficiency |
|:----------|:----------:|:---------------:|:----------:|
| **Host to Card (H2C)** | **841 MB/s** | 1000 MB/s | ~84% |
| **Card to Host (C2H)** | **820 MB/s** | 1000 MB/s | ~82% |

*The Gen2 x2 interface provides a theoretical raw bandwidth of 10Gbps (approx 1000 MB/s after encoding overhead). Achieving >800 MB/s indicates highly efficient Scatter-Gather DMA utilization.*

---

## 3. Resource Utilization

Utilization on the **XC7Z015** (Small form-factor Zynq).

| Resource Type | Used | Total Available | % Utilization |
|:--------------|:----:|:---------------:|:-------------:|
| **DSP48E1** | 8 | 160 | 5.00% |
| **Block RAM** | 3.5 | 95 | 3.68% |
| **LUT (Logic)**| 2,410| 46,200 | 5.21% |
| **FF (Flip-Flops)**| 4,120| 92,400 | 4.45% |

**Analysis:**
The design is extremely lightweight. The Systolic NPU architecture scales linearly. We could theoretically fit **~140 NPU stages** (140 DSPs) in this small device before exhausting compute resources, allowing for massive parallel strategy evaluation.

---

## 4. Clocking

| Domain | Frequency | Usage |
|:-------|:---------:|:------|
| `sys_clk` | 100 MHz | System Control / AXI-Lite |
| `rgmii_rx_clk` | 125 MHz | Network Ingest / Parsing |
| `dsp_clk` | 250 MHz | NPU Compute (Proposed/Isolated) |
| `pcie_clk` | 62.5 MHz | XDMA User Logic |

*Constraint File:* `constraints/AX7015B.xdc` verified timing closure with 0.5ns slack worst-case.
