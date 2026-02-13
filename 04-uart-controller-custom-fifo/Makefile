.PHONY: sim bit program clean

sim:
	vivado -mode batch -source scripts/sim.tcl

build:
	vivado -mode batch -source scripts/build.tcl

program:
	vivado -mode batch -source scripts/program.tcl

clean:
	rm -rf sim_build .Xil *.log *.jou *.pb xsim.dir *.wdb uart_fifo_prj uart_fifo.bit *.rpt
