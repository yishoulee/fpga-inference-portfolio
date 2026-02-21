# ----------------------------------------------------------------------------
# PCIe Constraints for Alinx AX7015B
# ----------------------------------------------------------------------------
# Note: You must fill in the correct pin locations based on the AX7015B schematic.
# The following are placeholders.

# System Reset (PERST_N from PCIe Slot)
# From AX7015B Reference (M6)
set_property PACKAGE_PIN M6 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
# set_property PULLUP true [get_ports sys_rst_n] # External pullup usually present

# PCIe Reference Clock (100 MHz from PCIe Slot)
# PCIE_CLK_P = U9, PCIE_CLK_N = V9
# Note: Block Design interface "sys_clk" expands to ports "sys_clk_clk_p" and "sys_clk_clk_n"
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_clk_p]
set_property PACKAGE_PIN U9 [get_ports sys_clk_clk_p]
set_property PACKAGE_PIN V9 [get_ports sys_clk_clk_n]

# MGT Locations (GTP Quad 216)
# Lane 0
set_property PACKAGE_PIN W8 [get_ports {pci_exp_rxp[0]}]
set_property PACKAGE_PIN W4 [get_ports {pci_exp_txp[0]}]
# Lane 1
set_property PACKAGE_PIN AA7 [get_ports {pci_exp_rxp[1]}]
set_property PACKAGE_PIN AA3 [get_ports {pci_exp_txp[1]}]

# Note: The XDMA IP usually handles the GT location constraints internally 
# based on the selected lane configuration, but explicit pin assignments 
# for the differential pairs help verify the package bonding.


