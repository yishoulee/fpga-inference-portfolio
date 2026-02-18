# XSCT/XSDB Script to Interact with BRAM Controller on Hardware
# Usage: xsct scripts/latency_test.tcl

connect
targets -set -nocase -filter {name =~ "ARM*#0"}
# Reset the processor core to clear MMU/Cache state (should be disabled on reset)
# This avoids "MMU section translation fault"
rst -processor
after 100

# Force memory access to bypass MMU/protection checks if possible
catch {configparams force-mem-access 1}

# PS Init is handled by init_ps.tcl now, but we can double check connectivity.
# Just drive traffic.

set BRAM_BASE_ADDR 0x43C00000

# 0. Force Enable PL Access (if level shifters are off or memmap missing)
# Sometimes needed if no ELF is loaded
# Check and add memory map entry for the PL AXI Slave
# Address 0x43C00000 is generic for AXI GP0; verify against Vivado Address Editor

# Disable MMU if enabled to avoid translation faults
# Cortex-A9 SCTLR (System Control Register) is CP15 c1
# But easier is to just tell XSCT to use physical addressing or force it.

# Try to add memory map entry using positional arguments or correct flags as per Xilinx UG1208
# Correct usage: memmap -addr <address> -size <size> -flags <flags>
catch { memmap -addr 0x43C00000 -size 0x10000 -flags rw }

# Disable MMU via CP15 c1 if possible (SCTLR)
# Bit 0 is MMU enable. Clear it.
catch {
    set sctlr [rd -arm-cp15 1 0 0] 
    # That syntax is for older XMD. 
    # For XSCT, we can use `regs` or `mrd - arm-cp15` etc.
    # But easier: just -phys flag for mwr/mrd if present.
}

# 1. Write Data
puts "Writing 0xDEADBEEF to BRAM (Offset 0x00)..."
if {[catch {mwr -force 0x43C00000 0xDEADBEEF} err]} {
    puts "mwr -force failed: $err"
    # Try disabling MMU logic or different addressing
    # Try mapping as physical?
}

puts "Writing 0x12345678 to BRAM (Offset 0x04)..."
catch {mwr -force 0x43C00004 0x12345678}

# 2. Read Data
puts "Reading from BRAM (Offset 0x00)..."
if {[catch {mrd -force 0x43C00000} val]} {
    puts "mrd failed: $val"
} else {
    puts "Read Value: $val"
}

# 2. Trigger ILA (Automated)
puts "Generating Traffic to trigger ILA..."
after 1000 ;# Wait a second to ensure ILA is armed

# 3. Read Data
puts "Reading from BRAM (Offset 0x00)..."
set val [mrd -force [expr $BRAM_BASE_ADDR + 0x00]]
puts "Read Value: $val"

if {[string match "*DEADBEEF*" $val]} {
    puts "PASS: Data verification successful."
} else {
    puts "FAIL: Data mismatch $val"
}

puts "----------------------------------------"
puts "Now check the ILA waveform for latency cycles."
puts "Calculate: (Cycle count between ARVALID and RVALID) - 1 = Overhead"
puts "----------------------------------------"
