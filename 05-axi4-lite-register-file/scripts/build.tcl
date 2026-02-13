# scripts/build.tcl

# 0. Settings
set project_name "axi_lite_sys"
set part "xc7z015clg485-2"
set top_module "system_wrapper"

# 1. Create Project
create_project -force $project_name ./build/vivado_prj -part $part

# 2. Add Sources
add_files -norecurse rtl/axi_lite_slave.v

# 3. Add Constraints
add_files -fileset constrs_1 -norecurse constraints/AX7015B.xdc

# 4. Create Block Design
create_bd_design "system"

# 5. Add Zynq Processing System
set zynq [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]

# Apply Block Automation (Basic Config)
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

# 6. Add RTL Reference (The AXI Slave)
create_bd_cell -type module -reference axi_lite_slave axi_lite_slave_0

# 7. Add Slice IP to connect 32-bit control_reg_o to 4-bit LEDs
set slice [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
set_property -dict [list CONFIG.DIN_WIDTH {32} CONFIG.DIN_FROM {3} CONFIG.DIN_TO {0}] $slice

# 8. Add Constant IP for status_reg_i (Input)
set const [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
set_property -dict [list CONFIG.CONST_WIDTH {32} CONFIG.CONST_VAL {0xDEADBEEF}] $const

# 9. Interconnect Automation
# Use 'apply_bd_automation' to connect AXI interfaces automatically
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Master "/processing_system7_0/M_AXI_GP0" intc_ip "Auto" Clk_xbar "Auto" Clk_master "Auto" Clk_slave "Auto" }  [get_bd_intf_pins axi_lite_slave_0/s_axi]

# 10. Manual Wiring (Ports)
# Connect Control Output to Slice
connect_bd_net [get_bd_pins axi_lite_slave_0/control_reg_o] [get_bd_pins xlslice_0/Din]

# Make Slice Output External (LEDs)
set leds_port [ create_bd_port -dir O -from 3 -to 0 leds ]
connect_bd_net [get_bd_pins xlslice_0/Dout] $leds_port

# Connect Status Constant
connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins axi_lite_slave_0/status_reg_i]

# 11. Validate Design
assign_bd_address
validate_bd_design
save_bd_design

# 12. Generate Wrapper
make_wrapper -files [get_files ./build/vivado_prj/${project_name}.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse ./build/vivado_prj/${project_name}.gen/sources_1/bd/system/hdl/system_wrapper.v
set_property top system_wrapper [current_fileset]

# 13. Synthesis, Implementation, Bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Check for success
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
   error "Implementation failed!"
}

# Copy Bitstream to Project Folder
file copy -force ./build/vivado_prj/${project_name}.runs/impl_1/system_wrapper.bit ./system_wrapper.bit

# Copy Reports to Project Folder
file copy -force ./build/vivado_prj/${project_name}.runs/impl_1/system_wrapper_timing_summary_routed.rpt ./timing_summary_routed.rpt
file copy -force ./build/vivado_prj/${project_name}.runs/impl_1/system_wrapper_utilization_placed.rpt ./utilization_placed.rpt

puts "Bitstream Generation Complete: ./system_wrapper.bit"
puts "Reports Copied: ./timing_summary_routed.rpt, ./utilization_placed.rpt"
