# scripts/demo_leds.tcl

# Connect to the local hardware server
connect

# Select the Zynq ARM Core
targets -set -nocase -filter {name =~ "ARM*#0"}

set BASE_ADDR 0x43C00000
set CONTROL_OFFSET 0x00

puts "=================================================="
puts "   AXI4-Lite LED Demo (Visual Confirmation)       "
puts "=================================================="

# Helper function to write to the Control Register
proc write_leds {val} {
    global BASE_ADDR CONTROL_OFFSET
    
    # User Note: LEDs are Active Low (0=ON, 1=OFF).
    # We invert the logical value here so the script logic remains intuitive (1=ON).
    # We mask with 0xF to ensure we only touch the 4 LEDs.
    set hw_val [expr {(~$val) & 0xF}]

    # Using -force to bypass memory map checks just like in test_jtag.tcl
    mwr -force [expr $BASE_ADDR + $CONTROL_OFFSET] $hw_val
}

puts "Starting LED Light Show..."

# 1. Blink All (3 times)
puts ">> Blinking All LEDs..."
for {set i 0} {$i < 3} {incr i} {
    write_leds 0xF; # All ON (1111)
    after 200
    write_leds 0x0; # All OFF
    after 200
}

# 2. Binary Counter (0 to 15)
puts ">> Binary Count..."
for {set i 0} {$i < 16} {incr i} {
    write_leds $i
    after 100
}

# 3. Knight Rider / Scanner Effect (Loop 5 times)
puts ">> Cylon Scanner..."
set scanner_pattern {1 2 4 8 4 2}
for {set loop 0} {$loop < 5} {incr loop} {
    foreach step $scanner_pattern {
        write_leds $step
        after 100
    }
}

# 4. Final Flash
puts ">> Done."
write_leds 0xF
after 500
write_leds 0x0
