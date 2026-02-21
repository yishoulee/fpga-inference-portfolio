.PHONY: all sim build program monitor send_packet clean

all: sim build

sim:
	# Run simulation for core logic
	tclsh scripts/sim.tcl

build:
	# Run Synthesis and Implementation to generate bitstream
	vivado -mode batch -source scripts/build.tcl

program:
	# Program the FPGA with the generated bitstream
	vivado -mode batch -source scripts/program.tcl

monitor:
	# Connect to ILA, arm trigger, and wait for packet
	vivado -mode batch -source scripts/monitor.tcl

send_packet:
	# Send UDP packets (requires sudo for raw sockets)
	sudo python3 scripts/send_packet.py

clean:
	rm -rf sim_build build
	rm -rf *.log *.jou *.pb *.wdb .Xil
	rm -f top.bit top.ltx captured_data.csv *.rpt
