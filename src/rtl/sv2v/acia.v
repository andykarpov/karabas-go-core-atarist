module acia (
	clk,
	E,
	reset,
	rxtxclk_sel,
	din,
	sel,
	rs,
	rw,
	dout,
	irq,
	tx,
	rx,
	dout_strobe
);
	input clk;
	input E;
	input reset;
	input rxtxclk_sel;
	input [7:0] din;
	input sel;
	input rs;
	input rw;
	output reg [7:0] dout;
	output reg irq;
	output wire tx;
	input rx;
	output wire dout_strobe;
	parameter INPUT_FILTER = 1;
	parameter TX_DELAY = 8'd16;
	reg E_d;
	always @(posedge clk) E_d <= E;
	wire clk_en = ~E_d & E;
	assign dout_strobe = ((clk_en && sel) && ~rw) && rs;
	reg [7:0] serial_cr;
	reg [7:0] serial_rx_data;
	reg serial_rx_data_available;
	reg serial_tx_empty;
	wire serial_irq = (serial_cr[7] && serial_rx_data_available) || ((serial_cr[6:5] == 2'b01) && serial_tx_empty);
	reg serial_rx_frame_error;
	reg serial_rx_overrun;
	wire [7:0] serial_status = {serial_irq, 1'b0, serial_rx_overrun, serial_rx_frame_error, 2'b00, serial_tx_empty, serial_rx_data_available};
	always @(sel or rw or rs or serial_status or serial_rx_data) begin
		dout = 8'h00;
		if (sel && rw) begin
			if (~rs)
				dout = serial_status;
			if (rs)
				dout = serial_rx_data;
		end
	end
	always @(posedge clk)
		if (reset)
			irq <= 0;
		else if (serial_cr[1:0] == 2'b11)
			irq <= 0;
		else
			irq <= serial_irq;
	reg [7:0] serial_clk;
	always @(posedge clk) serial_clk <= serial_clk + 1'd1;
	wire [7:0] serial_clk_cnt = (rxtxclk_sel ? {serial_clk[5:0], 2'b00} : serial_clk);
	wire serial_clk_en = ((serial_cr[1:0] == 2'b01) && (serial_clk_cnt[5:0] == 6'd0)) || ((serial_cr[1:0] == 2'b10) && (serial_clk_cnt[7:0] == 8'd0));
	reg [7:0] serial_rx_cnt;
	reg [7:0] serial_rx_shift_reg;
	reg [3:0] serial_rx_filter;
	reg serial_in_filtered;
	wire serial_in = (INPUT_FILTER ? serial_in_filtered : rx);
	always @(posedge clk)
		if (reset) begin
			serial_rx_cnt <= 8'd0;
			serial_rx_data_available <= 1'b0;
			serial_rx_filter <= 4'b1111;
			serial_in_filtered <= 1'b1;
			serial_rx_overrun <= 1'b0;
			serial_rx_frame_error <= 1'b0;
		end
		else begin
			if (((clk_en && sel) && rw) && rs) begin
				serial_rx_data_available <= 1'b0;
				serial_rx_overrun <= 1'b0;
			end
			if (serial_cr[1:0] == 2'b11) begin
				serial_rx_cnt <= 8'd0;
				serial_rx_data_available <= 1'b0;
				serial_rx_filter <= 4'b1111;
				serial_rx_overrun <= 1'b0;
				serial_rx_frame_error <= 1'b0;
			end
			serial_rx_filter <= {serial_rx_filter[2:0], rx};
			if (serial_rx_filter == 4'b0000)
				serial_in_filtered <= 1'b0;
			if (serial_rx_filter == 4'b1111)
				serial_in_filtered <= 1'b1;
			if (serial_clk_en) begin
				if (serial_rx_cnt == 8'd0) begin
					if (serial_in == 1'b0)
						serial_rx_cnt <= 8'h97;
				end
				else begin
					serial_rx_cnt <= serial_rx_cnt - 8'd1;
					if (serial_rx_cnt[3:0] == 4'd0)
						serial_rx_shift_reg <= {serial_in, serial_rx_shift_reg[7:1]};
					if (serial_rx_cnt[7:0] == 8'd1) begin
						if (serial_in == 1'b1) begin
							if (serial_rx_data_available)
								serial_rx_overrun <= 1'b1;
							else
								serial_rx_data <= serial_rx_shift_reg;
							serial_rx_data_available <= 1'b1;
							serial_rx_frame_error <= 1'b0;
						end
						else
							serial_rx_frame_error <= 1'b1;
					end
				end
			end
		end
	reg [7:0] serial_tx_cnt;
	reg [7:0] serial_tx_data;
	reg serial_tx_data_valid;
	reg [9:0] serial_tx_shift_reg = 10'b1111111111;
	reg [7:0] serial_tx_data_dly;
	assign tx = serial_tx_shift_reg[0];
	always @(posedge clk) begin
		if (serial_clk_en) begin
			if (serial_tx_data_dly != 0)
				serial_tx_data_dly <= serial_tx_data_dly - 1'd1;
			if (serial_tx_cnt == 0) begin
				if (serial_tx_data_valid && (serial_tx_data_dly == 0)) begin
					serial_tx_shift_reg <= {1'b1, serial_tx_data, 1'b0};
					serial_tx_cnt <= 8'h9f;
					serial_tx_data_valid <= 1'b0;
					serial_tx_empty <= 1'b1;
				end
			end
			else begin
				if (serial_tx_cnt[3:0] == 4'h0)
					serial_tx_shift_reg <= {1'b1, serial_tx_shift_reg[9:1]};
				serial_tx_cnt <= serial_tx_cnt - 8'd1;
			end
		end
		if (reset) begin
			serial_tx_cnt <= 8'd0;
			serial_tx_empty <= 1'b1;
			serial_tx_data_valid <= 1'b0;
			serial_tx_shift_reg <= 10'b1111111111;
			serial_tx_data_dly <= 8'd0;
			serial_cr <= 8'd3;
		end
		else if ((clk_en && sel) && ~rw) begin
			if (~rs) begin
				serial_cr <= din;
				if (din[1:0] == 2'b11) begin
					serial_tx_cnt <= 8'd0;
					serial_tx_empty <= 1'b1;
					serial_tx_data_valid <= 1'b0;
					serial_tx_shift_reg <= 10'b1111111111;
					serial_tx_data_dly <= 8'd0;
				end
			end
			if (rs) begin
				serial_tx_data <= din;
				serial_tx_data_dly <= TX_DELAY;
				serial_tx_data_valid <= 1'b1;
				serial_tx_empty <= 1'b0;
			end
		end
	end
endmodule
