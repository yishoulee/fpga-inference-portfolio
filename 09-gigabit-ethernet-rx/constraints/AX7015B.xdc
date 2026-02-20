## Physical Constraints (Alinx AX7015B)

# System Clock (50MHz)
set_property PACKAGE_PIN Y14 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -period 20.000 -name sys_clk -waveform {0.000 10.000} [get_ports sys_clk]

# Reset Button (Active Low)
set_property PACKAGE_PIN AB12 [get_ports btn_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports btn_rst_n]

# PHY2 (PL Side) - JL2121 / Realtek Compatible
# Bank 35 (Powered by 2.5V or 3.3V typically. Using LVCMOS33 as default, check schematics)

# PHY Reset (Active Low) - B7
set_property PACKAGE_PIN B7 [get_ports {phy_rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy_rst_n}]

# ETH RX Clock (RGMII_RXC) - PHY2_RXCK -> B4
set_property PACKAGE_PIN B4 [get_ports eth_rxc]
set_property IOSTANDARD LVCMOS33 [get_ports eth_rxc]
create_clock -period 8.000 -name rgmii_rx_clk -waveform {0.000 4.000} [get_ports eth_rxc]

# ETH RX Control (RGMII_RX_CTL) - PHY2_RXCTL -> B3
set_property PACKAGE_PIN B3 [get_ports eth_rx_ctl]
set_property IOSTANDARD LVCMOS33 [get_ports eth_rx_ctl]

# ETH RX Data (RGMII_RXD[3:0])
# PHY2_RXD0 -> A2
set_property PACKAGE_PIN A2 [get_ports {eth_rxd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_rxd[0]}]
# PHY2_RXD1 -> A1
set_property PACKAGE_PIN A1 [get_ports {eth_rxd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_rxd[1]}]
# PHY2_RXD2 -> B2
set_property PACKAGE_PIN B2 [get_ports {eth_rxd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_rxd[2]}]
# PHY2_RXD3 -> B1
set_property PACKAGE_PIN B1 [get_ports {eth_rxd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_rxd[3]}]

# LEDs
set_property PACKAGE_PIN A5 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]
set_property PACKAGE_PIN A7 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]
set_property PACKAGE_PIN A6 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[2]}]
# LED[3] is B8, which conflicts with PHY2_MDIO. 
# We disable it or map it to a safe pin (e.g. unused) to avoid bus contention.
# For now, we will NOT map it to B8 to be safe. Commenting out.
# set_property PACKAGE_PIN B8 [get_ports {leds[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {leds[3]}]



# Input Timing Constraints (Relaxed for now, assuming PHY adds delay or trace length match)
# Usually RGMII needs ~2ns setup/hold window.
set_input_delay -clock [get_clocks rgmii_rx_clk] -max 2.000 [get_ports {eth_rx_ctl eth_rxd[*]}]
set_input_delay -clock [get_clocks rgmii_rx_clk] -min 0.000 [get_ports {eth_rx_ctl eth_rxd[*]}]

# Configuration Voltage
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# IMPORTANT: Check your board schematic for Bank 35 Voltage!
# If Bank 35 (where Ethernet is connected) is powered by 1.8V, change IOSTANDARD to LVCMOS18.
# If 2.5V, use LVCMOS25. If 3.3V, use LVCMOS33 (Default below).
