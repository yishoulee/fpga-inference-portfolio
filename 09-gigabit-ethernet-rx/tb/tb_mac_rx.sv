`timescale 1ns / 1ps

module tb_mac_rx;
    
    // Testbench Signals
    logic       rx_clk;
    logic       rst_n;
    logic [7:0] gmii_rxd;
    logic       gmii_rx_dv;
    
    wire  [7:0] m_axis_tdata;
    wire        m_axis_tvalid;
    wire        m_axis_tlast;
    wire        m_axis_tuser;
    
    // DUT Instantiation
    mac_rx dut (
        .rx_clk(rx_clk),
        .rst_n(rst_n),
        .gmii_rxd(gmii_rxd),
        .gmii_rx_dv(gmii_rx_dv),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tuser(m_axis_tuser)
    );
    
    // Clock Generation (125 MHz -> 8ns period)
    initial begin
        rx_clk = 0;
        forever #4 rx_clk = ~rx_clk; 
    end
    
    // Task: Send Ethernet Packet
    task send_packet(input byte payload []);
        int i;
        
        // Synchronize to clock edge
        @(posedge rx_clk);
        
        // Assert DV and Send Preamble (7 bytes)
        gmii_rx_dv <= 1;
        for (i = 0; i < 7; i++) begin
            gmii_rxd <= 8'h55;
            @(posedge rx_clk);
        end
        
        // Send SFD (1 byte)
        gmii_rxd <= 8'hD5;
        @(posedge rx_clk);
        
        // Send Payload
        for (i = 0; i < payload.size(); i++) begin
            gmii_rxd <= payload[i];
            @(posedge rx_clk);
        end
        
        // Deassert DV
        gmii_rx_dv <= 0;
        gmii_rxd   <= 8'h00; // Idle bus
        @(posedge rx_clk);
        
    endtask
    
    // Latency Measurement
    integer start_time;
    integer latency;

    // Test Packet Data
    byte pkt[] = {8'h48, 8'h45, 8'h4C, 8'h4C, 8'h4F, 8'h5F, 8'h46, 8'h50, 8'h47, 8'h41};
    
    initial begin
        // Initialize
        rst_n = 0;
        gmii_rxd = 0;
        gmii_rx_dv = 0;
        
        // Reset Pulse
        #100;
        rst_n = 1;
        #20;
        
        $display("Starting Test...");
        
        fork
            begin
                // Thread 1: Send Packet after some delay
                #50;
                $display("[%0t] Sending Packet...", $time);
                send_packet(pkt);
            end
            
            begin
                // Thread 2: Measure Latency
                // Wait for SFD detection time roughly, or first valid payload out
                // We want to measure from "First byte of Payload presented at GMII" to "First byte of Payload valid at AXIS"
                
                // Wait for SFD completion in send_packet... 
                // That's hard to sync perfectly without peeking signals.
                // Let's just track when we send the first payload byte.
                wait (gmii_rxd == 8'hD5 && gmii_rx_dv); // SFD
                @(posedge rx_clk); 
                // Now we are at the edge where the first payload byte is DRIVEN.
                start_time = $time;
                $display("[%0t] Payload Start on GMII", $time);
                
                // Wait for Axis Valid
                wait (m_axis_tvalid);
                latency = ($time - start_time) / 8; // Divide by clock period (8ns)
                $display("[%0t] Payload Valid on AXIS. Latency: %0d cycles", $time, latency);
                
                if (latency <= 3) 
                    $display("PASS: Latency %0d cycles (Target <= 2-3)", latency);
                else
                    $display("FAIL: Latency %0d cycles (Target <= 2-3)", latency);
            end
            
            begin
                // Thread 3: Monitor Output
                wait(m_axis_tvalid);
                while(m_axis_tvalid) begin
                    $display("RX Data: %c (0x%h)", m_axis_tdata, m_axis_tdata);
                    
                    if (m_axis_tlast) begin
                        $display("RX TLAST detected.");
                        break;
                    end
                    @(posedge rx_clk);
                    // Add small delay to allow value update if blocking
                    #1; 
                end
            end
        join
        
        #100;
        $finish;
    end

endmodule
