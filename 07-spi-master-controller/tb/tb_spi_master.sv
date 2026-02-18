`timescale 1ns / 1ps

module tb_spi_master;

    // Parameters
    localparam CLK_FREQ   = 100_000_00; // 10 MHz simulation clock
    localparam SPI_FREQ   = 1_000_000;  // 1 MHz SPI
    localparam DATA_WIDTH = 8;
    localparam CLK_PERIOD = 100; // 10ns

    // Signals
    logic                   clk;
    logic                   rst_n;
    logic [DATA_WIDTH-1:0]  tx_data;
    logic                   start;
    logic [DATA_WIDTH-1:0]  rx_data;
    logic                   done;
    logic                   busy;
    
    logic                   spi_sclk;
    logic                   spi_cs_n;
    logic                   spi_mosi;
    logic                   spi_miso;

    // DUT Instantiation
    spi_master #(
        .CLK_FREQ(CLK_FREQ),
        .SPI_FREQ(SPI_FREQ),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .start(start),
        .rx_data(rx_data),
        .done(done),
        .busy(busy),
        .spi_sclk(spi_sclk),
        .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Loopback Connection: MISO <= MOSI
    assign spi_miso = spi_mosi; // Simple loopback

    // Stimulus
    initial begin
        // Initialize
        rst_n = 0;
        start = 0;
        tx_data = 8'h00;
        
        // Reset
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 5);
        
        // Test 1: Send 0xA5 (10100101)
        $display("Test 1: Loopback 0xA5");
        tx_data = 8'hA5;
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        
        // Wait for done
        wait(done);
        #(CLK_PERIOD);
        
        if (rx_data === 8'hA5) begin
            $display("Test 1 PASS: Rx Data match Tx Data (0xA5)");
        end else begin
            $display("Test 1 FAIL: Rx Data (0x%h) != Tx Data (0x%h)", rx_data, tx_data);
        end

        // Test 2: Send 0x3C (00111100)
        #(CLK_PERIOD * 10);
        $display("Test 2: Loopback 0x3C");
        tx_data = 8'h3C;
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        
        wait(done);
        #(CLK_PERIOD);
        
        if (rx_data === 8'h3C) begin
            $display("Test 2 PASS: Rx Data match Tx Data (0x3C)");
        end else begin
            $display("Test 2 FAIL: Rx Data (0x%h) != Tx Data (0x%h)", rx_data, tx_data);
        end

        // End simulation
        #(CLK_PERIOD * 10);
        $display("All tests completed.");
        $finish;
    end

endmodule
