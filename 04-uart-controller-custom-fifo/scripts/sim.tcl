# Usage: vivado -mode batch -source scripts/sim.tcl

# Create simulation directory
file mkdir sim_build

# Compile RTL and Testbench
puts [exec xvlog -sv -i rtl rtl/fifo.sv rtl/uart_rx.sv rtl/uart_tx.sv rtl/top.sv tb/tb_uart_loopback.sv]
puts [exec xelab -debug typical -top tb_uart_loopback -snapshot tb_uart_loopback_snap]

# Run Simulation
puts [exec xsim tb_uart_loopback_snap -R]
