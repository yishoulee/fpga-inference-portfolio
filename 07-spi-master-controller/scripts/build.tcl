# Vivado Build Script for Project 07

# 1. Set Project Name and Part
set project_name "spi_master_proj"
set part "xc7z015clg485-2"  ;# Verify your specific Zynq part!

# 2. Create Project
create_project -force $project_name ./build -part $part

# 3. Add Source Files
add_files rtl/spi_master.sv
add_files rtl/top.sv

# 4. Add Constraints
add_files -fileset constrs_1 constraints/AX7015B.xdc

# 5. Run Synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 6. Run Implementation and Bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Check for success
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
   error "Implementation failed!"
}

# 7. Copy Artifacts
set top_module "top"

# Open implemented design to generate reports
open_run impl_1

# Generate Reports if they don't exist in the run directory (or just regenerate to be sure)
report_timing_summary -file ./build/${project_name}.runs/impl_1/${top_module}_timing_summary_routed.rpt
report_utilization -file ./build/${project_name}.runs/impl_1/${top_module}_utilization_placed.rpt

# Copy Bitstream
file copy -force ./build/${project_name}.runs/impl_1/${top_module}.bit ./${top_module}.bit

# Copy Reports
file copy -force ./build/${project_name}.runs/impl_1/${top_module}_timing_summary_routed.rpt ./timing_summary_routed.rpt
file copy -force ./build/${project_name}.runs/impl_1/${top_module}_utilization_placed.rpt ./utilization_placed.rpt

puts "Bitstream Generation Complete: ./${top_module}.bit"
puts "Reports Copied: ./timing_summary_routed.rpt, ./utilization_placed.rpt"
exit
