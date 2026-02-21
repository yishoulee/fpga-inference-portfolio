# Build Script for Project 10: Market Data Parser
file mkdir build
cd build

# 1. Project Setup
set project_name "market_data_parser"
set part_name "xc7z015clg485-2"

create_project -force $project_name . -part $part_name

# 2. Add Sources
# Current Directory: project_root/build
# RTL sources
add_files ../rtl/top.sv
add_files ../rtl/udp_parser.sv
# Reuse PHY/MAC modules from Project 09
add_files ../../09-gigabit-ethernet-rx/rtl/rgmii_rx.sv
add_files ../../09-gigabit-ethernet-rx/rtl/mac_rx.sv

# Constraints
add_files -fileset constrs_1 ../constraints/AX7015B.xdc

# 3. Create ILA for Debugging
# We need to monitor:
# Probe 0: s_axis_tdata (8 bits)
# Probe 1: s_axis_tvalid (1 bit)
# Probe 2: s_axis_tlast (1 bit)
# Probe 3: price_valid (1 bit)
# Probe 4: price_data (32 bits)

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
set_property -dict [list \
    CONFIG.C_PROBE0_WIDTH {8} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_NUM_OF_PROBES {5} \
    CONFIG.C_INPUT_PIPE_STAGES {1} \
] [get_ips ila_0]

generate_target {instantiation_template} [get_ips ila_0]
update_compile_order -fileset sources_1

# Set Top Module
set_property top top [current_fileset]

# 4. Synthesis and Implementation
puts "Starting Synthesis..."
launch_runs synth_1 -jobs 8
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed."
    exit 1
}

puts "Starting Implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Check Status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed."
    exit 1
}

# Generate and Copy Reports
puts "Generating Reports..."
open_run impl_1
report_utilization -file utilization.rpt
report_timing_summary -file timing_summary.rpt

file copy -force utilization.rpt ../utilization.rpt
file copy -force timing_summary.rpt ../timing_summary.rpt
puts "Reports generated: utilization.rpt, timing_summary.rpt"

# 5. Export Bitstream
if {[file exists $project_name.runs/impl_1/top.bit]} {
    file copy -force $project_name.runs/impl_1/top.bit ../top.bit
    if {[file exists $project_name.runs/impl_1/top.ltx]} {
        file copy -force $project_name.runs/impl_1/top.ltx ../top.ltx
        puts "Debug Probes generated: top.ltx"
    } else {
        puts "WARNING: Debug probes (top.ltx) not found."
    }
    puts "Bitstream generated: top.bit"
} else {
    puts "ERROR: Bitstream not found."
}
