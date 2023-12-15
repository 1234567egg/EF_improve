`define 	RST_STATE 		3'd0
`define 	WAIT_STATE 		3'd1
`define 	EMPTY_STATE  	3'd2
`define 	READ_STATE1 	3'd3
`define 	READ_STATE2 	3'd4
`define 	WRT_STATE 		3'd5

module Clock(
	clk,
	reset,
	Pixel_Done,
	clk_odd,
	clk_even,
	Init_time,
	FB_Addr,
	CR_Q,
	CR_A,
	IM_A,
	IM_WEN,
	IM_D
//	CR_Done
);

parameter DATASIZE = 24;
parameter ADDRSIZE = 20;
parameter CR_ADDRSIZE = 9;
parameter CR_DATASIZE = 13;
parameter TIMESIZE = 8;
parameter BCDSIZE = 4;
parameter STATE = 3;
parameter COUNT = 6;


//----------------------------------------------------------------

input clk;
input reset;
input [CR_DATASIZE - 1:0] CR_Q;
input Pixel_Done;
input clk_odd;
input clk_even;
input [DATASIZE - 1 : 0] Init_time;
input [ADDRSIZE - 1 : 0] FB_Addr;

output [ADDRSIZE - 1:0] IM_A;
output IM_WEN;
output [CR_ADDRSIZE - 1:0] CR_A;
output [DATASIZE - 1:0] IM_D;
//output CR_Done;
reg Complete;


reg [ADDRSIZE - 1:0] IM_A;
reg IM_WEN;
reg [CR_ADDRSIZE - 1:0] CR_A, nx_CR_A;
reg [DATASIZE - 1:0] IM_D, nx_CR_Q_Out;
reg [COUNT - 1:0] CR_Q_count, nx_IM_D;									
reg [TIMESIZE - 1:0] hours, nx_hours;				  
reg [TIMESIZE - 1:0] minutes, nx_minutes;			
reg [TIMESIZE - 1:0] seconds, nx_seconds;													
reg [COUNT - 1:0] count_num, nx_count_num;       	
reg [COUNT - 1:0] count_data, nx_count_data;    		
reg [STATE - 1:0] cs, ns;
reg [BCDSIZE - 1:0] write_num;							
reg [CR_ADDRSIZE - 1:0] Init_CR_A;	


reg [ADDRSIZE - 1:0] _IM_A;
wire [BCDSIZE - 1:0] BCD_Sec[0:1], BCD_Min[0:1], BCD_Hor[0:1]; 	  	
wire nx_Complete;
wire start;
wire CR_Done;

//---------------------------------Loop dimension--------------------------//

reg Loop_En;
wire [4:0] Row;
wire [4:0] Column;
wire [4:0] Number; 
wire [6:0] Shift;

wire [ADDRSIZE - 1 : 0] FB_Base;
wire [ADDRSIZE - 1 : 0] FB_Base_test;
wire enj;
wire eni;

//-------------------------------------------------------------------------//
	
always @(posedge clk or posedge reset)
	if(reset == 1'd1) begin
		CR_A <= 8'b0;
		cs <= `RST_STATE;
		IM_D <= 24'b0;
		hours <= 8'b0;
		minutes <= 8'b0;
		seconds <= 8'b0;
		IM_A <= 20'd0;
	end
	else begin 
		CR_A <= nx_CR_A;
		cs <= ns;
		IM_D <= nx_CR_Q_Out;
		hours <= nx_hours;
		minutes <= nx_minutes;
		seconds <= nx_seconds;
		IM_A <= _IM_A;
	end
//--------------------------------Complete Condition------------------------------

assign CR_Done = (Number == 5'd7 && Column == 5'd23 && Row == 5'd13)? 1'd1 : 1'd0;
//-----------------------------------Start----------------------------------------

assign start = Pixel_Done | clk_odd;

//-------------------------------FSM-----------------------------------------------

always @(*)												
	case(cs)				
		`RST_STATE : ns = (start)? `EMPTY_STATE : cs;			//|Mode						 		
		`WAIT_STATE : ns = (start)? `EMPTY_STATE : cs;		//|Mode
		`EMPTY_STATE : ns = `READ_STATE1;
		`READ_STATE1 : ns = `READ_STATE2;
		`READ_STATE2 : ns = `WRT_STATE;
		`WRT_STATE : ns = (CR_Done == 1'd1)? `WAIT_STATE : 	
						((Row == 5'd13)? //4444
						`READ_STATE1 : 
						cs);								
		default ns = cs;
	endcase

//---------------------------FB_IM_A-----------------------------------------------

assign Shift = {Number,3'd0}+{Number,2'd0}+Number;  //**mul**//Number*13
assign FB_Base = 20'd59544 + {7'b0, Column, 3'b0, Row} + Shift;
//assign IM_A = FB_Base + FB_Addr;

always @(*)
	case(Row)
		5'd13 : _IM_A = IM_A;
		default : _IM_A = FB_Base + FB_Addr;
	endcase

//---------------------------IM_WEN------------------------------------------------

always @(*)
	case(cs)
		`WRT_STATE : IM_WEN = 1'd0;
		default : IM_WEN = 1'd1;
	endcase


//---------------------------CR_A & CR_Q Output-------------------------------------

/*
always @(*)									
	case(cs)
		`EMPTY_STATE : nx_CR_A = Init_CR_A;
		`WRT_STATE : nx_CR_A = (Row == 4'd13)? ((Column == 5'd23)? //4444
								Init_CR_A : 
								CR_A + 9'd1) : 
								CR_A;
		default nx_CR_A = CR_A;
	endcase	
*/
always @(*)									
	case(cs)
		`EMPTY_STATE : nx_CR_A = Init_CR_A;
		`READ_STATE1 : nx_CR_A = (Row == 5'd0 && Column == 5'd0)? Init_CR_A : CR_A + 9'd1; 
		default nx_CR_A = CR_A;
	endcase

always @(*)
	case(cs)
		`READ_STATE2 : nx_CR_Q_Out = (CR_Q[5'd12 - Row] == 1'd1)?  24'hffffff : 24'h000000; 
		`WRT_STATE : nx_CR_Q_Out = (CR_Q[5'd12 - Row] == 1'd1)? 24'hffffff : 24'h000000;//4444
		default nx_CR_Q_Out = IM_D;
	endcase
	
//--------------------------Loop ijk-----------------------------------------

always @(*)
	case(cs)
		`READ_STATE1 : Loop_En = 1'd0;
		`RST_STATE : Loop_En = 1'd0;
		`WAIT_STATE : Loop_En = 1'd0;
		`EMPTY_STATE : Loop_En = 1'd0;
		default : Loop_En = 1'd1;
	endcase
/*
Loop_ijk loop(
	.clk(clk), 
	.rst(reset),
	.set(start),
	.En(Loop_En),
	.i(Number), 
	.j(Column),
	.k(Row)
);
*/	


Loop_1 loopRow(
	.clk(clk),
	.rst(reset),
	.UB(5'd13),
	.LB(5'd0),
	.en(Loop_En),
	.en_n(enj),
	.loop_out(Row)
);

Loop_1 loopCol(
	.clk(clk),
	.rst(reset),
	.UB(5'd23),
	.LB(5'd0),
	.en(enj),
	.en_n(eni),
	.loop_out(Column)
);

Loop_1 loopNum(
	.clk(clk),
	.rst(reset),
	.UB(5'd7),
	.LB(5'd0),
	.en(eni),
	.en_n(),
	.loop_out(Number)
);
//--------------------------Get Init_CR_A------------------------------------

always @(*)								
	case(Number)
		5'd0 : write_num = BCD_Hor[1];
		5'd1 : write_num = BCD_Hor[0];
		5'd2 : write_num = 4'd10;		//colon
		5'd3 : write_num = BCD_Min[1];
		5'd4 : write_num = BCD_Min[0];
		5'd5 : write_num = 4'd10;		//colon
		5'd6 : write_num = BCD_Sec[1];
		5'd7 : write_num = BCD_Sec[0];
		default write_num = 4'dx;
	endcase

always @(*)
	case(write_num)						
		4'd0 : Init_CR_A = 13'd0;
		4'd1 : Init_CR_A = 13'd24;
		4'd2 : Init_CR_A = 13'd48;
		4'd3 : Init_CR_A = 13'd72;
		4'd4 : Init_CR_A = 13'd96;
		4'd5 : Init_CR_A = 13'd120;
		4'd6 : Init_CR_A = 13'd144;
		4'd7 : Init_CR_A = 13'd168;
		4'd8 : Init_CR_A = 13'd192;
		4'd9 : Init_CR_A = 13'd216;
		4'd10 : Init_CR_A = 13'd240;
		default Init_CR_A = 13'dx;
	endcase	

//-----------------------------Reset Initial Time------------------------------------------
// change to 6 bits
always @(*)
	case(cs)
		`RST_STATE : nx_hours = Init_time[23:16];
		`WAIT_STATE : nx_hours = (clk_even || clk_odd)? ((seconds == 8'd59)? 
								((minutes == 8'd59)? 
								((hours == 8'd23)? 8'd0 
								: hours + 8'd1) : 
								hours) : hours) : 
								hours;
		default nx_hours = hours;
	endcase
	
always @(*)
	case(cs)
		`RST_STATE : nx_minutes = Init_time[15:8];
		`WAIT_STATE : nx_minutes = (clk_even || clk_odd)? ((seconds == 8'd59)? 
									((minutes == 8'd59)? 8'd0 : 
									minutes + 8'd1) : 
									minutes) : 
									minutes;
		default nx_minutes = minutes;
	endcase
	
always @(*)
	case(cs)
		`RST_STATE : nx_seconds = Init_time[7:0];
		`WAIT_STATE : nx_seconds = (clk_even || clk_odd)? ((seconds == 8'd59)? 
									8'd0 : 
									seconds + 8'd1) : 
									seconds;
		default nx_seconds = seconds;
	endcase

BtoBCD_6bit BCD1(
    .raw_num(seconds),
    .bcd_ten(BCD_Sec[1]),
    .bcd_one(BCD_Sec[0])
);

BtoBCD_6bit BCD2(
    .raw_num(minutes),
    .bcd_ten(BCD_Min[1]),
    .bcd_one(BCD_Min[0])
);


BtoBCD_6bit_hour BCD3(
    .raw_num(hours),
    .bcd_ten(BCD_Hor[1]),
    .bcd_one(BCD_Hor[0])
);


endmodule
//----------------------------------------------//

// conver 6bit input to bcd code 
//input must be below 60

module BtoBCD_6bit (
    input [7:0] raw_num,
    output [3:0] bcd_ten,
    output [3:0] bcd_one
);

    assign bcd_ten = (raw_num < 8'd10) ? 4'd0 :
                     (raw_num < 8'd20) ? 4'd1 :
                     (raw_num < 8'd30) ? 4'd2 :
                     (raw_num < 8'd40) ? 4'd3 :
                     (raw_num < 8'd50) ? 4'd4 :
                     (raw_num < 8'd60) ? 4'd5 : 4'bxxxx;

    assign  bcd_one = raw_num - bcd_ten * 10 ;

endmodule

//-----------------------------------------------//

module BtoBCD_6bit_hour (
    input [7:0] raw_num,
    output [3:0] bcd_ten,
    output [3:0] bcd_one
);

    assign bcd_ten = (raw_num < 8'd10) ? 4'd0 :
                     (raw_num < 8'd20) ? 4'd1 :
                     (raw_num < 8'd30) ? 4'd2 : 4'bxxxx;

    assign  bcd_one = raw_num - bcd_ten * 10 ;

endmodule

//------------------------------Loop----------------------------------------

module Loop_1(
	clk,
	rst,
	UB,
	LB,
	en,
	en_n,
	loop_out
);

input clk, rst, en;
input [4:0] UB, LB;
output reg [4:0] loop_out;
output en_n;

reg [4:0] _loop_out;
wire cmpUB;

always @(posedge clk or posedge rst)
	if(rst)
		loop_out <= 5'd0;
	else
		loop_out <= _loop_out; 

always @(*)
	if(en_n)
		_loop_out <= LB;
	else if(en)
		_loop_out <= loop_out + 5'd1;
	else	
		_loop_out <= loop_out;

assign cmpUB = (loop_out >= UB)? 1'b1 : 1'b0;
assign en_n = cmpUB & en;

endmodule




