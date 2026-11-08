`timescale 1ns / 1ps
`default_nettype wire

/*
 st_sram.v

 The SRAM of the board (two 2M x 8 chips = one 2M x 16, 10 ns, asynchronous) for the TOS of the
 Atari ST: the ROM bus of atarist reads 16-bit words, the loaders of the mcu write bytes. The
 even byte of a word is the high one (MD[15:8], MWR_N[1], MRD_N[1]), as the 68000 has it, so a TOS
 file goes in byte by byte at its offsets and a word comes out as the CPU wants it.

 At 32 MHz (31 ns per clock):
 - a read slot puts the word address on MA and takes MD two clocks later (three clocks per slot) (62 ns for the pads
   and the 10 ns of the SRAM); slots follow each other, so rom_data follows a new rom_addr
   within seven clocks. The 68000 takes ROM data at the end of its bus cycle, four CPU clocks
   (16 clocks of clk) after the address.
 - a write slot (a byte of a loader, while the machine is held in reset) turns /OE of both chips
   off (MRD_N = 11) and drives MD for three clocks, /WE of the lane low in the middle one: the
   address and data are stable a clock before and after /WE, and the SRAM never drives MD at
   the same time.

 we is one clock with waddr / wdata; a write waits for the end of the slot in progress (at most
 four clocks); the loaders of the mcu write a byte per microsecond or less often.
*/

module st_sram (
	input wire clk,

	input wire [20:0] raddr,      // word address
	output reg [15:0] rdata = 16'hFFFF,

	input wire we,
	input wire [21:0] waddr,      // byte address
	input wire [7:0] wdata,

	output reg [20:0] MA = 21'd0,
	inout wire [15:0] MD,
	output reg [1:0] MWR_N = 2'b11,
	output reg [1:0] MRD_N = 2'b00
);

reg wr_pend = 1'b0;
reg [21:0] wr_addr = 22'd0;
reg [7:0] wr_data = 8'd0;
reg md_oe = 1'b0;
reg [15:0] md_out = 16'd0;
reg [2:0] st = 3'd0;
reg s_lane = 1'b0;   // the lane of the write slot (wr_addr may change during the slot)

localparam S_IDLE = 3'd0, S_R1 = 3'd1, S_R2 = 3'd2, S_W1 = 3'd3, S_W2 = 3'd4, S_W3 = 3'd5;

assign MD = md_oe ? md_out : 16'bz;

always @(posedge clk) begin
	case (st)
	S_IDLE:
		if (wr_pend) begin
			MA <= wr_addr[21:1];
			s_lane <= wr_addr[0];
			wr_pend <= 1'b0;
			md_out <= { wr_data, wr_data };
			md_oe <= 1'b1;
			MRD_N <= 2'b11;
			st <= S_W1;
		end
		else begin
			MA <= raddr;
			st <= S_R1;
		end
	S_R1:
		st <= S_R2;
	S_R2: begin
		// two clocks after the address (an IOB register can take MD)
		rdata <= MD;
		st <= S_IDLE;
	end
	S_W1: begin
		MWR_N <= s_lane ? 2'b10 : 2'b01;  // odd: the low byte (lane 0)
		st <= S_W2;
	end
	S_W2: begin
		MWR_N <= 2'b11;
		st <= S_W3;
	end
	default: begin  // S_W3
		md_oe <= 1'b0;
		MRD_N <= 2'b00;
		st <= S_IDLE;
	end
	endcase

	// a new byte (after the case: it wins over the clear of the slot that takes the old one)
	if (we) begin
		wr_pend <= 1'b1;
		wr_addr <= waddr;
		wr_data <= wdata;
	end
end

endmodule
