
open_hw_manager
connect_hw_server
open_hw_target

set dev [current_hw_device [get_hw_devices xc7z015*]]
set_property PROBES.FILE {./ethernet_rx.ltx} $dev
set_property FULL_PROBES.FILE {./ethernet_rx.ltx} $dev
refresh_hw_device $dev

# List IBIS/ILAs
puts "Available ILAs:"
set ilas [get_hw_ilas]
foreach ila $ilas {
    puts "  $ila"
}

if {[llength $ilas] > 0} {
    set my_ila [lindex $ilas 0]
    puts "Using ILA: $my_ila"
    
    set probes [get_hw_probes -of_objects $my_ila]
    foreach p $probes {
        puts "  Probe: [get_property NAME $p]"
    }

    # Setup Trigger: gmii_rx_dv == 1
    # Note: Values need to be sized correctly. gmii_rx_dv is 1 bit.
    
    # Reset any existing triggers
    reset_hw_ila $my_ila
    
    set probe_dv [get_hw_probes *gmii_rx_dv* -of_objects $my_ila]
    if {$probe_dv != ""} {
        puts "Found DV probe: $probe_dv"
        set_property TRIGGER_COMPARE_VALUE eq1'b1 $probe_dv
        set_property CONTROL.TRIGGER_POSITION 0 $my_ila
        
        puts "Arming ILA trigger..."
        run_hw_ila $my_ila
        
        set timeout 20
        for {set i 0} {$i < $timeout} {incr i} {
            set status [get_property STATUS.CORE_STATUS $my_ila]
            puts "ILA Status: $status"
            if {$status == "FULL"} {
                break
            }
            after 1000
        }

        if {[get_property STATUS.CORE_STATUS $my_ila] == "FULL"} {
            puts "Triggered! Uploading data..."
            upload_hw_ila_data $my_ila
            
            # Export to CSV
            write_hw_ila_data -force -csv_file ./ila_data.csv [current_hw_ila_data]
            puts "Data saved to ila_data.csv"
        } else {
            puts "ILA did not finish triggering (Status: [get_property STATUS.CORE_STATUS $my_ila])"
        }


    } else {
        puts "Could not find gmii_rx_dv probe."
    }
} else {
    puts "No ILA found in the design."
}

exit
