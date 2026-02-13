# Program script for Vivado Lab/Hardware Manager

open_hw_manager
connect_hw_server
open_hw_target

current_hw_device [get_hw_devices xc7z015_1]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7z015_1] 0]

set_property PROBES.FILE {} [get_hw_devices xc7z015_1]
set_property FULL_PROBES.FILE {} [get_hw_devices xc7z015_1]
set_property PROGRAM.FILE {./uart_fifo.bit} [get_hw_devices xc7z015_1]

program_hw_devices [get_hw_devices xc7z015_1]
refresh_hw_device [lindex [get_hw_devices xc7z015_1] 0]

puts "FPGA programmed successfully."
