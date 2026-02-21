import sys
import os
import time

def test_throughput(size_mb):
    size_bytes = size_mb * 1024 * 1024
    print(f"Testing with {size_mb} MB buffer...")

    # Write data (H2C)
    offset = 0x10000000 # 256MB offset to avoid OCM/Reserved regions
    data = os.urandom(size_bytes) # Generate data BEFORE timing
    
    start_time = time.time()
    try:
        with open("/dev/xdma0_h2c_0", "wb") as f:
            f.seek(offset)
            f.write(data)
            f.flush()
    except Exception as e:
        print(f"Error writing: {e}")
        return False

    end_time = time.time()
    write_speed = size_mb / (end_time - start_time)
    print(f"Write Speed: {write_speed:.2f} MB/s")

    # Read data (C2H)
    start_time = time.time()
    try:
        with open("/dev/xdma0_c2h_0", "rb") as f:
            f.seek(offset)
            read_data = f.read(size_bytes)
    except Exception as e:
        print(f"Error reading: {e}")
        return False

    end_time = time.time()
    read_speed = size_mb / (end_time - start_time)
    print(f"Read Speed: {read_speed:.2f} MB/s")

    if data == read_data:
        print("Data verification passed!")
        return True
    else:
        print("Data verification FAILED!")
        return False

if __name__ == "__main__":
    if not os.path.exists("/dev/xdma0_h2c_0"):
        print("XDMA devices not found. Is the driver loaded?")
        sys.exit(1)
    else:
        passed = True
        passed &= test_throughput(4)   # 4MB
        passed &= test_throughput(64)  # 64MB
        
        if passed:
            print("All tests passed.")
            sys.exit(0)
        else:
            print("Some tests failed.")
            sys.exit(1)
