.PHONY: all sim build program clean debug test

all: sim build

sim:
	# Run simulation for core logic
	tclsh scripts/sim.tcl

build:
	# Run Synthesis and Implementation to generate bitstream
	vivado -mode batch -source scripts/build.tcl

program:
	# Program the FPGA
	vivado -mode batch -source scripts/program.tcl

debug:
	# specific target to run the ILA debug 
	vivado -mode batch -source scripts/debug_ila.tcl

test:
	# Run packet generator to test activity LED and RX
	sudo python3 scripts/test_eth.py

clean:
	rm -rf sim_build build .Xil *.log *.jou *.pb *.wdb *.str usage_statistics_webtalk.xml utilization*.rpt timing_summary*.rpt xsim.dir ethernet_rx.bit ethernet_rx.ltx ila_data.csv
