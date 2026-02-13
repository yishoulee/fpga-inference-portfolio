`timescale 1ns / 1ps

module tb_uart_loopback;

    // Parameters
    localparam CLK_FREQ = 50_000_000;
    localparam BAUD_RATE = 115_200;
    localparam BIT_PERIOD_NS = 1_000_000_000 / BAUD_RATE;
    localparam CLK_PERIOD = 20;

    // Signals
    logic clk;
    logic rst_n;
    logic rx;
    logic tx;
    logic [3:0] leds;

    // DUT
    top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .FIFO_DEPTH(16)
    ) dut (
        .clk(clk),
        .btn_rst_n(rst_n),
        .rx(rx),
        .tx(tx),
        .leds(leds)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // UART Send Task
    task send_byte(input logic [7:0] data);
        integer i;
        begin
            // Start Bit
            rx = 0;
            #(BIT_PERIOD_NS);
            
            // Data Bits (LSB First)
            for (i = 0; i < 8; i++) begin
                rx = data[i];
                #(BIT_PERIOD_NS);
            end
            
            // Stop Bit
            rx = 1;
            #(BIT_PERIOD_NS);
        end
    endtask

    // UART Receive Task
    task receive_byte(output logic [7:0] data);
        integer i;
        begin
            // Wait for Start Bit (Falling Edge)
            wait(tx == 0);
            
            // Wait to middle of Start Bit
            #(BIT_PERIOD_NS / 2);
            
            // Wait to middle of first data bit
            #(BIT_PERIOD_NS);
            
            // Sample Data Bits
            for (i = 0; i < 8; i++) begin
                data[i] = tx;
                #(BIT_PERIOD_NS);
            end
            
            // Wait for Stop Bit
            // #(BIT_PERIOD_NS);
        end
    endtask

    // Test Sequence
    logic [7:0] sent_data;
    logic [7:0] received_data;

    initial begin
        // Initialize
        rst_n = 0;
        rx = 1; // Idle High
        
        // Reset
        #100;
        rst_n = 1;
        #1000;
        
        $display("Starting UART Loopback Test...");

        // Send 'A' (0x41)
        sent_data = 8'h41;
        fork
            send_byte(sent_data);
            receive_byte(received_data);
        join
        
        if (received_data == sent_data) 
            $display("SUCCESS: Sent 0x%h, Received 0x%h", sent_data, received_data);
        else 
            $display("ERROR: Sent 0x%h, Received 0x%h", sent_data, received_data);

        #1000;

        // Send 'B' (0x42)
        sent_data = 8'h42;
        fork
            send_byte(sent_data);
            receive_byte(received_data);
        join
        
        if (received_data == sent_data) 
            $display("SUCCESS: Sent 0x%h, Received 0x%h", sent_data, received_data);
        else 
            $display("ERROR: Sent 0x%h, Received 0x%h", sent_data, received_data);

        // Test FIFO Burst (Send fast, check returns)
        // ... (Optional)

        #5000;
        $finish;
    end

endmodule
