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

    // Reset Sync
    // We need to synchronize the button reset to the RX clock domain for the MAC
    reg [2:0] rst_sync;
    always_ff @(posedge gmii_rx_clk or negedge btn_rst_n) begin
        if (!btn_rst_n) begin
            rst_sync <= 3'b000;
        end else begin
            rst_sync <= {rst_sync[1:0], 1'b1};
        end
    end
    assign rst_n = rst_sync[2];
    
    // PHY Reset Logic
    // Drive Active High (Not Reset) usually. 
    // Simply connect to rst_n (which is active low system reset).
    assign phy_rst_n = btn_rst_n; // Hard reset from button directly or use internal logic

    // -------------------------------------------------------------------------
    // IDELAYCTRL Reference Clock Generation (200 MHz from 50 MHz)
    // -------------------------------------------------------------------------
    wire clk_200m_unbuf;
    wire clk_200m;
    wire clk_fb_out, clk_fb_in;
    wire pll_locked;

    // Use PLLE2_BASE to generate 200 MHz from 50 MHz sys_clk
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
        .RST(~btn_rst_n),         // Active High Reset for PLL (btn_rst_n is active low)
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

    // Instantiate IDELAYCTRL for IDELAYE2 calibration
    // Group name matches IODELAY_GROUP if set, otherwise calibrates all in bank?
    // In 7-series, one IDELAYCTRL per bank or clock region.
    // If we don't use groups, it calibrates all IDELAYs in the bank driven by refclk.
    (* IODELAY_GROUP = "rgmii_rx_group" *)
    IDELAYCTRL u_idelayctrl (
        .RDY(),            
        .REFCLK(clk_200m), // 200 MHz Reference Clock
        .RST(~pll_locked)  // Reset when PLL is not locked
    );

    // Instantiate RGMII Receiver
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

    // Instantiate MAC Receiver
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

    // LED Logic
    // LED 0: Heartbeat (blinks at ~1Hz from sys_clk)
    // LED 1: RX Activity (toggles on packet received)
    // LED 2: RX Error (latched high on tuser error)
    // LED 3: Link Up (based on gmii_rx_dv toggling? Or just on button)
    
    // Heartbeat
    reg [25:0] hb_cnt;
    always_ff @(posedge sys_clk) hb_cnt <= hb_cnt + 1;
    // assign leds[0] = hb_cnt[25]; // Moved to Active Low block below

    // RX Packet Counter for visible blinking (Bit 16 toggles every ~65k packets = Visible if high rate)
    reg [19:0] pkt_cnt;
    always_ff @(posedge gmii_rx_clk) begin
        if (!rst_n) pkt_cnt <= 0;
        else if (axis_tlast) pkt_cnt <= pkt_cnt + 1;
    end
    
    // Heartbeat for RX Clock (Slow division)
    reg [25:0] rx_hb_cnt;
    always_ff @(posedge gmii_rx_clk) rx_hb_cnt <= rx_hb_cnt + 1;

    // Heartbeat for RX Clock (Slow division)
    reg [25:0] rx_hb_cnt;
    always_ff @(posedge gmii_rx_clk) rx_hb_cnt <= rx_hb_cnt + 1;

    // LED Output Logic (Active Low: 0 = ON, 1 = OFF)
    assign leds[0] = ~rx_hb_cnt[25]; // RX Clock Heartbeat (0 = ON) - Proves PHY Clock is alive
    assign leds[1] = ~(pkt_cnt[6] || pkt_cnt[4]); // Activity (Blinks on every 64 packets, extended by bit 4 to look erratic/busy)
    assign leds[2] = ~hb_cnt[25];    // System Clock Heartbeat (0 = ON) - Proves Top Logic is alive
    
    // LED 3 (Valid) logic removed as dedicated pin (B8) is MDIO.
    // We could mux it onto one of the other LEDs if needed, or just drop it.
    // For now, leds[2] is the last one.

    // ILA for Debugging
    ila_0 u_ila (
        .clk(gmii_rx_clk),
        .probe0(gmii_rx_dv), 
        .probe1(gmii_rxd), 
        .probe2(gmii_rx_er), 
        .probe3(axis_tvalid), 
        .probe4(pkt_cnt), 
        .probe5(rx_hb_cnt)
    );

endmodule
