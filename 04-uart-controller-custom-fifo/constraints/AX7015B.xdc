set_property PACKAGE_PIN Y14 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports clk]

set_property PACKAGE_PIN A5 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]

set_property PACKAGE_PIN A7 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]

set_property PACKAGE_PIN A6 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[2]}]

set_property PACKAGE_PIN B8 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[3]}]

set_property PACKAGE_PIN AB12 [get_ports btn_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports btn_rst_n]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# UART - Replace with actual PINs for AX7015B
# IMPORTANT: The onboard USB-UART (CP2102) is connected to PS MIO 48 (TX) and MIO 49 (RX).
# It is NOT directly accessible from PL (this RTL) without routing through Zynq EMIO.
# To use this pure RTL UART, you must connect an external USB-UART adapter to PL PINS (e.g. Expansion Header).
#
# Hypothetical PMOD/Header Pins (Requires external adapter):
# Values V13/V14 are typical for Header J11 on AX7015B - Verify with your schematic!
set_property PACKAGE_PIN M1 [get_ports rx] 
set_property IOSTANDARD LVCMOS33 [get_ports rx]
set_property PACKAGE_PIN M2 [get_ports tx]
set_property IOSTANDARD LVCMOS33 [get_ports tx]
