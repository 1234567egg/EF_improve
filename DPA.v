////////////////////////////////////////////////////////////////////////////////
// File: DPA.v
// Author: 
// Date: 2023-12-16 03:31
// Version: 1.0
// Description: Brief description of your Verilog module or design.
//
// Updates:
// - 2023-12-16 03:31 -[name]
// - Description of the update.
////////////////////////////////////////////////////////////////////////////////
 
`include "Control_v4.v"
`include "IM_A_GEN.v"
`include "clock.v"
`include "scaling.v"
`include "fdiv.v"

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

wire [19:0]IM_A;
reg [23:0]IM_D;


//wire [19:0]IM_A_pic,IM_A_CR;

wire [23:0]init_time;

wire [19:0]FB_addr,PIC_addr;

wire [2:0]pic_size,photo_num;

wire [23:0]IM_D_CR,IM_D_Scaling;

//reg  [23:0]IM_D_Result;

wire IM_WEN;

wire CR_Done,Pixel_Done;

wire o_pic_write_done_200ms,o_pic_write_done_400ms;

wire [3:0]control_cs;

wire [1:0]control_ns;

//=============================temp=======================================

//wire process_mode;

reg transition_mode,transition_mode_ns;

reg Scaling_Enable,Scaling_Enable_CS;
//========================================================================


Control_v4 Control_v4(
    .clk(clk),
    .reset(reset),
    .PIC_Write_Done(o_pic_write_done_200ms|o_pic_write_done_400ms),
    .CR_Done(CR_Done),
    .clk_200ms(clk_200ms),
    .clk_odd(clk_odd),
    .clk_even(clk_even),
    .clk_19(clk_19),
    .IM_Q(IM_Q),
    .Control_CS(control_cs),
    .PIC_size(pic_size),
    .PIC_addr(PIC_addr),
    .FB_addr(FB_addr),
    .INIT_time(init_time),
    .PIC_num(photo_num)
);

fdiv fdiv(
    .clk(clk), // 1000ns clock input 
    .reset_p(reset),
    .clk_odd_sec(clk_odd),
    .clk_even_sec(clk_even),
    .clk_even_02sec(clk_200ms),
    .clk_19(clk_19) 
    );

IM_A_GEN IM_A_module(
    .clk(clk),
	.reset(reset),
	.i_1SEC(clk_odd),
	.i_200mSEC(clk_200ms),
	.i_2SEC(clk_even),
    .i_pic_num(photo_num),
	.i_pic_mode(pic_size),
	.i_pic_init_addr(PIC_addr),
	.i_FB_init_addr(FB_addr),
	.o_IM_WEN(IM_WEN),
	.o_IM_A(IM_A),
	.o_pic_done_2sec(o_pic_write_done_200ms),      // 	o_pic_done_2sec,		//DRAW Done before 0.2s
    .o_pic_done_200msec(o_pic_write_done_400ms),   // 	o_pic_done_200msec		//DRAW Done after 0.2s
    .clk_write_done(CR_Done)	
);

//  clk,
// 	reset,
// 	i_1SEC,
// 	i_200mSEC,
// 	i_2SEC,
// 	i_pic_mode,
// 	i_pic_num,
// 	i_pic_init_addr,
// 	i_FB_init_addr,
// 	o_pic_done,
// 	o_IM_WEN,
// 	o_IM_A,


//assign IM_D_256=IM_Q;

Clock Clock(
	.clk(clk),
	//Mode,
	.start_200ms(o_pic_write_done_200ms),
	.start_400ms(o_pic_write_done_400ms),
	.start_odd(clk_odd),
	.reset(reset),
	.CR_Q(CR_Q),
	.Init_time(init_time),
	.CR_A(CR_A),
	.CR_Q_Out(IM_D_CR)
);

// assign process_mode=(pic_size[0])?1'b0:
//                     (pic_size[2])?1'b1:1'bx;

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


scaling scaling 
(
    .pixel_in(IM_Q),
    .clk(clk), 
    .trantion_mode(transition_mode), // 0 for before 0.2sec, 1 for after 0.2 sec 
    .process_mode(pic_size),  // 001 for 128, 010 for 256, 100 for 512
    .enable(Scaling_Enable_CS),
    //input clk_200ms,  // clk_200ms reset siginal 
    .pixel_out(IM_D_Scaling)
);

//     input      [23:0] pixel_in,
//     input             clk, 
//     input             trantion_mode, // 0 for before 0.2sec, 1 for after 0.2 sec 
//     input       [2:0] process_mode,  // 001 for 128, 010 for 256, 100 for 512
//     input             enable,
//     //input clk_200ms,  // clk_200ms reset siginal 
//     output reg [23:0] pixel_out

//==========IM_WEN decide==============


//============IM_A decide===============


//============IM_D decide================

always @(*) begin
    case (control_cs)
        4'd5:IM_D=IM_D_Scaling;
        4'd6:IM_D=IM_D_CR;
        default: IM_D=24'dx;
    endcase
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        Scaling_Enable_CS<=1'b0;
    end
    else begin
        Scaling_Enable_CS<=Scaling_Enable;
    end
end

always @(*) begin
    if(control_cs==4'd5)begin
        Scaling_Enable=|pic_size;
    end
    else begin
        Scaling_Enable=1'b0;
    end
end


endmodule
