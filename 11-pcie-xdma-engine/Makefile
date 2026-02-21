.PHONY: all build program test clean

all: build

build:
	# Run Synthesis and Implementation to generate bitstream
	vivado -mode batch -source scripts/build.tcl

program:
	# Program the FPGA with the generated bitstream and initialize Zynq PS
	xsct scripts/program_xsct.tcl

driver:
	# Clone, patch, and build the XDMA driver
	@if [ ! -d "dma_ip_drivers" ]; then \
		echo "Cloning XDMA Driver..."; \
		git clone https://github.com/Xilinx/dma_ip_drivers.git; \
	fi
	# Fix "Header Hell": Copy include files to source dir so Make finds them
	cp dma_ip_drivers/XDMA/linux-kernel/include/libxdma*.h dma_ip_drivers/XDMA/linux-kernel/xdma/
	# Patch Device ID: Add 0x7015 to xdma_mod.c if not present
	@if ! grep -q "0x7015" dma_ip_drivers/XDMA/linux-kernel/xdma/xdma_mod.c; then \
		echo "Patching Device ID..."; \
		sed -i '/pci_device_id pci_ids\[\] = {/a \ \t{ PCI_DEVICE(0x10ee, 0x7015), },' dma_ip_drivers/XDMA/linux-kernel/xdma/xdma_mod.c; \
	fi
	# Build the driver
	make -C dma_ip_drivers/XDMA/linux-kernel/xdma

reset_pcie: driver
	# Reload driver and reset PCIe link (Fix for Error 512)
	-sudo rmmod xdma || true
	echo 1 | sudo tee /sys/bus/pci/devices/0000:01:00.0/remove
	echo 1 | sudo tee /sys/bus/pci/rescan
	sudo insmod dma_ip_drivers/XDMA/linux-kernel/xdma/xdma.ko

test:
	# Run host-side python tests (Throughput)
	# Requires: sudo insmod xdma.ko (Kernel driver loaded)
	sudo python3 scripts/test_throughput.py

clean:
	rm -rf pcie_xdma
	rm -rf *.log *.jou *.pb *.wdb .Xil
	rm -f *.str *.bin *.rpt system_wrapper.bit dma_to_device dma_from_device reg_rw performance
