`define  TRUEINIT		5'd0
`define  INITIAL		5'd1
`define  PHOTONUM	  	5'd2
`define  INITTIME		5'd3
`define  FBADDR			5'd4
`define	 PICSIZE		5'd5
`define  PICADDR		5'd6
`define  PREPARE1		5'd7
`define	 PREPARE2		5'd8		
`define	 GETPIXEL1		5'd9
`define	 GETPIXEL2		5'd10
`define	 GETPIXEL3		5'd11
`define	 GETPIXEL4		5'd12
`define  GETPIXEL5		5'd13		
`define  WRITEBACK1		5'd14
`define  WRITEBACK2		5'd15
`define  WAITNEXT		5'd16

module IM_A_module(
	clk,
	Reset,
	Clk_Even02,
	Clk_Even,
	Clk_19,
	Transition_Mode,
	IM_Q,	
	//Scaled_Data,
	IM_WEN,
	IM_A,
	//IM_D,
	Init_Time,
	FB_Addr,
	pic_size,
	Pixel_Done
	//header_done,
);

parameter DATASIZE = 24;
parameter ADDRSIZE = 20;
parameter STATE = 5;
parameter COORDINATE = 10;


input clk;
input Reset;
input [DATASIZE - 1 : 0] IM_Q;
input Clk_Even02;
input Clk_Even;
input Clk_19;
input Transition_Mode;
//input [DATASIZE - 1 : 0] Scaled_Data;

output [ADDRSIZE - 1 : 0] IM_A;
//output [DATASIZE - 1 : 0] IM_D;
output [DATASIZE - 1 : 0] Init_Time;
output [ADDRSIZE - 1 : 0] FB_Addr;
output [2:0] pic_size;
//output header_done;
//wire header_done;
output IM_WEN;
output Pixel_Done;

//-------------------------header--------------------------//

wire [DATASIZE - 1 : 0] _Init_Time;
wire [ADDRSIZE - 1 : 0] _FB_Addr;
wire [2:0] _Photo_Num;
wire [2:0] _pic_size;
wire [ADDRSIZE - 1 : 0] _pic_addr;
wire [1:0] _Photo_Num_Cnt;

reg [ADDRSIZE - 1 : 0] FB_Addr;
reg [DATASIZE - 1 : 0] Init_Time;
//==========================================================
//output [2:0] Photo_Num;
//==========================================================
reg [2:0] Photo_Num;
reg [2:0] pic_size;
reg [ADDRSIZE - 1 : 0] pic_addr;
reg [1:0] Photo_Num_Cnt;

//---------------------------------------------------------//

reg IM_WEN;
reg [ADDRSIZE - 1 : 0] IM_A, _IM_A;
reg [STATE - 1 : 0] cs, ns;
reg Read_En;
reg [ADDRSIZE - 1 : 0] IM_A_Base;

wire [COORDINATE - 1 : 0] pixel_PosX, pixel_PosY;
wire Pixel_Done;					// before 0.2s Transition_Mode = 0, after 0.2s Transition_Mode = 1

//--------------------Read loop-------------------------------------------//
reg Loop_Rst;
reg _Loop_Rst;
reg [ADDRSIZE - 1 : 0] pixel_IM_A;
reg [2:0] loopi_add;
reg [2:0] loopj_add;
reg [COORDINATE - 1 : 0] pixel_UB;
reg [1:0] LBj;
reg [1:0] _LBj;
reg [9:0] UBi;
reg [9:0] UBj;

//--------------------Write loop-------------------------------------------//
reg Write_En;
reg _Write_En;
reg Write_Set;
reg [1:0] Write_LBj;
reg [1:0] _Write_LBj;
reg [2:0] Readi_add;

wire [ADDRSIZE - 1 : 0] Write_IM_A;
wire [ADDRSIZE - 1 : 0] Read_Base;
wire [COORDINATE - 1 : 0] write_PosX, write_PosY;

//-------------------------------Done Signal----------------------------------//

//assign header_done = (cs == `PICSIZE)? 1'd1 : 1'd0;
assign Pixel_Done = (pic_size == 3'b001)? ((Loop_Rst == 1'd1 && cs == `WRITEBACK2)? 1'd1 : 1'd0) :
					(pic_size == 3'b010)? ((Loop_Rst == 1'd1 && cs == `WRITEBACK1)? 1'd1 : 1'd0) : 
					(pic_size == 3'b100)? ((Loop_Rst == 1'd1 && cs == `WRITEBACK1)? 1'd1 : 1'd0) : 
					1'd0;										  

//----------------------------Get Header Data-----------------------------------//

assign _Photo_Num = (cs == `PHOTONUM)? IM_Q : Photo_Num;
assign _Init_Time = (cs == `FBADDR)? IM_Q : Init_Time;
assign _FB_Addr = (cs == `PICSIZE && Loop_Rst == 1'd0)? IM_Q : FB_Addr;
assign _pic_size = (cs == `PICADDR)? IM_Q[9:7] : ((Clk_19 == 1'd1)? 3'dx : pic_size);
assign _pic_addr = (cs == `PREPARE1 && Transition_Mode == 1'd0)? IM_Q : pic_addr;
assign _Photo_Num_Cnt = (cs == `INITTIME)? Photo_Num - 3'd1 : 
						((cs == `PICADDR)? ((Photo_Num_Cnt == 2'd0)? Photo_Num - 3'd1 : Photo_Num_Cnt - 2'd1) : 
						Photo_Num_Cnt);

//-----------------------------DFF-----------------------------------//

always @(posedge clk or posedge Reset)
	if(Reset == 1'd1) begin
		IM_A      <= 20'd2;
		cs        <= `TRUEINIT;
		Init_Time <= 24'd0;
		FB_Addr   <= 20'd0;
		Photo_Num <= 3'd0;
		pic_addr  <= 20'd0;
		pic_size  <= 3'd0;
		Photo_Num_Cnt <= 2'd0;
		LBj       <= 2'd0;
		Loop_Rst  <= 1'd0;
		Write_LBj <= 2'd1;
	end
	else begin
		IM_A      <= _IM_A;
		cs        <= ns;
		Init_Time <= _Init_Time;
		FB_Addr   <= _FB_Addr;
		Photo_Num <= _Photo_Num;
		pic_addr  <= _pic_addr;
		pic_size  <= _pic_size;
		Photo_Num_Cnt <= _Photo_Num_Cnt;
		LBj       <= _LBj;
		Loop_Rst  <= _Loop_Rst;
		Write_LBj <= _Write_LBj;		
	end	

//------------------------------FSM-------------------------------------//

always @(*)
	case(cs)
		`TRUEINIT   : ns = `INITIAL;
		`INITIAL    : ns =   `PHOTONUM;
		`PHOTONUM   : ns =   `INITTIME;
		`INITTIME     : ns =   `FBADDR;
		`FBADDR   : ns =   `PICSIZE;
		`PICSIZE    : ns =   `PICADDR;
		`PICADDR    : ns =   `PREPARE1;
		`PREPARE1   : ns =   `PREPARE2;
		`PREPARE2   : ns =   `GETPIXEL1;
		`GETPIXEL1  : ns =   (pic_size == 3'b010)? `WRITEBACK1 : `GETPIXEL2;
		`GETPIXEL2  : ns =   `GETPIXEL3;
		`GETPIXEL3  : ns =   `GETPIXEL4;
		`GETPIXEL4  : ns =   `GETPIXEL5;
		`GETPIXEL5  : ns =   `WRITEBACK1;
		`WRITEBACK1 : ns =   (Pixel_Done == 1'd1)? `WAITNEXT : ((pic_size == 3'b001)?  `WRITEBACK2 : `GETPIXEL1);
		`WRITEBACK2 : ns =   (Pixel_Done == 1'd1)? `WAITNEXT : `GETPIXEL1;
		`WAITNEXT   : ns =   (Clk_Even == 1'd1)? `PICSIZE : ((Clk_Even02 == 1'd1)? `PREPARE1 : `WAITNEXT);
		default :ns = `INITIAL;
	endcase
	
//------------------------------IM_WEN-----------------------------------//

always @(*)
	case(cs)
		`INITIAL    : IM_WEN = 1'd1;
		`PREPARE2   : IM_WEN = 1'd1;
		`GETPIXEL1  : IM_WEN = 1'd1;
		`GETPIXEL2  : IM_WEN = 1'd1;
		`GETPIXEL3  : IM_WEN = 1'd1;
		`GETPIXEL4  : IM_WEN = 1'd1;
		`GETPIXEL5  : IM_WEN = 1'd1;
		`WRITEBACK1 : IM_WEN = 1'd0; //1'd0
		`WRITEBACK2 : IM_WEN = 1'd0; //1'd0
		default     : IM_WEN = 1'd1;
	endcase

//-----------------------------IM_A--------------------------------------//

always @(*)
	case(cs)
		`TRUEINIT	: _IM_A = IM_A;
		`INITIAL    : _IM_A = 20'd2;
		`PHOTONUM   : _IM_A = IM_A - 20'd2;
		`INITTIME   : _IM_A = IM_A + 20'd1;
		`FBADDR   	: _IM_A = ((Photo_Num - Photo_Num_Cnt) << 1) + 20'd2;
		//`FBADDR   : _IM_A = (Photo_Num << 1) + 20'd2;
		`PICSIZE    : _IM_A = IM_A - 20'd1;
		`PICADDR    : _IM_A = 20'dx;
		`PREPARE2   : _IM_A = pixel_IM_A;
		`GETPIXEL1  : _IM_A = (pic_size == 3'b010)? Write_IM_A : pixel_IM_A;
		`GETPIXEL2  : _IM_A = pixel_IM_A;
		`GETPIXEL3  : _IM_A = pixel_IM_A;
		`GETPIXEL4  : _IM_A = pixel_IM_A;
		`GETPIXEL5  : _IM_A = (pic_size == 3'b100 || pic_size == 3'b001)? Write_IM_A : pixel_IM_A; 
		`WRITEBACK1 : _IM_A = (pic_size == 3'b001)? ((Transition_Mode == 1'd0)? Write_IM_A + 20'd255 : Write_IM_A + 20'd257) : pixel_IM_A;			 
		`WRITEBACK2 : _IM_A = pixel_IM_A;
		`WAITNEXT 	: _IM_A = (Clk_Even == 1'd1)? ((Photo_Num - Photo_Num_Cnt) << 1) + 20'd2 : 20'dx;
		default     : _IM_A = IM_A;
	endcase

//-----------------------------IM_D--------------------------------------//



//-----------------------------Pic_IM_A Ctrl-----------------------------//

always @(*)
	case(pic_size)
		3'b001 : IM_A_Base = {6'b000000, pixel_PosY[6:0], pixel_PosX[6:0]};
		3'b010 : IM_A_Base = {4'b0000, pixel_PosY[7:0], pixel_PosX[7:0]};
		3'b100 : IM_A_Base = {2'b00, pixel_PosY[8:0], pixel_PosX[8:0]};
		default : IM_A_Base = 20'dx;
	endcase
always @(*)
	case(cs)
		`PREPARE2   : pixel_IM_A = IM_A_Base + pic_addr;
		`GETPIXEL1  : pixel_IM_A = (pic_size == 3'b001)? (pixel_PosY == 10'd127)?
														 IM_A_Base + pic_addr :
														 IM_A_Base + pic_addr + 20'd128 :
								   (pic_size == 3'b010)? IM_A_Base + pic_addr :
								   (pic_size == 3'b100)? IM_A_Base + pic_addr + 20'd1 :
								   20'dx;	
								   
		`GETPIXEL2  : pixel_IM_A = (pic_size == 3'b001)? (pixel_PosX == 10'd127)?
														 IM_A_Base + pic_addr:
														 IM_A_Base + pic_addr + 20'd1:
								   (pic_size == 3'b100)? IM_A_Base + pic_addr + 20'd512 : 
								   20'dx;
								   
		`GETPIXEL3  : pixel_IM_A = (pic_size == 3'b001)? (pixel_PosY == 10'd127)?
														 IM_A_Base + pic_addr + 20'd1 :
														 (pixel_PosX == 10'd127)?
														 IM_A_Base + pic_addr + 20'd128 :
														 IM_A_Base + pic_addr + 20'd129 : 
								   (pic_size == 3'b100)? IM_A_Base + pic_addr + 20'd513 : 
								   20'dx;	
								   
		`WRITEBACK1 : pixel_IM_A = (pic_size != 3'b001)? IM_A_Base + pic_addr : 20'dx;
		`WRITEBACK2 : pixel_IM_A = IM_A_Base + pic_addr;		
		default     : pixel_IM_A = 20'dx;
	endcase

//------------------------------Read pixel data IM_A(Loop_ij)------------------------------------//

always @(*)
	case(pic_size)
		3'b001 : Read_En = (cs == `WRITEBACK1)? 1'd1 : 1'd0;
		3'b010 : Read_En = (cs == `GETPIXEL1)? 1'd1 : 1'd0;
		3'b100 : Read_En = (cs == `GETPIXEL5)? 1'd1 : 1'd0;
		default  : Read_En = 1'd0;
	endcase

always @(*)
	case(cs)
		`PREPARE1   : _Loop_Rst = 1'd1;   // v
		`GETPIXEL1  : _Loop_Rst = (pic_size == 3'b010)? (((pixel_PosX == 10'd254 && pixel_PosY == 10'd255) || (pixel_PosX == 10'd255 && pixel_PosY == 10'd255))? 1'd1 : 1'd0) : 1'd0;		
		`GETPIXEL5  : _Loop_Rst = (pic_size == 3'b100)? (((pixel_PosX == 10'd510 && pixel_PosY == 10'd510) || (pixel_PosX == 10'd508 && pixel_PosY == 10'd510))? 1'd1 : 1'd0) : 1'd0;							 				 
		`WRITEBACK1 : _Loop_Rst = (pic_size == 3'b001)? ((pixel_PosX == 10'd127 && pixel_PosY == 10'd127)? 1'd1 : 1'd0) : 1'd0;		
		`WAITNEXT   : _Loop_Rst = 1'd1;
		default     : _Loop_Rst = 1'd0;
	endcase

always @(*)
	case(pic_size)
		3'b001 : loopi_add = 3'd1;
		3'b010 : loopi_add = 3'd1;
		3'b100 : loopi_add = 3'd2;
		default : loopi_add = 3'd2;
	endcase
	
always @(*)
	case(pic_size)
		3'b001 : loopj_add = 3'd1;
		3'b010 : loopj_add = 3'd2;
		3'b100 : loopj_add = 3'd4;
		default : loopj_add = 3'd1;
	endcase		


always @(*)
	case(cs)
		`PREPARE1   : _LBj = (Transition_Mode == 1'd0)? 
							 (pic_size == 3'b001)? 2'd0 : 
							 (pic_size == 3'b010)? 2'd1 :
							 (pic_size == 3'b100)? 2'd2 : LBj : 2'd0;						
		`WRITEBACK1 : _LBj = (pic_size == 3'b010)? ((pixel_PosX[0])? 2'd0 : 2'd1) : LBj;		
		`GETPIXEL5  : _LBj = (pic_size == 3'b100)? ((pixel_PosX[0] ^ pixel_PosX[1])? 2'd0 : 2'd2) : 2'd0;		
		`WAITNEXT   : _LBj = (pic_size == 3'b100)? ((Clk_Even02)? 2'd0 : LBj) : LBj;
		default     :  _LBj = LBj;
	endcase

always @(*)
	case(pic_size)
		3'b001 : UBi = 10'd127;
		3'b010 : UBi = 10'd255;
		3'b100 : UBi = 10'd510;
		default : UBi = 10'dx;
	endcase

always @(*)
	case(pic_size)
		3'b001 : UBj = 10'd127;
		3'b010 : UBj = 10'd254;
		3'b100 : UBj = 10'd508;
		default : UBj = 10'dx;
	endcase

Loop_ij Pixel(
	.clk(clk),
	.rst(Reset),
	.Reset(_Loop_Rst),
	.En(Read_En),
	.Loopi_Add(loopi_add),
	.Loopj_Add(loopj_add),
	.LBi(1'd0),
	.LBj(_LBj),
	.UBi(UBi),
	.UBj(UBj),
	.i(pixel_PosY),
	.j(pixel_PosX)
);

//-----------------------------FB_IM_A Ctrl-----------------------------//

assign Read_Base = {4'b0000, write_PosY[7:0], write_PosX[7:0]};
assign Write_IM_A = Read_Base + FB_Addr;



//------------------------------Write pixel data IM_A(Loop_ij------------------------------------//

always @(*)
	case(pic_size)
		3'b001 : Write_En = (cs == `WRITEBACK1)? 1'd1 : 1'd0;
		3'b010 : Write_En = (cs == `WRITEBACK1)? 1'd1 : 1'd0;
		3'b100 : Write_En = (cs == `WRITEBACK1)? 1'd1 : 1'd0;
		default  : Write_En = 1'd0;
	endcase

always @(*)
	case(cs)
		`PREPARE1   : Write_Set = 1'd1;   // v
		`GETPIXEL1  : Write_Set = (pic_size == 3'b010)? (((pixel_PosX == 10'd254 && pixel_PosY == 10'd255) || (pixel_PosX == 10'd255 && pixel_PosY == 10'd255))? 1'd1 : 1'd0) : 1'd0;		
		`GETPIXEL5  : Write_Set = (pic_size == 3'b100)? (((pixel_PosX == 10'd510 && pixel_PosY == 10'd510) || (pixel_PosX == 10'd508 && pixel_PosY == 10'd510))? 1'd1 : 1'd0) : 1'd0;							 				 
		`WRITEBACK1 : Write_Set = (pic_size == 3'b001)? ((pixel_PosX == 10'd127 && pixel_PosY == 10'd127)? 1'd1 : 1'd0) : 1'd0;		
		`WAITNEXT   : Write_Set = 1'd1;
		default     : Write_Set = 1'd0;
	endcase
	
always @(*)
	case(pic_size)
		3'b001 : Readi_add = 3'd2;
		default : Readi_add = 3'd1;
	endcase	

always @(*)
	case(cs)		
		`WRITEBACK1 : _Write_LBj = (write_PosX[0])? 2'd0 : 2'd1;
		`GETPIXEL5  : _Write_LBj = (pic_size == 3'b001)? ((Transition_Mode == 1'd0)? 2'd1 : 2'd0) : ((pic_size == 3'b100)? ((write_PosX[0])? 2'd0 : 2'd1) : Write_LBj); 
		default     :  _Write_LBj = Write_LBj;
	endcase
	

Loop_ij Write(
	.clk(clk),
	.rst(Reset), 
	.Reset(Write_Set),
	.En(Write_En),
	.Loopi_Add(Readi_add),
	.Loopj_Add(3'd2),
	.LBi(1'd0),
	.LBj(Write_LBj),
	.UBi(10'd255),
	.UBj(10'd254),
	.i(write_PosY),
	.j(write_PosX)
);


endmodule

//-------------------------Loop_ij--------------------------------------------------------//

module Loop_ij(
	clk, 
	rst,
	Reset,
	En,
	Loopi_Add,
	Loopj_Add,
	LBi, 
	LBj, 
	UBi, 
	UBj,
	i, 
	j 
);

input clk; 
input rst;
input Reset;
input En;
input LBi;
input [1:0] LBj;
input [9:0] UBi;
input [9:0] UBj;
input [2:0] Loopi_Add;
input [2:0] Loopj_Add;

output reg [9:0] i, j;
wire [9:0] ni, nj;

always@(posedge clk or posedge rst )
	begin
		if(rst)begin
			i <= 'd0;
			j <= 'd0;
		end
		//else 
//			if(Reset) begin
//				i <= {9'b000000000, LBi};
//				j <= {8'b00000000, LBj};
//			end
		else begin
			i <= ni;
			j <= nj;
		end
	end

assign ni = (Reset)?{9'b000000000, LBi}:(En == 1'd0)? i : ((i >= UBi)? i : (j >= UBj)? i + {7'b0000000, Loopi_Add} : i);
assign nj = (Reset)?{8'b00000000, LBj}:(En == 1'd0)? j : ((j >= UBj)? ((i >= UBi)? j : {8'b00000000, LBj}) : j + {7'b0000000, Loopj_Add});


endmodule

