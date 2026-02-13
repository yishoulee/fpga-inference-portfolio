# scripts/program.tcl

open_hw_manager
connect_hw_server
open_hw_target

# Select the FPGA device (FPGA Part), not the ARM DAP core
set device [lindex [get_hw_devices xc7*] 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device

set bitstream_file ./system_wrapper.bit

set_property PROGRAM.FILE $bitstream_file $device
program_hw_device $device

close_hw_manager

puts "FPGA Programmed Successfully."
