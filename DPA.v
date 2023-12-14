// DPA module 
// all module include
// last modify date 2023 11 28
// ALL PATTERN PASS

module DPA (clk,reset,IM_A, IM_Q,IM_D,IM_WEN,CR_A,CR_Q,IM_WEN_FB_neg);
input clk;
input reset;
input [23:0] IM_Q;
input [12:0] CR_Q;

output [19:0] IM_A;
output [23:0] IM_D;
output IM_WEN;
output [8:0] CR_A;
output IM_WEN_FB_neg;

reg [19:0]IM_A;
reg [23:0]IM_D;
reg IM_WEN;
reg [23:0]IM_D_cal;

wire clk_200ms,clk_odd,clk_even;
wire [19:0]IM_A_HR,IM_A_pic,IM_A_FB;
wire [23:0]init_time,FB_addr,pic_addr,pic_size;
wire [23:0]IM_D_scaling,IM_D_256,IM_D_CR;
wire IM_WEN_Header,IM_WEN_pic;
wire o_pic_write_done_200ms,o_pic_write_done_400ms,o_clk_write_done_400ms;
wire [2:0]control_cs;
wire [2:0]control_ns;
wire Header_Done;
wire [2:0]i_mode_start;
wire pic_change_flag;
wire clk_19;


Control_v2 Control_v2(
    .clk(clk),
    .reset(reset),
    .Header_Done(Header_Done),
    .Pic_Write_Done(o_pic_write_done_200ms|o_pic_write_done_400ms),
    .CR_Done(o_clk_write_done_400ms),
    .clk_200ms(clk_200ms),
    .clk_odd(clk_odd),
    .clk_even(clk_even),
    .pic_size(pic_size),
    .cs(control_cs),
    .i_mode_start(i_mode_start),
    .clk_19(clk_19)
);

fdiv fdiv(
    .clk(clk), // 1000ns clock input 
    .reset_p(reset),
    .clk_odd_sec(clk_odd),
    .clk_even_sec(clk_even),
    .clk_even_02sec(clk_200ms),
    .clk_19(clk_19) 
    );

assign pic_change_flag=(control_cs==1)?1:clk_even;

IM_A_Header IM_A_Header( 
            .clk(clk),
            .reset(reset),
            .pic_change_flag(pic_change_flag),
            .IM_Q(IM_Q),
            .IM_A_Header(IM_A_HR),
            .IM_WEN_Header(IM_WEN_Header),
            .init_time(init_time),
            .FB_addr(FB_addr),
            .pic_addr(pic_addr),
            .pic_size(pic_size),
            .Header_Done(Header_Done),
            .control_cs(control_cs)
            );

IM_A_module IM_A_module(
	.clk(clk),
	.reset(reset),
	.i_start_2s(clk_even),
	.i_start_200ms(clk_200ms),
	.i_mode_start(i_mode_start),
	.i_pic_init_addr(pic_addr),
	.read_flag(IM_WEN_pic),
	.IM_read_A(IM_A_pic)
);

scaling scaling_module (
    .pixel_in(IM_Q),
    .clk(clk), 
    .i_mode_start(i_mode_start), // 000 , 010 for disable module 100 for compress ,001 for expand 
    .clk_200ms(clk_200ms), //200ms will generate a paulse 
    .pixel_out(IM_D_scaling)
);

assign IM_D_256=IM_Q;

FB_Writer FB_Writer(
	.clk(clk),
	.reset(reset),
	.i_FB_init_addr(FB_addr),
	.i_mode_start(i_mode_start),
	.i_start_1s(clk_odd),
	.i_start_2s(clk_even),
	.i_start_200ms(clk_200ms),
	.o_IM_write_A(IM_A_FB),
	.o_pic_write_done_200ms(o_pic_write_done_200ms),
	.o_pic_write_done_400ms(o_pic_write_done_400ms),
	.o_clk_write_done_400ms(o_clk_write_done_400ms),
    .write_pixel(IM_WEN_FB_neg)
	);


Clock CR(
	.clk(clk),
	.start_200ms(o_pic_write_done_200ms),
	.start_400ms(o_pic_write_done_400ms),
	.start_odd(clk_odd),
	.reset(reset),
	.CR_Q(CR_Q),
	.Init_time(init_time),
	.CR_A(CR_A),
	.CR_Q_Out(IM_D_CR)
);
//==========IM_WEN decide==============
always @(*) begin
    case(control_cs)
    3'd1:IM_WEN=IM_WEN_Header;
    3'd2:IM_WEN=IM_WEN_pic;
    3'd3:IM_WEN=~IM_WEN_FB_neg;
    default:IM_WEN=1'b1;
    endcase
end

//============IM_A decide===============
always @(*) begin
    case(control_cs)
    3'd1,3'd5:IM_A=IM_A_HR;
    3'd2:IM_A=(IM_WEN)?IM_A_pic:IM_A_FB;
    3'd3:IM_A=IM_A_FB;
    default:IM_A=1'b0;
    endcase
end

//============IM_D decide================
always @(*) begin
    case(control_cs)
    3'd2:IM_D=IM_D_cal;
    3'd3:IM_D=IM_D_CR;
    default:IM_D=24'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx;
    endcase
end

always @(*) begin
    case (i_mode_start)
        3'b001,3'b100:begin 
            IM_D_cal=IM_D_scaling;
        end
        3'b010:begin
            IM_D_cal=IM_D_256;
        end
        default: begin
            IM_D_cal=24'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx;
        end
    endcase
end


endmodule





//==========Control_v2==========//

`define CONTROL_CS_WIDTH 3
module Control_v2(
    clk,
    reset,
    Header_Done,
    Pic_Write_Done,
    CR_Done,
    clk_200ms,
    clk_odd,
    clk_even,
    pic_size,
    cs,
    i_mode_start,
    clk_19
);

localparam INITIAL =`CONTROL_CS_WIDTH'd0 ;
localparam HEADER_READ =`CONTROL_CS_WIDTH'd1 ;
localparam PIC_DRAW =`CONTROL_CS_WIDTH'd2 ;
localparam CR_DRAW =`CONTROL_CS_WIDTH'd3 ;
localparam IDLE0 =`CONTROL_CS_WIDTH'd4 ;
localparam IDLE1 =`CONTROL_CS_WIDTH'd5 ;

input clk,reset;
input Header_Done;
input Pic_Write_Done;
input CR_Done;
input clk_200ms,clk_odd,clk_even;
input [23:0]pic_size;
input clk_19;

output [`CONTROL_CS_WIDTH-1:0]cs;
output reg [2:0]i_mode_start;


reg [`CONTROL_CS_WIDTH-1:0]cs,ns;

//=====================state change=============================
always@(posedge clk or posedge reset)begin
    if(reset)begin
        cs<=INITIAL;
    end
    else begin
        cs<=ns;
    end
end

always@(*)begin
    case(cs)
    INITIAL:begin
        ns=HEADER_READ;
    end
    HEADER_READ:begin
        ns=(Header_Done)?PIC_DRAW:HEADER_READ;
    end
    PIC_DRAW:begin
        ns=(Pic_Write_Done)?CR_DRAW:PIC_DRAW;
    end
    CR_DRAW:begin
        ns=(CR_Done)?IDLE0:CR_DRAW;
    end
    IDLE0:begin
        ns= (clk_even)?HEADER_READ: 
            (clk_200ms)?PIC_DRAW:
            (clk_odd)?CR_DRAW:
            (clk_19)?IDLE1:
            IDLE0;
    end
    IDLE1:begin
         ns= (clk_even)?HEADER_READ:IDLE1;
    end
    default:begin
        ns=INITIAL;
    end

    endcase
end

//================================================================

//=======================start set====================================
always @(posedge clk or posedge reset) begin
    if(reset)begin
        i_mode_start<=3'd0;
    end
    else begin
        if(cs==HEADER_READ)begin
            i_mode_start<=pic_size[9:7];
        end
        else if(cs==IDLE1) begin
            i_mode_start<=3'd0;
        end
    end
end


endmodule


//==========IM_A==========//

`define		IM_ADDRSIZE		20
`define		IM_STATE_BIT	3
`define		IM_COUNT_BIT	4



`define		IM_START	1
`define		IM_READ		2
`define		IM_WRITE	3
`define 	IM_WAIT		4
`define 	IM_WAIT2	5
`define		IM_2SEC		6
`define		IM_200mSEC	7



module IM_A_module(
	clk,
	reset,
	i_start_2s,
	i_start_200ms,
	i_mode_start,
	i_pic_init_addr,
	IM_read_A,
	read_flag
);

input clk;
input reset;
input i_start_2s;
input i_start_200ms;
input [2:0] i_mode_start;
input [23:0] i_pic_init_addr;

output reg [`IM_ADDRSIZE - 1:0] IM_read_A;

reg [`IM_STATE_BIT - 1:0] cs, ns;
reg [`IM_COUNT_BIT - 1:0] count;
wire [`IM_COUNT_BIT - 1:0] count_nxt;

output read_flag;
wire read_128;
wire read_512;

wire [`IM_ADDRSIZE - 1:0] IM_read_A_nxt;
reg [`IM_ADDRSIZE - 1:0] IM_shift_read_A;
wire [`IM_ADDRSIZE - 1:0] IM_shift_read_A_nxt;

reg start_2s_reg;
reg start_200ms_reg;
wire start_2s_reg_nxt;
wire start_200ms_reg_nxt;

wire next_round_even;
wire next_round_odd;
wire edge_128_lock;
reg edge_128_free;
wire edge_128_free_nxt;
wire bottom_lock;
wire read_finish;
wire pic_read_done;

//======================================== transitions mode ======================================== 
	always @(posedge clk or posedge reset )begin
		if(reset)begin
			//start_2s_reg<=1'b0;
			start_2s_reg<=1'b1;
			start_200ms_reg<=1'b0;
		end
		else begin
			start_2s_reg<=start_2s_reg_nxt;
			start_200ms_reg<=start_200ms_reg_nxt;
		end
	end

	assign start_2s_reg_nxt = (cs==`IM_2SEC) ? 1'b1 :
							  (cs==`IM_WAIT) ? 1'b0 : 
							  start_2s_reg;
	
	assign start_200ms_reg_nxt = (cs==`IM_200mSEC) ? 1'b1 :
							    (cs==`IM_WAIT) ? 1'b0:
							     start_200ms_reg;
	
	
//======================================== transitions mode ======================================== 




//==================================== FSM ===================================
always @(posedge clk or posedge reset)begin
	if(reset)begin
		cs <= `IM_2SEC;
	end
	else begin
		cs <= ns;
	end
end

always @(*)begin
	case(cs)
		`IM_2SEC	: ns <= (|i_mode_start) ? `IM_START : `IM_2SEC;	
		`IM_200mSEC	: ns <= (|i_mode_start) ? `IM_START : `IM_200mSEC;

		`IM_START	: ns <= `IM_READ;
		`IM_READ	: ns <= (pic_read_done) ? `IM_WAIT:
							(i_mode_start[1]==1'b1) ? `IM_WRITE :
							(i_mode_start[2]==1'b1 && count==`IM_COUNT_BIT'd3) ? `IM_WRITE:
							(i_mode_start[0]==1'b1 && count==`IM_COUNT_BIT'd3) ? `IM_WRITE:
							`IM_READ;
		`IM_WRITE	: ns <= (pic_read_done) ? `IM_WAIT:
							(i_mode_start[1]==1'b1) ? `IM_READ : 
							(i_mode_start[2]==1'b1 && count==`IM_COUNT_BIT'd5) ? `IM_READ:
							(i_mode_start[0]==1'b1 && count==`IM_COUNT_BIT'd6) ? `IM_READ:
							`IM_WRITE;
		`IM_WAIT	: ns <=`IM_WAIT2; 
		`IM_WAIT2	: ns <=(i_start_2s) ? `IM_2SEC : 
								(i_start_200ms) ? `IM_200mSEC:
								`IM_WAIT2;			
		
		default		: ns <= `IM_STATE_BIT'bx;
	endcase
end
//==================================== FSM ===================================

//=============================== FSM  COUNTER ===============================
always @(posedge clk or posedge reset)begin
	if(reset)begin
		count <= `IM_COUNT_BIT'd0;
	end
	else if(~read_finish) begin
		count <= count_nxt;
	end
end


assign read_128 = ((count>=`IM_COUNT_BIT'd0 && count<`IM_COUNT_BIT'd5) && (i_mode_start[0]==1'b1)) ? 1'b1 : 1'b0;
assign read_512 = ((count>=`IM_COUNT_BIT'd0 && count<`IM_COUNT_BIT'd5) && (i_mode_start[2]==1'b1)) ? 1'b1 : 1'b0;


assign count_nxt = (cs==`IM_START) ? `IM_COUNT_BIT'd0:
				   ((count>=`IM_COUNT_BIT'd0 && count<`IM_COUNT_BIT'd5) && (i_mode_start[2]==1'b1)) ? count+`IM_COUNT_BIT'd1:
				   ((count>=`IM_COUNT_BIT'd0 && count<`IM_COUNT_BIT'd6) && (i_mode_start[0]==1'b1)) ? count+`IM_COUNT_BIT'd1:
				   `IM_COUNT_BIT'd0;

assign read_flag = (cs==`IM_2SEC || cs==`IM_200mSEC || cs==`IM_START || cs==`IM_WAIT || cs==`IM_WAIT2) ? 1'b1:
				   ((cs==`IM_READ || cs==`IM_START) && i_mode_start[1]==1'b1) ? 1'b1 : 
				   (read_128) ? 1'b1: 
				   (read_512) ? 1'b1: 
				   1'b0;
//=============================== FSM  COUNTER ===============================

//=============================== IM SHIFT ADDR  =============================
always @(posedge clk or posedge reset)begin
	if(reset)begin
		IM_shift_read_A <= `IM_ADDRSIZE'd0;
		edge_128_free <= 1'b0;
	end
	else if(!read_finish)begin
		IM_shift_read_A <= IM_shift_read_A_nxt;
		edge_128_free <= edge_128_free_nxt;
	end
end

assign IM_shift_read_A_nxt = ((start_2s_reg==1'b1) && cs==`IM_START && i_mode_start[2]==1'b1) ?  `IM_ADDRSIZE'd2:
							 ((start_2s_reg==1'b1) && cs==`IM_START && i_mode_start[0]==1'b1) ?  `IM_ADDRSIZE'd0:
							 
							 
							 ((start_2s_reg==1'b1) && cs==`IM_START && i_mode_start[1]==1'b1) ?  `IM_ADDRSIZE'd1:
							 (start_200ms_reg==1'b1 && i_mode_start[1]==1'b1 && cs==`IM_START) ? `IM_ADDRSIZE'd0:
							 ((start_200ms_reg==1'b1) && cs==`IM_START && i_mode_start[2]==1'b1) ?  `IM_ADDRSIZE'd0:
							 ((start_200ms_reg==1'b1) && cs==`IM_START && i_mode_start[0]==1'b1) ?  `IM_ADDRSIZE'd0:


							 (next_round_even && i_mode_start[1]==1'b1) ? IM_shift_read_A + `IM_ADDRSIZE'd1:
							 (next_round_odd && i_mode_start[1]==1'b1)  ? IM_shift_read_A + `IM_ADDRSIZE'd3:
							 (read_flag==1'b1 && i_mode_start[1]==1'b1 && cs==`IM_READ) ? IM_shift_read_A + `IM_ADDRSIZE'd2:
							 
							 (read_flag==1'b1 && i_mode_start[2]==1'b1 && (count==`IM_COUNT_BIT'd2) && (IM_shift_read_A[10:0]==11'b001_1111_1111)) ? IM_shift_read_A + `IM_ADDRSIZE'd513:
							 (read_flag==1'b1 && i_mode_start[2]==1'b1 && (count==`IM_COUNT_BIT'd2) && (IM_shift_read_A[10:0]==11'b101_1111_1101)) ? IM_shift_read_A + `IM_ADDRSIZE'd517:
							 (read_flag==1'b1 && i_mode_start[2]==1'b1 && (count==`IM_COUNT_BIT'd2) && (IM_shift_read_A[10:0]==11'b001_1111_1101)) ? IM_shift_read_A + `IM_ADDRSIZE'd517:
							 (read_flag==1'b1 && i_mode_start[2]==1'b1 && (count==`IM_COUNT_BIT'd2) && (IM_shift_read_A[10:0]==11'b101_1111_1111)) ? IM_shift_read_A + `IM_ADDRSIZE'd513:
							 (read_flag==1'b1 && i_mode_start[2]==1'b1 && (count==`IM_COUNT_BIT'd0)) ? IM_shift_read_A + `IM_ADDRSIZE'd1:
							 (read_flag==1'b1 && i_mode_start[2]==1'b1 && (count==`IM_COUNT_BIT'd2)) ? IM_shift_read_A + `IM_ADDRSIZE'd3:
							 
							 (read_flag==1'b1 && i_mode_start[0]==1'b1 && (count==`IM_COUNT_BIT'd1) && edge_128_free==1'b1) ? IM_shift_read_A + `IM_ADDRSIZE'd1:
							 (read_flag==1'b1 && i_mode_start[0]==1'b1 && (count==`IM_COUNT_BIT'd0) && edge_128_lock==1'b1) ? IM_shift_read_A:
							 
							 (read_flag==1'b1 && i_mode_start[0]==1'b1 && (count==`IM_COUNT_BIT'd0)) ? IM_shift_read_A + `IM_ADDRSIZE'd1:
							 
							 
							 IM_shift_read_A;
							 
assign next_round_even = (read_flag==1'b1 && (&IM_shift_read_A[7:0]==1'b1)) ? 1'b1 : 1'b0;
assign next_round_odd  = (read_flag==1'b1 && (IM_shift_read_A[7:0]==8'b1111_1110)) ? 1'b1 : 1'b0;

assign edge_128_lock     = (&IM_shift_read_A[6:0]==1'b1);
assign edge_128_free_nxt = (edge_128_lock==1'b1 && count==`IM_ADDRSIZE'd0) ? 1'b1 : 1'b0;

assign bottom_lock = (&IM_shift_read_A[13:7]) ? 1'b1 : 1'b0;

assign read_finish = (cs==`IM_WAIT || cs==`IM_WAIT2) ? 1'b1 : 1'b0;

assign pic_read_done = ((IM_shift_read_A==`IM_ADDRSIZE'd65535 || IM_shift_read_A==`IM_ADDRSIZE'd65534) && cs==`IM_READ && i_mode_start[1]==1'b1) ? 1'b1 : 
					   ((IM_shift_read_A==`IM_ADDRSIZE'd262146 || IM_shift_read_A==`IM_ADDRSIZE'd261626) && cs==`IM_WRITE && i_mode_start[2]==1'b1) ? 1'b1 : 
					   ((IM_shift_read_A==`IM_ADDRSIZE'd16384) && cs==`IM_WRITE && i_mode_start[0]==1'b1) ? 1'b1 : 
					   1'b0;
//=============================== IM SHIFT ADDR  =============================

//================================== IM ADDR  ================================
always @(posedge clk or posedge reset)begin
	if(reset)begin
		IM_read_A <= `IM_ADDRSIZE'd0;
	end
	else begin
		IM_read_A <= IM_read_A_nxt;
	end
end

assign IM_read_A_nxt =(start_2s_reg==1'b1 && cs==`IM_START &&  i_mode_start[1]==1'b1) ? i_pic_init_addr + `IM_ADDRSIZE'd1:
					  (start_2s_reg==1'b1 && cs==`IM_START && i_mode_start[2]==1'b1) ? i_pic_init_addr+`IM_ADDRSIZE'd2:
					  ((start_2s_reg==1'b1 || start_200ms_reg==1'b1) && cs==`IM_START && (i_mode_start[0]==1'b1 ||  i_mode_start[1]==1'b1)) ? i_pic_init_addr:

					  
					  (start_200ms_reg==1'b1 && cs==`IM_START && i_mode_start[2]==1'b1) ? i_pic_init_addr:
					  
					  ((start_2s_reg==1'b1 || start_200ms_reg==1'b1) && (count==`IM_COUNT_BIT'd0 || count==`IM_COUNT_BIT'd2) && i_mode_start[2]==1'b1) ? IM_read_A + `IM_ADDRSIZE'd512:
					  ((start_2s_reg==1'b1 || start_200ms_reg==1'b1) && (count==`IM_COUNT_BIT'd1 || count==`IM_COUNT_BIT'd3) && i_mode_start[2]==1'b1) ? i_pic_init_addr + IM_shift_read_A :
					  (start_2s_reg==1'b1 && cs==`IM_START) ? i_pic_init_addr+`IM_ADDRSIZE'd1:
					  
					  (i_mode_start[0]==1'b1 && bottom_lock==1'b1 && (count==`IM_COUNT_BIT'd0 || count==`IM_COUNT_BIT'd2)) ? IM_read_A :
					  ((start_2s_reg==1'b1 || start_200ms_reg==1'b1) && (count==`IM_COUNT_BIT'd0 || count==`IM_COUNT_BIT'd2) && i_mode_start[0]==1'b1) ? IM_read_A + `IM_ADDRSIZE'd128:
					  ((start_2s_reg==1'b1 || start_200ms_reg==1'b1) && (count==`IM_COUNT_BIT'd1 || count==`IM_COUNT_BIT'd3) && i_mode_start[0]==1'b1) ? i_pic_init_addr + IM_shift_read_A :
					  //IM_read_A;
					  
					 i_pic_init_addr + IM_shift_read_A;
//================================== IM ADDR  ================================

endmodule

//==========FB_Writer==========//

`define			FB_ADDR_LENGTH			20
`define			FB_STATE_BIT			5


`define			FB_START		1
`define			FB_WAIT_0		2
`define			FB_WAIT_1		3
`define			FB_WAIT_2		4
`define			FB_WAIT_3		5
`define			FB_WAIT_4		6
`define			FB_WRITE_0		7		
`define         FB_WAIT_5		17
`define			FB_WRITE_1		8		
`define			FB_PIC_DONE		9	
`define			FB_CR_READ		10
`define			FB_CLK_WAIT		11
`define			FB_W_CLOCK		12		
`define			FB_DONE			13
`define			FB_2SEC			14
`define			FB_200mSEC		15
`define			FB_1SEC			16	



module FB_Writer(
	clk,
	reset,
	i_FB_init_addr,
	i_mode_start,
	i_start_1s,
	i_start_2s,
	i_start_200ms,
	o_IM_write_A,
	o_pic_write_done_200ms,
	o_pic_write_done_400ms,
	o_clk_write_done_400ms,
	write_pixel
	);
	
	input clk;
	input reset;
	input [23:0] i_FB_init_addr;
	input [2:0] i_mode_start;
	input i_start_1s;
	input i_start_2s;
	input i_start_200ms;
	output reg [`FB_ADDR_LENGTH-1:0] o_IM_write_A;
	output reg o_pic_write_done_200ms;	
	output reg o_pic_write_done_400ms;	
	output o_clk_write_done_400ms;		
	wire o_pic_write_done_200ms_nxt;
	wire o_pic_write_done_400ms_nxt;
	
	reg [`FB_STATE_BIT-1:0] cs;
	reg [`FB_STATE_BIT-1:0] ns;
	
	wire [`FB_ADDR_LENGTH-1:0] IM_write_A_nxt;
	reg [`FB_ADDR_LENGTH-1:0] IM_shift_A;
	wire [`FB_ADDR_LENGTH-1:0] IM_shift_A_nxt;
	
	reg first_round;
	wire first_round_nxt;
	reg clk_first_round;
	wire clk_first_round_nxt;
	
	
	reg [3:0] clock_w_count;
	wire [3:0] clock_w_count_nxt;
	reg  clock_counter_en;
	wire clock_counter_en_nxt;
	wire clock_write;
	reg clock_char_w_done;
	wire clock_char_w_done_nxt;
	reg clock_next_round;
	wire clock_next_round_nxt;
	
	wire next_round;
	wire next_round_even;
	wire next_round_odd ;
	wire next_round_128_2s;
	wire next_round_128_200ms;
	
	wire FB_pic_write_done;
	wire FB_o_pic_write_done_400ms;
	wire FB_pic_128_wirte_done;
	
	reg start_2s_reg;
	reg start_200ms_reg;
	reg start_1s_reg;
	wire start_2s_reg_nxt;
	wire start_200s_reg_nxt;
	wire start_1s_reg_nxt;
	//============================================== test ==============================================
	output write_pixel;
	assign write_pixel = (cs==`FB_WRITE_0 || cs==`FB_WRITE_1 || cs==`FB_W_CLOCK) ? 1'b1 : 1'b0;
	//============================================== test ==============================================
	
	//======================================== transitions mode ======================================== 
	always @(posedge clk or posedge reset)begin
		if(reset)begin
			start_2s_reg<=1'b1;
			start_200ms_reg<=1'b0;
			start_1s_reg<=1'b0;
		end
		else begin
			start_2s_reg<=start_2s_reg_nxt;
			start_200ms_reg<=start_200s_reg_nxt;
			start_1s_reg<=start_1s_reg_nxt;
		end
	end
	
	assign start_2s_reg_nxt = (cs==`FB_2SEC) ? 1'b1 :
							  (cs==`FB_DONE) ? 1'b0:
							  start_2s_reg;
	
	assign start_200s_reg_nxt = (cs==`FB_200mSEC) ? 1'b1 :
							    (cs==`FB_DONE) ? 1'b0:
							     start_200ms_reg;
								 
	assign start_1s_reg_nxt = (cs==`FB_1SEC) ? 1'b1 :
							    (cs==`FB_DONE) ? 1'b0:
							     start_1s_reg;
	
	
	//============================================== FSM ============================================== 
	always @(posedge clk or posedge reset)begin
		if(reset)begin
			cs<=`FB_2SEC;
			first_round<=1'b0;
			o_pic_write_done_200ms <=1'b0;
			o_pic_write_done_400ms <= 1'b0;
		end
		else begin
			cs<=ns;
			first_round<=first_round_nxt;
			o_pic_write_done_200ms <= o_pic_write_done_200ms_nxt;
			o_pic_write_done_400ms <= o_pic_write_done_400ms_nxt;
		end
	end
	
	always @(*)begin
		case(cs)
			`FB_2SEC	: ns <= (|i_mode_start) ? `FB_START : `FB_2SEC;	
			`FB_200mSEC	: ns <= (|i_mode_start) ? `FB_START : `FB_200mSEC;
			`FB_1SEC	: ns <= `FB_CLK_WAIT;
			`FB_START   : ns <= (i_mode_start[2]==1'b1 || i_mode_start[0]==1'b1) ? `FB_WAIT_0 : 
						 	    (i_mode_start[1]==1'b1) ? `FB_WAIT_4:
						 	    `FB_START;
			`FB_WAIT_0  : ns <= `FB_WAIT_1;
			`FB_WAIT_1  : ns <= `FB_WAIT_2;
			`FB_WAIT_2  : ns <= `FB_WAIT_3;
			`FB_WAIT_3  : ns <= `FB_WAIT_4;
			`FB_WAIT_4  : ns <= (i_mode_start[1]==1'b1) ? `FB_WRITE_1 : `FB_WRITE_0;
			`FB_WRITE_0 : ns <= (FB_pic_write_done) ? `FB_PIC_DONE :
							    (i_mode_start[2]==1'b1) ? `FB_WAIT_0 : 
								`FB_WRITE_1;
			`FB_WRITE_1 : ns <= (FB_pic_write_done| FB_pic_128_wirte_done)? `FB_PIC_DONE :
							    (i_mode_start[1]==1'b1) ? `FB_WAIT_4 :
								`FB_WAIT_0;
			`FB_PIC_DONE: ns <= `FB_CR_READ;
			`FB_CR_READ : ns <= `FB_CLK_WAIT;
			`FB_CLK_WAIT: ns <= `FB_W_CLOCK;
			`FB_W_CLOCK	: ns <= (o_clk_write_done_400ms) ? `FB_DONE : 
								(clock_write) ? `FB_W_CLOCK:
								`FB_CLK_WAIT;
			`FB_DONE    : ns <= (i_start_2s) ? `FB_2SEC :
								(i_start_200ms) ? `FB_200mSEC:
								(i_start_1s) ? `FB_1SEC:
								`FB_DONE;							    
			default	    : ns <= `FB_2SEC;
		endcase
	end
	
	assign first_round_nxt= (cs==`FB_DONE) ? 1'b0:
							(cs==`FB_WRITE_1 || cs==`FB_WRITE_0) ? 1'b1 : 
						   first_round;
	
	assign FB_pic_write_done=((IM_shift_A==`FB_ADDR_LENGTH'd65279 || IM_shift_A==`FB_ADDR_LENGTH'd65278) && i_mode_start[0]==1'b1) ? 1'b1 :
						     ((IM_shift_A==`FB_ADDR_LENGTH'd65535 || IM_shift_A==`FB_ADDR_LENGTH'd65534) && (i_mode_start[2]==1'b1 || i_mode_start[1]==1'b1)) ? 1'b1 : 
						     1'b0;		

	assign o_pic_write_done_200ms_nxt=(((cs==`FB_WRITE_0||cs==`FB_WRITE_1) && FB_pic_write_done==1'b1 && start_2s_reg==1'b1) ||
											(FB_pic_128_wirte_done==1'b1) && (cs==`FB_WRITE_1)) ? 1'b1 :
									   1'b0;	
	
	assign o_pic_write_done_400ms_nxt=((cs==`FB_WRITE_0||cs==`FB_WRITE_1) && FB_pic_write_done==1'b1 && start_200ms_reg==1'b1) ? 1'b1 : 1'b0;
	
	assign o_clk_write_done_400ms=(cs==`FB_W_CLOCK && IM_shift_A==`FB_ADDR_LENGTH'd65536) ? 1'b1 : 1'b0;	
	
	assign FB_pic_128_wirte_done=((i_mode_start[0]==1'b1) && (IM_shift_A==`FB_ADDR_LENGTH'd65278)) ? 1'b1:1'b0; 
	//============================================== FSM ============================================== 

	//======================================= CLOCK PAINT COUNT =======================================
	always @(posedge clk or posedge reset)begin
		if(reset)begin
			clock_w_count<=4'd1;
		end
		else begin
			clock_w_count<=clock_w_count_nxt;
		end
	end
	
	assign clock_w_count_nxt = (cs==`FB_CR_READ || cs==`FB_CLK_WAIT) ? 4'd1 :
							   ((clock_w_count>=4'd1 && clock_w_count<=4'd12) && (cs==`FB_W_CLOCK)) ? clock_w_count + 4'd1:
							   4'd1;
							   
	assign clock_write = ((clock_w_count>=4'd1 && clock_w_count<=4'd12) && (cs==`FB_W_CLOCK)) ? 1'b1 : 1'b0;
	
	
	//======================================= CLOCK PAINT COUNT =======================================


	//============================================== ADDR SHIFT ============================================== 	
	
	always @(posedge clk or posedge reset)begin
		if(reset)begin
			IM_shift_A<=`FB_ADDR_LENGTH'd0;
			clock_next_round<=1'b0;
			clock_char_w_done<=1'b0;
		end
		else begin
			IM_shift_A<=IM_shift_A_nxt;
			clock_next_round  <= clock_next_round_nxt;
			clock_char_w_done <= clock_char_w_done_nxt;
		end
	end
		  
					  
	assign IM_shift_A_nxt=(cs==`FB_START && start_2s_reg==1'b1 && i_mode_start[0]==1'b1) ? `FB_ADDR_LENGTH'd1:
						  (cs==`FB_START && start_200ms_reg==1'b1 && i_mode_start[0]==1'b1) ? `FB_ADDR_LENGTH'd0:
						  (cs==`FB_START && start_2s_reg==1'b1) ? `FB_ADDR_LENGTH'd1:
						  (cs==`FB_START && start_200ms_reg==1'b1) ? `FB_ADDR_LENGTH'd0:
						  
						  (i_mode_start[0]==1'b1 && cs==`FB_WAIT_3 && first_round==1'b1 && (next_round_128_2s==1'b1 || next_round_128_200ms==1'b1)) ?IM_shift_A + `FB_ADDR_LENGTH'd258 /*{IM_shift_A[`FB_ADDR_LENGTH-1:8]+12'd2, 8'b0000_0001}*/:
						  (i_mode_start[0]==1'b1 && cs==`FB_WAIT_3 && first_round==1'b1) ? IM_shift_A + `FB_ADDR_LENGTH'd2:
						  
 						  (i_mode_start[1]==1'b1 && cs==`FB_WRITE_1 && next_round_even==1'b1) ? IM_shift_A + `FB_ADDR_LENGTH'd1:
						  (i_mode_start[1]==1'b1 && cs==`FB_WRITE_1 && next_round_odd==1'b1) ? IM_shift_A + `FB_ADDR_LENGTH'd3:
						  (i_mode_start[1]==1'b1 && cs==`FB_WRITE_1) ? IM_shift_A + `FB_ADDR_LENGTH'd2:

						  (i_mode_start[2]==1'b1 && cs==`FB_START && first_round==1'b1) ?  `FB_ADDR_LENGTH'd0:
						  (i_mode_start[2]==1'b1 && cs==`FB_WAIT_3 && next_round_even==1'b1 && first_round==1'b1) ? IM_shift_A + `FB_ADDR_LENGTH'd1:
						  (i_mode_start[2]==1'b1 && cs==`FB_WAIT_3 && next_round_odd==1'b1 && first_round==1'b1) ? IM_shift_A + `FB_ADDR_LENGTH'd3:
						  (i_mode_start[2]==1'b1 && cs==`FB_WAIT_3 && first_round==1'b1) ? IM_shift_A + `FB_ADDR_LENGTH'd2:
						  
						  (cs==`FB_WRITE_1 && i_mode_start[1]==1'b1 && FB_pic_write_done==1'b0) ? IM_shift_A + `FB_ADDR_LENGTH'd2:
						 
						  (cs==`FB_PIC_DONE || cs==`FB_1SEC) ? `FB_ADDR_LENGTH'd59544:
						  
						  (clock_char_w_done == 1'b1) ? {IM_shift_A[`FB_ADDR_LENGTH-1:16], 8'b1110_1000, IM_shift_A[7:4], IM_shift_A[3:0]}:
						  
						  (clock_next_round==1'b1) ? {IM_shift_A + `FB_ADDR_LENGTH'd243}:
						  
						  
						  (cs==`FB_CLK_WAIT) ? IM_shift_A + `FB_ADDR_LENGTH'd1:
						  
						  (cs==`FB_W_CLOCK && clock_next_round!=1'b1) ? IM_shift_A + `FB_ADDR_LENGTH'd1:
						  IM_shift_A;
	
	
	
	assign clock_next_round_nxt = (cs==`FB_W_CLOCK &&(IM_shift_A[15:8]>=8'd232 && IM_shift_A[15:8]<=8'd254) &&
							   ((IM_shift_A[7:0]==8'd164) ||
							    (IM_shift_A[7:0]==8'd177) ||
							    (IM_shift_A[7:0]==8'd190) ||
							    (IM_shift_A[7:0]==8'd203) ||
							    (IM_shift_A[7:0]==8'd216) ||
							    (IM_shift_A[7:0]==8'd229) ||
							    (IM_shift_A[7:0]==8'd242) ||
							    (IM_shift_A[7:0]==8'd255)) ) ? 1'b1 : 1'b0;
		
	
	
	assign clock_char_w_done_nxt = (cs==`FB_W_CLOCK && (IM_shift_A[15:7]==9'b1111_1111_1) && 
								   ((IM_shift_A[6:0]==7'd36) ||
								    (IM_shift_A[6:0]==7'd49) ||
							        (IM_shift_A[6:0]==7'd62) ||
							        (IM_shift_A[6:0]==7'd75) ||
							        (IM_shift_A[6:0]==7'd88) ||
							        (IM_shift_A[6:0]==7'd101) ||
							        (IM_shift_A[6:0]==7'd114) ||
							        (IM_shift_A[6:0]==7'd127)) ) ? 1'b1 : 1'b0;
	
	assign next_round_128_2s  = (i_mode_start[0]==1'b1 && IM_shift_A[8:0]==9'b0_1111_1111) ? 1'b1: 1'b0;
	assign next_round_128_200ms  = (i_mode_start[0]==1'b1 && IM_shift_A[8:0]==9'b0_1111_1110) ? 1'b1: 1'b0;
	
	assign next_round_even = (&IM_shift_A[7:0]==1'b1) ? 1'b1 : 1'b0;
    assign next_round_odd  = (IM_shift_A[7:0]==8'b1111_1110) ? 1'b1 : 1'b0;
	
	//============================================== ADDR SHIFT ============================================== 


	//============================================== ADDR IM ============================================== 	
	
	always @(posedge clk or posedge reset)begin
		if(reset)begin
			o_IM_write_A<=`FB_ADDR_LENGTH'd0;
		end
		else begin
			o_IM_write_A<=IM_write_A_nxt;
		end
	end
	
	assign IM_write_A_nxt = (cs==`FB_START && start_2s_reg==1'b1) ? i_FB_init_addr+`FB_ADDR_LENGTH'd1:
							(cs==`FB_PIC_DONE || cs==`FB_1SEC) ? i_FB_init_addr+`FB_ADDR_LENGTH'd59544:
							(cs==`FB_WRITE_0 && start_2s_reg==1'b1) ? o_IM_write_A+`FB_ADDR_LENGTH'd255:
							(cs==`FB_WRITE_0 && start_200ms_reg==1'b1) ? o_IM_write_A+`FB_ADDR_LENGTH'd257:
							i_FB_init_addr+IM_shift_A;
	//============================================== ADDR IM ============================================== 	

	
endmodule 





//==========Clock==========//


module Clock(
	clk,
	//Mode,
	start_200ms,
	start_400ms,
	start_odd,
	reset,
	CR_Q,
	Init_time,
	CR_A,
	CR_Q_Out
);

parameter DATASIZE = 24;
parameter CR_ADDRSIZE = 9;
parameter CR_DATASIZE = 13;
parameter TIMESIZE = 8;
parameter BCDSIZE = 4;
parameter STATE = 4;
parameter COUNT = 6;

parameter RST_STATE = 4'd0;
parameter WAIT_STATE = 4'd2;
parameter EMPTY_STATE = 4'd3;
parameter READ_STATE = 4'd4;
parameter WRT_STATE = 4'd5;


//----------------------------------------------------------------

input clk;
input start_200ms;
input start_400ms;
input start_odd;
input reset;
input [CR_DATASIZE - 1:0] CR_Q;
input [DATASIZE - 1:0] Init_time;	

output [CR_ADDRSIZE - 1:0] CR_A;
output [DATASIZE - 1:0] CR_Q_Out;
reg Complete;


reg [CR_ADDRSIZE - 1:0] CR_A, nx_CR_A;
reg [DATASIZE - 1:0] CR_Q_Out, nx_CR_Q_Out;
reg [COUNT - 1:0] CR_Q_count, nx_CR_Q_count;									
reg [TIMESIZE - 1:0] hours, nx_hours;				  
reg [TIMESIZE - 1:0] minutes, nx_minutes;			
reg [TIMESIZE - 1:0] seconds, nx_seconds;													
reg [COUNT - 1:0] count_num, nx_count_num;       	
reg [COUNT - 1:0] count_data, nx_count_data;    		
reg [STATE - 1:0] cs, ns;
reg [BCDSIZE - 1:0] write_num;							
reg [CR_ADDRSIZE - 1:0] Init_CR_A;	

wire [BCDSIZE - 1:0] BCD_Sec[0:1], BCD_Min[0:1], BCD_Hor[0:1]; 	  	
wire nx_Complete;
wire start;
	
always @(posedge clk or posedge reset)
	if(reset == 1'd1) begin
		CR_A <= 8'bxxxx_xxxx;
		cs <= 4'd0;
		CR_Q_Out <= 24'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx;
		hours <= 8'bxxxx_xxxx;
		minutes <= 8'bxxxx_xxxx;
		seconds <= 8'bxxxx_xxxx;
		count_num <= 6'd0;
		count_data <= 6'bxxxx_xx;
		Complete <= 1'bx;
		CR_Q_count <= 6'bxxxx_xx;
	end
	else begin 
		CR_A <= nx_CR_A;
		cs <= ns;
		CR_Q_Out <= nx_CR_Q_Out;
		hours <= nx_hours;
		minutes <= nx_minutes;
		seconds <= nx_seconds;
		count_num <= nx_count_num;
		count_data <= nx_count_data;
		Complete <= nx_Complete;
		CR_Q_count <= nx_CR_Q_count;
	end
//--------------------------------Complete Condition------------------------------

assign nx_Complete = (count_num == 6'd7 && count_data == 6'd24 && CR_Q_count == 6'd2)? 1'd1 : 1'd0;	//44444

//-----------------------------------Start----------------------------------------

assign start = start_400ms | start_200ms | start_odd;

//-------------------------------FSM-----------------------------------------------

always @(*)												
	case(cs)				
		RST_STATE : ns = (start)? EMPTY_STATE : cs;			//|Mode						 		
		WAIT_STATE : ns = (start)? EMPTY_STATE : cs;		//|Mode
		EMPTY_STATE : ns = READ_STATE;
		READ_STATE : ns = WRT_STATE;						
		WRT_STATE : ns = (Complete == 1'd1)? WAIT_STATE : 	
						((CR_Q_count == 6'd1)? //4444
						READ_STATE : 
						cs);								
		default ns = cs;
	endcase

//---------------------------CR_A & CR_Q Output-------------------------------------

always @(*)									
	case(cs)
		EMPTY_STATE : nx_CR_A = Init_CR_A;
		WRT_STATE : nx_CR_A = (CR_Q_count == 6'd1)? ((count_data == 9'd24)? //4444
								Init_CR_A : 
								CR_A + 9'd1) : 
								CR_A;
		default nx_CR_A = CR_A;
	endcase
	
	
always @(*)
	case(cs)
		READ_STATE : nx_CR_Q_Out = (CR_Q[12] == 1'd1)?  24'hffffff : 24'h000000; 
		WRT_STATE : nx_CR_Q_Out = (CR_Q[CR_Q_count-6'd2] == 1'd1)? 24'hffffff : 24'h000000;//4444
		default nx_CR_Q_Out = CR_Q_Out;
	endcase

//------------------------------3 Counter------------------------------------------
	
always @(*)
	case(cs)
		RST_STATE : nx_CR_Q_count = 6'd14;
		READ_STATE : nx_CR_Q_count = 6'd13;
		WRT_STATE : nx_CR_Q_count = CR_Q_count - 6'd1;
		default nx_CR_Q_count = CR_Q_count;
	endcase
	
always @(*)		
	case(cs)
		RST_STATE : nx_count_num = 6'd0;							
		WRT_STATE : nx_count_num = ((count_data == 6'd24 && CR_Q_count == 6'd2)? ((count_num == 6'd7)? //4444
									6'd0 : 
									count_num + 6'd1) : 
									count_num);
		default nx_count_num = count_num;
	endcase
	
always @(*)		
	case(cs)
		RST_STATE : nx_count_data = 6'd0;												
		READ_STATE : nx_count_data = (count_data == 6'd24)? 6'd1 : count_data + 6'd1;	
		default nx_count_data = count_data;
	endcase	
	
//--------------------------Get Init_CR_A------------------------------------
	
always @(*)								
	case(count_num + 6'd1)
		6'd1 : write_num = BCD_Hor[1];
		6'd2 : write_num = BCD_Hor[0];
		6'd3 : write_num = 4'd10;		//colon
		6'd4 : write_num = BCD_Min[1];
		6'd5 : write_num = BCD_Min[0];
		6'd6 : write_num = 4'd10;		//colon
		6'd7 : write_num = BCD_Sec[1];
		6'd8 : write_num = BCD_Sec[0];
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
	
always @(*)
	case(cs)
		RST_STATE : nx_hours = Init_time[23:16];
		WAIT_STATE : nx_hours = (start && (start_400ms == 1'b0))? ((seconds == 8'd59)? 
								((minutes == 8'd59)? 
								((hours == 8'd23)? 8'd0 
								: hours + 8'd1) : 
								hours) : hours) : 
								hours;
		default nx_hours = hours;
	endcase
	
always @(*)
	case(cs)
		RST_STATE : nx_minutes = Init_time[15:8];
		WAIT_STATE : nx_minutes = (start && (start_400ms == 1'b0))? ((seconds == 8'd59)? 
									((minutes == 8'd59)? 8'd0 : 
									minutes + 8'd1) : 
									minutes) : 
									minutes;
		default nx_minutes = minutes;
	endcase
	
always @(*)
	case(cs)
		RST_STATE : nx_seconds = Init_time[7:0];
		WAIT_STATE : nx_seconds = (start && (start_400ms == 1'b0))? ((seconds == 8'd59)? 
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

module btobcd_6bit (
    input [7:0] raw_num,
    output reg [3:0] bcd_ten,
    output [3:0] bcd_one
);
    wire less_than_10, less_than_20, less_than_30, less_than_40, less_than_50, less_than_60;
    wire [5:0] bcd_ten_flag;

    assign less_than_10 = (raw_num < 8'd10) ? 1:0;
    assign less_than_20 = (raw_num < 8'd20) ? 1:0;
    assign less_than_30 = (raw_num < 8'd30) ? 1:0;
    assign less_than_40 = (raw_num < 8'd40) ? 1:0;
    assign less_than_50 = (raw_num < 8'd50) ? 1:0;
    assign less_than_60 = (raw_num < 8'd60) ? 1:0;

    assign bcd_ten_flag = {less_than_60, less_than_50, less_than_40, less_than_30, less_than_20, less_than_10};

    always @ (*) begin 
        casex (bcd_ten_flag)
            6'bxxxxx1: begin
                bcd_ten = 4'd0;
            end
            6'bxxxx1x: begin
                bcd_ten = 4'd1;
            end
            6'bxxx1xx: begin 
                bcd_ten = 4'd2;
            end
            6'bxx1xxx : begin 
                bcd_ten = 4'd3;
            end
            6'bx1xxxx : begin 
                bcd_ten = 4'd4;
            end
            6'b1xxxxx : begin 
                bcd_ten = 4'd5;
            end 
            default: begin 
                bcd_ten = 4'dx;
            end

        endcase 
    end 

    assign  bcd_one = raw_num - bcd_ten * 10 ;

endmodule


//-----------------------------------------------//

module btobcd_6bit_hour (
    input [7:0] raw_num,
    output reg [3:0] bcd_ten,
    output [3:0] bcd_one
);
    wire less_than_10, less_than_20, less_than_30;
    wire [2:0] bcd_ten_flag;

    assign less_than_10 = (raw_num < 8'd10) ? 1:0;
    assign less_than_20 = (raw_num < 8'd20) ? 1:0;
    assign less_than_30 = (raw_num < 8'd30) ? 1:0;
 
    assign bcd_ten_flag = {less_than_30, less_than_20, less_than_10};

    always @ (*) begin 
        casex (bcd_ten_flag)
            3'bxx1: begin
                bcd_ten = 4'd0;
            end
            3'bx1x: begin
                bcd_ten = 4'd1;
            end
            3'b1xx: begin 
                bcd_ten = 4'd2;
            end
            default: begin 
                bcd_ten = 4'dx;
            end

        endcase 
    end 

    assign  bcd_one = raw_num - bcd_ten * 10 ;

endmodule

//==========fdiv==========//



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



//==========IM_A_Header==========//


`define HEADER_CS_WIDTH 4
`define HEADER_IM_A_WIDTH 20
`define HEADER_IM_D_WIDTH 24
module IM_A_Header( clk,
                    reset,
                    pic_change_flag,
                    IM_Q,
                    IM_A_Header,
                    IM_WEN_Header,
                    init_time,
                    FB_addr,
                    pic_addr,
                    pic_size,
                    Header_Done,
                    control_cs
                    );

localparam RESET = `HEADER_CS_WIDTH'd0;
localparam READ_INIT_TIME =`HEADER_CS_WIDTH'd1 ;
localparam READ_FB_ADDR =`HEADER_CS_WIDTH'd2 ;
localparam READ_PHOTO_NUM =`HEADER_CS_WIDTH'd3 ;
localparam PIC_CHANGE_DECIDE =`HEADER_CS_WIDTH'd4 ;
localparam READ_PIC_ADDR =`HEADER_CS_WIDTH'd5 ;
localparam READ_PIC_SIZE =`HEADER_CS_WIDTH'd6 ;
localparam IDLE0 =`HEADER_CS_WIDTH'd7 ;

input clk,reset;
input pic_change_flag;
input [`HEADER_IM_D_WIDTH-1:0]IM_Q;
input [2:0]control_cs;
output reg [`HEADER_IM_A_WIDTH-1:0]IM_A_Header;
output IM_WEN_Header;
output reg [`HEADER_IM_D_WIDTH-1:0]init_time,FB_addr,pic_addr,pic_size;
output reg Header_Done;

reg [`HEADER_IM_D_WIDTH-1:0]Photo_num;
reg [`HEADER_CS_WIDTH-1:0]cs,ns;

//=================================state change================================

always@(posedge clk or posedge reset)
begin
    if(reset)
    begin
        cs<=RESET;
    end
    else
    begin
        cs<=ns;
    end
end

always@(*)
begin
    case(cs)
    RESET:begin
        ns=READ_INIT_TIME;
    end
    READ_INIT_TIME:begin
        ns=READ_FB_ADDR;
    end
    READ_FB_ADDR:begin
        ns=READ_PHOTO_NUM;
    end
    READ_PHOTO_NUM:begin
        ns=PIC_CHANGE_DECIDE;
    end
    PIC_CHANGE_DECIDE:begin
        ns=(pic_change_flag)?READ_PIC_ADDR:PIC_CHANGE_DECIDE;
    end
    READ_PIC_ADDR:begin
        ns=READ_PIC_SIZE;
    end
    READ_PIC_SIZE:begin
        ns=IDLE0;
    end
    IDLE0:begin
        ns=PIC_CHANGE_DECIDE;
    end
    default:begin
        ns=RESET;
    end
    endcase
end

//=============================================================================

//============================IM_WEN set=======================================

assign IM_WEN_Header=1;

//=============================================================================

//=================================IR_Q_Receive================================

always @(posedge clk or posedge reset) begin
    if(reset)begin
        init_time<=0;
        FB_addr<=0;
        Photo_num<=0;
        pic_addr<=0;
        pic_size<=0;
    end
    else begin
        case (cs)
        READ_INIT_TIME:begin     
            init_time<=IM_Q;
        end 
        READ_FB_ADDR:begin
            FB_addr<=IM_Q;
        end
        READ_PHOTO_NUM:begin
            Photo_num<=IM_Q;
        end
        PIC_CHANGE_DECIDE:begin
            pic_size<=(control_cs==5)?24'd0:pic_size; 
        end
        READ_PIC_ADDR:begin
            pic_addr<=IM_Q;
        end
        READ_PIC_SIZE:begin
            pic_size<=IM_Q;
        end
        // IDLE0:begin
        //     pic_size<=24'd0;        //fix flag
        // end
        endcase
    end
end


//=============================================================================

//================================IM_A_Header==================================

reg [`HEADER_IM_A_WIDTH-1:0] IM_A_Header_ns;
wire [`HEADER_IM_A_WIDTH-1:0]Target_IM_A;
always @(posedge clk or posedge reset) begin
    if(reset)begin
        IM_A_Header<=0;
    end
    else begin
        IM_A_Header<=IM_A_Header_ns;
    end
end

always @(*) begin
    case (cs)
        RESET,READ_INIT_TIME,READ_FB_ADDR:begin
            IM_A_Header_ns=IM_A_Header+`HEADER_IM_A_WIDTH'd1;
        end 
        
        PIC_CHANGE_DECIDE:begin
            IM_A_Header_ns=(pic_change_flag)?IM_A_Header+`HEADER_IM_A_WIDTH'd1:IM_A_Header;
        end

        READ_PIC_ADDR:begin
            IM_A_Header_ns=(IM_A_Header==Target_IM_A)?`HEADER_IM_A_WIDTH'd3:(IM_A_Header+`HEADER_IM_A_WIDTH'd1);
        end 
        default:begin
            IM_A_Header_ns=IM_A_Header;
        end
    endcase
end

assign Target_IM_A=(Photo_num<<1)+`HEADER_IM_A_WIDTH'd2;

//=============================================================================

//======================Header_Done set========================================
always @(posedge clk or posedge reset) begin
    if(reset)begin
        Header_Done<=0;
    end
    else if(cs==READ_PIC_SIZE)begin
        Header_Done<=1;
    end
    else begin
        Header_Done<=0;
    end
end

endmodule


//==========scaling==========//


// This module combine compress and expand  to one module 
// reduce 2 state machine 
// build on 2023 / 11 / 25

module scaling (
    input [23:0] pixel_in,
    input clk, 
    input [2:0] i_mode_start, // 000 , 010 for disable module 100 for compress ,001 for expand 
    input clk_200ms, //200ms will generate a paulse 
    output reg [23:0] pixel_out
);

    // initial state 
    localparam INIT = 4'd0;
    localparam NOP1 = 4'd1;
    localparam NOP2 = 4'd2;
    // receive state 
    localparam RECEIVE_A = 4'd3;
    localparam RECEIVE_B = 4'd4;
    localparam RECEIVE_C = 4'd5;
    localparam RECEIVE_D = 4'd6;
    // pixel out 
    localparam WB1 = 4'd7; 
    localparam WB2 = 4'd8; 
    // nop state 
    localparam NOP = 4'd9;

    // check i_mode_start 
    localparam COMPRESS = 3'b100;  
    localparam EXPAND = 3'b001;

    localparam  BEFORE02SEC = 1'b0;

    // define color 
    `define PIXEL_IN_R pixel_in[23:16]
    `define PIXEL_IN_G pixel_in[15:8]
    `define PIXEL_IN_B pixel_in[7:0]

    // before 0.2sec of after 0.2 sec
    reg mode; 
    wire next_mode;
    
    wire enable; 

    reg [3:0] cs,ns;

    // temp pixel r g b 
    reg [7:0] a_temp_r, a_temp_g, a_temp_b;
    reg [7:0] b_temp_r, b_temp_g, b_temp_b;
    reg [7:0] c_temp_r, c_temp_g, c_temp_b;
    reg [7:0] d_temp_r, d_temp_g, d_temp_b;

    reg [9:0] temp_r_out, temp_g_out, temp_b_out;

    //check enable 
    assign enable = (i_mode_start == COMPRESS || i_mode_start == EXPAND) ? 1 : 0; 

    // lock before 200ms and after 200ms 
    assign next_mode = (clk_200ms) ? ~mode : mode;

    // next state 
    always @(posedge clk ) begin
        // enable s
        if (enable == 0) begin 
            cs <= INIT;
            mode <= BEFORE02SEC;
        end
        // clk_200 ms come go to initil state
        else if (clk_200ms)begin 
            cs <= INIT;
            mode <= next_mode;
        end
        // 
        else begin 
            cs <= ns;
            mode <= next_mode;
        end
    end

    // state transfer 
    always @(*) begin
        case (cs)
            INIT : begin 
                ns = (enable) ? NOP1 : INIT;
            end

            NOP1 : begin 
                ns = (enable) ? NOP2 : INIT;
            end

            NOP2 : begin 
                ns = (enable) ? RECEIVE_A : INIT;
            end

            RECEIVE_A: begin 
                ns = (enable) ? RECEIVE_B :INIT;
            end

            RECEIVE_B: begin 
                ns = (enable) ? RECEIVE_C : INIT;
            end

            RECEIVE_C : begin 
                ns = (enable) ? RECEIVE_D :INIT ; 
            end

            RECEIVE_D :begin 
                ns = (enable) ? (i_mode_start == COMPRESS)?  WB2 : WB1 
                            :INIT;
            end

            WB1 :begin  
                ns = (enable) ? WB2 : INIT; 
            end

            WB2 : begin 
                ns = (enable) ? NOP : INIT;
            end
            
            NOP : begin 
                ns = (enable) ? RECEIVE_A: INIT ;
            end

            default : begin 
                ns = INIT;
            end
            
        endcase 
    end

// lock data
    always @(posedge clk ) begin
        case (cs)
            INIT : begin // reset all temp pixel
                a_temp_r <= 8'd0;
                a_temp_g <= 8'd0;
                a_temp_b <= 8'd0;

                b_temp_r <= 8'd0;
                b_temp_g <= 8'd0;
                b_temp_b <= 8'd0;

                c_temp_r <= 8'd0;
                c_temp_g <= 8'd0;
                c_temp_b <= 8'd0;

                d_temp_r <= 8'd0;
                d_temp_g <= 8'd0;
                d_temp_b <= 8'd0;
            end

            RECEIVE_A : begin  
                a_temp_r <= `PIXEL_IN_R;
                a_temp_g <= `PIXEL_IN_G;
                a_temp_b <= `PIXEL_IN_B;
            end 

            RECEIVE_B : begin 
                b_temp_r <= `PIXEL_IN_R;
                b_temp_g <= `PIXEL_IN_G;
                b_temp_b <= `PIXEL_IN_B;
            end

            RECEIVE_C : begin
                c_temp_r <= `PIXEL_IN_R;
                c_temp_g <= `PIXEL_IN_G;
                c_temp_b <= `PIXEL_IN_B;
            end

            RECEIVE_D : begin 
                d_temp_r <= `PIXEL_IN_R;
                d_temp_g <= `PIXEL_IN_G;
                d_temp_b <= `PIXEL_IN_B;
            end
        endcase
    end



    always @(*) begin
        case(cs)
            WB1 : begin 
                if (mode == BEFORE02SEC) begin  //divide by 2 
                    temp_r_out = a_temp_r + c_temp_r;
                    temp_b_out = a_temp_b + c_temp_b;
                    temp_g_out = a_temp_g + c_temp_g;
                    pixel_out = {temp_r_out [8:1], temp_g_out [8:1], temp_b_out[8:1]};   
                end
                else begin 
                    pixel_out = {a_temp_r, a_temp_g, a_temp_b};
                end
            end
            WB2: begin 
                if (mode == BEFORE02SEC && i_mode_start == EXPAND) begin  //divide by 2 
                    temp_r_out = a_temp_r + b_temp_r;
                    temp_b_out = a_temp_b + b_temp_b;
                    temp_g_out = a_temp_g + b_temp_g;
                    pixel_out = {temp_r_out [8:1], temp_g_out [8:1], temp_b_out[8:1]};   
                end
                else begin 
                    temp_r_out = a_temp_r + b_temp_r + c_temp_r + d_temp_r ;
                    temp_b_out = a_temp_b + b_temp_b + c_temp_b + d_temp_b ;
                    temp_g_out = a_temp_g + b_temp_g + c_temp_g + d_temp_g ;
                    pixel_out =  {temp_r_out [9:2], temp_g_out [9:2], temp_b_out[9:2]};
                end
            end

            default : begin 
                pixel_out = 24'd0;
            end

        endcase
    end
endmodule



//^^^^^^^^^^ALL MODULE^^^^^^^^^^//