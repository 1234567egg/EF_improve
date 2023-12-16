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
parameter WAIT_STATE_1sec = 4'd6;

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

assign start = start_400ms | start_200ms ;

//-------------------------------FSM-----------------------------------------------

always @(*)												
	case(cs)				
		RST_STATE : ns = (start)? EMPTY_STATE : cs;			//|Mode						 		
		WAIT_STATE : ns = (start_odd)? WAIT_STATE_1sec : 
						  (start) ? EMPTY_STATE : cs;		//|Mode
		WAIT_STATE_1sec : ns = EMPTY_STATE;
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
		WAIT_STATE : nx_hours = ((start | start_odd) && (start_400ms == 1'b0))? ((seconds == 8'd59)? 
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
		WAIT_STATE : nx_minutes = ((start | start_odd) && (start_400ms == 1'b0))? ((seconds == 8'd59)? 
									((minutes == 8'd59)? 8'd0 : 
									minutes + 8'd1) : 
									minutes) : 
									minutes;
		default nx_minutes = minutes;
	endcase
	
always @(*)
	case(cs)
		RST_STATE : nx_seconds = Init_time[7:0];
		WAIT_STATE : nx_seconds = ((start | start_odd) && (start_400ms == 1'b0))? ((seconds == 8'd59)? 
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