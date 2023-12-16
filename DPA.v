////////////////////////////////////////////////////////////////////////////////
// File: DPA.v
// Author: MPD_EF_G07
// Date: 2023-12-16 19:20
// Version: 1.0
// modify version of EF project,
// reduce hardware size 
//
// Updates:
// - 2023-12-16 19:20 -[Jason]
// - conbine all module in to DPA
////////////////////////////////////////////////////////////////////////////////
 
module DPA (clk,reset,IM_A, IM_Q,IM_D,IM_WEN,CR_A,CR_Q);
input clk;
input reset;
output [19:0] IM_A;
input [23:0] IM_Q;
output [23:0] IM_D;
output IM_WEN;
output [8:0] CR_A;
input [12:0] CR_Q;

wire clk_200ms,clk_odd,clk_even,clk_19;

reg [19:0]IM_A;
reg [23:0]IM_D;
reg IM_WEN;

wire [19:0]IM_A_pic,IM_A_CR;

wire [23:0]init_time;

wire [19:0]FB_addr;

wire [2:0]pic_size;

wire [23:0]IM_D_CR,IM_D_256,IM_D_Scaling;

//reg  [23:0]IM_D_Result;

wire IM_WEN_PIC,IM_WEN_CR;

wire CR_Done,Pixel_Done;

//wire o_pic_write_done_200ms,o_pic_write_done_400ms,o_clk_write_done_400ms;

wire [1:0]control_cs;

wire [1:0]control_ns;

wire [2:0]i_mode_start;
//=============================temp=======================================

wire process_mode;

reg transition_mode,transition_mode_ns;


//========================================================================


Control_v3 Control_v3(
    .clk(clk),
    .reset(reset),
    .PIC_Write_Done(Pixel_Done),
//    .CR_Done(CR_Done),
    .clk_200ms(clk_200ms),
//   .clk_odd(clk_odd),
    .clk_even(clk_even),
    .PIC_size(pic_size),
    .Control_CS(control_cs),
    .i_mode_start(i_mode_start)
);

fdiv fdiv(
    .clk(clk), // 1000ns clock input 
    .reset_p(reset),
    .clk_odd_sec(clk_odd),
    .clk_even_sec(clk_even),
    .clk_even_02sec(clk_200ms),
    .clk_19(clk_19) 
    );

IM_A_module IM_A_module(
	.clk(clk),
	.Reset(reset),
	.Clk_Even02(clk_200ms),
	.Clk_Even(clk_even),
	.Clk_19(clk_19),
	.Transition_Mode(transition_mode),
	.IM_Q(IM_Q),	
	//.Scaled_Data(IM_D_Result),
	.IM_WEN(IM_WEN_PIC),
	.IM_A(IM_A_pic),
	//.IM_D(IM_D),
	.Init_Time(init_time),
	.FB_Addr(FB_addr),
	.pic_size(pic_size),
	.Pixel_Done(Pixel_Done)
);

assign IM_D_256=IM_Q;

Clock CR(
	.clk(clk),
	.reset(reset),
	.Pixel_Done(Pixel_Done),
	.clk_odd(clk_odd),
	.clk_even(clk_even),
	.Init_time(init_time),
	.FB_Addr(FB_addr),
	.CR_Q(CR_Q),
	.CR_A(CR_A),
	.IM_A(IM_A_CR),
	.IM_WEN(IM_WEN_CR),
	.IM_D(IM_D_CR)
//	.CR_Done(CR_Done)
);

assign process_mode=(i_mode_start[0])?1'b0:
                    (i_mode_start[2])?1'b1:1'bx;

always @(posedge clk or posedge reset) begin
    if(reset)begin
        transition_mode<=1'b0;
    end
    else begin
        transition_mode<=transition_mode_ns;
    end
end

always @(*) begin
    if(clk_200ms)begin
            transition_mode_ns=1'b1;
        end
    else if(clk_even) begin
            transition_mode_ns=1'b0;
        end
    else begin
            transition_mode_ns=transition_mode;
        end
end


scaling scaling(
    .pixel_in(IM_Q),
    .clk(clk), 
    .trantion_mode(transition_mode), // 0 for before 0.2sec, 1 for after 0.2 sec 
    .process_mode(process_mode),  // 0 -> 128, 1 -> 512
    .enable(|i_mode_start),        //1 work, 0 not work
    .pixel_out(IM_D_Scaling),
    .clk_200ms(clk_200ms)
);

//==========IM_WEN decide==============

always @(*) begin
    case (control_cs)
        2'd1:IM_WEN=IM_WEN_PIC;
        2'd2:IM_WEN=IM_WEN_CR; 
        default: IM_WEN=1'd1;
    endcase
end

//============IM_A decide===============

always @(*) begin
    case (control_cs)
        2'd1:IM_A=IM_A_pic;
        2'd2:IM_A=IM_A_CR; 
        default: IM_A=20'dx;
    endcase    
end
//============IM_D decide================

always @(*) begin
    case (control_cs)
        2'd1:IM_D=(pic_size==3'd2)?IM_D_256:IM_D_Scaling;
        2'd2:IM_D=IM_D_CR;
        default: IM_D=24'dx;
    endcase
end


endmodule

//========== Control_v3 ==========//
`define CS_WIDTH 2

module Control_v3(
    clk,
    reset,
    PIC_Write_Done,
//    CR_Done,
    clk_200ms,
//    clk_odd,
    clk_even,
    PIC_size,
    Control_CS,
    i_mode_start
);

input clk;
input reset;
input PIC_Write_Done;
//input CR_Done;
input clk_200ms;
//input clk_odd;
input clk_even;
input [2:0]PIC_size;

output [`CS_WIDTH-1:0]Control_CS;
output [2:0]i_mode_start;


localparam INITIAL = `CS_WIDTH'd0;
localparam PIC_DRAW = `CS_WIDTH'd1;
localparam CR_DRAW = `CS_WIDTH'd2;

reg [`CS_WIDTH-1:0]Control_CS,Control_NS;
reg [2:0]i_mode_start;

always @(posedge clk or posedge reset) begin
    if(reset)begin
        Control_CS<=INITIAL;
    end
    else begin
        Control_CS<=Control_NS;
    end
end

always @(*) begin
    case(Control_CS)
    INITIAL:begin
        Control_NS=PIC_DRAW;
    end
    PIC_DRAW:begin
        Control_NS=(PIC_Write_Done)?CR_DRAW:Control_CS;
    end
    CR_DRAW:begin
        Control_NS=(clk_even|clk_200ms)?PIC_DRAW:Control_CS;
    end
    default:begin
        Control_NS=INITIAL;
    end
    endcase
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        i_mode_start<=3'd0;
    end
    else begin
        if(Control_CS==PIC_DRAW && |PIC_size==1)begin
            i_mode_start<=PIC_size;
        end
        else begin
            i_mode_start<=3'd0;
        end
    end
end


endmodule


// ========== IM_A ========== //
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

// ========== Clock ========== // 


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

// ========== scaling ========== //

// this module reduce hardware size of old scaling 
// only store two adder result 
// reduce two 24 bit reg 
// modify date 2023 12 10 
module scaling 
(
    input [23:0] pixel_in,
    input clk, 
    input trantion_mode, // 0 for before 0.2sec, 1 for after 0.2 sec 
    input process_mode,  // 0 -> 128, 1 -> 512
    input enable,
    input clk_200ms,
    output reg [23:0] pixel_out
);
    // state machine para 
    localparam INIT = 4'd0;
    localparam RECEIVE_A = 4'd1;
    localparam RECEIVE_B = 4'd2;
    localparam RECEIVE_C = 4'd3;
    localparam RECEIVE_D = 4'd4;
    localparam WB1 = 4'd5;
    // if raw pic is 512 than skip WB1  
    localparam WB2 = 4'd6;
    localparam NOP = 4'd7;
    // transtion mode 
    localparam BEFORE02SEC = 1'b0;
    localparam AFTER02SEC = 1'b1;
    // process mode
    localparam EXPAND = 1'b0;
    localparam COMPRESS = 1'b1;
    // define color 
    `define PIXEL_IN_R pixel_in[23:16]
    `define PIXEL_IN_G pixel_in[15:8] 
    `define PIXEL_IN_B pixel_in[7:0]
    
    // scaling state 
    reg [3:0] scaling_cs, scaling_ns;

    // next 
    reg  [8:0] next_pixel_sum_r, next_pixel_sum_g, next_pixel_sum_b;
    reg  [9:0] next_pixel_sum_r1, next_pixel_sum_g1, next_pixel_sum_b1;
    reg  [8:0] pixel_sum_r, pixel_sum_g, pixel_sum_b;
    reg  [9:0] pixel_sum_r1, pixel_sum_g1, pixel_sum_b1;
    
    reg  [9:0] pixel_addition_r, pixel_addition_g, pixel_addition_b;
    wire [9:0] pixel_addition_sum_r, pixel_addition_sum_g, pixel_addition_sum_b;


    // state transfer 
    always @(posedge clk ) begin
        if (enable == 0) begin 
            scaling_cs <= NOP;
        end
        else if(clk_200ms)begin
            scaling_cs <= WB1;
        end
        else begin 
            scaling_cs <= scaling_ns;
        end
    end

    // next state generator  
    always @(*) begin
        case (scaling_cs)
            NOP:begin
                scaling_ns = INIT;
            end
            INIT : begin 
                scaling_ns = RECEIVE_A ;
            end

            RECEIVE_A: begin 
                scaling_ns = RECEIVE_B ;
            end

            RECEIVE_B: begin 
                scaling_ns = RECEIVE_C ;
            end

            RECEIVE_C : begin 
                scaling_ns = RECEIVE_D ; 
            end

            RECEIVE_D :begin 
                scaling_ns = (process_mode == COMPRESS)?  WB2 : WB1 ;
            end

            WB1 :begin  
                scaling_ns =  WB2 ; 
            end

            WB2 : begin 
                scaling_ns = INIT ;  
            end
        
            default : begin 
                scaling_ns = INIT;
            end
            
        endcase 
    end

    // store data // 
    always @(posedge clk) begin
        case (scaling_cs)
            INIT, NOP : begin 
            // reset all temp pixel
                pixel_sum_r <= 9'd0;
                pixel_sum_g <= 9'd0;
                pixel_sum_b <= 9'd0;
                pixel_sum_r1 <= 10'd0;
                pixel_sum_g1 <= 10'd0;
                pixel_sum_b1 <= 10'd0;
            end

            RECEIVE_A, RECEIVE_B, RECEIVE_C, RECEIVE_D : begin  
            //store next data // 
                pixel_sum_r <= next_pixel_sum_r;
                pixel_sum_g <= next_pixel_sum_g;
                pixel_sum_b <= next_pixel_sum_b;
                pixel_sum_r1 <= next_pixel_sum_r1;
                pixel_sum_g1 <= next_pixel_sum_g1;
                pixel_sum_b1 <= next_pixel_sum_b1;
            end 
        endcase
    end


// adder unit 
    assign pixel_addition_sum_r = pixel_addition_r + `PIXEL_IN_R;
    assign pixel_addition_sum_g = pixel_addition_g + `PIXEL_IN_G;
    assign pixel_addition_sum_b = pixel_addition_b + `PIXEL_IN_B;

// choose pixel_addition_r

    always @(*) begin 
        case (scaling_cs)
            RECEIVE_B : begin // EXPAND_BEFORE02SEC & EXPAND AFTER02SEC & COMPRESS are all A+B
                pixel_addition_r = pixel_sum_r1;
                pixel_addition_g = pixel_sum_g1;
                pixel_addition_b = pixel_sum_b1;
            end

            RECEIVE_C : begin // A+C
                if (process_mode == EXPAND && trantion_mode == BEFORE02SEC) begin 
                    pixel_addition_r = {1'b0,pixel_sum_r};
                    pixel_addition_g = {1'b0,pixel_sum_g};
                    pixel_addition_b = {1'b0,pixel_sum_b};
                end else begin // 
                    pixel_addition_r = pixel_sum_r1;
                    pixel_addition_g = pixel_sum_g1;
                    pixel_addition_b = pixel_sum_b1;
                end
            end

            RECEIVE_D : begin 
                    pixel_addition_r = pixel_sum_r1;
                    pixel_addition_g = pixel_sum_g1;
                    pixel_addition_b = pixel_sum_b1;
            end 

            default : begin 
                pixel_addition_r = 10'dx;
                pixel_addition_g = 10'dx;
                pixel_addition_b = 10'dx;
            end
        endcase
    end
    
// choose next_pixel_sum r g b, next_pixel_sum_r1 g1 b1

    always @(*) begin
        case(scaling_cs)
            RECEIVE_A : begin   // EXPAND & COMPRESS both store A                 
                    next_pixel_sum_r = `PIXEL_IN_R;
                    next_pixel_sum_g = `PIXEL_IN_G; 
                    next_pixel_sum_b = `PIXEL_IN_B;

                    next_pixel_sum_r1 = `PIXEL_IN_R;
                    next_pixel_sum_g1 = `PIXEL_IN_G;
                    next_pixel_sum_b1 = `PIXEL_IN_B;
            end

            RECEIVE_B : begin
                        next_pixel_sum_r = pixel_sum_r;
                        next_pixel_sum_g = pixel_sum_g; 
                        next_pixel_sum_b = pixel_sum_b;

                        next_pixel_sum_r1 = pixel_addition_sum_r;
                        next_pixel_sum_g1 = pixel_addition_sum_g;
                        next_pixel_sum_b1 = pixel_addition_sum_b;
            end

            RECEIVE_C : begin
                    if (trantion_mode == BEFORE02SEC && process_mode == EXPAND)begin 
                        next_pixel_sum_r = pixel_addition_sum_r [8:0];
                        next_pixel_sum_g = pixel_addition_sum_g [8:0];
                        next_pixel_sum_b = pixel_addition_sum_b [8:0];

                        next_pixel_sum_r1 = pixel_sum_r1;
                        next_pixel_sum_g1 = pixel_sum_g1;
                        next_pixel_sum_b1 = pixel_sum_b1;
                    end else begin 
                        next_pixel_sum_r = pixel_sum_r;
                        next_pixel_sum_g = pixel_sum_g; 
                        next_pixel_sum_b = pixel_sum_b;

                        next_pixel_sum_r1 =  pixel_addition_sum_r;
                        next_pixel_sum_g1 =  pixel_addition_sum_g;
                        next_pixel_sum_b1 =  pixel_addition_sum_b;
                    end
            end

            RECEIVE_D : begin                    
                    if (trantion_mode == BEFORE02SEC && process_mode == EXPAND)begin 
                        next_pixel_sum_r = pixel_sum_r;
                        next_pixel_sum_g = pixel_sum_g; 
                        next_pixel_sum_b = pixel_sum_b;

                        next_pixel_sum_r1 = pixel_sum_r1;
                        next_pixel_sum_g1 = pixel_sum_g1;
                        next_pixel_sum_b1 = pixel_sum_b1;
                    end else begin 
                        next_pixel_sum_r = pixel_sum_r;
                        next_pixel_sum_g = pixel_sum_g; 
                        next_pixel_sum_b = pixel_sum_b;

                        next_pixel_sum_r1 =  pixel_addition_sum_r;
                        next_pixel_sum_g1 =  pixel_addition_sum_g;
                        next_pixel_sum_b1 =  pixel_addition_sum_b;
                    end
            end

            default : begin 
                next_pixel_sum_r1 = 10'dx;
                next_pixel_sum_g1 = 10'dx;
                next_pixel_sum_b1 = 10'dx;

                next_pixel_sum_r = 9'dx;
                next_pixel_sum_g = 9'dx;
                next_pixel_sum_b = 9'dx;
            end 

        endcase
    end

// output decoder // 
always @ (*) begin 
    case (scaling_cs) 


    
        WB1 : begin
            if(trantion_mode == BEFORE02SEC) begin  
                pixel_out = {pixel_sum_r[8:1], pixel_sum_g[8:1], pixel_sum_b[8:1]}; // a+b
            end else begin 
                pixel_out = {pixel_sum_r[7:0], pixel_sum_g[7:0], pixel_sum_b[7:0]}; // a
            end
        end

        WB2 : begin 
            if (trantion_mode == BEFORE02SEC && process_mode == EXPAND) begin 
                pixel_out = {pixel_sum_r1[8:1], pixel_sum_g1[8:1], pixel_sum_b1[8:1]}; // a+c /2
            end else begin 
                pixel_out = {pixel_sum_r1[9:2], pixel_sum_g1[9:2], pixel_sum_b1[9:2]}; //a+b+c+d /4
            end
        end
        
        default: begin 
            pixel_out = 24'dx;
        end
    endcase
end

endmodule

// ========== fdiv ========== //

// this module use 1us clock 
// will output 3 different paulse 
// Output 1 paulse every "odd" second 
// Output 1 paulse every "even" seconds( 0 sec will not output paulse).
// Output 1 clock at intervals of 0.2, 2.2, 4.2 seconds, and so on
// state transfer  0 -> 0.2 -> 1 ->2 -> 2.2 -> 0.4 .....
// notice that system clock = 1M (1us)
// 1_000_000 us =1s
// modify state (counter) bit number and pin name
// last modify date 2023/11/23


module fdiv (
    input clk, // 1ns clock input 
    input reset_p,
    output reg clk_odd_sec,
    output reg clk_even_sec,
    output reg clk_even_02sec,
    output reg clk_19
     );

    reg [21:0] cs; 
    wire [21:0] ns;

    always @(posedge clk or posedge reset_p ) begin
        if(reset_p == 1) begin
            cs <= 22'd0;
        end
        else begin
            cs <= ns ;
        end
    end

    assign ns = (cs >= 22'd2_200_000) ? 200_001 : cs + 1; 
// if state >= 2.2 sec state will go back to 0.2 sec , else will + 1


// generate paulse 

    always @(posedge clk) begin
        case (cs)
            22'd 200_000 : begin // 0.2sec generate paulse 
                clk_odd_sec <= 1'b0;
                clk_even_sec <= 1'b0;
                clk_even_02sec <= 1'b1;
                clk_19 <= 1'b0;
            end

            22'd 1_000_000 :begin // odd generate palse 
                clk_odd_sec <= 1'b1;
                clk_even_sec <= 1'b0;
                clk_even_02sec <= 1'b0;
                clk_19 <= 1'b0;
            end 

            22'd 1_999_999 : begin // even generate palse 
                clk_odd_sec <= 1'b0;
                clk_even_sec <= 1'b1;
                clk_even_02sec <= 1'b0;
                clk_19 <= 1'b0;
            end

            22'd 1_900_000 : begin // even generate palse 
                clk_odd_sec <= 1'b0;
                clk_even_sec <= 1'b0;
                clk_even_02sec <= 1'b0;
                clk_19 <= 1'b1;
            end

            22'd 2_200_000 : begin // (2.2sec)
                clk_odd_sec <= 1'b0;
                clk_even_sec <= 1'b0;
                clk_even_02sec <= 1'b1;
                clk_19 <= 1'b0;
            end

            default : begin 
                clk_odd_sec <= 1'b0;
                clk_even_sec <= 1'b0;
                clk_even_02sec <= 1'b0;
                clk_19 <= 1'b0;
            end

        endcase    
    end

endmodule