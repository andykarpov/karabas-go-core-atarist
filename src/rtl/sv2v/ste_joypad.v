module ste_joypad (
	joy,
	din,
	dout,
	buttons
);
	input [15:0] joy;
	input [3:0] din;
	output reg [7:0] dout;
	output reg [1:0] buttons;
	always @(*) begin
		dout = 8'hff;
		buttons = 2'b11;
		dout[4] = ~(~din[0] & joy[3]);
		dout[5] = ~((((~din[3] & joy[8]) | (~din[2] & joy[9])) | (~din[1] & joy[12])) | (~din[0] & joy[2]));
		dout[6] = ~(((~din[3] & joy[11]) | (~din[1] & joy[10])) | (~din[0] & joy[1]));
		dout[7] = ~(~din[0] & joy[0]);
		buttons[1] = ~((((~din[3] & joy[7]) | (~din[2] & joy[6])) | (~din[1] & joy[5])) | (~din[0] & joy[4]));
		buttons[0] = ~(~din[0] & joy[13]);
	end
endmodule
