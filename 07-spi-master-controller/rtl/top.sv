
module top #(
    parameter int CLK_FREQ = 50_000_000,
    parameter int SPI_FREQ = 100_000      // Slow down to 100kHz for visibility/signal integrity on wires
) (
    input  logic       sys_clk,
    input  logic       btn_rst_n,
    
    output logic [3:0] leds,
    
    // SPI Interface (PMOD J11)
    output logic       spi_mosi, 
    input  logic       spi_miso
    // SCLK and CS_N removed for simple loopback test
);

    // -------------------------------------------------------------------------
    // Signal Declarations
    // -------------------------------------------------------------------------
    logic       rst_n;
    logic [7:0] tx_data;
    logic [7:0] rx_data;
    logic       start;
    logic       done;
    logic       busy;
    
    // Internal SPI signals (unconnected to pads)
    logic       spi_sclk;
    logic       spi_cs_n;
    
    // Synchronize Reset
    logic rst_n_sync_0, rst_n_sync_1;
    always_ff @(posedge sys_clk) begin
        rst_n_sync_0 <= btn_rst_n;
        rst_n_sync_1 <= rst_n_sync_0;
    end
    assign rst_n = rst_n_sync_1;

    // -------------------------------------------------------------------------
    // 1 Hz Trigger Generation
    // -------------------------------------------------------------------------
    localparam int CNT_MAX = CLK_FREQ - 1;
    logic [$clog2(CNT_MAX+1)-1:0] timer_cnt;
    
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_cnt <= '0;
            start     <= 1'b0;
            tx_data   <= 8'h00;
        end else begin
            start <= 1'b0; // Pulse
            
            if (timer_cnt == CNT_MAX) begin
                timer_cnt <= '0;
                start     <= 1'b1;       // Trigger SPI transaction
                tx_data   <= tx_data + 1; // Increment data
            end else begin
                timer_cnt <= timer_cnt + 1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // SPI Master Instantiation
    // -------------------------------------------------------------------------
    spi_master #(
        .CLK_FREQ(CLK_FREQ),
        .SPI_FREQ(SPI_FREQ), // 100kHz
        .DATA_WIDTH(8)
    ) u_spi_master (
        .clk(sys_clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .start(start),
        .rx_data(rx_data),
        .done(done),
        .busy(busy),
        .spi_sclk(spi_sclk),
        .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

    // -------------------------------------------------------------------------
    // LED Output
    // -------------------------------------------------------------------------
    // Display received data (Lower 4 bits)
    // LEDs on AX7015 are Active HIGH? NO, Active HIGH according to schematic usually 
    // BUT the constraint file indicates common LEDs are often Active High on Alinx boards.
    // Wait, let's check the user's previous statement "LEDS active low -> Fix LED logic".
    // I previously inverted them.
    // If the user says "led is not shining", maybe they mean it SHOULD shine but isn't?
    // If it isn't shining, it's OFF.
    // If Active Low logic is used: Output 1 -> OFF. Output 0 -> ON.
    // If RX Data is 0 (LSB 0), Output is ~0 = 1 (OFF).
    // So if RX Data is 0, LED is OFF.
    // If it *should* be shining, then RX Data *should* be 1 (LSB 1).
    // But TX Data is incrementing, so LSB toggles.
    // If LED is *never* shining, then RX Data is *always* 0.
    
    // So my hypothesis holds: RX Data LSB is stuck at 0.
    
    assign leds = ~rx_data[3:0]; // Assuming Active Low LEDs based on previous context

endmodule
