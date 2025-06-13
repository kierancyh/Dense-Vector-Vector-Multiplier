`timescale 1ns / 1ps

/* MAC_pipelined (2-Stage Multiply Unit)
   Performs 8-bit unsigned multiplication using a shift-and-add method
   Stage 1: Latches inputs, computes shift-and-add product
   Stage 2: Latches result and asserts done
*/

module MAC_pipelined (
    input clk,                 // Clock signal 
    input rst,                 // Asynchronous reset 
    input enable,              // Enable signal 
    input [7:0] A,             // 8-bit input from Vector A
    input [7:0] B,             // 8-bit input from Vector B
    output reg [15:0] result,  // 32-bit Output (holds final product)
    output reg done            // Done signal goes high when result is valid
);

    // Stage 1 Registers
    reg [7:0] reg_A;           // Holds A input
    reg [7:0] reg_B;           // Holds B input
    reg       stage1_valid;    // Stage 1 valid flag

    // Stage 2 Registers
    reg [15:0] mult_result;    // Full shift-and-add result
    reg       stage2_valid;    // Stage 2 valid flag

    reg [15:0] temp_product;   // Intermediate product

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_A        <= 8'd0;
            reg_B        <= 8'd0;
            mult_result  <= 16'd0;
            result       <= 16'd0;
            temp_product <= 16'd0;
            stage1_valid <= 1'b0;
            stage2_valid <= 1'b0;
            done         <= 1'b0;
        end else begin
            // Stage 1: Latch A, B and perform shift-and-add multiplication
            if (enable) begin
                reg_A <= A;
                reg_B <= B;

                // Unrolled shift-and-add
                temp_product = 32'd0;
                if (B[0]) temp_product = temp_product + (A << 0);
                if (B[1]) temp_product = temp_product + (A << 1);
                if (B[2]) temp_product = temp_product + (A << 2);
                if (B[3]) temp_product = temp_product + (A << 3);
                if (B[4]) temp_product = temp_product + (A << 4);
                if (B[5]) temp_product = temp_product + (A << 5);
                if (B[6]) temp_product = temp_product + (A << 6);
                if (B[7]) temp_product = temp_product + (A << 7);

                mult_result  <= temp_product;
                stage1_valid <= 1'b1;
            end else begin
                stage1_valid <= 1'b0;
            end

            // Stage 2: Output result and done signal
            if (stage1_valid) begin
                result <= mult_result;
                done   <= 1'b1;
                stage2_valid <= 1'b1;
            end else begin
                done <= 1'b0;
                stage2_valid <= 1'b0;
            end
        end
    end

endmodule
