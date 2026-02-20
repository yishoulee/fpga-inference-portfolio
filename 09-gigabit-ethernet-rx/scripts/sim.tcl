# simulation script for Mac Rx
file mkdir sim_build
cd sim_build

puts "Compiling Sources..."
exec xvlog -sv ../rtl/mac_rx.sv ../tb/tb_mac_rx.sv >@ stdout

puts "Elaborating..."
exec xelab -debug typical -top tb_mac_rx -snapshot tb_mac_rx_snap >@ stdout

puts "Running Simulation..."
exec xsim tb_mac_rx_snap --runall >@ stdout
