#!/usr/bin/env python3
import time
import struct
from scapy.all import Ether, IP, UDP, sendp, get_if_list

# Configuration
INTERFACE = "eno1" # Change to your interface
TARGET_MAC = "ff:ff:ff:ff:ff:ff" # Broadcast or your FPGA MAC
TARGET_IP = "192.168.1.10" # Doesn't really matter for this parser

def send_market_data(symbol="0050", price=15000):
    print(f"Sending Market Data: Symbol={symbol}, Price={price} on {INTERFACE}")
    
    # Payload Construction
    # 1. Symbol: 4 bytes (ASCII)
    symbol_bytes = symbol.encode('ascii')
    if len(symbol_bytes) != 4:
        print("Error: Symbol must be exactly 4 characters.")
        return

    # 2. Price: 4 bytes (32-bit Integer, Big Endian)
    price_bytes = struct.pack('>I', price)
    
    # 3. Create Payload
    payload = symbol_bytes + price_bytes
    
    # 4. Construct Packet
    # Padded with dummy data to offset 42 if needed? 
    # No, assuming standard headers:
    # Ether (14) + IP (20) + UDP (8) = 42 bytes.
    # The payload starts immediately at byte 42 relative to the start of the frame?
    # Actually, Scapy handles the headers.
    # The FPGA parser logic counts bytes from the START Of the AXI Stream.
    # The AXI Stream usually starts with the Destination MAC (Byte 0).
    # So:
    # Bytes 0-13: Ether Header
    # Bytes 14-33: IP Header
    # Bytes 34-41: UDP Header
    # Bytes 42-45: Symbol
    # Bytes 46-49: Price
    
    pkt = Ether(dst=TARGET_MAC) / IP(dst=TARGET_IP) / UDP(dport=1234, sport=5678) / payload
    
    # Send
    sendp(pkt, iface=INTERFACE, verbose=False)
    print("Sent.")

if __name__ == "__main__":
    try:
        while True:
            # Send Matching Packet (Target is hardcoded to 0050 in FPGA)
            send_market_data("0050", 15200) # e.g., 152.00 TWD
            time.sleep(1)
            
            # Send Non-Matching Packet (e.g., TSMC 2330)
            send_market_data("2330", 10000) # 1000.00 TWD
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\nStopped.")
