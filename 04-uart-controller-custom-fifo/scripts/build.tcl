# Build script for Vivado
set project_name "uart_fifo_prj"
set part "xc7z015clg485-2"

# Create project
create_project -force $project_name ./$project_name -part $part

# Add sources
add_files [glob ./rtl/*.sv]
add_files -fileset constrs_1 ./constraints/AX7015B.xdc

# Set top
set_property top top [current_fileset]

# Synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1

# Report Timing
report_timing_summary -file timing_summary.rpt
report_utilization -file utilization.rpt

# Implementation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Copy bitstream to root
file copy -force ./$project_name/$project_name.runs/impl_1/top.bit ./uart_fifo.bit

puts "Bitstream generated: uart_fifo.bit"
