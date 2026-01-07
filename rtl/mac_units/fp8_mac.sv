module fp8_mac #(
	parameter int NUM_OPERATIONS = 1
	)(
	
	input logic 	clk, 
	input logic		rst_n,
	
	input logic [7:0] operand_a,
	input logic [7:0] operand_b,
	input logic 		enable, 
	input logic 		clear,
	
	output logic [15:0] accumulator,  // fp16 result
	output logic [7:0] accumulator_fp8, // fp8 converted result
	output logic 		valid
	
	);
	
	
	localparam int COUNTER_WIDTH = (NUM_OPERATIONS <= 1) ? 1: $clog2(NUM_OPERATIONS +1);
	
	// pipeline registers
	
	logic [7:0] 	a_reg, b_reg;
	logic 			enable_pipe;
	logic 			clear_pipe;
	
	
	// fp8 product
	logic [7:0] 	product_fp8;
	
	// fp16 product
	logic [15:0] 	product_fp16;
	
	logic [15:0] accum_reg ; // fp16 accum
	logic [15:0] accum_sum ; // fp16 adder output 
	logic [COUNTER_WIDTH-1:0] op_count;
	
	
	
	// STAGE 1 - INPUT REG
	
	always_ff @(posedge clk) begin 
		if(!rst_n) begin 
			a_reg <=8'd0;
			b_reg <=8'd0;
			enable_pipe <= 1'b0;
			clear_pipe <=1'b0;
			
		end else begin 
			a_reg  <= operand_a;
			b_reg  <= operand_b;
			enable_pipe <= enable;
			clear_pipe <= clear;
		end 
	end 
	
	// FP8 MULT
	
	fp8_e4m3_multiplier fp8_mult(
		.operand_a(a_reg), 
		.operand_b(b_reg),
		.product(product_fp8)
	);
	
	// convert fp8 product to fp16
	
	fp8_to_fp16 product_convert(
		.fp8_in(product_fp8), 
		.fp16_out(product_fp16)
	);
	
	// fp16 addition 
	fp16_adder fp16_add(
		.operand_a(accum_reg),
		.operand_b(product_fp16),
		.sum(accum_sum)
	);
	
	
	// STAGE 2 - ACCUMULATOR UPDATE
		
	always_ff @(posedge clk) begin
		if(!rst_n) begin 
			accum_reg <= 16'd0;
		end else if( clear_pipe) begin 
			accum_reg <= 16'd0;
		end else if (enable_pipe) begin
			accum_reg <= accum_sum;
			
		end
	end
	
	
	// counter and valid generation 
	
	always_ff @(posedge clk) begin 
		if (!rst_n) begin 
			op_count <='0;
			valid <= 1'b0;
		end else if (clear_pipe) begin 
			op_count <='0;
			valid <= 1'b0;
		end else if (enable_pipe) begin 	
			if (op_count == NUM_OPERATIONS -1) begin 
				valid <= 1'b1;
				op_count <=op_count;
			end else begin 
				op_count <= op_count +1'b1;
				valid <= 1'b0;
			end 
		end
	end 
	
	// output conversion 
	
	assign accumulator = accum_reg;
	
	fp16_to_fp8 output_convert(
		.fp16_in(accum_reg) , 
		.fp8_out(accumulator_fp8)
	);
endmodule
