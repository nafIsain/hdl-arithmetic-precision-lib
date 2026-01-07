module fp16_adder (
	input logic [15:0] operand_a,
	input logic [15:0 ] operand_b, 
	output logic [15:0] sum 
);

// unpack the operands

logic sign_a, sign_b;
logic [4:0]  exp_a, exp_b;
logic [9:0] mant_a, mant_b;

assign sign_a = operand_a[15];
assign exp_a = operand_a[14:10];
assign mant_a= operand_a[9:0];

assign sign_b = operand_b[15];
assign exp_b = operand_b[14:10];
assign mant_b = operand_b[9:0];


//special case detection 
logic a_is_zero , b_is_zero;
assign a_is_zero = (exp_a ==5'd0) && (mant_a == 10'd0);
assign b_is_zero = (exp_b == 5'd0) && (mant_b == 10'd0);

logic a_larger;
logic [4:0] exp_diff;

always_comb begin 
	if (exp_a > exp_b) begin 
		a_larger = 1'b1;
		exp_diff = exp_a -exp_b;
		
	end else if (exp_a <exp_b) begin 
		a_larger = 1'b0;
		exp_diff = exp_b - exp_a;
	end else begin 
		a_larger =(mant_a >= mant_b) ;
		exp_diff = 5'd0;
	end 
end 

logic  sign_large , sign_small;

logic [4:0] exp_large;
logic [9:0] mant_large, mant_small;

always_comb begin
	if (a_larger) begin 
		sign_large = sign_a;
		sign_small = sign_b;
		exp_large = exp_a;
		mant_large = mant_a;
		mant_small = mant_b;
	end else begin
		sign_large = sign_b;
		sign_small = sign_a;
		exp_large = exp_b;
		mant_large = mant_b;
		mant_small = mant_a;
	end 
end 

logic [14:0] sig_large, sig_small;

assign sig_large = {1'b1, mant_large, 4'b0000};
assign sig_small = {1'b1, mant_small, 4'b0000};


logic[14:0] sig_small_aligned;

always_comb begin 
	if (exp_diff>= 5'd15)
		sig_small_aligned = 15'd0;
	else 
		sig_small_aligned = sig_small >> exp_diff;
	end 
	
	
	logic effective_subtract;
	logic [15:0] sig_result;
	
	assign effective_subtract = sign_large ^ sign_small;
	
	always_comb  begin 
		if (effective_subtract)
			sig_result = {1'b0, sig_large} -{1'b0, sig_small_aligned};
		else
			sig_result = {1'b0, sig_large} + {1'b0, sig_small_aligned};
		end
	
	logic [14:0] sig_normalized;
	logic  [5:0] exp_result;
	logic 	result_sign;
	
	assign result_sign = sign_large;
	
	always_comb begin 
		exp_result = {1'b0, exp_large}; 
		sig_normalized  = sig_result[14:0];
		
		
		if (sig_result[15]) begin 
			// carry out - shift right 
			sig_normalized = sig_result[15:1];
			exp_result = exp_result +1;
		end else if (sig_result[14]) begin
			sig_normalized = sig_result[14:0];
		end else if (sig_result[13]) begin
            sig_normalized = {sig_result[13:0], 1'b0};
            exp_result = exp_result - 1;
	  end else if (sig_result[12]) begin
			sig_normalized = {sig_result[12:0], 2'b0};
			exp_result = exp_result - 2;
	  end else if (sig_result[11]) begin
			sig_normalized = {sig_result[11:0], 3'b0};
			exp_result = exp_result - 3;
	  end else if (sig_result[10]) begin
			sig_normalized = {sig_result[10:0], 4'b0};
			exp_result = exp_result - 4;
	  end else if (sig_result[9]) begin
			sig_normalized = {sig_result[9:0], 5'b0};
			exp_result = exp_result - 5;
	  end else if (sig_result[8]) begin
			sig_normalized = {sig_result[8:0], 6'b0};
			exp_result = exp_result - 6;
	  end else if (sig_result[7]) begin
			sig_normalized = {sig_result[7:0], 7'b0};
			exp_result = exp_result - 7;
	  end else if (sig_result[6]) begin
			sig_normalized = {sig_result[6:0], 8'b0};
			exp_result = exp_result - 8;
	  end else if (sig_result[5]) begin
			sig_normalized = {sig_result[5:0], 9'b0};
			exp_result = exp_result - 9;
	  end else if (sig_result[4]) begin
			sig_normalized = {sig_result[4:0], 10'b0};
			exp_result = exp_result - 10;
	  end else begin
			// very small or zero
			sig_normalized = 15'd0;
			exp_result = 6'd0;
	  end
 end
 
 //e xtract mantissa
 logic [9:0] mant_result;
 assign mant_result = sig_normalized[13:4];
 
 
 logic [4:0] exp_final;
 logic [9:0] mant_final;
 logic 		sign_final;
 
 always_comb begin
        sign_final = result_sign;
        exp_final  = exp_result[4:0];
        mant_final = mant_result;
        
        if (a_is_zero && b_is_zero) begin
            sign_final = 1'b0;
            exp_final  = 5'd0;
            mant_final = 10'd0;
        end else if (a_is_zero) begin
            sign_final = sign_b;
            exp_final  = exp_b;
            mant_final = mant_b;
        end else if (b_is_zero) begin
            sign_final = sign_a;
            exp_final  = exp_a;
            mant_final = mant_a;
        end else if (exp_result[5] || exp_result == 6'd0) begin
            // Underflow
            sign_final = 1'b0;
            exp_final  = 5'd0;
            mant_final = 10'd0;
        end else if (exp_result > 6'd30) begin
            // Overflow - saturate to max
            exp_final  = 5'd30;
            mant_final = 10'h3FF;
        end else if (sig_normalized == 15'd0) begin
            // Zero from cancellation
            sign_final = 1'b0;
            exp_final  = 5'd0;
            mant_final = 10'd0;
        end
    end
    
    assign sum = {sign_final, exp_final, mant_final};

endmodule
