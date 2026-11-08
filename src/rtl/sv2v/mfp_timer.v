module mfp_timer (
	CLK,
	RST,
	DS,
	DAT_WE,
	DAT_I,
	DAT_O,
	CTRL_WE,
	CTRL_I,
	CTRL_O,
	XCLK_I,
	T_I,
	PULSE_MODE,
	EVENT_MODE,
	T_O,
	T_O_PULSE,
	SET_DATA_OUT
);
	input CLK;
	input RST;
	input DS;
	input DAT_WE;
	input [7:0] DAT_I;
	output wire [7:0] DAT_O;
	input CTRL_WE;
	input [4:0] CTRL_I;
	output wire [3:0] CTRL_O;
	input XCLK_I;
	input T_I;
	output wire PULSE_MODE;
	output wire EVENT_MODE;
	output reg T_O;
	output reg T_O_PULSE;
	output wire [7:0] SET_DATA_OUT;
	reg [7:0] data;
	assign SET_DATA_OUT = data;
	reg [7:0] down_counter;
	reg [7:0] cur_counter;
	reg [3:0] control;
	wire pulse_mode;
	assign PULSE_MODE = pulse_mode;
	wire event_mode;
	assign EVENT_MODE = event_mode;
	wire [7:0] prescaler;
	reg [7:0] prescaler_counter;
	wire prescaler_active;
	reg count;
	wire started;
	wire delay_mode;
	wire xclk_en = XCLK_I;
	always @(posedge CLK) begin : sv2v_autoblock_1
		reg DS_last;
		DS_last <= DS;
		if (~DS_last & DS)
			cur_counter <= down_counter;
	end
	reg [7:0] trigger_shift;
	wire trigger_pulse = trigger_shift[5:2] == 4'b0011;
	always @(posedge CLK)
		if (xclk_en)
			trigger_shift <= {trigger_shift[6:0], T_I};
	always @(posedge CLK) begin : sv2v_autoblock_2
		reg timer_tick;
		reg timer_tick_r;
		reg reload;
		if (RST === 1'b1) begin
			T_O <= 1'b0;
			control <= 4'd0;
			data <= 8'd0;
			down_counter <= 8'd0;
			count <= 1'b0;
			prescaler_counter <= 8'd0;
			reload <= 1'b0;
		end
		else begin
			if (xclk_en)
				timer_tick_r <= timer_tick;
			reload <= 1'b0;
			if (started & reload)
				down_counter <= data;
			if (DAT_WE) begin
				data <= DAT_I;
				if (!started) begin
					reload <= 1'b0;
					down_counter <= DAT_I;
				end
			end
			if (CTRL_WE) begin
				control <= CTRL_I[3:0];
				if (CTRL_I[4] == 1'b1)
					T_O <= 1'b0;
			end
			count <= 1'b0;
			if (prescaler_active) begin
				if (xclk_en) begin
					if ((prescaler_counter == prescaler) || (prescaler_counter == 8'd199)) begin
						prescaler_counter <= 8'd0;
						timer_tick <= ~timer_tick;
					end
					else
						prescaler_counter <= prescaler_counter + 8'd1;
				end
			end
			else
				prescaler_counter <= 8'd0;
			T_O_PULSE <= 1'b0;
			if (event_mode === 1'b1) begin
				if (xclk_en && trigger_pulse)
					count <= 1'b1;
			end
			if (delay_mode === 1'b1) begin
				if (xclk_en && (timer_tick_r ^ timer_tick))
					count <= 1'b1;
			end
			if (pulse_mode === 1'b1) begin
				if ((xclk_en && (timer_tick_r ^ timer_tick)) && trigger_pulse)
					count <= 1'b1;
			end
			if (count) begin
				down_counter <= down_counter - 8'd1;
				if (down_counter === 8'd1) begin
					T_O <= ~T_O;
					T_O_PULSE <= 1'b1;
					reload <= 1'b1;
				end
			end
		end
	end
	assign prescaler = (control[2:0] === 3'd1 ? 8'd3 : (control[2:0] === 3'd2 ? 8'd9 : (control[2:0] === 3'd3 ? 8'd15 : (control[2:0] === 3'd4 ? 8'd49 : (control[2:0] === 3'd5 ? 8'd63 : (control[2:0] === 3'd6 ? 8'd99 : (control[2:0] === 3'd7 ? 8'd199 : 8'd1)))))));
	assign prescaler_active = |control[2:0];
	assign delay_mode = control[3] === 1'b0;
	assign pulse_mode = (control[3] === 1'b1) & !event_mode;
	assign event_mode = control[3:0] === 4'b1000;
	assign started = control[3:0] != 4'd0;
	assign DAT_O = cur_counter;
	assign CTRL_O = control;
endmodule
