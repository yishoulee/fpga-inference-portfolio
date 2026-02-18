# scripts/program.tcl

open_hw_manager
connect_hw_server
open_hw_target

# Select the FPGA device (FPGA Part), not the ARM DAP core
# P05 uses a wildcard which is robust
set device [lindex [get_hw_devices xc7*] 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device

set bitstream_file ./top.bit

if { ![file exists $bitstream_file] } {
    puts "Error: Bitstream file $bitstream_file not found. Run 'make build' first."
    exit 1
}

set_property PROGRAM.FILE $bitstream_file $device
program_hw_device $device

close_hw_manager

puts "FPGA Programmed Successfully."

