# scripts/xsim_wave.tcl

# Add all signals recursively to the waveform window
add_wave -recursive *

# Run simulation for sufficient duration
run 20us
