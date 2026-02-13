`timescale 1ns / 1ps

module axi_lite_slave # (
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
) (
    // Global Signals
    input wire  s_axi_aclk,
    input wire  s_axi_aresetn,

    // Write Address Channel (AW)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
    input wire [2 : 0] s_axi_awprot,
    input wire  s_axi_awvalid,
    output wire  s_axi_awready,

    // Write Data Channel (W)
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
    input wire  s_axi_wvalid,
    output wire  s_axi_wready,

    // Write Response Channel (B)
    output wire [1 : 0] s_axi_bresp,
    output wire  s_axi_bvalid,
    input wire  s_axi_bready,

    // Read Address Channel (AR)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
    input wire [2 : 0] s_axi_arprot,
    input wire  s_axi_arvalid,
    output wire  s_axi_arready,

    // Read Data Channel (R)
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
    output wire [1 : 0] s_axi_rresp,
    output wire  s_axi_rvalid,
    input wire  s_axi_rready,

    // User Interface
    output wire [31:0] control_reg_o,
    input  wire [31:0] status_reg_i
);

    // Register declarations
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0; // Control Reg (0x00)
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1; // Status Reg (0x04) - internal shadow or direct mapping
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg2; // Scratchpad (0x08)

    // AXI4-Lite Internal Signals
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0] axi_rresp;
    reg axi_rvalid;

    // Address decoding
    // We only care about bits [ADDR_WIDTH-1 : 2] for 32-bit aligned addresses
    wire [1:0] write_addr_index;
    wire [1:0] read_addr_index;

    // I/O Connections assignments
    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bresp   = axi_bresp; // 'b00 is OKAY
    assign s_axi_bvalid  = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rdata   = axi_rdata;
    assign s_axi_rresp   = axi_rresp; // 'b00 is OKAY
    assign s_axi_rvalid  = axi_rvalid;

    // Map control register to output (e.g., to LEDs / NPU control)
    assign control_reg_o = slv_reg0;
    
    // Status register comes from input (e.g. from NPU/FIFO status)
    // Note: We don't write to slv_reg1 from AXI, we read from status_reg_i
    
    //----------------------------------------------
    // Write State Machine / Logic
    //----------------------------------------------
    
    // Helper to detect a valid write request
    // Strategy: Accept write address and data in the same cycle if possible, or handshake independently.
    // Spec suggestion: "Combine AW and W channels." 
    // We will assert ready when both valid signals are present.
    
    assign write_addr_index = s_axi_awaddr[3:2];

    integer i;

    always @(posedge s_axi_aclk) begin
        if (s_axi_aresetn == 1'b0) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            axi_bresp   <= 2'b0;
            // Active Low LEDs: Reset to all 1s so LEDs are OFF by default
            slv_reg0    <= {C_S_AXI_DATA_WIDTH{1'b1}};

            slv_reg2    <= 32'd0;
        end else begin
            // Handshake Logic for Write Address and Write Data
            // We only accept them when both are valid to simplify state
            if (~axi_awready && ~axi_wready && s_axi_awvalid && s_axi_wvalid && ~axi_bvalid) begin
                axi_awready <= 1'b1;
                axi_wready  <= 1'b1;
                
                // Perform the write
                case (write_addr_index)
                    2'h0: begin // 0x00
                        for (i=0; i < (C_S_AXI_DATA_WIDTH/8); i=i+1) begin
                            if (s_axi_wstrb[i]) 
                                slv_reg0[(i*8) +: 8] <= s_axi_wdata[(i*8) +: 8];
                        end
                    end
                    2'h1: begin // 0x04
                        // Status register is READ ONLY. Writes are ignored.
                    end
                    2'h2: begin // 0x08
                        for (i=0; i < (C_S_AXI_DATA_WIDTH/8); i=i+1) begin
                            if (s_axi_wstrb[i]) 
                                slv_reg2[(i*8) +: 8] <= s_axi_wdata[(i*8) +: 8];
                        end
                    end
                    default: begin
                        // Invalid address, do nothing
                    end
                endcase
            end else begin
                // Deassert ready signals after one cycle
                if (axi_awready) axi_awready <= 1'b0;
                if (axi_wready)  axi_wready  <= 1'b0;
            end

            // Write Response Logic
            if (axi_awready && axi_wready && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b00; // OKAY
            end else if (s_axi_bready && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    //----------------------------------------------
    // Read State Machine / Logic
    //----------------------------------------------

    assign read_addr_index = s_axi_araddr[3:2];

    always @(posedge s_axi_aclk) begin
        if (s_axi_aresetn == 1'b0) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rresp   <= 2'b0;
            axi_rdata   <= 32'd0;
        end else begin
            // Read Address Handshaking
            if (~axi_arready && s_axi_arvalid) begin
                axi_arready <= 1'b1;
            end else begin
                axi_arready <= 1'b0;
            end

            // Read Data Generation
            if (axi_arready && s_axi_arvalid && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b00; // OKAY
                
                case (read_addr_index)
                    2'h0: axi_rdata <= slv_reg0;    // Control
                    2'h1: axi_rdata <= status_reg_i; // Status (External Input)
                    2'h2: axi_rdata <= slv_reg2;    // Scratchpad
                    default: axi_rdata <= 32'd0;
                endcase
            end else if (axi_rvalid && s_axi_rready) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
