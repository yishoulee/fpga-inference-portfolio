# Program AX7015B FPGA

open_hw_manager
connect_hw_server
open_hw_target

# Find the Zynq PL device
set dev [current_hw_device [get_hw_devices xc7z015*]]
if {[llength $dev] == 0} {
    puts "ERROR: No AX7015 device found."
    exit 1
}

# Program
set_property PROGRAM.FILE {./ethernet_rx.bit} $dev
program_hw_devices $dev

puts "FPGA Programmed Successfully"
exit
