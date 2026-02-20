#!/usr/bin/env python3
import time
from scapy.all import Ether, IP, UDP, sendp, get_if_list

# Configuration
# Replace with your network interface name (e.g., "eth0", "enp3s0")
INTERFACE = "eno1" 

def send_test_packets():
    print(f"Sending packets on {INTERFACE}...")
    
    # 1. Broadcast Packet (Destination MAC FF:FF:FF:FF:FF:FF)
    # This should definitely be picked up by the FPGA if promiscuous or broadcast aware.
    pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / IP(dst="255.255.255.255") / UDP(dport=1234, sport=1234) / "Hello FPGA"
    
    try:
        while True:
            sendp(pkt, iface=INTERFACE, verbose=False)
            print(".", end="", flush=True)
            time.sleep(0.1) # 10 packets per second
    except KeyboardInterrupt:
        print("\nStopped.")

if __name__ == "__main__":
    print("Available Interfaces:", get_if_list())
    try:
        send_test_packets()
    except Exception as e:
        print(f"Error: {e}")
        print("You might need to run with sudo: sudo python3 scripts/test_eth.py")
