## Constraints for AX7015B (Zynq 7015)
## Based on schematics for common connectors (PMOD/J11)

## Clock Signal
set_property PACKAGE_PIN Y14 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports sys_clk]

## Reset Button (Key 1 / RESET)
set_property PACKAGE_PIN AB12 [get_ports btn_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports btn_rst_n]

## LEDs
set_property PACKAGE_PIN A5 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]

set_property PACKAGE_PIN A7 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]

set_property PACKAGE_PIN A6 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[2]}]

set_property PACKAGE_PIN B8 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[3]}]

## SPI Interface PINS (Assigned to J11 Header for example) 
## WARNING: Check your schematic! Providing generic accessible GPIOs.
## Assuming user connects wire from MOSI to MISO for Loopback.

# SPI_MOSI (Pin 1)
set_property PACKAGE_PIN M1 [get_ports spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi]

# SPI_MISO (Pin 2)
set_property PACKAGE_PIN M2 [get_ports spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
