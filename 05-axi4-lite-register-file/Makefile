# Makefile for Project 05: AXI4-Lite Register File

.PHONY: all build program sim test clean

default: sim

build:
	vivado -mode batch -source scripts/build.tcl

program:
	vivado -mode batch -source scripts/program.tcl

sim:
	vivado -mode batch -source scripts/sim.tcl

test:
	@echo "--- Running JTAG Test (XSDB) ---"
	xsdb scripts/test.tcl

demo:
	@echo "--- Running LED Demo visualizer ---"
	xsdb scripts/demo_leds.tcl

clean:
	rm -rf sim_build build .Xil system_wrapper.bit
	rm -f *.log *.jou *.pb *.wdb *.str *.rpt
	rm -f scripts/*.log scripts/*.jou
