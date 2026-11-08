module acsi (
	clk,
	clk_en,
	reset,
	enable,
	img_size,
	data_rd_req,
	data_wr_req,
	data_lba,
	data_length,
	data_busy,
	data_done,
	dma_done,
	data_next,
	cpu_a1,
	cpu_sel,
	cpu_rw,
	cpu_din,
	cpu_dout,
	reply_data,
	reply_req,
	reply_ack,
	irq,
	leds
);
	input clk;
	input clk_en;
	input reset;
	input [7:0] enable;
	input [127:0] img_size;
	output reg [1:0] data_rd_req;
	output reg [1:0] data_wr_req;
	output reg [31:0] data_lba;
	output reg [15:0] data_length;
	input data_busy;
	input data_done;
	input dma_done;
	input data_next;
	input cpu_a1;
	input cpu_sel;
	input cpu_rw;
	input [7:0] cpu_din;
	output wire [7:0] cpu_dout;
	output wire [15:0] reply_data;
	output wire reply_req;
	input reply_ack;
	output reg irq;
	output wire [1:0] leds;
	reg [15:0] led_counter [0:1];
	assign leds = {|led_counter[1], |led_counter[0]};
	reg cpu_selD;
	always @(posedge clk)
		if (clk_en)
			cpu_selD <= cpu_sel;
	wire cpu_req = ~cpu_selD & cpu_sel;
	reg [1:0] data_rd_req_int;
	reg [1:0] data_wr_req_int;
	reg [7:0] cmd_parameter [15:0];
	wire [7:0] cmd_code = cmd_parameter[0];
	wire [3:0] parms = ((cmd_code >= 8'h00) && (cmd_code <= 8'h1f) ? 4'd5 : ((cmd_code >= 8'h20) && (cmd_code <= 8'h5f) ? 4'd9 : ((cmd_code >= 8'h80) && (cmd_code <= 8'h9f) ? 4'd15 : 4'd11)));
	reg [2:0] target;
	reg [3:0] byte_counter;
	reg err;
	reg [7:0] asc [0:1];
	assign cpu_dout = {6'b000000, err, 1'b0};
	wire [2:0] lun = cmd_parameter[1][7:5];
	wire [31:0] lba6 = {10'd0, cmd_parameter[1][4:0], cmd_parameter[2], cmd_parameter[3]};
	wire [15:0] length6 = {8'h00, cmd_parameter[4]};
	wire [31:0] lba10 = {cmd_parameter[2], cmd_parameter[3], cmd_parameter[4], cmd_parameter[5]};
	wire [15:0] length10 = {cmd_parameter[7], cmd_parameter[8]};
	wire [31:0] lba = (cmd_code[7:4] == 4'h2 ? lba10 : lba6);
	wire [15:0] length = (cmd_code[7:4] == 4'h2 ? length10 : length6);
	wire [223:0] inquiry_str;
	reg [6:0] reply_cnt;
	wire [15:0] inquiry_reply_data = ((reply_cnt == 0) && (lun != 3'd0) ? 16'h7f00 : (reply_cnt == 1 ? 16'h0100 : (reply_cnt == 2 ? {cmd_parameter[4] - 8'd5, 8'h00} : ((reply_cnt >= 4) && (reply_cnt < 18) ? {inquiry_str[(27 - (2 * (reply_cnt - 4))) * 8+:8], inquiry_str[(27 - ((2 * (reply_cnt - 4)) + 1)) * 8+:8]} : 16'h0000))));
	wire current_target = target[0];
	wire [63:0] current_image_size = img_size[(1 - current_target) * 64+:64];
	wire [31:0] current_block_size = current_image_size[40:9];
	wire [15:0] mode_sense_reply_data = (reply_cnt == 0 ? 16'h000e : (reply_cnt == 1 ? 16'h0008 : (reply_cnt == 2 ? current_block_size[31:16] : (reply_cnt == 3 ? current_block_size[15:0] : (reply_cnt == 5 ? 16'd512 : 16'h0000)))));
	wire [31:0] max_block_number = current_block_size - 32'd1;
	wire [15:0] read_capacity_reply_data = (reply_cnt == 0 ? max_block_number[31:16] : (reply_cnt == 1 ? max_block_number[15:0] : (reply_cnt == 3 ? 16'd512 : 16'h0000)));
	wire [15:0] report_luns_reply_data = (reply_cnt == 1 ? 16'h0008 : 16'h0000);
	wire [15:0] request_sense_reply_data = (reply_cnt == 0 ? 16'h7000 : ((reply_cnt == 1) && (asc[current_target] != 0) ? 16'h0500 : (reply_cnt == 3 ? 16'd11 : (reply_cnt == 6 ? {asc[current_target], 8'h00} : 16'h0000))));
	assign reply_data = (cmd_code == 8'h03 ? request_sense_reply_data : (cmd_code == 8'h12 ? inquiry_reply_data : (cmd_code == 8'h1a ? mode_sense_reply_data : (cmd_code == 8'h25 ? read_capacity_reply_data : (cmd_code == 8'ha0 ? report_luns_reply_data : 16'h0000)))));
	localparam REPLY_IDLE = 7'd127;
	localparam REPLY_START = 7'd0;
	assign reply_req = reply_cnt != REPLY_IDLE;
	wire [6:0] cmd_req_len = (cmd_code == 8'h03 ? cmd_parameter[4][7:1] : (cmd_code == 8'h12 ? cmd_parameter[4][7:1] : 7'd0));
	wire [6:0] cmd_max_reply_len = (cmd_code == 8'h03 ? 7'd9 : (cmd_code == 8'h12 ? 7'd48 : (cmd_code == 8'h1a ? 7'd8 : (cmd_code == 8'h25 ? 7'd4 : (cmd_code == 8'ha0 ? 7'd8 : 7'd0)))));
	wire [6:0] cmd_reply_len = ((cmd_req_len != 0) && (cmd_req_len < cmd_max_reply_len) ? cmd_req_len : cmd_max_reply_len);
	assign inquiry_str = "MiSTery Harddisk Image  4711";
	wire cmd_has_lun = ((((((cmd_code == 8'h00) || (cmd_code == 8'h08)) || (cmd_code == 8'h0b)) || (cmd_code == 8'h28)) || (cmd_code == 8'h2b)) || (cmd_code == 8'h0a)) || (cmd_code == 8'h2a);
	reg ignore_a1;
	always @(posedge clk)
		if (reset) begin
			target <= 3'd0;
			irq <= 1'b0;
			data_rd_req <= 2'b00;
			data_wr_req <= 2'b00;
			data_rd_req_int <= 2'b00;
			data_wr_req_int <= 2'b00;
			reply_cnt <= REPLY_IDLE;
			led_counter[0] <= 16'd0;
			led_counter[1] <= 16'd0;
			ignore_a1 <= 1'b0;
			byte_counter <= 4'd15;
		end
		else begin
			if (led_counter[0])
				led_counter[0] <= led_counter[0] - 16'd1;
			if (led_counter[1])
				led_counter[1] <= led_counter[1] - 16'd1;
			if (reply_cnt != REPLY_IDLE) begin
				if (reply_ack) begin
					if (reply_cnt < cmd_reply_len)
						reply_cnt <= reply_cnt + 7'd1;
					else begin
						reply_cnt <= REPLY_IDLE;
						irq <= 1'b1;
						asc[current_target] <= 8'h00;
					end
				end
			end
			if (data_busy) begin
				data_rd_req <= 2'b00;
				data_wr_req <= 2'b00;
			end
			else begin
				if (data_rd_req_int) begin
					data_rd_req <= data_rd_req_int;
					data_rd_req_int <= 2'b00;
				end
				if (data_wr_req_int) begin
					data_wr_req <= data_wr_req_int;
					data_wr_req_int <= 2'b00;
				end
			end
			if (data_next) begin
				if ((cmd_code[3:0] == 4'h8) && !data_busy)
					data_rd_req[current_target] <= 1'b1;
				if ((cmd_code[3:0] == 4'ha) && !data_busy)
					data_wr_req[current_target] <= 1'b1;
				data_lba <= data_lba + 32'd1;
				data_length <= data_length - 16'd1;
			end
			if (dma_done) begin
				irq <= 1'b1;
				asc[current_target] <= 8'h00;
			end
			if (clk_en && cpu_req)
				irq <= 1'b0;
			if ((clk_en && cpu_req) && !cpu_rw) begin
				if (!cpu_a1 && !ignore_a1) begin
					target <= cpu_din[7:5];
					err <= 1'b0;
					if ((cpu_din[7:5] < 2) && (enable[cpu_din[7:5]] == 1'b1)) begin
						irq <= 1'b1;
						if (cpu_din[4:0] == 5'h1f)
							byte_counter <= 3'd0;
						else begin
							cmd_parameter[0] <= {3'd0, cpu_din[4:0]};
							byte_counter <= 3'd1;
						end
						ignore_a1 <= 1'b1;
					end
					else
						ignore_a1 <= 1'b0;
				end
				else begin
					ignore_a1 <= 1'b0;
					cmd_parameter[byte_counter] <= cpu_din;
					if (byte_counter != 4'd15)
						byte_counter <= byte_counter + 3'd1;
					if (enable[target] == 1'b1) begin
						if (byte_counter < parms)
							irq <= 1'b1;
						else if (((((((cmd_code == 8'h08) || (cmd_code == 8'h0a)) || (cmd_code == 8'h0b)) || (cmd_code == 8'h28)) || (cmd_code == 8'h2a)) || (cmd_code == 8'h2b)) && (lba >= current_block_size)) begin
							err <= 1'b1;
							irq <= 1'b1;
							asc[current_target] <= 8'h21;
						end
						else if ((lun == 3'd0) || !cmd_has_lun)
							case (cmd_code)
								8'h00, 8'h04, 8'h0b, 8'h12, 8'h15, 8'h1a, 8'h1b, 8'h25, 8'h2b, 8'ha0: reply_cnt <= REPLY_START;
								8'h03: begin
									if (lun != 3'd0)
										asc[current_target] = 8'h25;
									reply_cnt <= REPLY_START;
								end
								8'h08, 8'h28: begin
									data_rd_req_int[current_target] <= 1'b1;
									data_lba <= lba;
									data_length <= length;
									led_counter[current_target] <= 16'hffff;
								end
								8'h0a, 8'h2a: begin
									data_wr_req_int[current_target] <= 1'b1;
									data_lba <= lba;
									data_length <= length;
									led_counter[current_target] <= 16'hffff;
								end
								default: begin
									err <= 1'b1;
									irq <= 1'b1;
									asc[current_target] <= 8'h20;
								end
							endcase
						else begin
							err <= 1'b1;
							irq <= 1'b1;
							asc[current_target] <= 8'h25;
						end
					end
				end
			end
		end
endmodule
