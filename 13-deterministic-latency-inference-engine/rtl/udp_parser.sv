`timescale 1ns / 1ps

module udp_parser (
    input  logic        clk,
    input  logic        rst_n,

    // AXI-Stream Input (From MAC)
    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,

    // Configuration
    input  logic [31:0] target_feature_id, // e.g., "ID01" or "0050"

    // Output Interface
    output logic [7:0]  feature_out, // Truncated to 8-bit for NPU
    output logic        feature_valid,
    output logic        debug_id_match // Expose ID match for LED debugging
);

    // Byte counter to track position in the packet
    logic [15:0] byte_counter;
    
    // Internal registers for symbol and feature accumulation
    logic [31:0] current_feature_id;
    logic match_active;
    logic [2:0]  post_match_count;
    
    // Main processing logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_counter       <= '0;
            current_feature_id <= '0;
            match_active       <= 1'b0;
            post_match_count   <= '0;
            feature_out        <= '0;
            feature_valid      <= 1'b0;
            debug_id_match     <= 1'b0;
        end else begin
            // Default valid low (pulse for one cycle)
            feature_valid <= 1'b0;
            debug_id_match <= 1'b0; 

            if (s_axis_tvalid) begin
                // Update counter
                if (!s_axis_tlast) begin
                    byte_counter <= byte_counter + 1;
                end else begin
                    byte_counter <= '0;
                end

                // CONTINUOUS SHIFT REGISTER: Bulletproof against network stack misalignments!
                // We shift every byte in. When we see "0050", we know the value is exactly 4 bytes away.
                current_feature_id <= {current_feature_id[23:0], s_axis_tdata};
                
                if ({current_feature_id[23:0], s_axis_tdata} == target_feature_id) begin 
                    match_active <= 1'b1;
                    post_match_count <= 3'd0;
                end
                
                if (match_active) begin
                    post_match_count <= post_match_count + 1;
                    if (post_match_count == 3'd3) begin
                        // Exactly 4th byte after the ID is the target value (Because of Big-Endian packing)
                        debug_id_match <= 1'b1;
                        feature_out    <= s_axis_tdata; // Pipe directly to NPU
                        feature_valid  <= 1'b1;
                        match_active   <= 1'b0; // Reset after triggering
                    end
                end
            end else begin
                match_active <= 1'b0;
            end

            // Auto-clear output one cycle after valid
            // Essential for multi-PE wavefront: subsequent cycles must be 0
            if (feature_valid) begin
                feature_out <= 8'd0;
                feature_valid <= 1'b0; // Clear valid pulse to prevent trailing zeros from triggering NPU valid
            end
        end
    end

endmodule

