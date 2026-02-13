# scripts/sim.tcl

# create_project -force -part xc7z015clg485-2 axi_lite_reg_file_sim ./sim_build
create_project -force -part xc7z015clg485-2 axi_lite_reg_file_sim ./sim_build

# Add Source Files
add_files -norecurse rtl/axi_lite_slave.v
add_files -norecurse tb/tb_axi_lite_slave.sv

set_property top tb_axi_lite_slave [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

# Run Simulation
launch_simulation
close_project
exit
