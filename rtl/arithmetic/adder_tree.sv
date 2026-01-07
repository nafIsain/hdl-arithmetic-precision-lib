module adder_tree #(
    parameter int NUM_INPUTS  = 8,   // MUST BE POWER OF 2
    parameter int INPUT_WIDTH = 32,
    parameter bit PIPELINE    = 1
)(
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic signed [INPUT_WIDTH-1:0] data_in [NUM_INPUTS],
    output logic signed [INPUT_WIDTH+$clog2(NUM_INPUTS)-1:0] sum_out,
    output logic valid_out
);

    localparam int NUM_LEVELS   = $clog2(NUM_INPUTS);
    localparam int OUTPUT_WIDTH = INPUT_WIDTH + NUM_LEVELS;
    
    logic signed [OUTPUT_WIDTH-1:0] tree [NUM_LEVELS:0][NUM_INPUTS-1:0];
    logic valid_pipe [NUM_LEVELS:0];
    
    // Level 0: sign-extend inputs
    genvar i;
    generate
        for (i = 0; i < NUM_INPUTS; i++) begin : gen_input_extend
            always_comb begin
                tree[0][i] = {{(OUTPUT_WIDTH-INPUT_WIDTH){data_in[i][INPUT_WIDTH-1]}}, data_in[i]};
            end
        end
    endgenerate
    
    assign valid_pipe[0] = valid_in;
    
    // Reduction tree
    genvar level, j;
    generate
        for (level = 0; level < NUM_LEVELS; level++) begin : gen_levels
            localparam int IN_COUNT  = NUM_INPUTS >> level;
            localparam int OUT_COUNT = IN_COUNT >> 1;
            
            // Valid pipeline: ONE driver per level (outside the node loop)
            if (PIPELINE) begin : gen_valid_pipe
                always_ff @(posedge clk) begin
                    if (!rst_n)
                        valid_pipe[level+1] <= 1'b0;
                    else
                        valid_pipe[level+1] <= valid_pipe[level];
                end
            end else begin : gen_valid_comb
                always_comb begin
                    valid_pipe[level+1] = valid_pipe[level];
                end
            end
            
            // Data tree nodes: multiple adders per level
            for (j = 0; j < OUT_COUNT; j++) begin : gen_nodes
                if (PIPELINE) begin : gen_pipe
                    always_ff @(posedge clk) begin
                        if (!rst_n)
                            tree[level+1][j] <= '0;
                        else
                            tree[level+1][j] <= tree[level][2*j] + tree[level][2*j+1];
                    end
                end else begin : gen_comb
                    always_comb begin
                        tree[level+1][j] = tree[level][2*j] + tree[level][2*j+1];
                    end
                end
            end
        end
    endgenerate
    
    assign sum_out   = tree[NUM_LEVELS][0];
    assign valid_out = valid_pipe[NUM_LEVELS];

endmodule
