`include "Control_v3.v"
`include "IM_A.v"
`include "Clock.v"
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
