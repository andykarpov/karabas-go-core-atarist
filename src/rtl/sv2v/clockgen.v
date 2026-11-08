module clockgen (
	clk32,
	resb,
	porb,
	turbo,
	clk,
	mhz8,
	mhz8_en1,
	mhz8_en2,
	mhz4,
	mhz4_en,
	time0,
	time1,
	time2,
	time3,
	time4,
	time5,
	time6,
	time7,
	m2clock,
	m2clock_en_p,
	m2clock_en_n,
	clk4,
	latch
);
	input clk32;
	input resb;
	input porb;
	input turbo;
	output wire clk;
	output wire mhz8;
	output reg mhz8_en1;
	output reg mhz8_en2;
	output wire mhz4;
	output reg mhz4_en;
	output wire time0;
	output wire time1;
	output wire time2;
	output wire time3;
	output wire time4;
	output wire time5;
	output wire time6;
	output wire time7;
	output wire m2clock;
	output wire m2clock_en_p;
	output wire m2clock_en_n;
	output wire clk4;
	output wire latch;
	reg mhz16_s;
	assign clk = mhz16_s;
	reg mhz8_s;
	assign mhz8 = mhz8_s;
	reg mhz4_s;
	assign mhz4 = mhz4_s;
	reg time0_s;
	assign time0 = time0_s;
	reg time1_s;
	assign time1 = time1_s;
	reg time2_s;
	assign time2 = time2_s;
	reg time3_s;
	assign time3 = time3_s;
	reg time4_s;
	assign time4 = time4_s;
	reg time5_s;
	assign time5 = time5_s;
	reg time6_s;
	assign time6 = time6_s;
	reg time7_s;
	assign time7 = time7_s;
	assign m2clock = ~time6_s;
	assign m2clock_en_p = ~time5_s & time6_s;
	assign m2clock_en_n = time5_s & ~time6_s;
	reg l2_s;
	assign clk4 = l2_s;
	reg latchb_s;
	assign latch = ~latchb_s;
	reg mhz8_sD;
	reg l3_s;
	always @(posedge clk32 or negedge resb or negedge porb)
		if (!porb) begin
			{mhz16_s, mhz8_sD, mhz8_s, mhz8_en1, mhz8_en2, mhz4_s} <= 0;
			{time0_s, time1_s, time2_s, time3_s, time4_s, time5_s, time6_s, time7_s} <= 0;
			latchb_s <= 1;
		end
		else if (!resb) begin
			{mhz16_s, mhz8_sD, mhz8_s, mhz8_en1, mhz8_en2, mhz4_s} <= 0;
			l2_s <= 0;
			l3_s <= 1;
		end
		else begin
			{mhz8_en1, mhz8_en2, mhz4_en} <= 0;
			mhz16_s <= ~mhz16_s;
			if (mhz16_s)
				mhz8_sD <= ~mhz8_sD;
			if (~mhz16_s)
				mhz8_s <= mhz8_sD;
			if (mhz16_s & ~mhz8_s)
				mhz8_en1 <= 1;
			if (mhz16_s & mhz8_s)
				mhz8_en2 <= 1;
			if (mhz16_s & ~mhz8_s)
				l2_s <= ~l2_s;
			if (~mhz16_s & ~mhz8_s)
				mhz4_s <= ~l2_s;
			if ((mhz16_s & ~mhz8_s) & l2_s)
				mhz4_en <= 1;
			if ((mhz16_s & ~l2_s) & ~mhz8_s)
				l3_s <= ~l3_s;
			if (~mhz16_s)
				time0_s <= (turbo ? ~l2_s : ~l3_s);
			if (mhz16_s)
				time1_s <= time0_s;
			if (~mhz16_s)
				time2_s <= time1_s;
			if (mhz16_s)
				time3_s <= time2_s;
			if (~mhz16_s)
				time4_s <= time3_s;
			if (mhz16_s)
				time5_s <= time4_s;
			if (~mhz16_s)
				time6_s <= time5_s;
			if (mhz16_s)
				time7_s <= time6_s;
			if (~mhz16_s)
				latchb_s <= (turbo ? ~(time2_s & ~time0_s) : ~(time5_s & ~time1_s));
		end
endmodule
