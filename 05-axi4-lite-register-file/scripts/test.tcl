# scripts/test_jtag.tcl

# Connect to the local hardware server
connect

# Select the Zynq ARM Core (Cortex-A9 #0) as the target
# This allows us to use the processor's memory map to access the PL (FPGA)
targets -set -nocase -filter {name =~ "ARM*#0"}

# FORCE MEMORY MAP:
# XSDB sometimes blocks access to PL addresses if it doesn't know they exist.
# We explicitly tell it that 0x43C0_0000 is a valid Read/Write region.
# memmap -add -addr 0x43C00000 -size 0x10000 -access rw

# Reset the system to ensuring a clean state (optional, but good for consistent tests)
# rst -system

puts "=================================================="
puts "   AXI4-Lite Register Test (JTAG / XSDB)          "
puts "=================================================="

set BASE_ADDR 0x43C00000
set CONTROL_OFFSET 0x00
set STATUS_OFFSET  0x04
set SCRATCH_OFFSET 0x08

# 1. Test Scratchpad
puts "\n--- [1] Testing Scratchpad Register (0x08) ---"
set pattern 0xAA55AA55
puts [format "Writing: 0x%08X" $pattern]

# mwr = Memory Write
mwr -force [expr $BASE_ADDR + $SCRATCH_OFFSET] $pattern

# mrd = Memory Read
set read_back [mrd -force -value [expr $BASE_ADDR + $SCRATCH_OFFSET]]
puts [format "Read:    0x%08X" $read_back]

if {$read_back == $pattern} {
    puts "RESULT: PASS"
} else {
    puts "RESULT: FAIL"
}

# 2. Test Control Register (LEDs)
puts "\n--- [2] Testing Control Register (0x00) ---"
puts "Turning LED 0 ON, others OFF (Active Low: Writing 0xE -> 1110)..."
mwr -force [expr $BASE_ADDR + $CONTROL_OFFSET] 0xE

set val [mrd -force -value [expr $BASE_ADDR + $CONTROL_OFFSET]]
puts [format "Read Back: 0x%08X" $val]

if {$val == 0xE} {
    puts "RESULT: PASS"
} else {
    puts "RESULT: FAIL"
}

# 3. Test Status Register
puts "\n--- [3] Reading Status Register (0x04) ---"
set status [mrd -force -value [expr $BASE_ADDR + $STATUS_OFFSET]]
puts [format "Status Value: 0x%08X" $status]
puts [format "  NPU Busy: %d" [expr $status & 1]]
puts [format "  FIFO Full: %d" [expr ($status >> 1) & 1]]

if {$status == 0xDEADBEEF} {
    puts "RESULT: PASS (Matches Expectation)"
} else {
    puts "RESULT: FAIL (Expected 0xDEADBEEF)"
}

puts "\nTest Complete."
