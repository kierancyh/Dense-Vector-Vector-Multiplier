`timescale 1ns / 1ps

module tb_Parallel_Vector;

    // Testbench parameters
    parameter VECTOR_SIZE = 1024;           // Total number of elements per vector (Can be changed according to Test; Up to 1024)
    parameter NUM_MACS    = 64;            // Number of parallel MAC units {Can be changed according to Test/User; Can also do non-powers of 2;
                                            // Up to 256 MACs [Anymore Vivado Behavioral Simulation starts to buffer or fail]                                    
    // Clock and control signals
    reg clk = 0;
    reg rst;
    reg start;
    wire done;                              // Asserted when computation finishes
    wire [31:0] result;                     // Final accumulated dot product result
    wire [9:0] cycle_count;                 // Number of cycles taken by computation
    wire [31:0] adder_output;               // Current adder tree output

    // Flattened debug outputs from DUT 
    wire [8*NUM_MACS-1:0] A_debug_flat;     
    wire [8*NUM_MACS-1:0] B_debug_flat;
    wire [16*NUM_MACS-1:0] MAC_debug_flat;

    wire [2:0] fsm_state;                   // FSM state of the DUT
    wire [NUM_MACS-1:0] done_flags;         // Done flags from each MAC unit

    // Loop counter
    integer i;

    // Flattened input vectors
    reg [8*VECTOR_SIZE-1:0] vec_A_flat;
    reg [8*VECTOR_SIZE-1:0] vec_B_flat;

    // Performance metrics
    integer elements_processed;
    real throughput;
    real utilization;

    // Clock and throughput timing (For Performance Metrics)
    real clk_period_ns = 10.0;             // 10ns period = 100 MHz (Changed given FMAX -> 13.7s ns period for 128 MACs)
    real clk_freq_hz;                      // Calculated in initial block
    real latency_time;
    real throughput_e_per_s;

    // Latency tracking
    integer latency_cycles;
    reg latency_started;
    real latency_time_ns;

    // Expected result (use 64-bit to prevent overflow)
    reg [63:0] expected_result;

    // Instantiate the DUT
    Parallel_Vector #(
        .VECTOR_SIZE(VECTOR_SIZE),
        .NUM_MACS(NUM_MACS)
    ) dut (
        .clk(clk), .rst(rst), .start(start),
        .vec_A_flat(vec_A_flat), .vec_B_flat(vec_B_flat),
        .result(result), .done(done),
        .cycle_count(cycle_count),
        .A_debug_flat(A_debug_flat), .B_debug_flat(B_debug_flat),
        .MAC_debug_flat(MAC_debug_flat), .adder_output(adder_output),
        .fsm_state_debug(fsm_state),
        .done_flags(done_flags)
    );

    // Clock generation (10ns period)
    // always #5 clk = ~clk;
    // FMAX 
     always #5 clk = ~clk;       

    // System reset task
    task reset_system;
    begin
        rst = 1;
        start = 0;
        vec_A_flat = 0;
        vec_B_flat = 0;
        latency_cycles = 0;
        latency_started = 0;
        #20;
        rst = 0;
        #10;
    end
    endtask

    initial begin
        // Initialize clock
        clk = 0;
        clk_freq_hz = 1e9 / clk_period_ns;  //Change to 0.909e9 for FMAX of 90.91MHz
        /*
        // TEST 1: Linear dot product
        $display("TEST 1: Linear Dot Product for 1 to 8 in each Vector");
        reset_system();

        // Setup: A = [1..8], B = [1..8]
        vec_A_flat = {8'd8, 8'd7, 8'd6, 8'd5, 8'd4, 8'd3, 8'd2, 8'd1};
        vec_B_flat = {8'd8, 8'd7, 8'd6, 8'd5, 8'd4, 8'd3, 8'd2, 8'd1};
        expected_result = 204;

        // Start signal
        start = 1; #10; start = 0;

        while (!done) begin
            #10;
            if (!latency_started && fsm_state == 3'b001) begin // LOAD state
                latency_started = 1;
                latency_cycles = 0;
            end else if (latency_started && !done) begin
                latency_cycles = latency_cycles + 1;
            end
        end

        $display("Result       : %0d", result);
        $display("Expected     : %0d", expected_result);
        $display("Cycles       : %0d", cycle_count);
        if (result === expected_result[31:0])
            $display("PASS\n");
        else
            $display("FAIL\n");
        */
        
        // TEST 2: Max Stress Test
        $display("TEST 2: MAX STRESS CASE (255 x 255 x VECTOR_SIZE)");
        reset_system();

        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
            vec_A_flat[i*8 +: 8] = 8'd255;
            vec_B_flat[i*8 +: 8] = 8'd255;
        end
        expected_result = VECTOR_SIZE * 255 * 255;

        start = 1; #10; start = 0;

        while (!done) begin
            #10;
            if (!latency_started && fsm_state == 3'b001) begin
                latency_started = 1;
                latency_cycles = 0;
            end else if (latency_started && !done) begin
                latency_cycles = latency_cycles + 1;
            end
        end

        $display("Result       : %0d", result);
        $display("Expected     : %0d", expected_result);
        $display("Cycles       : %0d", cycle_count);
        if (result === expected_result[31:0])
            $display("PASS\n");
        else
            $display("FAIL\n");
        
        /*
        // TEST 3: All Zeros
        $display("TEST 3: EDGE CASE - All Zeros");
        reset_system();

        vec_A_flat = 0;
        vec_B_flat = 0;
        expected_result = 0;

        start = 1; #10; start = 0;

        while (!done) begin
            #10;
            if (!latency_started && fsm_state == 3'b001) begin
                latency_started = 1;
                latency_cycles = 0;
            end else if (latency_started && !done) begin
                latency_cycles = latency_cycles + 1;
            end
        end

        $display("Result       : %0d", result);
        $display("Expected     : %0d", expected_result);
        $display("Cycles       : %0d", cycle_count);
        if (result === expected_result[31:0])
            $display("PASS\n");
        else
            $display("FAIL\n");
        */
        // Performance Metrics
        elements_processed       = VECTOR_SIZE;
        throughput               = VECTOR_SIZE / (cycle_count * 1.0);
        utilization              = (VECTOR_SIZE * 1.0) / (NUM_MACS * cycle_count);
        clk_freq_hz              = 1e9 / clk_period_ns;                         // Clock frequency in Hz
        latency_time_ns          = latency_cycles * clk_period_ns;              // Total latency in ns
        throughput_e_per_s       = VECTOR_SIZE * clk_freq_hz / latency_cycles;  // Throughput in elements/sec

        $display("Performance Metrics Summary (Unpipelined MACs using Wallace Tree):");
        $display("  Total Cycles            : %0d", cycle_count);
        $display("  Elements Processed      : %0d", elements_processed);
        $display("  Latency (cycles)        : %0d", latency_cycles);
        $display("  Latency Time            : %.2f ns", latency_time_ns);
        $display("  Throughput              : %0f elements/second (%.2f MHz clock)", throughput_e_per_s, clk_freq_hz / 1e6);
        $display("  MACs Used               : %0d ", NUM_MACS);
        $display("  MAC Utilization Rate    : %0f (ideal = 1.0)", utilization);

        $finish;
    end

endmodule
