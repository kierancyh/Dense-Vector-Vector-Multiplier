`timescale 1ns / 1ps

module tb_WallaceTree;

    parameter N = 4;

    reg clk;
    reg rst;

    reg  [N*16-1:0] in_flat;
    reg  in_valid;
    wire in_ready;

    wire [31:0] out;
    wire out_valid;

    // DUT
    WallaceTree #(N) uut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_flat(in_flat),
        .out_valid(out_valid),
        .out(out)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Unpack for readability
    wire [15:0] A0 = in_flat[15:0];
    wire [15:0] A1 = in_flat[31:16];
    wire [15:0] A2 = in_flat[47:32];
    wire [15:0] A3 = in_flat[63:48];

    // Test task using handshake
    task run_test;
        input [N*16-1:0] input_vec;
        input [31:0] expected;
        input [255:0] label;
        begin
            // Wait until in_ready is high
            while (!in_ready) @(posedge clk);

            // Apply input
            in_flat  <= input_vec;
            in_valid <= 1'b1;
            @(posedge clk);  // Hold for one cycle
            in_valid <= 1'b0;

            // Wait for out_valid
            while (!out_valid) @(posedge clk);

            // Display result
            $display("%s", label);
            $display("Inputs  : A3 = %5d | A2 = %5d | A1 = %5d | A0 = %5d", A3, A2, A1, A0);
            $display("Expected: %5d", expected);
            $display("Result  : %5d", out);
            $display("Status  : %s\n", (out === expected) ? "PASS" : "FAIL");
        end
    endtask

    initial begin
        $display("=== Starting Handshake Wallace Tree test with N = %0d inputs ===\n", N);

        clk = 0;
        rst = 1;
        in_flat = 0;
        in_valid = 0;
        #10;
        rst = 0;
        #10;

        run_test({16'd0,     16'd0,     16'd0,     16'd0},     32'd0,      "Test 1: All zeros");
        run_test({16'd65535, 16'd65535, 16'd65535, 16'd65535}, 32'd262140, "Test 2: All max values");
        run_test({16'd30,    16'd20,    16'd10,    16'd5},     32'd65,     "Test 3: Incremental values");
        run_test({16'd3000,  16'd1234,  16'd999,   16'd1},     32'd5234,   "Test 4: Random values");
        run_test({16'd0,     16'd65535, 16'd0,     16'd1},     32'd65536,  "Test 5: Mixed edge case");

        $finish;
    end

endmodule
