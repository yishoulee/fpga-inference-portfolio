`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] din,
    input  logic       din_valid,
    output logic       tx_ready,
    output logic       tx
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    typedef enum logic [2:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT,
        CLEANUP
    } state_t;

    state_t state;
    
    logic [$clog2(CLKS_PER_BIT):0] clk_cnt;
    logic [2:0] bit_index;
    logic [7:0] tx_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_cnt <= 0;
            bit_index <= 0;
            tx_data <= 0;
            tx_ready <= 1'b0; // Will set to 1 in IDLE
            tx <= 1'b1;       // Idle high
        end else begin
            case (state)
                IDLE: begin
                    tx_ready <= 1'b1;
                    tx <= 1'b1;
                    clk_cnt <= 0;
                    bit_index <= 0;
                    
                    if (din_valid) begin
                        tx_ready <= 1'b0;
                        tx_data <= din;
                        state <= START_BIT;
                    end
                end

                START_BIT: begin
                    tx <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        state <= DATA_BITS;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                DATA_BITS: begin
                    tx <= tx_data[bit_index];
                    
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
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
                    tx <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        state <= IDLE; // Or CLEANUP if we need delay
                        clk_cnt <= 0;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                // Optional: Ensure stop bit duration or extra guard time
                CLEANUP: begin
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
