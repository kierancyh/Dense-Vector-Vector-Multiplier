`timescale 1ns / 1ps

module tb_MAC_pipelined;

    // Inputs
    reg clk;
    reg rst;
    reg enable;
    reg [7:0] A;
    reg [7:0] B;

    // Outputs
    wire [15:0] result;
    wire done;

    // Instantiate the Unit Under Test (UUT)
    MAC_pipelined uut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .A(A),
        .B(B),
        .result(result),
        .done(done)
    );

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        enable = 0;
        A = 0;
        B = 0;

        // Reset pulse
        #10;
        rst = 0;

        // Test case 1: 0 * 0
        @(posedge clk);
        A = 8'd0;
        B = 8'd0;
        enable = 1;
        @(posedge clk);
        enable = 0;
        wait (done);
        $display("A = 0, B = 0, Product = %d", result);

        // Test case 2: 5 * 0
        @(posedge clk);
        A = 8'd5;
        B = 8'd0;
        enable = 1;
        @(posedge clk);
        enable = 0;
        wait (done);
        $display("A = 5, B = 0, Product = %d", result);

        // Test case 3: 0 * 5
        @(posedge clk);
        A = 8'd0;
        B = 8'd5;
        enable = 1;
        @(posedge clk);
        enable = 0;
        wait (done);
        $display("A = 0, B = 5, Product = %d", result);

        // Test case 4: 3 * 4 = 12
        @(posedge clk);
        A = 8'd3;
        B = 8'd4;
        enable = 1;
        @(posedge clk);
        enable = 0;
        wait (done);
        $display("A = 3, B = 4, Product = %d", result);

        // Test case 5: 15 * 10 = 150
        @(posedge clk);
        A = 8'd15;
        B = 8'd10;
        enable = 1;
        @(posedge clk);
        enable = 0;
        wait (done);
        $display("A = 15, B = 10, Product = %d", result);

        // Test case 6: 255 * 1 = 255
        @(posedge clk);
        A = 8'd255;
        B = 8'd1;
        enable = 1;
        @(posedge clk);
        enable = 0;
        wait (done);
        $display("A = 255, B = 1, Product = %d", result);

        // Test case 7: 255 * 255 = 65025
        @(posedge clk);
        A = 8'd255;
        B = 8'd255;
        enable = 1;
        @(posedge clk);
        enable = 0;
        wait (done);
        $display("A = 255, B = 255, Product = %d", result);

        #20;
        $display("Test complete.");
        $finish;
    end

endmodule
