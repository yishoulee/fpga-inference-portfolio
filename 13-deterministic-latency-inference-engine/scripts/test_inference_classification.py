#!/usr/bin/env python3
import time
import struct
import argparse
import random
from scapy.all import Ether, IP, UDP, sendp, get_if_list

# Configuration
INTERFACE = "eno1" 
FEATURE_ID = "0050"

def create_packet(feature_id, value, payload_bytes):
    # 1. Construct Payload
    feature_id_data = feature_id.ljust(4, '\x00').encode()
    value_data  = struct.pack('>I', value)
    udp_payload = feature_id_data + value_data + payload_bytes
    
    # 2. Construct Ethernet Frame
    pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / \
          IP(dst="255.255.255.255") / \
          UDP(dport=1234, sport=1234) / \
          udp_payload
    return pkt

def send_burst(interface, count, mode, delay):
    print(f"Sending {count} inference vectors. Mode: {mode}")
    
    payload = b'\x01\x02\x03\x04\x05\x06\x07\x08'
    
    for i in range(count):
        if mode == 'class0':
            # Class 0: Value < Threshold (50)
            val = random.randint(20, 49)
        elif mode == 'class1':
            # Class 1: Value > Threshold (50)
            val = random.randint(50, 80)
        elif mode == 'mix':
            val = random.randint(20, 80)
        else: # force specific value
            val = int(mode)
            
        pkt = create_packet(FEATURE_ID, val, payload)
        sendp(pkt, iface=interface, verbose=False)
        
        print(f"Sent Value: {val}")
        if delay > 0:
            time.sleep(delay)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Test Inference Classification')
    parser.add_argument('--iface', default=INTERFACE, help=f'Network Interface (default: {INTERFACE})')
    parser.add_argument('--mode', default='mix', help='Mode: class0, class1, mix, or integer value')
    parser.add_argument('--count', type=int, default=100, help='Number of packets')
    parser.add_argument('--delay', type=float, default=0.05, help='Delay between packets (s)')
    
    args = parser.parse_args()
    
    available = get_if_list()
    if args.iface not in available:
        print(f"Warning: Interface '{args.iface}' not found. Available: {available}")
    
    try:
        send_burst(args.iface, args.count, args.mode, args.delay)
    except KeyboardInterrupt:
        print("\nStopped.")
    except Exception as e:
        print(f"\nError: {e}")
        print("Try with sudo.")
