# Build Script for Project 09: Gigabit Ethernet RX
file mkdir build
cd build

# 1. Project Setup
set project_name "ethernet_rx"
set part_name "xc7z015clg485-2"

# Avoid deleting if running simple modifications only, but here we rebuild from scratch to be safe
# file delete -force $project_name 

create_project -force $project_name . -part $part_name

# 2. Add Sources
# We are inside the 'build' directory (project root/build)
# So 'rtl' is at '../rtl'
add_files [glob ../rtl/*.sv]
add_files -fileset constrs_1 ../constraints/AX7015B.xdc

# 3. Create ILA for Debugging
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
set_property -dict [list \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {8} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {20} \
    CONFIG.C_PROBE5_WIDTH {26} \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_NUM_OF_PROBES {6} \
    CONFIG.C_INPUT_PIPE_STAGES {1} \
] [get_ips ila_0]
generate_target {instantiation_template} [get_files */ila_0.xci]
update_compile_order -fileset sources_1

# Set Top Module
set_property top top [current_fileset]

# 3. Synthesis and Implementation
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Check Status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed."
    exit 1
}

# 4. Copy Bitstream & Reports
if {[file exists $project_name.runs/impl_1/top.bit]} {
    # Open Implemented Design for Reporting
    open_run impl_1
    
    # 4a. Copy Bitstream
    file copy -force $project_name.runs/impl_1/top.bit ../ethernet_rx.bit
    
    # 4b. Generate Reports (Utilization & Timing)
    report_utilization -file ../utilization.rpt
    report_timing_summary -file ../timing_summary.rpt
    
    # 4c. Export Debug Probes (LTX)
    if {[file exists $project_name.runs/impl_1/top.ltx]} {
        # Vivado sometimes generates it automatically
        file copy -force $project_name.runs/impl_1/top.ltx ../ethernet_rx.ltx
    } else {
        # Explicitly write it if not found (or to be safe)
        write_debug_probes -force ../ethernet_rx.ltx
    }

    puts "SUCCESS: Artifacts generated:"
    puts "  - Bitstream: ../ethernet_rx.bit"
    puts "  - Debug Probes: ../ethernet_rx.ltx"
    puts "  - Utilization: ../utilization.rpt"
    puts "  - Timing: ../timing_summary.rpt"
} else {
    puts "ERROR: Bitstream file not found."
    exit 1
}
