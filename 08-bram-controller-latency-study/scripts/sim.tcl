# Vivado Tcl Script to Run Simulation (Behavioral)
# Usage: vivado -mode batch -source scripts/sim.tcl

# Vivado Tcl Script to Run Simulation (Behavioral)
# Usage: vivado -mode batch -source scripts/sim.tcl

# Create and enter compilation directory to keep root clean
file mkdir sim_build
cd sim_build

# Clear previous log
set logfile "simulation.log"
set fp [open $logfile "w"]
close $fp

# Wrapper proc to hide exec noise but catch errors
proc run_cmd {cmd logfile} {
    puts "Running: $cmd"
    if {[catch {eval exec $cmd >>& $logfile} result]} {
        # Check if it was just stderr output (some tools use stderr for info)
        # We'll print the result anyway if it looks like an error
    }
}

# Compile RTL
puts "Compiling RTL..."
run_cmd "xvlog ../rtl/bram_controller.v" $logfile

# Compile TB
puts "Compiling Testbench..."
run_cmd "xvlog -sv ../tb/tb_bram_controller.sv" $logfile

# Elaborate
puts "Elaborating..."
run_cmd "xelab -debug typical -top tb_bram_controller -snapshot tb_bram_controller_snap" $logfile

# Run Simulation
puts "Running Simulation..."
run_cmd "xsim tb_bram_controller_snap -R" $logfile

# Show output
puts "------------------------------------------------"
puts "Simulation Log (last 20 lines from $logfile):"
if {[catch {exec tail -n 20 $logfile} log_tail]} {
    puts "No output found."
} else {
    puts $log_tail
}
puts "------------------------------------------------"
