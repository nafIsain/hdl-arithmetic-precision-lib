module multi_precision_mac_array #(
    parameter int NUM_MACS          = 8,
    parameter int ACCUMULATOR_WIDTH = 32,
    parameter int OPS_PER_MAC       = 9
)(
    input  logic        clk,
    input  logic        rst_n,
    
    // Precision mode (applied to all MACs)
    input  logic [1:0]  precision_mode,
    
    // Data inputs : unsigned to match buffer outputs
    input  logic [7:0]  activations [NUM_MACS],
    input  logic [7:0]  weights     [NUM_MACS],
    
    // Control
    input  logic        enable,
    input  logic        clear,
    
    // Outputs
    output logic signed [ACCUMULATOR_WIDTH+$clog2(NUM_MACS)-1:0] result_int,
    output logic [15:0] result_fp16,
    output logic        valid,
    
    // Debug outputs
    output logic signed [ACCUMULATOR_WIDTH-1:0] mac_accumulators_int  [NUM_MACS],
    output logic [15:0]                         mac_accumulators_fp16 [NUM_MACS]
);

    localparam logic [1:0] MODE_FP8 = 2'b10;
    
    // MAC outputs
    logic signed [ACCUMULATOR_WIDTH-1:0] mac_int_outputs  [NUM_MACS];
    logic [15:0]                         mac_fp16_outputs [NUM_MACS];
    logic                                mac_valid        [NUM_MACS];
    
    // MAC instantiation
    
    genvar i;
    generate
        for (i = 0; i < NUM_MACS; i++) begin : gen_macs
            multi_precision_mac #(
                .ACCUMULATOR_WIDTH(ACCUMULATOR_WIDTH),
                .NUM_OPERATIONS(OPS_PER_MAC)
            ) mac_inst (
                .clk(clk),
                .rst_n(rst_n),
                .precision_mode(precision_mode),
                .operand_a(activations[i]),
                .operand_b(weights[i]),
                .enable(enable),
                .clear(clear),
                .accumulator_int(mac_int_outputs[i]),
                .accumulator_fp16(mac_fp16_outputs[i]),
                .valid(mac_valid[i])
            );
        end
    endgenerate
    
    // Connect debug outputs
    assign mac_accumulators_int  = mac_int_outputs;
    assign mac_accumulators_fp16 = mac_fp16_outputs;
    
    // Integer Adder Tree (for INT8/INT4 modes)
    
    logic tree_valid_out;
    
    adder_tree #(
        .NUM_INPUTS(NUM_MACS),
        .INPUT_WIDTH(ACCUMULATOR_WIDTH),
        .PIPELINE(1)
    ) int_sum_tree (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(mac_valid[0]),
        .data_in(mac_int_outputs),
        .sum_out(result_int),
        .valid_out(tree_valid_out)
    );
    
    // FP16 Reduction (for FP8 mode) - Cascaded combinational
    
    logic [15:0] fp16_partial [NUM_MACS];
    
    assign fp16_partial[0] = mac_fp16_outputs[0];
    
    genvar j;
    generate
        for (j = 1; j < NUM_MACS; j++) begin : gen_fp16_cascade
            fp16_adder fp16_add_cascade (
                .operand_a(fp16_partial[j-1]),
                .operand_b(mac_fp16_outputs[j]),
                .sum(fp16_partial[j])
            );
        end
    endgenerate
    
    // Pipeline FP16 result to match integer tree latency
    logic [15:0] result_fp16_reg;
    logic [$clog2(NUM_MACS):0] fp16_valid_pipe;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            result_fp16_reg <= 16'd0;
        end else if(mac_valid[0]) begin
                result_fp16_reg <= fp16_partial[NUM_MACS-1];
        end
    end
    
    assign result_fp16 = result_fp16_reg;
    assign valid = tree_valid_out;

endmodule
