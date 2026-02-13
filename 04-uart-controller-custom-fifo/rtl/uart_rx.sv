`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,
    output logic [7:0] dout,
    output logic       dout_valid
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2;

    typedef enum logic [2:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT,
        CLEANUP
    } state_t;

    state_t state;
    
    logic rx_sync_chain [1:0];
    logic rx_stable;

    logic [$clog2(CLKS_PER_BIT):0] clk_cnt;
    logic [2:0] bit_index;
    logic [7:0] rx_byte;

    // Double-flop synchronization for metastability
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_chain[1] <= 1'b1; // Idle high
            rx_sync_chain[0] <= 1'b1;
        end else begin
            rx_sync_chain[0] <= rx;
            rx_sync_chain[1] <= rx_sync_chain[0];
        end
    end
    assign rx_stable = rx_sync_chain[1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_cnt <= 0;
            bit_index <= 0;
            rx_byte <= 0;
            dout <= 0;
            dout_valid <= 0;
        end else begin
            dout_valid <= 1'b0; // Default

            case (state)
                IDLE: begin
                    clk_cnt <= 0;
                    bit_index <= 0;
                    if (rx_stable == 1'b0) begin // Start bit detected
                        state <= START_BIT;
                    end
                end

                START_BIT: begin
                    if (clk_cnt == HALF_CLKS_PER_BIT - 1) begin
                        if (rx_stable == 1'b0) begin
                            clk_cnt <= 0;
                            state <= DATA_BITS;
                        end else begin
                            state <= IDLE; // False start
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                DATA_BITS: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        rx_byte[bit_index] <= rx_stable;
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP_BIT;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                STOP_BIT: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        state <= CLEANUP;
                        clk_cnt <= 0;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                CLEANUP: begin
                    dout <= rx_byte;
                    dout_valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
