set project_name "pcie_xdma"
set part "xc7z015clg485-2"
set board_part "" 

create_project $project_name ./$project_name -part $part -force
set_property target_language Verilog [current_project]

create_bd_design "system"

# 1. Add Processing System (PS) - Enable HP0 for DDR access
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Source the custom PS configuration script
source ./scripts/ps_config.tcl

# Apply the custom configuration (including correct DDR timings)
# This sets most properties, including enabling HP0 and setting MIO/DDR parameters
set_ps_config processing_system7_0

# Ensure HP0 is definitely enabled and 64-bit (in case ps_config varies)
set_property -dict [list \
  CONFIG.PCW_USE_S_AXI_HP0 {1} \
  CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
  CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
  CONFIG.PCW_IRQ_F2P_INTR {1} \
] [get_bd_cells processing_system7_0]

# Apply automation to create external interfaces (FIXED_IO, DDR)
# We use apply_board_preset "0" to avoid overwriting our custom config if possible, 
# or just rely on the fact that we set properties.
# Actually, apply_bd_automation might reset some things if 'apply_board_preset' is true.
# Let's try to apply automation first, then custom config. But automation needs the cell to exist.
# Let's run automation first with a dummy preset, then overwrite.

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

# Re-apply the custom configuration to override any defaults from automation
set_ps_config processing_system7_0

# Re-assert specific requirements for this design
set_property -dict [list \
  CONFIG.PCW_USE_S_AXI_HP0 {1} \
  CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
  CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
  CONFIG.PCW_IRQ_F2P_INTR {1} \
  CONFIG.PCW_USE_M_AXI_GP0 {0} \
] [get_bd_cells processing_system7_0]

# 2. Add XDMA (PCIe)
create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.2 xdma_0
set_property -dict [list \
  CONFIG.functional_mode {DMA} \
  CONFIG.mode_selection {Basic} \
  CONFIG.pl_link_cap_max_link_width {X2} \
  CONFIG.pl_link_cap_max_link_speed {5.0_GT/s} \
  CONFIG.axi_data_width {64_Bit} \
  CONFIG.axisten_freq {125} \
  CONFIG.pf0_device_id {7015} \
  CONFIG.pf0_base_class_menu {Memory_controller} \
  CONFIG.pf0_class_code_base {05} \
  CONFIG.pf0_class_code_sub {80} \
  CONFIG.pf0_class_code_interface {00} \
] [get_bd_cells xdma_0]

# 3. Add SmartConnect (Interconnect)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
set_property CONFIG.NUM_SI {1} [get_bd_cells axi_smc]

# 4. Add Utility Buffer for PCIe Reference Clock
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0
set_property -dict [list CONFIG.C_BUF_TYPE {IBUFDSGTE}] [get_bd_cells util_ds_buf_0]

# 5. Create Interface Ports
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk
create_bd_port -dir I -type rst sys_rst_n

# 5a. Use create_bd_intf_port for PCIe pins to match XDC automatically if names align? 
# Actually, XDMA creates interface pins. We need to make them external.
# The XDMA IP has 'pcie_mgt' interface.
make_bd_intf_pins_external [get_bd_intf_pins xdma_0/pcie_mgt]
set_property name pci_exp [get_bd_intf_ports pcie_mgt_0]

# 6. Connections

# Clock Input -> Buffer -> XDMA
connect_bd_intf_net [get_bd_intf_ports sys_clk] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins xdma_0/sys_clk]
connect_bd_net [get_bd_ports sys_rst_n] [get_bd_pins xdma_0/sys_rst_n]

# XDMA AXI Master -> SmartConnect -> PS7 HP0
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins processing_system7_0/S_AXI_HP0]

# Clocks
# XDMA provides axi_aclk (derived from PCIe link or sys_clk). 
# We use this to drive the AXI interconnect and the PS HP0 port interface.
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins processing_system7_0/S_AXI_HP0_ACLK]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_smc/aclk]

# Resets
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_smc/aresetn]


# 8. Address Mapping
# Map PS DDR (HP0) to 0x00000000 in XDMA address space
assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs processing_system7_0/S_AXI_HP0/HP0_DDR_LOWOCM] -force

validate_bd_design

save_bd_design

make_wrapper -files [get_files ./$project_name/$project_name.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse ./$project_name/$project_name.gen/sources_1/bd/system/hdl/system_wrapper.v
update_compile_order -fileset sources_1

# Add Constraints
add_files -fileset constrs_1 -norecurse constraints/AX7015B.xdc

# Run Synthesis and Implementation
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Check if implementation was successful
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed."
    exit 1
}

puts "Implementation completed successfully."

# Open the Implemented Design to generate reports
open_run impl_1

puts "Generating Timing Report..."
report_timing_summary -file ./timing_summary.rpt

puts "Generating Utilization Report..."
report_utilization -file ./utilization.rpt

puts "Copying Bitstream to root..."
file copy -force ./$project_name/$project_name.runs/impl_1/system_wrapper.bit ./system_wrapper.bit

puts "Build Complete. Artifacts: system_wrapper.bit, timing_summary.rpt, utilization.rpt"

