`timescale 1ns / 1ps

module tb_axi_lite_slave;

    // Parameters
    parameter C_S_AXI_DATA_WIDTH = 32;
    parameter C_S_AXI_ADDR_WIDTH = 4;

    // Signals
    reg  aclk;
    reg  aresetn;

    // Write Address Channel
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] awaddr;
    reg [2 : 0] awprot;
    reg  awvalid;
    wire awready;

    // Write Data Channel
    reg [C_S_AXI_DATA_WIDTH-1 : 0] wdata;
    reg [(C_S_AXI_DATA_WIDTH/8)-1 : 0] wstrb;
    reg  wvalid;
    wire wready;

    // Write Response Channel
    wire [1 : 0] bresp;
    wire bvalid;
    reg  bready;

    // Read Address Channel
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] araddr;
    reg [2 : 0] arprot;
    reg  arvalid;
    wire arready;

    // Read Data Channel
    wire [C_S_AXI_DATA_WIDTH-1 : 0] rdata;
    wire [1 : 0] rresp;
    wire rvalid;
    reg  rready;

    // User Interface
    wire [31:0] control_reg_o;
    reg  [31:0] status_reg_i;

    // Clock Generation
    always #5 aclk = ~aclk; // 100MHz clock

    // DUT Instantiation
    axi_lite_slave #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) dut (
        .s_axi_aclk(aclk),
        .s_axi_aresetn(aresetn),

        .s_axi_awaddr(awaddr),
        .s_axi_awprot(awprot),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),

        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),

        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),

        .s_axi_araddr(araddr),
        .s_axi_arprot(arprot),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),

        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),

        .control_reg_o(control_reg_o),
        .status_reg_i(status_reg_i)
    );

    // Tasks for AXI Transactions
    
    // Write Task (Simultaneous Address and Data)
    task axi_write(input [3:0] addr, input [31:0] data);
        begin
            @(posedge aclk);
            awaddr <= addr;
            awvalid <= 1'b1;
            wdata <= data;
            wstrb <= 4'hF; // Write all bytes
            wvalid <= 1'b1;
            bready <= 1'b0;

            // Wait for partial handshakes
            // In our design, we expect ready signals to come up together or close
            wait (awready && wready);

            @(posedge aclk);
            awvalid <= 1'b0;
            wvalid <= 1'b0;
            
            // Wait for response
            bready <= 1'b1;
            wait (bvalid);
            
            @(posedge aclk);
            bready <= 1'b0;
        end
    endtask

    // Read Task
    task axi_read(input [3:0] addr, output [31:0] data_out);
        begin
            @(posedge aclk);
            araddr <= addr;
            arvalid <= 1'b1;
            rready <= 1'b0;

            wait (arready);
            @(posedge aclk);
            arvalid <= 1'b0;

            // Wait for data
            rready <= 1'b1;
            wait (rvalid);
            data_out = rdata; // Sample data

            @(posedge aclk);
            rready <= 1'b0;
        end
    endtask

    // Main Test Sequence
    initial begin
        reg [31:0] read_val;

        // Initialize
        aclk = 0;
        aresetn = 0;
        awaddr = 0; awprot = 0; awvalid = 0;
        wdata = 0; wstrb = 0; wvalid = 0;
        bready = 0;
        araddr = 0; arprot = 0; arvalid = 0;
        rready = 0;
        status_reg_i = 32'hDEAD_BEEF; // Default Status

        // Reset
        #20 aresetn = 1;
        #20;

        $display("Starting AXI Lite Register File Verification...");

        // 1. Write to Control Register (0x00)
        $display("Writing 0x12345678 to Control Register (0x00)");
        axi_write(4'h0, 32'h12345678);

        // Check Output
        #10;
        if (control_reg_o == 32'h12345678) 
            $display("PASS: Control Register Output updated correctly.");
        else
            $display("FAIL: Control Register Output mismatch. Expected 0x12345678, got %h", control_reg_o);

        // 2. Read back Control Register
        axi_read(4'h0, read_val);
        if (read_val == 32'h12345678) 
            $display("PASS: Read back Control Register matches.");
        else 
            $display("FAIL: Read back Control Register mismatch. Got %h", read_val);

        // 3. Read Status Register (0x04)
        $display("Reading Status Register (0x04) - Input is 0xDEADBEEF");
        axi_read(4'h4, read_val);
        if (read_val == 32'hDEAD_BEEF) 
            $display("PASS: Status Register Read matches input.");
        else 
            $display("FAIL: Status Register Read mismatch. Got %h", read_val);

        // 4. Test Scratchpad (0x08)
        $display("Writing 0xAA55AA55 to Scratchpad (0x08)");
        axi_write(4'h8, 32'hAA55AA55);
        
        $display("Reading Scratchpad (0x08)");
        axi_read(4'h8, read_val);
        
        if (read_val == 32'hAA55AA55) 
            $display("PASS: Scratchpad Read/Write successful.");
        else 
            $display("FAIL: Scratchpad mismatch. Got %h", read_val);

        // 5. Test Write to Read-Only Status Reg (Should not change)
        $display("Attempting to write to READ-ONLY Status Register (0x04)");
        axi_write(4'h4, 32'hBAD_C0DE);
        
        // Change input slightly to verification doesn't read old value if it was latent
        status_reg_i = 32'h00C0_FFEE;
        #10;
        axi_read(4'h4, read_val);
        if (read_val == 32'h00C0_FFEE) 
            $display("PASS: Status Register is indeed Read Only (Value reflects input, not write).");
        else 
            $display("FAIL: Status Register seems to have been overwritten or incorrect. Got %h", read_val);


        $display("Test Bench Completed.");
        $finish;
    end

endmodule
