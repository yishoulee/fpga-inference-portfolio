`timescale 1ns / 1ps

module bram_controller #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 12 // 4KB = 1024 * 4 bytes -> 12 bits
) (
    // Global Signals
    input wire  s_axi_aclk,
    input wire  s_axi_aresetn,

    // AXI4-Lite Write Address Channel
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
    input wire [2 : 0] s_axi_awprot,
    input wire  s_axi_awvalid,
    output wire  s_axi_awready,

    // AXI4-Lite Write Data Channel
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
    input wire  s_axi_wvalid,
    output wire  s_axi_wready,

    // AXI4-Lite Write Response Channel
    output wire [1 : 0] s_axi_bresp,
    output wire  s_axi_bvalid,
    input wire  s_axi_bready,

    // AXI4-Lite Read Address Channel
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
    input wire [2 : 0] s_axi_arprot,
    input wire  s_axi_arvalid,
    output wire  s_axi_arready,

    // AXI4-Lite Read Data Channel
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
    output wire [1 : 0] s_axi_rresp,
    output wire  s_axi_rvalid,
    input wire  s_axi_rready,

    // Port B: Native Read Interface (Hardware Side)
    // We assume this might run on a distinct clock in a real system,
    // but for inferred BRAM in this specific task setup, we will use s_axi_aclk 
    // for simplicity unless a separate clock is requested. 
    // The prompt says "True Dual-Port (TDP) BRAM naturally handles the CDC".
    // So let's provide a clk input for Port B to be safe/correct.
    input wire       bram_clk_b,
    input wire       bram_en_b,
    input wire [9:0] bram_addr_b, // 1024 depth
    output reg [31:0] bram_rdata_b
);

    // --------------------------------------------------------
    // 1. Memory Inference
    // --------------------------------------------------------
    // 1024 words of 32-bit memory (4KB total)
    (* ram_style = "block" *) 
    reg [31:0] memory_array [0:1023];

    // --------------------------------------------------------
    // 2. Port A: AXI4-Lite Slave Controller
    // --------------------------------------------------------
    
    // Internal AXI Signals
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp; // 'b00 is OKAY
    reg axi_bvalid;
    
    reg axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0] axi_rresp; // 'b00 is OKAY
    reg axi_rvalid;

    // Derived signals
    // Addr is byte address, so [11:2] is the word index (0-1023)
    wire [9:0] mem_write_addr;
    wire [9:0] mem_read_addr;

    assign mem_write_addr = s_axi_awaddr[11:2];
    assign mem_read_addr  = s_axi_araddr[11:2];

    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bresp   = axi_bresp;
    assign s_axi_bvalid  = axi_bvalid;

    assign s_axi_arready = axi_arready;
    assign s_axi_rdata   = axi_rdata;
    assign s_axi_rresp   = axi_rresp;
    assign s_axi_rvalid  = axi_rvalid;

    // AXI WRITE STATE MACHINE
    always @(posedge s_axi_aclk) begin
        if (s_axi_aresetn == 1'b0) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            axi_bresp   <= 2'b0;
        end else begin
            // Handshake: Accept Address and Data
            // We implement a simple mode where we assert Ready only when Valid is present for both (or independently)
            // To simplify creating BRAM write pulses, we'll wait for both AWVALID and WVALID before acknowledging.
            
            if (~axi_awready && ~axi_wready && s_axi_awvalid && s_axi_wvalid && ~axi_bvalid) begin
                axi_awready <= 1'b1;
                axi_wready  <= 1'b1;
                
                // --- WRITE TO BRAM PORT A ---
                // We use s_axi_wstrb for byte enables.
                // Inferred BRAM supports byte enables.
                if (s_axi_wstrb[0]) memory_array[mem_write_addr][7:0]   <= s_axi_wdata[7:0];
                if (s_axi_wstrb[1]) memory_array[mem_write_addr][15:8]  <= s_axi_wdata[15:8];
                if (s_axi_wstrb[2]) memory_array[mem_write_addr][23:16] <= s_axi_wdata[23:16];
                if (s_axi_wstrb[3]) memory_array[mem_write_addr][31:24] <= s_axi_wdata[31:24];
                
            end else begin
                // Deassert Ready
                if (axi_awready) axi_awready <= 1'b0;
                if (axi_wready)  axi_wready  <= 1'b0;
            end

            // Write Response (B Channel)
            if (axi_awready && axi_wready && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b00; 
            end else if (s_axi_bready && axi_bvalid) begin
                axi_bvalid <= 1'b0; 
            end
        end
    end

    // AXI READ STATE MACHINE (Port A Read)
    // To allow the CPU to verify what it wrote
    always @(posedge s_axi_aclk) begin
        if (s_axi_aresetn == 1'b0) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rresp   <= 2'b0;
            // axi_rdata   <= 32'd0; // Optional reset
        end else begin
            // 1. Read Address Handshake
            if (~axi_arready && s_axi_arvalid) begin
                axi_arready <= 1'b1;
                // Latch address if needed, or use directly in next cycle
            end else begin
                axi_arready <= 1'b0;
            end

            // 2. Read Data Generation 
            // In a real BRAM, read is registered. AXI requires the data to be valid with RVALID.
            // When ARVALID/ARREADY handshake happens, we can fetch data.
            // BRAM read latency is 1 cycle (synchronous read).
            
            if (axi_arready && s_axi_arvalid && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b00; 
                
                // --- READ FROM BRAM PORT A ---
                axi_rdata <= memory_array[mem_read_addr];
            end else if (axi_rvalid && s_axi_rready) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // --------------------------------------------------------
    // 3. Port B: Native Read Interface
    // --------------------------------------------------------
    always @(posedge bram_clk_b) begin
        if (bram_en_b) begin
            bram_rdata_b <= memory_array[bram_addr_b];
        end
    end

endmodule
