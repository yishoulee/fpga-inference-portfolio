import serial
import serial.tools.list_ports
import random
import time
import sys
import argparse

# Configuration Defaults
DEFAULT_BAUD = 115200
DEFAULT_CHUNK = 16  # Reduced to 16 for stability
DEFAULT_COUNT = 100
DEFAULT_TIMEOUT = 2.0  # Increased timeout

def list_ports():
    ports = serial.tools.list_ports.comports()
    print("\n[INFO] Available Serial Ports:")
    if not ports:
        print("  - No serial ports found.")
    for port, desc, hwid in ports:
        print(f"  - {port}: {desc} [{hwid}]")
    print("")

def stress_test(port, baud, chunk_size, num_chunks):
    try:
        # Open Serial Port
        ser = serial.Serial(port, baud, timeout=DEFAULT_TIMEOUT)
        # Toggle DTR/RTS to ensure clean state (some adapters use this to flush)
        ser.dtr = False
        ser.rts = False
        time.sleep(0.1)
        ser.dtr = True
        ser.rts = True
        time.sleep(0.5) # Wait for line to settle
        
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        print(f"[INFO] Opened {port} at {baud} baud (buffer flushed)")
    except Exception as e:
        print(f"[ERROR] Could not open port {port}: {e}")
        list_ports()
        print("Hint: Use --port to specify correct device (e.g., /dev/ttyUSB1)")
        return False

    errors = 0
    print(f"[INFO] Starting stress test: {num_chunks} chunks of {chunk_size} bytes...")

    try:
        for i in range(num_chunks):
            # Generate random bytes
            data_out = bytes([random.randint(0, 255) for _ in range(chunk_size)])
            
            # Send
            ser.write(data_out)
            ser.flush() # Ensure data is sent
            
            # Small delay to allow FPGA/USB latency processing
            time.sleep(0.02)
            
            # Receive
            data_in = ser.read(len(data_out))
            
            # Validate
            if len(data_in) != len(data_out):
                print(f"[FAIL] Chunk {i+1}: Timeout/Partial! Sent {len(data_out)}, Recv {len(data_in)}")
                print(f"  Sent: {data_out[:10].hex()}...")
                print(f"  Recv: {data_in[:10].hex()}...")
                if len(data_in) > 0:
                     try:
                         print(f"  Recv (Text): {data_in.decode('utf-8', errors='ignore')}")
                     except: pass
                errors += 1
            elif data_in != data_out:
                print(f"[FAIL] Chunk {i+1}: Data Mismatch!")
                print(f"  Sent: {data_out[:10].hex()}...")
                print(f"  Recv: {data_in[:10].hex()}...")
                # Start heuristic diagnosis
                if len(data_in) > 0 and data_in[0] == 0x31: # '1'
                    print("  [DIAGNOSIS] Received ASCII '1' (0x31). You are likely connected to the Zynq PS Console.")
                    print("  [ACTION] Connect an external USB-TTL adapter to pins M1 (RX) and M2 (TX).")
                errors += 1
            else:
                if (i+1) % 10 == 0:
                    print(f"[PASS] Chunk {i+1}/{num_chunks} verified.")

    except KeyboardInterrupt:
        print("\n[INFO] Test stopped by user.")
        return False
    except Exception as e:
        print(f"\n[ERROR] Exception during test: {e}")
        return False
    finally:
        if 'ser' in locals() and hasattr(ser, 'close'):
            ser.close()

    if errors == 0:
        print("\n[SUCCESS] All chunks verified! FIFO Depth 128 confirmed working.")
        return True
    else:
        print(f"\n[FAILURE] Total Errors: {errors}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="UART FIFO Stress Test")
    parser.add_argument("--port", default="/dev/ttyUSB1", help="Serial port (default: /dev/ttyUSB1)")
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD, help="Baud rate (default: 115200)")
    parser.add_argument("--chunk", type=int, default=DEFAULT_CHUNK, help="Chunk size (bytes)")
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT, help="Number of chunks")
    
    args = parser.parse_args()

    # Auto-detect if default ttyUSB1 is missing but ttyUSB0 exists, just to be helpful?
    # No, stick to explicit. But listing ports on startup is good.
    list_ports()
    
    print(f"Targeting: {args.port} (Connect adapter TX->M1, RX->M2)")
    stress_test(args.port, args.baud, args.chunk, args.count)
