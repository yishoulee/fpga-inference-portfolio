# Makefile for Project 07: SPI Master Controller

.PHONY: all clean sim wave build program

all: sim

sim:
	@mkdir -p sim_build
	@echo "Compiling RTL..."
	cd sim_build && xvlog -sv ../rtl/spi_master.sv ../tb/tb_spi_master.sv -L uvm
	@echo "Elaborating..."
	cd sim_build && xelab -debug typical -top tb_spi_master -snapshot tb_spi_master_snap -L uvm
	@echo "Running Simulation..."
	cd sim_build && xsim tb_spi_master_snap -tclbatch ../scripts/sim.tcl


wave:
	cd sim_build && xsim tb_spi_master_snap -gui -tclbatch ../scripts/xsim_wave.tcl

build:
	@mkdir -p build
	vivado -mode batch -source scripts/build.tcl

program:
	vivado -mode batch -source scripts/program.tcl

clean:
	rm -rf sim_build build xsim.dir .Xil .ip_user_files .cache .hw
	rm -f *.log *.jou *.wdb *.str *.pb *.rpt *.bit *.dcp webtalk* usage_statistics_webtalk.xml
