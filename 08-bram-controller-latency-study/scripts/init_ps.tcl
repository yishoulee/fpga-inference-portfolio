# XSCT Script to Initialize Zynq PS Clocks
# Usage: xsct scripts/init_ps.tcl

connect
targets -set -nocase -filter {name =~ "ARM*#0"}
rst -system

# Wait for system to reset
after 1000

# Program the FPGA with the bitstream
set bitstream_paths [list \
    "./design_1_wrapper.bit" \
    "./bram_latency_study/bram_latency_study.runs/impl_1/design_1_wrapper.bit" \
]

set programmed 0
foreach bit $bitstream_paths {
    if {[file exists $bit]} {
        puts "Programming FPGA with: $bit"
        fpga -f $bit
        set programmed 1
        break
    }
}

if {$programmed == 0} {
    puts "recusively searching for bitstream..."
    set result [glob -nocomplain -directory "." -types f "design_1_wrapper.bit"]
    if {[llength $result] > 0} {
        puts "Programming FPGA with: [lindex $result 0]"
        fpga -f [lindex $result 0]
        set programmed 1
    } else {
        # Try deeper search
         foreach dir [glob -nocomplain -directory "." -types d *] {
            set result [glob -nocomplain -directory $dir -types f "design_1_wrapper.bit"]
            if {[llength $result] > 0} {
                 puts "Programming FPGA with: [lindex $result 0]"
                 fpga -f [lindex $result 0]
                 set programmed 1
                 break
            }
             # One more level deep for typical Vivado structure
            foreach subdir [glob -nocomplain -directory $dir -types d *] {
                 set result [glob -nocomplain -directory $subdir -types f "design_1_wrapper.bit"]
                 if {[llength $result] > 0} {
                     puts "Programming FPGA with: [lindex $result 0]"
                     fpga -f [lindex $result 0]
                     set programmed 1
                     break
                 }
            }
            if {$programmed == 1} { break }
         }
    }
}

if {$programmed == 0} {
    puts "Error: Could not find design_1_wrapper.bit to program FPGA."
    # We continue anyway hoping user programmed it, but rst -system likely cleared it.
}

# Search for ps7_init.tcl recursively
# Tcl's glob doesn't always support ** robustly across all versions/shells for deep search.
# We'll use a finder procedure or check specific common locations.
proc find_files {basedir pattern} {
    set result [glob -nocomplain -directory $basedir -types f $pattern]
    foreach dir [glob -nocomplain -directory $basedir -types d *] {
        set result [concat $result [find_files $dir $pattern]]
    }
    return $result
}

puts "Searching for ps7_init.tcl..."
set p [find_files "." "ps7_init.tcl"]

# Also check specific known path if search fails (optimization)
if {[llength $p] == 0} {
    set manual_path "./bram_latency_study/bram_latency_study.gen/sources_1/bd/design_1/ip/design_1_processing_system7_0_0/ps7_init.tcl"
    if {[file exists $manual_path]} {
        set p [list $manual_path]
    }
}

if {[llength $p] > 0} {
    puts "Found ps7_init.tcl at [lindex $p 0]"
    source [lindex $p 0]
    ps7_init
    ps7_post_config
    puts "PS7 Initialization Complete (Clocks Active)."
} else {
    puts "Error: ps7_init.tcl not found. Cannot initialize PS clocks."
    exit 1
}

disconnect
exit
