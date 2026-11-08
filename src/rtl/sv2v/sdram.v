module sdram (
	sd_clk,
	sd_cke,
	sd_data,
	sd_addr,
	sd_dqm,
	sd_ba,
	sd_cs,
	sd_we,
	sd_ras,
	sd_cas,
	clk,
	reset_n,
	ready,
	refresh,
	din,
	dout,
	addr,
	ds,
	cs,
	we
);
	output wire sd_clk;
	output wire sd_cke;
	inout [15:0] sd_data;
	output reg [12:0] sd_addr;
	output wire [1:0] sd_dqm;
	output reg [1:0] sd_ba;
	output wire sd_cs;
	output wire sd_we;
	output wire sd_ras;
	output wire sd_cas;
	input clk;
	input reset_n;
	output wire ready;
	input refresh;
	input [15:0] din;
	output reg [15:0] dout;
	input [21:0] addr;
	input [1:0] ds;
	input cs;
	input we;
	assign sd_clk = ~clk;
	assign sd_cke = 1'b1;
	localparam RASCAS_DELAY = 3'd1;
	localparam BURST_LENGTH = 3'b000;
	localparam ACCESS_TYPE = 1'b0;
	localparam CAS_LATENCY = 3'd2;
	localparam OP_MODE = 2'b00;
	localparam NO_WRITE_BURST = 1'b1;
	localparam MODE = {1'b0, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH};
	localparam STATE_IDLE = 3'd0;
	localparam STATE_CMD_CONT = STATE_IDLE + RASCAS_DELAY;
	localparam STATE_READ = (STATE_CMD_CONT + CAS_LATENCY) + 3'd1;
	localparam STATE_LAST = 3'd6;
	reg [2:0] state;
	reg [4:0] init_state;
	assign ready = !(|init_state);
	localparam CMD_INHIBIT = 4'b1111;
	localparam CMD_NOP = 4'b0111;
	localparam CMD_ACTIVE = 4'b0011;
	localparam CMD_READ = 4'b0101;
	localparam CMD_WRITE = 4'b0100;
	localparam CMD_BURST_TERMINATE = 4'b0110;
	localparam CMD_PRECHARGE = 4'b0010;
	localparam CMD_AUTO_REFRESH = 4'b0001;
	localparam CMD_LOAD_MODE = 4'b0000;
	reg [3:0] sd_cmd;
	assign sd_cs = sd_cmd[3];
	assign sd_ras = sd_cmd[2];
	assign sd_cas = sd_cmd[1];
	assign sd_we = sd_cmd[0];
	reg [15:0] dq_out;
	reg dq_oe = 1'b0;
	reg [1:0] dqm_r = 2'b00;
	assign sd_data[15:0] = (dq_oe ? dq_out : 16'bzzzzzzzzzzzzzzzz);
	assign sd_dqm = dqm_r;
	always @(posedge clk) begin : sv2v_autoblock_1
		reg csD;
		sd_cmd <= CMD_INHIBIT;
		dq_oe <= 1'b0;
		dqm_r <= 2'b00;
		if (!reset_n) begin
			init_state <= 5'h1f;
			state <= STATE_IDLE;
		end
		else begin
			if (init_state != 0)
				state <= state + 3'd1;
			if ((state == STATE_LAST) && (init_state != 0))
				init_state <= init_state - 5'd1;
		end
		if (init_state != 0) begin
			csD <= 1'b0;
			if (state == STATE_IDLE) begin
				if (init_state == 13) begin
					sd_cmd <= CMD_PRECHARGE;
					sd_addr[10] <= 1'b1;
				end
				if ((init_state == 10) || (init_state == 6))
					sd_cmd <= CMD_AUTO_REFRESH;
				if (init_state == 2) begin
					sd_cmd <= CMD_LOAD_MODE;
					sd_addr <= MODE;
				end
			end
		end
		else begin
			csD <= cs;
			if (state == STATE_IDLE) begin
				if (cs && !csD) begin
					if (!refresh) begin
						sd_cmd <= CMD_ACTIVE;
						sd_addr <= addr[21:9];
						sd_ba <= 2'b00;
						state <= 3'd1;
					end
					else
						sd_cmd <= CMD_AUTO_REFRESH;
				end
			end
			else begin
				state <= state + 3'd1;
				if (state == STATE_CMD_CONT) begin
					sd_cmd <= (we ? CMD_NOP : CMD_READ);
					sd_addr <= {4'b0010, addr[8:0]};
				end
				if ((state > STATE_CMD_CONT) && (state < STATE_READ))
					sd_cmd <= CMD_NOP;
				if ((state == (STATE_CMD_CONT + 3'd1)) && we) begin
					sd_cmd <= CMD_WRITE;
					dq_out <= din;
					dq_oe <= 1'b1;
					dqm_r <= ds;
				end
				if ((state == STATE_READ) && !we)
					dout <= sd_data[15:0];
			end
		end
	end
endmodule
