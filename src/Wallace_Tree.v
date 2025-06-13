`timescale 1ns / 1ps

/* Handshake-Enabled Pipelined True Wallace Tree
   - Accepts input via in_valid/in_ready handshake
   - Produces output with out_valid
   - Fully pipelined across CSA and CPA stages
*/

module WallaceTree #(
    parameter N = 1024  // Number of 16-bit inputs (N ≥ 3, ideally divisible by 3)
)(
    input clk,
    input rst,

    input in_valid,                // Assert high when input is valid
    output reg in_ready,           // High when module can accept new input

    input [N*16-1:0] in_flat,      // Input vector (flattened)

    output reg out_valid,          // High when 'out' is valid
    output reg [31:0] out          // Final reduced output
);

    // Unpack inputs
    wire [15:0] in [0:N-1];
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin
            assign in[i] = in_flat[i*16 +: 16];
        end
    endgenerate

    // Pipeline valid tracker
    reg [3:0] pipeline_valid;
    always @(posedge clk or posedge rst) begin
        if (rst)
            pipeline_valid <= 4'b0000;
        else
            pipeline_valid <= {pipeline_valid[2:0], in_valid};
    end

    // Handshake outputs
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_valid <= 1'b0;
            in_ready  <= 1'b1;
        end else begin
            out_valid <= pipeline_valid[3];
            in_ready  <= ~pipeline_valid[0];  // Ready when stage0 is free
        end
    end

    // Stage 0: Extend to 32-bit and register
    reg [31:0] stage0 [0:N-1];
    integer j;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (j = 0; j < N; j = j + 1)
                stage0[j] <= 32'd0;
        end else if (in_valid) begin
            for (j = 0; j < N; j = j + 1)
                stage0[j] <= {16'd0, in[j]};
        end
    end

    // Stage 1: CSA compression
    localparam N1 = (N+2)/3;
    reg [31:0] sum1   [0:N1-1];
    reg [31:0] carry1 [0:N1-1];
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (j = 0; j < N1; j = j + 1) begin
                sum1[j]   <= 32'd0;
                carry1[j] <= 32'd0;
            end
        end else if (pipeline_valid[0]) begin
            for (j = 0; j < N/3; j = j + 1) begin
                sum1[j]   <= stage0[3*j] ^ stage0[3*j+1] ^ stage0[3*j+2];
                carry1[j] <= (stage0[3*j] & stage0[3*j+1]) |
                             (stage0[3*j] & stage0[3*j+2]) |
                             (stage0[3*j+1] & stage0[3*j+2]);
            end
            if (N % 3 == 1) begin
                sum1[N/3]   <= stage0[N-1];
                carry1[N/3] <= 32'd0;
            end else if (N % 3 == 2) begin
                sum1[N/3]   <= stage0[N-2] ^ stage0[N-1];
                carry1[N/3] <= stage0[N-2] & stage0[N-1];
            end
        end
    end

    // Stage 2: sum + (carry << 1)
    reg [31:0] stage2 [0:N1-1];
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (j = 0; j < N1; j = j + 1)
                stage2[j] <= 32'd0;
        end else if (pipeline_valid[1]) begin
            for (j = 0; j < N1; j = j + 1)
                stage2[j] <= sum1[j] + (carry1[j] << 1);
        end
    end

    // Stage 3: Accumulate all stage2[j]
    reg [31:0] result;
    reg [31:0] temp_sum;
    integer k;
    always @(posedge clk or posedge rst) begin
        if (rst)
            result <= 32'd0;
        else if (pipeline_valid[2]) begin
            temp_sum = 32'd0;
            for (k = 0; k < N1; k = k + 1)
                temp_sum = temp_sum + stage2[k];
            result <= temp_sum;
        end
    end

    // Final output register
    always @(posedge clk or posedge rst) begin
        if (rst)
            out <= 32'd0;
        else if (pipeline_valid[3])
            out <= result;
    end

endmodule
