# Vivado Tcl Script to Program FPGA and Capture ILA Data
# Usage: vivado -mode batch -source scripts/measure_latency.tcl

# 1. Open Hardware Manager and Connect
open_hw_manager
connect_hw_server
open_hw_target

# 2. Program FPGA (Optional - checks if programmed, or force programs)
# Select the FPGA device (filter for 7-series or Zynq PL)
set device [lindex [get_hw_devices xc7*] 0]
if {$device == ""} {
    # Fallback/Retry if xc7 not found, maybe look for other patterns or list all
    puts "Warning: Could not find device matching xc7*. Listing all devices:"
    foreach dev [get_hw_devices] { puts $dev }
    set device [lindex [get_hw_devices] 0]   
}

current_hw_device $device
refresh_hw_device -update_hw_probes false $device

# Assuming bitstream is at:
set bitstream_path "./bram_latency_study/bram_latency_study.runs/impl_1/design_1_wrapper.bit"
set probes_path "./bram_latency_study/bram_latency_study.runs/impl_1/design_1_wrapper.ltx"

puts "Setting probes file: $probes_path"
# Do not re-program if possible, as it resets PS-PL interface which we just initialized with init_ps.tcl
if {[file exists $probes_path]} {
    set_property PROBES.FILE $probes_path $device
    refresh_hw_device $device
} else {
    puts "Probes file not found at $probes_path. Cannot connect to ILA."
    exit 1
}

# We assume init_ps.tcl has programmed the FPGA and initialized PS.

# 3. Setup ILA Trigger
# Wait for the clock to be active (PS init)
puts "Waiting for ILA core to be accessible (Clock active)..."
set max_retries 20
set retry_count 0
set ila_found 0

while {$retry_count < $max_retries} {
    refresh_hw_device $device
    set ila [get_hw_ilas -of_objects $device -filter {CELL_NAME=~"*/system_ila_0/inst/ila_lib"}]
    if {[llength $ila] == 0} {
         set ila [lindex [get_hw_ilas] 0]
    }
    
    # Check if we can access a property
    if {[catch {get_property CONTROL.TRIGGER_POSITION $ila} err]} {
        puts "ILA not ready yet. Retrying in 2 seconds... ($retry_count/$max_retries)"
        after 2000
        incr retry_count
    } else {
        puts "ILA Core found and accessible."
        set ila_found 1
        break
    }
}

if {$ila_found == 0} {
    puts "Error: Timeout waiting for ILA core. Is the PL clock running (ps7_init)?"
    exit 1
}

# Reset ILA
reset_hw_ila $ila

# Set Trigger Position
set_property CONTROL.TRIGGER_POSITION 10 $ila


# Configure Trigger Probe: probe2 is s_axi_arvalid (from build.tcl)
# Use a broader search first if specific name fails
set arvalid_probe [get_hw_probes -of_objects $ila -filter {NAME =~ "*arvalid*"}]
if {[llength $arvalid_probe] == 0} {
    puts "Error: Could not find ARVALID probe. Listing all probes:"
    foreach p [get_hw_probes -of_objects $ila] { puts [get_property NAME $p] }
    exit 1
}
# Pick the first one if multiple (e.g., awvalid vs arvalid, check strictly)
# System ILA usually names them like ..._ARVALID
foreach p $arvalid_probe {
    if {[string match "*ARVALID" [get_property NAME $p]] || [string match "*arvalid" [get_property NAME $p]]} {
        set arvalid_probe $p
        break
    }
}

set rvalid_probe [get_hw_probes -of_objects $ila -filter {NAME =~ "*rvalid*"}]

# trigger on arvalid == 1
set_property TRIGGER_COMPARE_VALUE eq1'b1 $arvalid_probe
# set_property CONTROL.TRIGGER_MODE BASIC_ONLY $ila
# set_property CONTROL.TRIGGER_CONDITION_AND_OR_IMPLY AND $ila

# 4. Arm the ILA
puts "Arming ILA..."
run_hw_ila $ila

# 5. Wait for Trigger (User must run XSCT script externally to generate traffic)
puts "ILA Armed. Waiting for trigger..."
puts "Please run 'make drive_traffic' in another terminal to generate AXI transactions."

wait_on_hw_ila $ila

# 6. Upload Data
puts "Triggered! Uploading data..."
upload_hw_ila_data $ila

# 7. Analyze Latency Programmatically
# We have the data in memory now. We can search for the rising edge of ARVALID and RVALID.
# CSV Export is easiest for text parsing, but we can try Tcl list manipulation.

write_hw_ila_data -csv_file ./ila_data.csv -force [current_hw_ila_data]
puts "ILA Data saved to ./ila_data.csv"

# Simple Parsing to find Latency
# We read the CSV and find the cycle difference between ARVALID=1 and RVALID=1
set fp [open "./ila_data.csv" r]
set file_data [read $fp]
close $fp

set lines [split $file_data "\n"]
set arvalid_idx -1
set rvalid_idx -1
set headers [split [lindex $lines 0] ","]

# Find column indices
set arvalid_col -1
set rvalid_col -1
set col 0

puts "Searching for trigger columns in CSV headers..."
foreach h $headers {
    # Match generic AXI valid signals (System ILA naming)
    if {[string match "*axi_arvalid*" $h]} { 
        set arvalid_col $col 
        puts "  Found ARVALID at col $col: $h"
    }
    if {[string match "*axi_rvalid*" $h]} { 
        set rvalid_col $col 
        puts "  Found RVALID at col $col: $h"
    }
    incr col
}

if {$arvalid_col == -1 || $rvalid_col == -1} {
    puts "Error: Could not find ARVALID or RVALID columns in CSV."
    puts "Headers: $headers"
    exit 1
}

# Find first occurrence of '1' in data
set row_idx 0
set start_time -1
set end_time -1

foreach line $lines {
    if {$row_idx > 0 && [llength $line] > 1} { # Skip header
        set values [split $line ","]
        set ar_val [lindex $values $arvalid_col]
        set r_val [lindex $values $rvalid_col]
        
        # Detect ARVALID rising edge (simplification: just first '1')
        if {$ar_val == 1 && $start_time == -1} {
            set start_time $row_idx
        }
        
        # Detect RVALID rising edge
        if {$r_val == 1 && $start_time != -1 && $end_time == -1} {
            set end_time $row_idx
        }
    }
    incr row_idx
}

if {$start_time != -1 && $end_time != -1} {
    set latency [expr $end_time - $start_time]
    puts "------------------------------------------------"
    puts "MEASURED LATENCY: $latency clock cycles"
    puts "------------------------------------------------"
    
    # Calculate Overhead
    set native 1
    set overhead [expr $latency - $native]
    puts "AXI Overhead: $overhead cycles"
} else {
    puts "Could not determine latency from captured data."
}

close_hw_target
close_hw_manager
