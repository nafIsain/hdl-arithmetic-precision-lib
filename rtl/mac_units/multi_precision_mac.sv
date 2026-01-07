module multi_precision_mac #(
    parameter int ACCUMULATOR_WIDTH = 32,
    parameter int NUM_OPERATIONS    = 1
)(
    input  logic        clk,
    input  logic        rst_n,
    
    // Precision mode
    input  logic [1:0]  precision_mode,
    
    // Data inputs (8 bits, interpreted based on mode)
    input  logic [7:0]  operand_a,
    input  logic [7:0]  operand_b,
    
    // Control
    input  logic        enable,
    input  logic        clear,
    
    // Outputs
    output logic signed [ACCUMULATOR_WIDTH-1:0] accumulator_int,
    output logic [15:0]                         accumulator_fp16,
    output logic                                valid
);

    localparam int COUNTER_WIDTH = (NUM_OPERATIONS <= 1) ? 1 : $clog2(NUM_OPERATIONS + 1);
    
    // Precision mode encoding
    localparam logic [1:0] MODE_INT8 = 2'b00;
    localparam logic [1:0] MODE_INT4 = 2'b01;
    localparam logic [1:0] MODE_FP8  = 2'b10;
    
    // Pipeline registers
    
    logic [7:0]  a_reg, b_reg;
    logic [1:0]  mode_reg;
    logic        enable_pipe;
    logic        clear_pipe;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            a_reg       <= 8'd0;
            b_reg       <= 8'd0;
            mode_reg    <= MODE_INT8;
            enable_pipe <= 1'b0;
            clear_pipe  <= 1'b0;
        end else begin
            a_reg       <= operand_a;
            b_reg       <= operand_b;
            mode_reg    <= precision_mode;
            enable_pipe <= enable;
            clear_pipe  <= clear;
        end
    end
    
    // INT8 Datapath
    
    logic signed [7:0]  int8_a, int8_b;
    logic signed [15:0] int8_product;
    
    assign int8_a = $signed(a_reg);
    assign int8_b = $signed(b_reg);
    assign int8_product = int8_a * int8_b;
    
    // INT4 Datapath
    
    logic signed [3:0] int4_a, int4_b;
    logic signed [7:0] int4_product;
    
    assign int4_a = $signed(a_reg[3:0]);
    assign int4_b = $signed(b_reg[3:0]);
    assign int4_product = int4_a * int4_b;
    
    // FP8 Datapath - FIXED: Added fp8_to_fp16 conversion
    
    logic [7:0]  fp8_product;
    logic [15:0] fp8_product_fp16;  // FIXED: Now properly driven
    logic [15:0] fp16_accum_sum;
    logic [15:0] fp16_accum_reg;
    
    // FP8 multiplication
    fp8_e4m3_multiplier fp8_mult (
        .operand_a(a_reg),
        .operand_b(b_reg),
        .product(fp8_product)
    );
    
    // FIXED: Convert FP8 product to FP16 for accumulation
    fp8_to_fp16 fp8_convert (
        .fp8_in(fp8_product),
        .fp16_out(fp8_product_fp16)
    );
    
    // FP16 accumulation
    fp16_adder fp16_add (
        .operand_a(fp16_accum_reg),
        .operand_b(fp8_product_fp16),
        .sum(fp16_accum_sum)
    );
    
    // Integer Accumulator
    
    logic signed [ACCUMULATOR_WIDTH-1:0] int_accum_reg;
    logic signed [ACCUMULATOR_WIDTH-1:0] int_product_extended;
    
    // Select product based on mode
    always_comb begin
        case (mode_reg)
            MODE_INT4:  int_product_extended = ACCUMULATOR_WIDTH'(int4_product);
            default:    int_product_extended = ACCUMULATOR_WIDTH'(int8_product);
        endcase
    end
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            int_accum_reg <= '0;
        end else if (clear_pipe) begin
            int_accum_reg <= '0;
        end else if (enable_pipe && mode_reg != MODE_FP8) begin
            int_accum_reg <= int_accum_reg + int_product_extended;
        end
    end
    
    // FP16 Accumulator
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            fp16_accum_reg <= 16'd0;
        end else if (clear_pipe) begin
            fp16_accum_reg <= 16'd0;
        end else if (enable_pipe && mode_reg == MODE_FP8) begin
            fp16_accum_reg <= fp16_accum_sum;
        end
    end
    
    // Counter and valid generation
    
    logic [COUNTER_WIDTH-1:0] op_count;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            op_count <= '0;
            valid    <= 1'b0;
        end else if (clear_pipe) begin
            op_count <= '0;
            valid    <= 1'b0;
        end else if (enable_pipe) begin
            if (op_count == NUM_OPERATIONS - 1) begin
                valid    <= 1'b1;
                op_count <= op_count;  // Hold at max
            end else begin
                op_count <= op_count + 1'b1;
                valid    <= 1'b0;
            end
        end
    end
    
    // Output assignment
    
    assign accumulator_int  = int_accum_reg;
    assign accumulator_fp16 = fp16_accum_reg;

endmodule
