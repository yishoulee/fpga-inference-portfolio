# simulation script for UDP Parser
file mkdir sim_build
cd sim_build

puts "Compiling Sources..." 
# Paths are relative to CWD (sim_build). Since we run valid make from project root, sim_build is in project root.
# So ../rtl/udp_parser.sv should work.
exec xvlog -sv ../rtl/udp_parser.sv ../tb/tb_udp_parser.sv >@ stdout

puts "Elaborating..."
exec xelab -debug typical -top tb_udp_parser -snapshot tb_udp_parser_snap >@ stdout

puts "Running Simulation..."
exec xsim tb_udp_parser_snap -R >@ stdout
