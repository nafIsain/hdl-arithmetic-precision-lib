`timescale 1ns/1ps

module multi_precision_mac_comprehensive_tb;
    localparam int NUM_OPS = 8;
    localparam int ACCUMULATOR_WIDTH = 32;
    
    // DUT interface signals
    logic clk, rst_n, enable, clear, valid;
    logic [1:0] precision_mode;
    logic [7:0] operand_a, operand_b;
    logic signed [ACCUMULATOR_WIDTH-1:0] accumulator_int;
    logic [15:0] accumulator_fp16;
    
    // Test tracking and verification
    int test_count, pass_count, fail_count;
    real expected_fp_accum;
    longint expected_int_accum;
    
    // Instantiate DUT
    multi_precision_mac #(
        .ACCUMULATOR_WIDTH(ACCUMULATOR_WIDTH),
        .NUM_OPERATIONS(NUM_OPS)
    ) dut (.*);
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;
    
    // FP16 encoding/decoding functions for verification
    function real fp16_to_real(logic [15:0] fp16);
        logic sign;
        logic [4:0] exponent;
        logic [10:0] mantissa;
        int exp_unbiased;
        real mantissa_val;
        
        sign = fp16[15];
        exponent = fp16[14:10];
        mantissa = fp16[9:0];
        
        if (exponent == 0) begin
            // Denormalized
            exp_unbiased = -14;
            mantissa_val = mantissa / 1024.0;
        end else if (exponent == 31) begin
            // Inf or NaN
            return sign ? -999999.0 : 999999.0;
        end else begin
            // Normalized
            exp_unbiased = exponent - 15;
            mantissa_val = 1.0 + (mantissa / 1024.0);
        end
        
        return sign ? -(mantissa_val * (2.0 ** exp_unbiased)) : 
                      (mantissa_val * (2.0 ** exp_unbiased));
    endfunction
    
    // Test execution tasks
    task automatic reset_dut();
        rst_n = 0;
        clear = 1;
        enable = 0;
        operand_a = 0;
        operand_b = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        clear = 0;
        @(posedge clk);
    endtask
    
    task automatic run_fp8_accumulation(
        input real values_a[],
        input real values_b[],
        input logic [7:0] hex_a[],
        input logic [7:0] hex_b[],
        input int num_ops,
        input string test_name
    );
        real computed_sum;
        real actual_result;
        real rel_error;
        
        expected_fp_accum = 0.0;
        computed_sum = 0.0;
        
        $display("\n[TEST] %s", test_name);
        $display("  Accumulating %0d FP8 products...", num_ops);
        
        enable = 1;
        for (int i = 0; i < num_ops; i++) begin
            operand_a = hex_a[i];
            operand_b = hex_b[i];
            computed_sum += values_a[i] * values_b[i];
            @(posedge clk);
        end
        enable = 0;
        
        wait(valid);
        @(posedge clk);
        
        actual_result = fp16_to_real(accumulator_fp16);
        rel_error = (actual_result == 0.0) ? 0.0 : 
                    $abs((actual_result - computed_sum) / computed_sum);
        
        $display("  Expected: %f, Got: %f (0x%h)", 
                 computed_sum, actual_result, accumulator_fp16);
        $display("  Relative error: %e", rel_error);
        
        // FP16 has ~3 decimal digits of precision, so allow 0.1% error
        if (rel_error < 0.001 || $abs(actual_result - computed_sum) < 0.01) begin
            $display("  [PASS]");
            pass_count++;
        end else begin
            $display("  [FAIL]");
            fail_count++;
        end
        
        test_count++;
        clear = 1;
        @(posedge clk);
        clear = 0;
        @(posedge clk);
    endtask
    
    task automatic run_int_accumulation(
        input logic signed [7:0] values_a[],
        input logic signed [7:0] values_b[],
        input int num_ops,
        input logic [1:0] mode,
        input string test_name
    );
        longint computed_sum;
        logic signed [ACCUMULATOR_WIDTH-1:0] actual_result;
        
        expected_int_accum = 0;
        computed_sum = 0;
        
        $display("\n[TEST] %s", test_name);
        $display("  Accumulating %0d %s products...", 
                 num_ops, mode == 2'b00 ? "INT8" : "INT4");
        
        enable = 1;
        for (int i = 0; i < num_ops; i++) begin
            operand_a = values_a[i];
            operand_b = values_b[i];
            
            if (mode == 2'b00) // INT8
                computed_sum += $signed(values_a[i]) * $signed(values_b[i]);
            else // INT4
                computed_sum += $signed(values_a[i][3:0]) * $signed(values_b[i][3:0]);
            
            @(posedge clk);
        end
        enable = 0;
        
        wait(valid);
        @(posedge clk);
        
        actual_result = accumulator_int;
        
        $display("  Expected: %0d, Got: %0d", computed_sum, actual_result);
        
        if (actual_result == computed_sum) begin
            $display("  [PASS]");
            pass_count++;
        end else begin
            $display("  [FAIL] Mismatch!");
            fail_count++;
        end
        
        test_count++;
        clear = 1;
        @(posedge clk);
        clear = 0;
        @(posedge clk);
    endtask
    
    // Main test sequence
    initial begin
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        
        $display("Multi-Precision MAC Comprehensive Test Suite");
      
        
        reset_dut();
        
       
        // FP8 E4M3 Tests
      
        precision_mode = 2'b10;
        
        begin
            // Test 1: Basic positive accumulation
            real fp8_vals_a[8] = '{0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5};
            real fp8_vals_b[8] = '{1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0};
            logic [7:0] fp8_hex_a[8] = '{8'h30, 8'h30, 8'h30, 8'h30, 
                                          8'h30, 8'h30, 8'h30, 8'h30};
            logic [7:0] fp8_hex_b[8] = '{8'h38, 8'h38, 8'h38, 8'h38,
                                          8'h38, 8'h38, 8'h38, 8'h38};
            run_fp8_accumulation(fp8_vals_a, fp8_vals_b, fp8_hex_a, fp8_hex_b, 
                               8, "FP8: Basic positive 0.5*1.0 x8");
        end
        
        begin
            // Test 2: Mixed signs
            real fp8_vals_a[8] = '{2.0, -2.0, 2.0, -2.0, 2.0, -2.0, 2.0, -2.0};
            real fp8_vals_b[8] = '{1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0};
            logic [7:0] fp8_hex_a[8] = '{8'h40, 8'hC0, 8'h40, 8'hC0,
                                          8'h40, 8'hC0, 8'h40, 8'hC0};
            logic [7:0] fp8_hex_b[8] = '{8'h38, 8'h38, 8'h38, 8'h38,
                                          8'h38, 8'h38, 8'h38, 8'h38};
            run_fp8_accumulation(fp8_vals_a, fp8_vals_b, fp8_hex_a, fp8_hex_b,
                               8, "FP8: Mixed signs (should cancel to 0)");
        end
        
        begin
            // Test 3: Small values (testing denormal handling)
            real fp8_vals_a[8] = '{0.0625, 0.0625, 0.0625, 0.0625,
                                    0.0625, 0.0625, 0.0625, 0.0625};
            real fp8_vals_b[8] = '{0.125, 0.125, 0.125, 0.125,
                                    0.125, 0.125, 0.125, 0.125};
            logic [7:0] fp8_hex_a[8] = '{8'h10, 8'h10, 8'h10, 8'h10,
                                          8'h10, 8'h10, 8'h10, 8'h10};
            logic [7:0] fp8_hex_b[8] = '{8'h18, 8'h18, 8'h18, 8'h18,
                                          8'h18, 8'h18, 8'h18, 8'h18};
            run_fp8_accumulation(fp8_vals_a, fp8_vals_b, fp8_hex_a, fp8_hex_b,
                               8, "FP8: Small values (0.0625*0.125 x8)");
        end
        
        begin
            // Test 4: Larger values
            real fp8_vals_a[8] = '{8.0, 8.0, 8.0, 8.0, 8.0, 8.0, 8.0, 8.0};
            real fp8_vals_b[8] = '{4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0};
            logic [7:0] fp8_hex_a[8] = '{8'h50, 8'h50, 8'h50, 8'h50,
                                          8'h50, 8'h50, 8'h50, 8'h50};
            logic [7:0] fp8_hex_b[8] = '{8'h48, 8'h48, 8'h48, 8'h48,
                                          8'h48, 8'h48, 8'h48, 8'h48};
            run_fp8_accumulation(fp8_vals_a, fp8_vals_b, fp8_hex_a, fp8_hex_b,
                               8, "FP8: Larger values (8.0*4.0 x8 = 256)");
        end
        
        // INT8 Tests
        precision_mode = 2'b00;
        
        begin
            // Test 5: INT8 positive accumulation
            logic signed [7:0] int8_a[8] = '{10, 10, 10, 10, 10, 10, 10, 10};
            logic signed [7:0] int8_b[8] = '{5, 5, 5, 5, 5, 5, 5, 5};
            run_int_accumulation(int8_a, int8_b, 8, 2'b00, 
                               "INT8: Positive 10*5 x8 = 400");
        end
        
        begin
            // Test 6: INT8 negative accumulation
            logic signed [7:0] int8_a[8] = '{-10, -10, -10, -10, -10, -10, -10, -10};
            logic signed [7:0] int8_b[8] = '{5, 5, 5, 5, 5, 5, 5, 5};
            run_int_accumulation(int8_a, int8_b, 8, 2'b00,
                               "INT8: Negative -10*5 x8 = -400");
        end
        
        begin
            // Test 7: INT8 mixed signs (products all positive)
            logic signed [7:0] int8_a[8] = '{-20, -20, -20, -20, -20, -20, -20, -20};
            logic signed [7:0] int8_b[8] = '{-3, -3, -3, -3, -3, -3, -3, -3};
            run_int_accumulation(int8_a, int8_b, 8, 2'b00,
                               "INT8: Both negative -20*-3 x8 = 480");
        end
        
        begin
            // Test 8: INT8 maximum values
            logic signed [7:0] int8_a[8] = '{127, 127, 127, 127, 127, 127, 127, 127};
            logic signed [7:0] int8_b[8] = '{127, 127, 127, 127, 127, 127, 127, 127};
            run_int_accumulation(int8_a, int8_b, 8, 2'b00,
                               "INT8: Maximum 127*127 x8 = 129032");
        end
        
        begin
            // Test 9: INT8 minimum value edge case
            logic signed [7:0] int8_a[8] = '{-128, -128, -128, -128, -128, -128, -128, -128};
            logic signed [7:0] int8_b[8] = '{-128, -128, -128, -128, -128, -128, -128, -128};
            run_int_accumulation(int8_a, int8_b, 8, 2'b00,
                               "INT8: Minimum -128*-128 x8 = 131072");
        end
        
        // INT4 Tests
        precision_mode = 2'b01;
        
        begin
            // Test 10: INT4 basic (upper bits should be ignored)
            logic signed [7:0] int4_a[8] = '{8'hF3, 8'hF3, 8'hF3, 8'hF3, // 3 in lower 4 bits
                                              8'hF3, 8'hF3, 8'hF3, 8'hF3};
            logic signed [7:0] int4_b[8] = '{8'h05, 8'h05, 8'h05, 8'h05, // 5 in lower 4 bits
                                              8'h05, 8'h05, 8'h05, 8'h05};
            run_int_accumulation(int4_a, int4_b, 8, 2'b01,
                               "INT4: Basic 3*5 x8 = 120 (upper bits ignored)");
        end
        
        begin
            // Test 11: INT4 negative
            logic signed [7:0] int4_a[8] = '{8'hFE, 8'hFE, 8'hFE, 8'hFE, // -2 in lower 4 bits
                                              8'hFE, 8'hFE, 8'hFE, 8'hFE};
            logic signed [7:0] int4_b[8] = '{8'h04, 8'h04, 8'h04, 8'h04, // 4 in lower 4 bits
                                              8'h04, 8'h04, 8'h04, 8'h04};
            run_int_accumulation(int4_a, int4_b, 8, 2'b01,
                               "INT4: Negative -2*4 x8 = -64");
        end
        
        begin
            // Test 12: INT4 maximum values
            logic signed [7:0] int4_a[8] = '{8'h07, 8'h07, 8'h07, 8'h07, // 7 (max)
                                              8'h07, 8'h07, 8'h07, 8'h07};
            logic signed [7:0] int4_b[8] = '{8'h07, 8'h07, 8'h07, 8'h07, // 7 (max)
                                              8'h07, 8'h07, 8'h07, 8'h07};
            run_int_accumulation(int4_a, int4_b, 8, 2'b01,
                               "INT4: Maximum 7*7 x8 = 392");
        end
        
        begin
            // Test 13: INT4 minimum value
            logic signed [7:0] int4_a[8] = '{8'h08, 8'h08, 8'h08, 8'h08, // -8 (min)
                                              8'h08, 8'h08, 8'h08, 8'h08};
            logic signed [7:0] int4_b[8] = '{8'h08, 8'h08, 8'h08, 8'h08, // -8 (min)
                                              8'h08, 8'h08, 8'h08, 8'h08};
            run_int_accumulation(int4_a, int4_b, 8, 2'b01,
                               "INT4: Minimum -8*-8 x8 = 512");
        end
        
        // Test summary
        $display("Test Summary:");
        $display("  Total tests: %0d", test_count);
        $display("  Passed: %0d", pass_count);
        $display("  Failed: %0d", fail_count);
        
        if (fail_count == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");
        
        #100;
        $finish;
    end
    
endmodule
