connect
puts "Connected to hw_server."

puts "Targeting FPGA..."
targets -set -filter {name =~ "xc7z015*"}
puts "Programming FPGA..."
fpga ./pcie_xdma/pcie_xdma.runs/impl_1/system_wrapper.bit

puts "Targeting ARM Core 0..."
targets -set -filter {name =~ "ARM*#0"}
rst -processor
puts "Sourcing ps7_init.tcl..."
source ./pcie_xdma/pcie_xdma.gen/sources_1/bd/system/ip/system_processing_system7_0_0/ps7_init.tcl

puts "Running ps7_init..."
ps7_init
puts "Running ps7_post_config..."
ps7_post_config

puts "Done!"
exit
