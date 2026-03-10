
import struct
from scapy.all import Ether, IP, UDP

def analyze_packet(feature_id, feature_val):
    feature_id_data = feature_id.encode('utf-8').ljust(4, b'\x00') 
    feature_val_data  = struct.pack('>I', feature_val)
    payload_bytes = struct.pack('B', feature_val) * 16
    
    udp_payload = feature_id_data + feature_val_data + payload_bytes
    
    pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / \
          IP(dst="255.255.255.255") / \
          UDP(dport=1234, sport=1234) / \
          udp_payload
          
    raw_bytes = bytes(pkt)
    
    print(f"Total Length: {len(raw_bytes)}")
    print("--- Byte Map ---")
    for i, b in enumerate(raw_bytes):
        desc = ""
        if i < 14: desc = "ETH"
        elif i < 34: desc = "IP"
        elif i < 42: desc = "UDP"
        elif i < 46: desc = f"ID[{i-42}]"
        elif i < 50: desc = f"VAL[{i-46}]"
        else: desc = "PAYLOAD"
        print(f"Byte {i}: 0x{b:02x} ({chr(b) if 32<=b<=126 else '.'}) - {desc}")

analyze_packet("0050", 20)
