# Monitor the FPGA with ILA
# Usage: vivado -mode batch -source scripts/monitor.tcl

puts "Connecting to Hardware Server..."
open_hw_manager
connect_hw_server
open_hw_target

puts "Identifying Device and Probes..."
set dev [current_hw_device [get_hw_devices xc7z015*]]
set_property PROBES.FILE {./top.ltx} $dev
set_property FULL_PROBES.FILE {./top.ltx} $dev
refresh_hw_device $dev

# Get the ILA Core
set ilas [get_hw_ilas -of_objects $dev]
if {[llength $ilas] == 0} {
    puts "ERROR: No ILA core found on the device. Is the bitstream programmed correctly?"
    exit 1
}
set my_ila [lindex $ilas 0]
puts "Using ILA: $my_ila"

# Configure Trigger
# We want to trigger when 'price_valid' goes high.
# Probe names are often mangled, so we search by pattern.
set valid_probe [get_hw_probes -of_objects $my_ila -filter {NAME =~ *price_valid*}]

if {$valid_probe == ""} {
    puts "ERROR: Could not find probe for 'price_valid'."
    exit 1
}

puts "Configuring Trigger on $valid_probe == 1..."
set_property TRIGGER_COMPARE_VALUE eq1'b1 $valid_probe
set_property CONTROL.TRIGGER_POSITION 10 $my_ila
# set_property CONTROL.TRIGGER_MODE BASIC_ONLY $my_ila

puts "Arming Trigger... Waiting for Price Update..."
run_hw_ila $my_ila
wait_on_hw_ila $my_ila

puts "Triggered! Uploading waveform data..."
current_hw_ila_data [upload_hw_ila_data $my_ila]
write_hw_ila_data -force -csv_file ./captured_data.csv [current_hw_ila_data]

puts "Data captured to ./captured_data.csv"
puts "Success."
exit
