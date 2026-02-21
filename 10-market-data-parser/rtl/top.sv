`timescale 1ns / 1ps

module top (
    input  wire       sys_clk,      // 50 MHz System Clock
    input  wire       btn_rst_n,    // Active Low Reset Button

    // RGMII Interface (from PHY)
    input  wire       eth_rxc,
    input  wire       eth_rx_ctl,
    input  wire [3:0] eth_rxd,
    
    // PHY Controls
    output wire       phy_rst_n,

    // LEDs for Debug
    output wire [2:0] leds
);

    // Internal Signals
    wire        rst_n;
    wire        gmii_rx_clk;
    wire        gmii_rx_dv;
    wire [7:0]  gmii_rxd;
    wire        gmii_rx_er;

    wire [7:0]  axis_tdata;
    wire        axis_tvalid;
    wire        axis_tlast;
    wire        axis_tuser;

    // Parser Signals
    logic [31:0] target_symbol;
    logic [31:0] price_data;
    logic        price_valid;
    
    // Parser Debug Signals (Internal to udp_parser, but we want to see them if we probe hierarchy)
    // For ILA at top level, we might just look at IOs, but VIO is better for target_symbol.
    
    // Reset Sync
    reg [2:0] rst_sync;
    always_ff @(posedge gmii_rx_clk or negedge btn_rst_n) begin
        if (!btn_rst_n) begin
            rst_sync <= 3'b000;
        end else begin
            rst_sync <= {rst_sync[1:0], 1'b1};
        end
    end
    assign rst_n = rst_sync[2];
    
    assign phy_rst_n = btn_rst_n; 

    // -------------------------------------------------------------------------
    // IDELAYCTRL Reference Clock Generation (200 MHz from 50 MHz)
    // -------------------------------------------------------------------------
    wire clk_200m_unbuf;
    wire clk_200m;
    wire clk_fb_out, clk_fb_in;
    wire pll_locked;

    PLLE2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT(20),       // 50 MHz * 20 = 1000 MHz VCO
        .CLKFBOUT_PHASE(0.0),
        .CLKIN1_PERIOD(20.0),     // 50 MHz input period
        .CLKOUT0_DIVIDE(5),       // 1000 MHz / 5 = 200 MHz
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),
        .DIVCLK_DIVIDE(1),
        .REF_JITTER1(0.0),
        .STARTUP_WAIT("FALSE")
    ) u_pll_200 (
        .CLKOUT0(clk_200m_unbuf),
        .CLKOUT1(),
        .CLKOUT2(),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKFBOUT(clk_fb_out),
        .LOCKED(pll_locked),
        .CLKIN1(sys_clk),
        .PWRDWN(1'b0),
        .RST(~btn_rst_n),
        .CLKFBIN(clk_fb_in)
    );

    BUFG u_bufg_fb (
        .I(clk_fb_out),
        .O(clk_fb_in)
    );

    BUFG u_bufg_200 (
        .I(clk_200m_unbuf),
        .O(clk_200m)
    );

    (* IODELAY_GROUP = "rgmii_rx_group" *)
    IDELAYCTRL u_idelayctrl (
        .RDY(),            
        .REFCLK(clk_200m), 
        .RST(~pll_locked)
    );

    // -------------------------------------------------------------------------
    // Core Logic
    // -------------------------------------------------------------------------

    // 1. RGMII Receiver
    rgmii_rx u_rgmii_rx (
        .rst_n          (rst_n),
        .rgmii_rxc      (eth_rxc),
        .rgmii_rx_ctl   (eth_rx_ctl),
        .rgmii_rxd      (eth_rxd),
        .gmii_rx_clk    (gmii_rx_clk), // 125 MHz buffered
        .gmii_rx_dv     (gmii_rx_dv),
        .gmii_rxd_out   (gmii_rxd),
        .gmii_rx_er     (gmii_rx_er)
    );

    // 2. MAC Receiver (Stripping Preamble/CRC)
    mac_rx u_mac_rx (
        .rx_clk         (gmii_rx_clk),
        .rst_n          (rst_n),
        .gmii_rxd       (gmii_rxd),
        .gmii_rx_dv     (gmii_rx_dv),
        .m_axis_tdata   (axis_tdata),
        .m_axis_tvalid  (axis_tvalid),
        .m_axis_tlast   (axis_tlast),
        .m_axis_tuser   (axis_tuser)
    );

    // 3. UDP Market Data Parser
    // For now, hardcode target symbol to 0050 (Taiwan top 50 ETF). 
    // "0050" in ASCII: 0x30303530
    assign target_symbol = "0050"; 

    udp_parser u_parser (
        .clk            (gmii_rx_clk),
        .rst_n          (rst_n),
        .s_axis_tdata   (axis_tdata),
        .s_axis_tvalid  (axis_tvalid),
        .s_axis_tlast   (axis_tlast),
        .target_symbol  (target_symbol),
        .price_data     (price_data),
        .price_valid    (price_valid)
    );

    // -------------------------------------------------------------------------
    // Debug & Status
    // -------------------------------------------------------------------------

    // Heartbeat
    reg [25:0] hb_cnt;
    always_ff @(posedge sys_clk) hb_cnt <= hb_cnt + 1;

    // Latch Price Valid for LED (Flash for human visibility)
    reg [23:0] led_flash_cnt;
    reg        val_latched;

    always_ff @(posedge gmii_rx_clk) begin
        // Use synchronous reset or simple init
        if (!rst_n) begin
            led_flash_cnt <= 0;
            val_latched <= 0;
        end else begin
            if (price_valid) begin
                led_flash_cnt <= 24'hFFFFFF; // Set max count (~0.13s at 125MHz)
                val_latched <= 1'b1;
            end else if (led_flash_cnt > 0) begin
                led_flash_cnt <= led_flash_cnt - 1;
                val_latched <= 1'b1;
            end else begin
                val_latched <= 1'b0;
            end
        end
    end

    // Extend Activity LED as well
    reg [23:0] act_flash_cnt;
    reg        act_latched;
    
    always_ff @(posedge gmii_rx_clk) begin
        if (!rst_n) begin
            act_flash_cnt <= 0;
            act_latched <= 0;
        end else begin
            if (axis_tvalid) begin
                act_flash_cnt <= 24'h400000; // Shorter flash for activity (~0.03s)
                act_latched <= 1'b1;
            end else if (act_flash_cnt > 0) begin
                act_flash_cnt <= act_flash_cnt - 1;
                act_latched <= 1'b1;
            end else begin
                act_latched <= 1'b0;
            end
        end
    end

    // LED Assignments
    assign leds[0] = ~hb_cnt[25];    // Fast blink: System Alive
    assign leds[1] = ~val_latched;   // Flash on Price Update (0050 found)
    assign leds[2] = ~act_latched;   // Activity light (flickers on any packet)

    // -------------------------------------------------------------------------
    // ILA Instantiation
    // -------------------------------------------------------------------------

    // We want to probe:
    // 1. Data In (8)
    // 2. Valid In (1)
    // 3. Price Valid (1)
    // 4. Price Data (32)
    // 5. Total 42 bits? No.
    // Let's create an ILA with specific port widths.
    
    ila_0 u_ila (
        .clk(gmii_rx_clk),
        .probe0(axis_tdata),    // [7:0]
        .probe1(axis_tvalid),   // [0:0]
        .probe2(axis_tlast),    // [0:0]
        .probe3(price_valid),   // [0:0]
        .probe4(price_data)     // [31:0]
    );

endmodule
