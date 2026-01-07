// FP8 EM43 format multlplier
// this implementation handles 
// - normal x normal multiplication 
// - zero detection 
// - basic overflow , underflow 

// does not handle :
// - denormal outputs - treated as zero for simplicity
// - NaN propagation (E=15, M!=0 not specially handled)


module fp8_e4m3_multiplier(
	input logic [7:0] operand_a,
	input logic [7:0] operand_b, 
	output logic [7:0] product
	);
	
	
	// constants
	
	localparam int BIAS = 7;
	localparam int EXP_MAX = 14; 
	
	// UNPCACK OPERANDS
	
	logic		sign_a, sign_b;
	logic [3:0] exp_a, exp_b;
	logic [2:0] mant_a, mant_b;
	
	assign sign_a = operand_a[7];
	assign exp_a = operand_a[6:3];
	assign mant_a = operand_a[2:0];
	
	assign sign_b = operand_b[7];
	assign exp_b = operand_b[6:3];
	assign mant_b= operand_b[2:0];
	
	
	// detect special cases
	
	logic a_is_zero, b_is_zero;
	logic a_is_denormal, b_is_denormal;
	
	
	// zero exponent =0 and mantissa= 0;
	
	assign a_is_zero  = 	(exp_a === 4'd0);
	assign b_is_zero 	= 	(exp_b == 4'd0);
	assign a_is_denormal=(exp_a == 4'd0) && (mant_a != 3'd0);
	assign b_is_denormal =(exp_b == 4'd0) &&  (mant_b != 3'd0);
	
	
	// COMPUTE THE PRODUCT SIGN 
	
	logic sign_product;
	assign sign_product = sign_a ^ sign_b;
	
	
	// COMPUTE THE PRODUCT EXPONENT
	// before normalization 
	
	logic signed [5:0] exp_sum;
	assign exp_sum = $signed({1'b0, exp_a}) + $signed({1'b0, exp_b}) - $signed(6'd7);
	
	// COMPUTE PRODUCT MANTISAA
	// significants with implicict leading 1: 1.mmmm = 4 bits each 
	
	logic [3:0] sig_a, sig_b;
	assign sig_a ={1'b1, mant_a};
	assign sig_b = {1'b1, mant_b};
	
	 // 4-bit × 4-bit unsigned multiplication = 8-bit product
    // product range: 1.000 × 1.000 = 1.000000 (0x40 in 8-bit with 6 fractional bits)
    // to: 1.111 × 1.111 = 11.100001 (0xE1)
	 
	 logic[7:0] sig_product;
	 assign sig_product =sig_a * sig_b;
	 
	 
	 logic needs_shift;
	 assign needs_shift= sig_product[7];
	 
	 // normalized mantissa - take 3 bit after tje implicit one
	 
	 logic [2:0] mant_normalized;
	 logic [5:0] exp_normalized;
	 
	 always_comb begin 
		if (needs_shift)begin 
			mant_normalized =sig_product[6:4];
			exp_normalized = exp_sum+1;
		end else begin 
			mant_normalized = sig_product[5:3];
			exp_normalized = exp_sum;
		end 
	end
	
	
	// OVERFLOW,UNDERFLOW AND SPECIAL CASES
	logic [3:0] exp_final;
	logic [2:0]  mant_final;
	
	logic result_is_zero;
	logic result_overflow;
	logic result_underflow;
	
	
	always_comb begin 
		result_is_zero = a_is_zero ||b_is_zero;
		result_overflow = (exp_normalized  > EXP_MAX) && !result_is_zero;
		result_underflow = (exp_normalized <1) && !result_is_zero;
		
		if (result_is_zero) begin 
			exp_final = 4'd0;
			mant_final = 3'd0;
			
		end else if  (result_overflow) begin 
			exp_final  = 4'd14;
			mant_final  = 3'd7; 
			
		end else if (result_underflow) begin 
			exp_final = 4'd0;
			mant_final = 3'd0;
		end else begin 
			exp_final = exp_normalized[3:0];
			mant_final =mant_normalized;
		end 
	end 
	
	
	// PACK RESULT 
	assign product = {sign_product, exp_final, mant_final};
endmodule

