`timescale 1ns / 1ps

module tb_bram_controller;

    // Parameters
    parameter   C_S_AXI_DATA_WIDTH = 32;
    parameter   C_S_AXI_ADDR_WIDTH = 12;

    // Signals
    logic       s_axi_aclk;
    logic       s_axi_aresetn;

    logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    logic [2:0] s_axi_awprot;
    logic       s_axi_awvalid;
    logic       s_axi_awready;

    logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb;
    logic       s_axi_wvalid;
    logic       s_axi_wready;

    logic [1:0] s_axi_bresp;
    logic       s_axi_bvalid;
    logic       s_axi_bready;

    logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    logic [2:0] s_axi_arprot;
    logic       s_axi_arvalid;
    logic       s_axi_arready;

    logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0] s_axi_rresp;
    logic       s_axi_rvalid;
    logic       s_axi_rready;

    // Port B Signals
    logic       bram_clk_b;
    logic       bram_en_b;
    logic [9:0] bram_addr_b;
    logic [31:0] bram_rdata_b;

    // DUT Instantiation
    bram_controller #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) dut (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),

        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .bram_clk_b(bram_clk_b),
        .bram_en_b(bram_en_b),
        .bram_addr_b(bram_addr_b),
        .bram_rdata_b(bram_rdata_b)
    );

    // Clock Generation
    initial begin
        s_axi_aclk = 0;
        forever #5 s_axi_aclk = ~s_axi_aclk; // 100MHz
    end

    // Use same clock for Port B for simplicity in testbench
    assign bram_clk_b = s_axi_aclk;

    // AXI Write Task
    task axi_write(input [C_S_AXI_ADDR_WIDTH-1:0] addr, input [C_S_AXI_DATA_WIDTH-1:0] data);
        begin
            // Setup data
            s_axi_awaddr <= addr;
            s_axi_awvalid <= 1;
            s_axi_wdata <= data;
            s_axi_wvalid <= 1;
            s_axi_wstrb <= 4'hF;
            s_axi_bready <= 1; // Accept response

            // Wait for handshake
            wait (s_axi_awready && s_axi_wready);
            @(posedge s_axi_aclk);
            
            s_axi_awvalid <= 0;
            s_axi_wvalid <= 0;

            // Wait for response
            wait (s_axi_bvalid);
            @(posedge s_axi_aclk);
            s_axi_bready <= 0;
        end
    endtask

    // AXI Read Task
    task axi_read(input [C_S_AXI_ADDR_WIDTH-1:0] addr, output [C_S_AXI_DATA_WIDTH-1:0] data);
        begin
            s_axi_araddr <= addr;
            s_axi_arvalid <= 1;
            s_axi_rready <= 1;

            wait (s_axi_arready);
            @(posedge s_axi_aclk);
            s_axi_arvalid <= 0;

            wait (s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge s_axi_aclk);
            s_axi_rready <= 0;
        end
    endtask

    // Main Test Sequence
    logic [31:0] read_val;

    initial begin
        // Reset
        s_axi_aresetn = 0;
        s_axi_awvalid = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;
        bram_en_b = 0;
        bram_addr_b = 0;

        #100;
        s_axi_aresetn = 1;
        #20;

        $display("Starting BRAM Controller Test...");

        // 1. Write Data to Address 0x00 (Index 0)
        $display("Writing 0xDEADBEEF to Addr 0x00");
        axi_write(12'h000, 32'hDEADBEEF);
        #20;

        // 2. Write Data to Address 0x10 (Index 4)
        $display("Writing 0x12345678 to Addr 0x10");
        axi_write(12'h010, 32'h12345678);
        #20;

        // 3. Read back via AXI
        $display("Reading back Addr 0x00 via AXI");
        axi_read(12'h000, read_val);
        if (read_val === 32'hDEADBEEF) $display("PASS: AXI Read matched.");
        else $error("FAIL: AXI Read mismatch. Expected 0xDEADBEEF, got 0x%h", read_val);

        // 4. Read back via Port B (Native Interface)
        $display("Reading Addr 0x04 (Index 4) via Port B");
        bram_addr_b = 10'd4; // 0x10 bytes -> index 4 words
        bram_en_b = 1;
        @(posedge bram_clk_b); // Wait for clock edge
        #1; // Wait a tiny bit for read propagation in simulation (behavioral)
            // Actually in synchronous RAM, data is available AFTER clock edge.
            // Wait one more clock cycle to see the data captured
        @(posedge bram_clk_b); 
        #1;

        if (bram_rdata_b === 32'h12345678) $display("PASS: Port B Read matched.");
        else $error("FAIL: Port B Read mismatch. Expected 0x12345678, got 0x%h", bram_rdata_b);

        bram_en_b = 0;

        // Latency Measurement Simulation
        // In this simulation, we can see the waveforms.
        // AXI Latency = Time from ARVALID high to RVALID high.
        
        $display("Measuring AXI Read Latency...");
        s_axi_araddr <= 12'h000;
        s_axi_arvalid <= 1;
        s_axi_rready <= 1;
        
        // Capture time when request is made
        // We are at a clock edge (or just after due to previous delays)
        // Let's align to clock
        
        // Wait for handshake to complete to confirm start of transaction
        // But latency starts when we ASSERT Valid.
        
        // Actually, let's just count cycles.
        fork
            begin
                wait(s_axi_rvalid);
            end
            begin
                int cycles = 0;
                while (!s_axi_rvalid) begin
                    @(posedge s_axi_aclk);
                    cycles++;
                end
                $display("AXI Read Latency: %0d clock cycles (Simulation)", cycles);
            end
        join

        @(posedge s_axi_aclk);
        s_axi_arvalid <= 0;
        s_axi_rready <= 0;


        #50;
        $finish;
    end

endmodule
