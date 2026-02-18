# Makefile for Project 08: BRAM Controller

.PHONY: all clean sim wave

all: sim

sim:
	@vivado -mode batch -source scripts/sim.tcl

wave:
	@# Generate wave.tcl in sim_build directory
	@echo "add_wave -recursive *" > sim_build/wave.tcl
	@echo "run all" >> sim_build/wave.tcl
	cd sim_build && xsim tb_bram_controller_snap -gui -tclbatch wave.tcl

build:
	vivado -mode batch -source scripts/build.tcl

program:
	vivado -mode batch -source scripts/program.tcl

measure:
	# Step 1: Initialize PS Clocks (Critical for ILA)
	xsct scripts/init_ps.tcl
	# Step 2: Arm ILA in background
	# We use a subshell and trap to ensure cleanup if user Ctrl-C
	(vivado -mode batch -nojournal -nolog -source scripts/measure_latency.tcl > ila_output.log 2>&1 & echo $$! > ila.pid)
	@echo "Waiting for ILA to Arm..."
	@sleep 15
	# Step 3: Drive Traffic
	@echo "Driving Traffic to Trigger ILA..."
	xsct scripts/latency_test.tcl
	@echo "Waiting for ILA capture to complete..."
	@# Wait for the background process to finish by checking if PID exists
	@while ps -p `cat ila.pid` > /dev/null; do sleep 1; done
	@cat ila_output.log
	@rm ila.pid ila_output.log

clean:
	rm -rf sim_build bram_latency_study .Xil
	rm -f *.jou *.log *.pb *.wdb *.str
	rm -f design_1_wrapper.bit design_1_wrapper.xsa
	rm -f timing_summary.rpt utilization.rpt
	rm -f ila_data.csv ila_output.log ila.pid
