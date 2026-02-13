`timescale 1ns / 1ps

module top #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115_200,
    parameter FIFO_DEPTH = 32
)(
    input  logic       clk,
    input  logic       btn_rst_n,
    input  logic       rx,
    output logic       tx,
    output logic [3:0] leds
);

    logic rst_n;
    assign rst_n = btn_rst_n; // Assuming button is active low and debounced or clean enough for this simple lab

    // Internal signals
    logic [7:0] rx_data;
    logic       rx_valid;
    
    logic [7:0] tx_data;
    logic       tx_ready;
    logic       tx_start; // Derived from FIFO empty status
    
    logic       fifo_full;
    logic       fifo_empty;
    logic       fifo_w_en;
    logic       fifo_r_en;
    
    // UART RX
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx         (rx),
        .dout       (rx_data),
        .dout_valid (rx_valid)
    );

    // FIFO Control Logic
    // Write whenever RX has valid data and FIFO is not full
    assign fifo_w_en = rx_valid && !fifo_full;

    // FIFO
    fifo #(
        .DATA_WIDTH (8),
        .DEPTH      (128)
    ) u_fifo (
        .clk    (clk),
        .rst_n  (rst_n),
        .w_en   (fifo_w_en),
        .w_data (rx_data),
        .full   (fifo_full),
        .r_en   (fifo_r_en),
        .r_data (tx_data),
        .empty  (fifo_empty)
    );

    // UART TX Control Logic
    // Start transmission if FIFO is not empty and TX is ready
    assign fifo_r_en = !fifo_empty && tx_ready;
    assign tx_start  = !fifo_empty; // Valid data available for TX

    // UART TX
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk       (clk),
        .rst_n     (rst_n),
        .din       (tx_data),
        .din_valid (tx_start), // If FIFO not empty, we present valid data
        .tx_ready  (tx_ready),
        .tx        (tx)
    );

    // --- DEBUG: HARDWARE LOOPBACK BYPASS ---
    // Connect RX directly to TX to verify electrical signal path
    // assign tx = rx; 
    // ---------------------------------------

    // Debug LEDs
    // LEDs are Active Low on AX7015B (0 = ON, 1 = OFF)
    assign leds[0] = ~fifo_full;   // ON when FIFO Full
    assign leds[1] = ~fifo_empty;  // ON when FIFO Empty
    assign leds[2] = ~rx;          // ON when RX Low (Activity)
    assign leds[3] = ~tx;          // ON when TX Low (Activity)

endmodule
