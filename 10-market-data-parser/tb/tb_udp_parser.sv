`timescale 1ns / 1ps

module tb_udp_parser;

    // Parameters
    localparam CLK_PERIOD = 8; // 125 MHz

    // Signals
    logic        clk;
    logic        rst_n;
    logic [7:0]  s_axis_tdata;
    logic        s_axis_tvalid;
    logic        s_axis_tlast;
    logic [31:0] target_symbol;
    logic [31:0] price_data;
    logic        price_valid;

    // DUT Instantiation
    udp_parser dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .target_symbol(target_symbol),
        .price_data(price_data),
        .price_valid(price_valid)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test Procedure
    initial begin
        // Initialize
        rst_n = 0;
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        target_symbol = "0050"; // Taiwan 50 ETF (0x30303530)

        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        $display("Starting Test: Sending UDP Packet with Symbol '0050' (should trigger) and Price 15000");

        // Send Packet
        send_packet("0050", 32'd15000);

        #(CLK_PERIOD * 10);
        
        // Test Mismatch
        // Update target to 2330 (TSMC) so 0050 matches would fail if we didn't change target
        target_symbol = "2330"; 
        $display("Starting Test: Sending UDP Packet with Symbol '0050' (should be ignored, target is 2330)");
        send_packet("0050", 32'd2048);

        #(CLK_PERIOD * 10);
        $finish;
    end

    // Task to send packet
    task send_packet(input [31:0] curr_symbol, input [31:0] curr_price);
        integer i;
        logic [7:0] byte_data;
        
        // Header (42 bytes of dummy data: byte index 0 to 41)
        for (i = 0; i < 42; i++) begin
            s_axis_tdata  <= i[7:0]; // Dummy header data
            s_axis_tvalid <= 1;
            s_axis_tlast  <= 0;
            @(posedge clk);
        end
        // At this point, byte_counter in DUT will be 42

        // Payload: Symbol (4 bytes: 42, 43, 44, 45)
        // Send MSB first (Big Endian)
        s_axis_tdata  <= curr_symbol[31:24]; // Byte 42 'T'
        s_axis_tvalid <= 1;
        @(posedge clk);
        // DUT byte_counter goes 42 -> 43

        s_axis_tdata  <= curr_symbol[23:16]; // Byte 43 'S'
        @(posedge clk);
        // DUT byte_counter goes 43 -> 44

        s_axis_tdata  <= curr_symbol[15:8];  // Byte 44 'L'
        @(posedge clk);
        // DUT byte_counter goes 44 -> 45

        s_axis_tdata  <= curr_symbol[7:0];   // Byte 45 'A'
        @(posedge clk);
        // DUT byte_counter goes 45 -> 46

        // Payload: Price (4 bytes: 46, 47, 48, 49)
        // Send MSB first
        s_axis_tdata  <= curr_price[31:24]; // Byte 46
        s_axis_tvalid <= 1;
        @(posedge clk);
        // DUT byte_counter goes 46 -> 47

        s_axis_tdata  <= curr_price[23:16]; // Byte 47
        @(posedge clk);
        // DUT byte_counter goes 47 -> 48

        s_axis_tdata  <= curr_price[15:8];  // Byte 48
        @(posedge clk);
        // DUT byte_counter goes 48 -> 49
        
        // Last Price Byte + TLAST
        s_axis_tdata  <= curr_price[7:0];   // Byte 49
        s_axis_tlast  <= 1; // Mark end of packet
        @(posedge clk);
        // DUT byte_counter goes 49 -> 0 (on next edge if no reset logic)

        // End of Packet
        s_axis_tlast  <= 0;
        s_axis_tvalid <= 0;
        s_axis_tdata  <= 0;
    endtask

    // Monitor
    always @(posedge clk) begin
        if (price_valid) begin
            $display("Time %t: Price Valid! Price: %0d (0x%h)", $time, price_data, price_data);
        end
    end

endmodule
