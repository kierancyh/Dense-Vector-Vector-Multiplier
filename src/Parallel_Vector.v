`timescale 1ns / 1ps

/* Parallel Dot Product Accumulator (Pipelined MAC + Handshake Wallace Tree)
   Iteratively computes dot product of long vectors using NUM_MACS MACs.
   Uses pipelined MAC and handshake-enabled Wallace Tree.
*/
module Parallel_Vector #(
    parameter VECTOR_SIZE = 1024,          // Total number of elements in vectors
    parameter NUM_MACS = 128                 // Number of parallel MAC units
)(
    input clk,
    input rst,
    input start,
    input  [8*VECTOR_SIZE-1:0] vec_A_flat, // Flattened vector A
    input  [8*VECTOR_SIZE-1:0] vec_B_flat, // Flattened vector B

    output reg [31:0] result,              // Final dot product result
    output reg done,                       // High for 1 cycle when done
    output reg [9:0] cycle_count,          // Counts how many MAC rounds executed
    output [8*NUM_MACS-1:0] A_debug_flat,
    output [8*NUM_MACS-1:0] B_debug_flat,
    output [16*NUM_MACS-1:0] MAC_debug_flat,
    output [31:0] adder_output,
    output [2:0] fsm_state_debug,
    output [NUM_MACS-1:0] done_flags
);

    // Vector Unpacking
    wire [7:0] vec_A [0:VECTOR_SIZE-1];
    wire [7:0] vec_B [0:VECTOR_SIZE-1];
    genvar i;
    generate
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin : unpack
            assign vec_A[i] = vec_A_flat[8*i +: 8];
            assign vec_B[i] = vec_B_flat[8*i +: 8];
        end
    endgenerate

    // Index and MAC Wiring
    reg [9:0] idx;
    wire [15:0] mac_results [0:NUM_MACS-1];
    wire [NUM_MACS-1:0] done_flags_internal;
    assign done_flags = done_flags_internal;
    reg [15:0] mac_results_latched [0:NUM_MACS-1];
    wire [NUM_MACS*16-1:0] mac_results_flat;
    reg [7:0] A_debug [0:NUM_MACS-1];
    reg [7:0] B_debug [0:NUM_MACS-1];
    reg [15:0] MAC_debug [0:NUM_MACS-1];

    // FSM states
    localparam IDLE  = 3'b000,
               LOAD  = 3'b001,
               WAIT  = 3'b010,
               LATCH = 3'b011,
               RUN   = 3'b100,
               DONE  = 3'b101;

    reg [2:0] state;
    assign fsm_state_debug = state;

    reg mac_start;          // Enables MACs for 1 cycle
    reg all_done_last;      // Previous cycle's done_flags check

    // New Wallace handshake signals
    reg  wallace_in_valid;
    wire wallace_in_ready;
    wire wallace_out_valid;

    // Instantiate MAC units and debug trackers
    generate
        for (i = 0; i < NUM_MACS; i = i + 1) begin : mac_array
            wire [7:0] a_val = (idx + i < VECTOR_SIZE) ? vec_A[idx + i] : 8'd0;
            wire [7:0] b_val = (idx + i < VECTOR_SIZE) ? vec_B[idx + i] : 8'd0;

            MAC_pipelined mac_inst (
                .clk(clk),
                .rst(rst),
                .enable(mac_start),
                .A(a_val),
                .B(b_val),
                .result(mac_results[i]),
                .done(done_flags_internal[i])
            );

            assign mac_results_flat[i*16 +: 16] = mac_results_latched[i];

            always @(posedge clk) begin
                A_debug[i]   <= a_val;
                B_debug[i]   <= b_val;
                MAC_debug[i] <= mac_results[i];
                if (all_done_last) begin
                    mac_results_latched[i] <= mac_results[i];   // Latch when MACs done
                end
            end
        end
    endgenerate

    // Flatten debug arrays
    genvar j;
    generate
        for (j = 0; j < NUM_MACS; j = j + 1) begin : pack_debug
            assign A_debug_flat[8*j +: 8]     = A_debug[j];
            assign B_debug_flat[8*j +: 8]     = B_debug[j];
            assign MAC_debug_flat[16*j +: 16] = MAC_debug[j];
        end
    endgenerate

    // Instantiate handshake Wallace Tree
    wire [31:0] batch_sum;
    WallaceTree #(.N(NUM_MACS)) wallace_tree_inst (
        .clk(clk),
        .rst(rst),
        .in_valid(wallace_in_valid),
        .in_ready(wallace_in_ready),
        .in_flat(mac_results_flat),
        .out_valid(wallace_out_valid),
        .out(batch_sum)
    );

    reg [31:0] adder_output_reg;
    assign adder_output = adder_output_reg;

    // FSM Control Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idx                  <= 0;
            state                <= IDLE;
            result               <= 0;
            done                 <= 0;
            cycle_count          <= 0;
            adder_output_reg     <= 0;
            mac_start            <= 0;
            all_done_last        <= 0;
            wallace_in_valid     <= 0;
        end else begin
            all_done_last <= &done_flags_internal;
            done <= 0;
            wallace_in_valid <= 0;  // default unless pulsed in LATCH

            case (state)
                // IDLE: Wait for start
                IDLE: begin
                    result           <= 0;
                    cycle_count      <= 0;
                    idx              <= 0;
                    mac_start        <= 0;
                    wallace_in_valid <= 0;
                    if (start)
                        state <= LOAD;
                end

                // LOAD: Load MACs with 8-bit inputs
                LOAD: begin
                    mac_start <= 1;
                    state     <= WAIT;
                end

                // WAIT: Wait for all MACs to finish computing
                WAIT: begin
                    mac_start <= 0;
                    if (&done_flags_internal)
                        state <= LATCH;
                end

                // LATCH: Capture MAC outputs and feed to Wallace Tree
                LATCH: begin
                    if (wallace_in_ready) begin
                        wallace_in_valid <= 1'b1;  // Pulse input into Wallace Tree
                        state <= RUN;
                    end
                end

                // RUN: Wait for Wallace Tree result
                RUN: begin
                    if (wallace_out_valid) begin
                        adder_output_reg <= batch_sum;
                        result           <= result + batch_sum;
                        cycle_count      <= cycle_count + 1;
                        idx              <= idx + NUM_MACS;
                        state            <= (idx + NUM_MACS >= VECTOR_SIZE) ? DONE : LOAD;
                    end
                end

                // DONE: Dot product complete
                DONE: begin
                    done  <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
