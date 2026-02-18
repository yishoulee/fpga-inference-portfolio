# Vivado Tcl Script to Program FPGA
# Usage: vivado -mode batch -source scripts/program.tcl

open_hw_manager
connect_hw_server
open_hw_target

# Select the FPGA device
set device [lindex [get_hw_devices xc7*] 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device

set bitstream_file ./design_1_wrapper.bit

if { ![file exists $bitstream_file] } {
    puts "Error: Bitstream file $bitstream_file not found. Run 'make build' first."
    exit 1
}

# We also need the ILA probes file (.ltx) for this project since we are using ILA
set probes_file ./bram_latency_study/bram_latency_study.runs/impl_1/design_1_wrapper.ltx

if { [file exists $probes_file] } {
    puts "Found ILA probes file: $probes_file"
    set_property PROBES.FILE $probes_file $device
} else {
    puts "Warning: ILA probes file not found at $probes_file. Debugging might not work."
}

puts "Programming FPGA with $bitstream_file..."
set_property PROGRAM.FILE $bitstream_file $device
program_hw_device $device

close_hw_manager

puts "FPGA Programmed Successfully."
exit
