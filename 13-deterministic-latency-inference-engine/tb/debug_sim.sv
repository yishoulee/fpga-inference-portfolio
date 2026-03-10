`timescale 1ns / 1ps

module debug_sim;
    reg clk;
    reg rst_n;
    // We cannot connect directly to internal ports like weight_0, but npu_core exposes them.
    // Wait, npu_core takes 8 weight inputs.
    
    // Wire up inputs
    reg [7:0] w0, w1, w2, w3, w4, w5, w6, w7;
    reg [7:0] f_in;
    reg v_in;
    
    // Outputs
    wire [31:0] res;
    wire res_valid;
    
    // Instance
    npu_core dut (
        .clk(clk), 
        .rst_n(rst_n),
        .weight_0(w0), .weight_1(w1), .weight_2(w2), .weight_3(w3),
        .weight_4(w4), .weight_5(w5), .weight_6(w6), .weight_7(w7),
        .feature_in(f_in), 
        .valid_in(v_in),
        .result_out(res), 
        .result_valid(res_valid)
    );
    
    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end
    
    // Stimulus
    initial begin
        $monitor("Time=%t | F_in=%d | Valid_In=%b | Result=%d | Valid_Out=%b | Pipe=%h", 
                 $time, f_in, v_in, res, res_valid, dut.valid_pipe);
                 
        rst_n = 0;
        w0 = 1; w1 = 1; w2 = 1; w3 = 1; w4 = 1; w5 = 1; w6 = 1; w7 = 1;
        f_in = 0;
        v_in = 0;
        
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("--- Starting Pulse ---");
        // Pulse Input
        @(posedge clk);
        f_in <= 100;
        v_in <= 1;
        
        @(posedge clk);
        f_in <= 0;
        v_in <= 0;
        
        $display("--- Pulse Sent ---");
        
        repeat(30) @(posedge clk);
        $finish;
    end

endmodule
