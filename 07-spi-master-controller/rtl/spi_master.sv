`timescale 1ns / 1ps

module spi_master #(
    parameter int CLK_FREQ  = 50_000_000, // System clock frequency
    parameter int SPI_FREQ  = 1_000_000,  // Target SPI clock frequency
    parameter int DATA_WIDTH = 8          // Data width
) (
    input  logic                   clk,
    input  logic                   rst_n,
    
    // User Interface
    input  logic [DATA_WIDTH-1:0]  tx_data,
    input  logic                   start,
    output logic [DATA_WIDTH-1:0]  rx_data,
    output logic                   done,
    output logic                   busy,
    
    // SPI Physical Interface
    output logic                   spi_sclk,
    output logic                   spi_cs_n,
    output logic                   spi_mosi,
    input  logic                   spi_miso
);

    // Calculate clock divider
    // We need 2 edges per SPI period (Toggle). 
    // Count = (System / Target) / 2
    localparam int CLK_DIV = (CLK_FREQ / SPI_FREQ) / 2;
    
    // -------------------------------------------------------------------------
    // Signal Declarations
    // -------------------------------------------------------------------------
    logic [$clog2(CLK_DIV+1)-1:0] clk_cnt;
    logic                         sclk_en_rise; // Enable for rising edge of SPI clock
    logic                         sclk_en_fall; // Enable for falling edge of SPI clock
    
    // FSM States
    typedef enum logic [2:0] {
        IDLE,
        CS_LOW,
        TRANSFER,
        CS_HIGH,
        DONE_STATE
    } state_t;
    
    state_t state, next_state;

    logic [$clog2(DATA_WIDTH+1)-1:0] bit_cnt;
    logic [DATA_WIDTH-1:0]           shift_reg;
    logic                            sclk_reg;
    logic                            miso_sample; // New signal
    
    // -------------------------------------------------------------------------
    // Clock Divider / Edge Generation
    // -------------------------------------------------------------------------
    // Generates enable pulses for the SPI clock edges
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt      <= '0;
            sclk_en_rise <= 1'b0;
            sclk_en_fall <= 1'b0;
        end else if (state == TRANSFER) begin
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= '0;
                // If current sclk is 0, next is rising edge
                // If current sclk is 1, next is falling edge
                if (sclk_reg == 1'b0) begin
                    sclk_en_rise <= 1'b1;
                    sclk_en_fall <= 1'b0;
                end else begin
                    sclk_en_rise <= 1'b0;
                    sclk_en_fall <= 1'b1;
                end
            end else begin
                clk_cnt      <= clk_cnt + 1;
                sclk_en_rise <= 1'b0;
                sclk_en_fall <= 1'b0;
            end
        end else begin
            // Reset counters when not transferring
            clk_cnt      <= '0;
            sclk_en_rise <= 1'b0;
            sclk_en_fall <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // SPI Clock Generation (Toggle on Enables)
    // -------------------------------------------------------------------------
    // CPOL = 0: Idle Low
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_reg <= 1'b0;
        end else if (state == IDLE) begin
            sclk_reg <= 1'b0;
        end else if (sclk_en_rise) begin
            sclk_reg <= 1'b1;
        end else if (sclk_en_fall) begin
            sclk_reg <= 1'b0;
        end
    end
    
    assign spi_sclk = sclk_reg;

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = CS_LOW;
            end
            
            CS_LOW: begin
                // Wait one cycle or immediately go to transfer
                // Usually good to give a setup time for CS before first clock
                next_state = TRANSFER; 
            end
            
            TRANSFER: begin
                // We leave transfer state when we have shifted all bits
                // Mode 0: Sample on Rise, Shift on Fall.
                // We start with bit count 0.
                // When we are processing the last bit (DATA_WIDTH-1),
                // We sample at Rise, and then at Fall we are done.
                // So if bit_cnt == DATA_WIDTH-1 && sclk_en_fall
                if (bit_cnt == DATA_WIDTH - 1 && sclk_en_fall) begin 
                   // Finished last falling edge
                   next_state = CS_HIGH;
                end
            end
            
            CS_HIGH: begin
                // Hold CS high for a bit if needed, or just done
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Datapath & Output Logic
    // -------------------------------------------------------------------------
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= '0;
            bit_cnt   <= '0;
            rx_data   <= '0;
            done      <= 1'b0;
            spi_cs_n  <= 1'b1;
        end else begin
            // Default assignments
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    spi_cs_n  <= 1'b1;
                    bit_cnt   <= '0;
                    if (start) begin
                        shift_reg <= tx_data; // Load data
                    end
                end
                
                CS_LOW: begin
                    spi_cs_n <= 1'b0; // Assert CS
                end
                
                TRANSFER: begin
                    // SPI Mode 0: Sample on Rise, Shift on Fall
                    if (sclk_en_rise) begin
                        miso_sample <= spi_miso; // Safe sample into separate register
                    end
                    
                    if (sclk_en_fall) begin
                         // Shift counter check
                        if (bit_cnt < DATA_WIDTH - 1) begin
                           // Shift Left: Discards MSB (TX bit), shifts in sampled LSB
                           shift_reg <= {shift_reg[DATA_WIDTH-2:0], miso_sample};
                           bit_cnt   <= bit_cnt + 1;
                        end else begin
                           // Last Bit (count=7)
                           // We shift one last time to bring the final sampled bit into LSB
                           shift_reg <= {shift_reg[DATA_WIDTH-2:0], miso_sample}; 
                           bit_cnt   <= bit_cnt + 1;
                        end
                    end
                end
                
                CS_HIGH: begin
                    spi_cs_n <= 1'b1;
                end
                
                DONE_STATE: begin
                   done    <= 1'b1;
                   rx_data <= shift_reg; 
                end
            endcase
            
        end
    end

    assign busy = (state != IDLE);
    
    // MSB First
    assign spi_mosi = shift_reg[DATA_WIDTH-1];

endmodule
