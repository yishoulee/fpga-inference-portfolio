`timescale 1ns / 1ps

module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 32
)(
    input  logic                   clk,
    input  logic                   rst_n,
    
    // Write Interface
    input  logic                   w_en,
    input  logic [DATA_WIDTH-1:0]  w_data,
    output logic                   full,
    
    // Read Interface
    input  logic                   r_en,
    output logic [DATA_WIDTH-1:0]  r_data,
    output logic                   empty
);

    // Calculate pointer width needed to address DEPTH
    localparam PTR_WIDTH = $clog2(DEPTH);

    // Memory array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers with one extra bit for wrap-around detection
    logic [PTR_WIDTH:0] w_ptr; // Write pointer
    logic [PTR_WIDTH:0] r_ptr; // Read pointer

    // Reset and Pointer Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_ptr <= '0;
            r_ptr <= '0;
        end else begin
            // Write Operation
            if (w_en && !full) begin
                mem[w_ptr[PTR_WIDTH-1:0]] <= w_data;
                w_ptr <= w_ptr + 1'b1;
            end

            // Read Operation
            if (r_en && !empty) begin
                r_ptr <= r_ptr + 1'b1;
            end
        end
    end

    // Read Data Output (asynchronous read for standard memory, 
    // but often better to register if BRAM inference is desired.
    // For small UART FIFO, distributed RAM is fine, so async read is okay.
    // However, let's stick to simple behavioral model).
    assign r_data = mem[r_ptr[PTR_WIDTH-1:0]];

    // Full/Empty Flags
    // Empty: Pointers are identical
    assign empty = (w_ptr == r_ptr);

    // Full: MSB is different (wrapped once), rest is same
    assign full = (w_ptr[PTR_WIDTH] != r_ptr[PTR_WIDTH]) && 
                  (w_ptr[PTR_WIDTH-1:0] == r_ptr[PTR_WIDTH-1:0]);

endmodule
