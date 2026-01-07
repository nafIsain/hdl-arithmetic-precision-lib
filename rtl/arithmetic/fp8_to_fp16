module fp8_to_fp16 (
	input logic [7:0] fp8_in, 
	output logic [15:0] fp16_out
	
	);
	
	logic 	sign_8;
	logic [3:0]exp_8;
	logic [2:0] mant_8;
	
	logic 	sign_16;
	logic [4:0] exp_16;
	logic [9:0] mant_16;
	
	assign sign_8 = fp8_in[7];
	assign exp_8 = fp8_in[6:3];
	assign mant_8 = fp8_in[2:0];
	
	
	always_comb begin 
		sign_16= sign_8;
		
		if (exp_8 == 4'd0 && mant_8 ==3'd0) begin 
			// zero 
			exp_16 = 5'd0;
			mant_16 = 10'd0;
			
		end else if (exp_8 === 4'd0) begin 
			// denormal in fp8 - neesd normalzation forfp16
			exp_16 = 5'd0;
			mant_16 = 10'd0;
		end else begin 
			// normal 
			
			exp_16 = {1'b0, exp_8} +5'd8;
			
			mant_16 = {mant_8, 7'b0};
		end
	end 
	
	assign fp16_out = {sign_16, exp_16, mant_16};
endmodule
