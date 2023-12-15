////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/* 	2023.12.14																								  
	header, 128x128, 256x256 pixel read and frame buffer write.						  
	2023.12.14													
	header, 128x128, 256x256, 512x512 pic read and pic write(before 0.2sec)
	2023.12.15
	select first and add.
	first char first row is OK.
	2023.12.15
	read, write 128x128, 256x256, 512x512 and clock.


 
*/																											  
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`define		STATE_BIT			4
`define		STATE_COUNT_BIT		5
`define		IM_A_LENGTH			20
`define		IM_A_2D_SIZE		9		//IM_A row, column all 9 bits.


`define		IM_1SEC			0
`define		IM_2SEC			1			
`define		IM_200mSEC		2
`define		IM_HEADER		3	//read header(include first pic addr, pic size).
`define		IM_START		4	//get initial pic addr
`define		IM_R_PIXEL		5	//read image memory pic
`define		IM_W_PIXEL		6	//write FB pic
`define		IM_PIC_DONE		7	//pic write done, clock not.	
`define		IM_R_CLK		8	//read charom	
`define		IM_W_CLK		9	//write FB clock
`define		IM_CLK_DONE		10  //pic and clock write done.
`define		IM_R_PIC		11	//read next pic addr, size.	
`define		IM_MODE_CHECK	12



module IM_A_GEN(
	clk,
	reset,
	i_1SEC,
	i_200mSEC,
	i_2SEC,
	i_pic_mode,
	i_pic_init_addr,
	i_FB_init_addr,
	o_IM_WEN,
	o_IM_A,
	o_pic_done_2sec,		//DRAW Done before 0.2s
	o_pic_done_200msec,		//DRAW Done after 0.2s
	clk_write_done
	//o_test_out
);

	input clk;
	input reset;
	input i_1SEC;
	input i_200mSEC;
	input i_2SEC;
	input [2:0] i_pic_mode;
	input [`IM_A_LENGTH-1:0] i_pic_init_addr;
	input [`IM_A_LENGTH-1:0] i_FB_init_addr;
	output o_IM_WEN;
	output reg [`IM_A_LENGTH-1:0] o_IM_A;
	
	output o_pic_done_2sec;
	output o_pic_done_200msec;
	output clk_write_done;
	//output o_test_out;
	
	
	
	reg  [`IM_A_LENGTH-1:0] o_IM_A_nxt;
	reg  [`IM_A_LENGTH-1:0] IM_A_read_format;		//mix the read_row_format, read_column_format.
	wire [`IM_A_LENGTH-1:0] IM_A_write_format;
	
	reg [`STATE_COUNT_BIT-1:0] IM_cs;
	reg [`STATE_COUNT_BIT-1:0] IM_ns;
	
	reg [`STATE_COUNT_BIT-1:0] count;
	reg [`STATE_COUNT_BIT-1:0] count_nxt;
	
	reg pic_write_done;
	//assign pic_write_done=1'b0;		//test or FMS will nuknown. 2023.12.14
	wire [3:0] pic_done_condition;
	//wire clk_write_done;
	//assign o_test_out = clk_write_done;
	//assign clk_write_done=1'b0;	//test or FMS will nuknown. 2023.12.14
	
	reg [1:0] size_mask; //for calcuale the read/write address. 
	
	reg flag_1sec;
	reg flag_200msec;
	reg flag_2sec;
	wire flag_1sec_nxt;
	wire flag_200msec_nxt;
	wire flag_2sec_nxt;
	
	//read pic IM_A row, column base
	reg [`IM_A_2D_SIZE-1:0] read_row;			
	reg [`IM_A_2D_SIZE-1:0] read_row_nxt;
	reg [`IM_A_2D_SIZE-1:0] read_column;
	reg [`IM_A_2D_SIZE-1:0] read_column_nxt;
	wire 	  				read_change_row_128;		//read pic edge. for 128 lock edge or 256 and 512 change row.
	wire 					read_change_row_256;
	
	wire [4:0] read_addr_sel; 		//control read_row, read_column mode.
	
	wire [`IM_A_2D_SIZE-1:0] read_row_format;		//mix the row base and size_mask to the IM_A form.
	wire [`IM_A_2D_SIZE-1:0] read_column_format;    //mix the the base and size_mask column base to the IM_A form.
	wire [`IM_A_2D_SIZE-1:0] read_row_format_first_addr;		//first address of 4, don't need to add count.
	wire [`IM_A_2D_SIZE-1:0] read_column_format_first_addr;
	wire [`IM_A_2D_SIZE-1:0] read_row_format_edge_addr;
	wire [`IM_A_2D_SIZE-1:0] read_column_format_edge_addr;
	
	wire [`IM_A_2D_SIZE-1:0] write_row_format_512; 
	wire [`IM_A_2D_SIZE-1:0] write_column_format_512;
	
	
	
	wire [4:0] read_format_sel;	
	
	//write FB IM_A row, column base
	reg [`IM_A_2D_SIZE-1:0] write_row;
	reg [`IM_A_2D_SIZE-1:0] write_row_nxt;
	reg [`IM_A_2D_SIZE-1:0] write_column;
	reg [`IM_A_2D_SIZE-1:0] write_column_nxt;
	
	wire [3:0] write_addr_sel;
	
	wire [`IM_A_2D_SIZE-1:0] write_row_format;  
	wire [`IM_A_2D_SIZE-1:0] write_column_format;
	wire [`IM_A_2D_SIZE-1:0] write_row_format_first_addr;
	wire [`IM_A_2D_SIZE-1:0] write_column_format_first_addr;
	
	wire [1:0]		    	 write_row_format_offset_sel;
	wire [`IM_A_2D_SIZE-1:0] write_row_format_base;
	reg  [`IM_A_2D_SIZE-1:0] write_row_format_offset;
	
	wire [2:0]		     	 write_column_format_offset_sel;
	wire [`IM_A_2D_SIZE-1:0] write_column_format_base; 
	reg  [`IM_A_2D_SIZE-1:0] write_column_format_offset;
	
	
	wire read_change_row_512_even;
	wire read_change_row_512_odd;
	
	wire [2:0] write_format_sel;
	wire 	   write_change_row_256;
	wire 	   write_change_row_512;	//for write 512x512 change row.
	//--------------------------------------------- size mode -------------------------------------------------------
	always @(*)begin
		case(i_pic_mode)
			3'b001 : size_mask=2'b00;
			3'b010 : size_mask=2'b01;
			3'b100 : size_mask=2'b11;
			default: size_mask=2'b00;
		endcase
	end
	//--------------------------------------------- size mode -------------------------------------------------------
	
	//--------------------------------------------- time mode -------------------------------------------------------
	always @(posedge clk or posedge reset)begin
		if(reset)begin
			flag_1sec	 <= 1'b0;
			flag_200msec <= 1'b0; 
			flag_2sec	 <= 1'b1; 
		end
		else begin
			flag_1sec	 <= flag_1sec_nxt;
			flag_200msec <= flag_200msec_nxt; 
			flag_2sec	 <= flag_2sec_nxt; 
		end
	end
	
	//lock time mode(1sec, 2sec, 200msec)
	assign flag_1sec_nxt = (IM_cs==`IM_1SEC) 	 ? 1'b1:
						   (IM_cs==`IM_CLK_DONE) ? 1'b0:
						   flag_1sec;
	
	assign flag_200msec_nxt = (IM_cs==`IM_200mSEC) 	? 1'b1:
							  (IM_cs==`IM_CLK_DONE) ? 1'b0:
							  flag_200msec;
						   
	assign flag_2sec_nxt = (IM_cs==`IM_2SEC) 	 ? 1'b1:
						   (IM_cs==`IM_CLK_DONE) ? 1'b0:
						   flag_2sec;
	//--------------------------------------------- time mode -------------------------------------------------------
	
	//--------------------------------------------- FSM and FSM_counter ---------------------------------------------
	always @(posedge clk or posedge reset)begin
		if(reset)begin
			IM_cs <= `IM_HEADER;
			//IM_cs <= `IM_CLK_DONE;  //test one second;
			count <= `STATE_COUNT_BIT'd0;
		end
		else begin
			IM_cs <= IM_ns;
			count <= count_nxt;
		end
	end

	always @(*)begin
		case(IM_cs)
			`IM_1SEC	   : IM_ns = `IM_PIC_DONE;
						   
			`IM_2SEC	   : IM_ns = `IM_MODE_CHECK;
						   
			`IM_200mSEC	   : IM_ns = `IM_MODE_CHECK;
						   
			`IM_HEADER	   : IM_ns = (count==`STATE_COUNT_BIT'd4) ? `IM_MODE_CHECK : `IM_HEADER;
			
			`IM_MODE_CHECK : IM_ns = (|i_pic_mode) ? `IM_START : `IM_MODE_CHECK;
			
			`IM_START	   : IM_ns = (|i_pic_mode) ? `IM_R_PIXEL : `IM_START;
						   
			`IM_R_PIXEL	   : IM_ns = (count==`STATE_COUNT_BIT'd4) ? `IM_W_PIXEL : `IM_R_PIXEL;
						   
			`IM_W_PIXEL	   : IM_ns = (pic_write_done) ? `IM_PIC_DONE:
						   		     (count==`STATE_COUNT_BIT'd2) ? `IM_R_PIXEL : `IM_W_PIXEL;
						   
			`IM_PIC_DONE   : IM_ns = (count==`STATE_COUNT_BIT'd2) ? `IM_W_CLK : `IM_PIC_DONE ;		//test 2023.12.14
						   
			`IM_R_CLK	   : IM_ns = `IM_W_CLK;
						   
			`IM_W_CLK	   : IM_ns = (clk_write_done) ? `IM_CLK_DONE :
									 (count==`STATE_COUNT_BIT'd13) ? `IM_R_CLK  : `IM_W_CLK;
						   
			`IM_CLK_DONE   : IM_ns = (i_1SEC) 	 ? `IM_1SEC    :
									 (i_200mSEC)? `IM_200mSEC :
									 (i_2SEC)   ? `IM_2SEC    :
									 `IM_CLK_DONE;
						   
			`IM_R_PIC	   : IM_ns = (count==`STATE_COUNT_BIT'd1) ? `IM_START : `IM_R_PIC;
						   
			default		   : IM_ns = `IM_2SEC;
		endcase
	end
	
	always @(*)begin
		case(IM_cs)
			`IM_1SEC	: count_nxt = `STATE_COUNT_BIT'd0;
			
			`IM_2SEC	: count_nxt = `STATE_COUNT_BIT'd0;
			
			`IM_200mSEC	: count_nxt = `STATE_COUNT_BIT'd0;
			
			`IM_HEADER	: count_nxt = (count==`STATE_COUNT_BIT'd4) ? `STATE_COUNT_BIT'd1 : count + `STATE_COUNT_BIT'd1;
			
			`IM_START	: count_nxt = `STATE_COUNT_BIT'd1;
			
			`IM_R_PIXEL	: count_nxt = (count==`STATE_COUNT_BIT'd4) ? `STATE_COUNT_BIT'd1 : count + `STATE_COUNT_BIT'd1;
			
			`IM_W_PIXEL	: count_nxt = (pic_write_done) ? `STATE_COUNT_BIT'd0:
								      (count==`STATE_COUNT_BIT'd2) ? `STATE_COUNT_BIT'd1 : count + `STATE_COUNT_BIT'd1;
			
			`IM_PIC_DONE: count_nxt = (count==`STATE_COUNT_BIT'd2) ? `STATE_COUNT_BIT'd1 : count + `STATE_COUNT_BIT'd1;
			
			`IM_R_CLK	: count_nxt = `STATE_COUNT_BIT'd1;
			
			`IM_W_CLK	: count_nxt = (clk_write_done) ? `STATE_COUNT_BIT'd1 :
								      (count==`STATE_COUNT_BIT'd13) ? `STATE_COUNT_BIT'd1  : count + `STATE_COUNT_BIT'd1;
			
			`IM_CLK_DONE: count_nxt = `STATE_COUNT_BIT'd1;
			
			`IM_R_PIC	: count_nxt = (count==`STATE_COUNT_BIT'd1) ? `STATE_COUNT_BIT'd1 :  count + `STATE_COUNT_BIT'd1;
			
			default		: count_nxt = `STATE_COUNT_BIT'd0;
		endcase
	end
	
	
	assign o_IM_WEN = (!(IM_cs==`IM_W_PIXEL || IM_cs==`IM_W_CLK));
	
	
	//--------------------------------------------- FSM and FSM_counter ---------------------------------------------
	
	
	//--------------------------------------------- IM_A read row, column --------------------------------------------
	always @(posedge clk or posedge reset)begin
		if(reset)begin
			read_row	<= `IM_A_2D_SIZE'd0;
			read_column <= `IM_A_2D_SIZE'd0;
		end
		else begin
			read_row	<= read_row_nxt;
			read_column <= read_column_nxt;
		end
	end 
	
	assign read_change_row_128 = ({(size_mask & read_column[8:7]),read_column[6:0]} == {size_mask, 7'd127}) && size_mask==2'b00;
	assign read_change_row_256 = ({(size_mask & read_column[8:7]),read_column[6:0]} == {size_mask, 7'd126}) && size_mask==2'b01;
	assign read_change_row_512_even = ({(size_mask & read_column[8:7]),read_column[6:0]} == {size_mask, 7'd126}) && size_mask==2'b11;	//0,2,4 (max column 510)
	assign read_change_row_512_odd = ({(size_mask & read_column[8:7]),read_column[6:0]} == {size_mask, 7'd124}) && size_mask==2'b11;	//1,3,5 (max column 508)
	
	assign read_addr_sel = {size_mask, (count==`STATE_COUNT_BIT'd4), read_change_row_128, (read_change_row_256|read_change_row_512_even|read_change_row_512_odd)};
	//512x512, 256x256 jump 2 row
	
	always @(*)begin
		case(IM_cs)
			`IM_MODE_CHECK : begin
								if(i_pic_mode[2] && flag_2sec)begin
									read_row_nxt    = `IM_A_2D_SIZE'd0;
									read_column_nxt = `IM_A_2D_SIZE'd2;
								end
								else begin
									read_row_nxt    = `IM_A_2D_SIZE'd0;
									read_column_nxt = `IM_A_2D_SIZE'd0;
								end
							 end
			`IM_START   : begin
							read_row_nxt    = read_row;
							read_column_nxt = read_column;
						  end
			
			`IM_R_PIXEL	: begin
							case(read_addr_sel)
								5'b00_1_0_0 : begin
												read_row_nxt 	= read_row;
												read_column_nxt = read_column + `IM_A_2D_SIZE'd1;
											  end
								5'b00_1_1_0	: begin
												read_row_nxt 	= read_row + `IM_A_2D_SIZE'd1;
												read_column_nxt = `IM_A_2D_SIZE'd0;
											  end
								5'b01_1_0_0 : begin
												read_row_nxt 	= read_row;
												read_column_nxt = read_column + `IM_A_2D_SIZE'd2;
											  end
								5'b01_1_0_1 : begin
												read_row_nxt 	= read_row + `IM_A_2D_SIZE'd2;
												read_column_nxt = `IM_A_2D_SIZE'd0;
											  end
								5'b11_1_0_0 : begin
												read_row_nxt 	= read_row;
												read_column_nxt = read_column + `IM_A_2D_SIZE'd4;
											  end
								5'b11_1_0_1 : begin
												read_row_nxt 	= read_row + `IM_A_2D_SIZE'd2;
												read_column_nxt = (read_change_row_512_even) ? `IM_A_2D_SIZE'd0 : `IM_A_2D_SIZE'd2;
											  end
								default  	: begin
												read_row_nxt 	= read_row;
												read_column_nxt = read_column;
											  end
							endcase
						  end
		
			`IM_W_PIXEL	: begin
							read_row_nxt 	= read_row;
							read_column_nxt = read_column;
						  end
			default		: begin
							read_row_nxt 	= read_row;
							read_column_nxt = read_column;
						  end
		endcase
	end
	//--------------------------------------------- IM_A read row, column --------------------------------------------
	
	//--------------------------------------------- IM_A read row, column format --------------------------------------
	//select first and add.
	assign read_row_format    = {read_row[8:7]    & size_mask, read_row[6:0]}    + {8'd0, count[1]};
	assign read_column_format = {read_column[8:7] & size_mask, read_column[6:0]} + {8'd0, count[0]};
	
	assign read_row_format_first_addr    = {read_row[8:7]    & size_mask, read_row[6:0]};
	assign read_column_format_first_addr = {read_column[8:7] & size_mask, read_column[6:0]};
	
	assign read_row_format_edge_addr    = {read_row[8:7]    & size_mask, read_row[6:0]} + {8'd0, count[1]};
	assign read_column_format_edge_addr = {read_column[8:7] & size_mask, read_column[6:0]};
	
	assign read_format_sel = {size_mask, (IM_cs==`IM_R_PIXEL), (IM_cs==`IM_W_PIXEL), read_change_row_128};
	
	always @(*)begin
		case(read_format_sel)
			5'b00_0_0_0 : IM_A_read_format = {4'd0, read_row_format, read_column_format[6:0]};
			
			5'b00_1_0_0 : IM_A_read_format = {4'd0, read_row_format, read_column_format[6:0]};	//4, 9, 7
			
			5'b00_0_1_0 : IM_A_read_format = {4'd0, read_row_format_first_addr, read_column_format_first_addr[6:0]};
			
			5'b00_0_1_1 : IM_A_read_format = {4'd0, read_row_format_first_addr, read_column_format_first_addr[6:0]};
			
			5'b00_1_0_1 : IM_A_read_format = {4'd0, read_row_format_edge_addr, read_column_format_edge_addr[6:0]};
			
			5'b01_0_0_0 : IM_A_read_format = {3'd0, read_row_format, read_column_format[7:0]};
			
			5'b01_1_0_0 : IM_A_read_format = {3'd0, read_row_format, read_column_format[7:0]};
			
			5'b01_0_1_0 : IM_A_read_format = {3'd0, read_row_format_first_addr, read_column_format_first_addr[7:0]};
			
			5'b11_1_0_0 : IM_A_read_format = {2'd0, read_row_format, read_column_format[8:0]}; 
			
			5'b11_0_0_0 : IM_A_read_format = {2'd0, read_row_format, read_column_format[8:0]};  
			
			5'b11_0_1_0 : IM_A_read_format = {2'd0, read_row_format_first_addr, read_column_format_first_addr[8:0]}; 
			
			default	    : IM_A_read_format = `IM_A_LENGTH'dx;
		endcase
	end
	//--------------------------------------------- IM_A read row, column format --------------------------------------
	
	//--------------------------------------------- IM_A write row, column --------------------------------------------
	always @(posedge clk or posedge reset)begin
		if(reset)begin
			write_row	 <= `IM_A_2D_SIZE'd0;
			write_column <= `IM_A_2D_SIZE'd0;
		end
		else begin
			write_row	 <= write_row_nxt;
			write_column <= write_column_nxt;
		end
	end
	
	assign write_change_row_256 = (write_column == `IM_A_2D_SIZE'd254);
	assign write_change_row_512 = (write_column == `IM_A_2D_SIZE'd255);		//for 512x512 change row. even row
	
	assign write_addr_sel = {flag_2sec|flag_200msec, count==`STATE_COUNT_BIT'd2, write_change_row_256, write_change_row_512};
	
	
	always @(*)begin
		case(IM_cs) 
			`IM_MODE_CHECK : begin
								if(i_pic_mode[2])begin
									write_row_nxt    = `IM_A_2D_SIZE'd0;
									write_column_nxt = `IM_A_2D_SIZE'd0 + {8'd0, flag_2sec};
								end
								else begin
									write_row_nxt    = `IM_A_2D_SIZE'd0;
									write_column_nxt = `IM_A_2D_SIZE'd0;
								end
							  end
			`IM_START		: begin
								write_row_nxt    = write_row;
								write_column_nxt = write_column;
							  end
				
			`IM_R_PIXEL		: begin
								write_row_nxt    = write_row;
								write_column_nxt = write_column;
							  end
		
			`IM_W_PIXEL		: begin
								case(write_addr_sel)
									4'b1100 : begin
												write_row_nxt    = write_row;
												write_column_nxt = write_column + `IM_A_2D_SIZE'd2;
											  end
									4'b1110 : begin
												write_row_nxt    = write_row + ((&size_mask) ? `IM_A_2D_SIZE'd1 : `IM_A_2D_SIZE'd2);
												write_column_nxt = (&size_mask && flag_200msec) ? `IM_A_2D_SIZE'd1 : `IM_A_2D_SIZE'd0;
											  end
									4'b1101 : begin
												write_row_nxt    = write_row + `IM_A_2D_SIZE'd1;
												write_column_nxt = (write_change_row_512) ? `IM_A_2D_SIZE'd0 : `IM_A_2D_SIZE'd1;
											  end
									default: begin
												write_row_nxt    = write_row;
												write_column_nxt = write_column;
											end
								endcase
							   end
			
			`IM_PIC_DONE	: begin
								write_row_nxt = `IM_A_2D_SIZE'd232;
								write_column_nxt = `IM_A_2D_SIZE'd152;
							  end
				
			`IM_R_CLK		: begin
								write_row_nxt = write_row;
								write_column_nxt = write_column;
							  end
				
			`IM_W_CLK		: begin
								if(count==`STATE_COUNT_BIT'd13)begin
									if(write_row==`IM_A_2D_SIZE'd255)begin	
										write_row_nxt = `IM_A_2D_SIZE'd232;
										write_column_nxt = write_column + `IM_A_2D_SIZE'd13 ;
									end
									else begin
										write_row_nxt = write_row + `IM_A_2D_SIZE'd1;
										write_column_nxt = write_column ;
									end
								end
								else begin
									write_row_nxt = write_row;
									write_column_nxt = write_column;
								end
							  end
			default			: begin
								write_row_nxt = write_row;
								write_column_nxt = write_column;
							  end
		endcase
	end
	
	
	
	//pic write done condition.			
	assign pic_done_condition = {size_mask, (IM_cs==`IM_W_PIXEL), (count==`STATE_COUNT_BIT'd2)};
	//clk write done condition.
	assign clk_write_done = {(IM_cs==`IM_W_CLK) && (write_row==`IM_A_2D_SIZE'd255) && (write_column==`IM_A_2D_SIZE'd243)};

	assign o_pic_done_2sec = pic_write_done & flag_2sec;
	assign o_pic_done_200msec = pic_write_done & flag_200msec;
				
	always @(*)begin
		case(pic_done_condition)
			4'b00_1_1	: pic_write_done = (write_row==`IM_A_2D_SIZE'd254 && write_column==`IM_A_2D_SIZE'd254);
			4'b01_1_1	: pic_write_done = (write_row==`IM_A_2D_SIZE'd254 && write_column==`IM_A_2D_SIZE'd254);
			4'b11_1_1	: pic_write_done = (write_row==`IM_A_2D_SIZE'd255 && (write_column==`IM_A_2D_SIZE'd254 || write_column==`IM_A_2D_SIZE'd255));
			default		: pic_write_done = 1'b0;
		endcase
	end
	
	//--------------------------------------------- IM_A write row, column --------------------------------------------
	
	//--------------------------------------------- IM_A write row, column format -------------------------------------
	assign write_row_format_offset_sel = {(&size_mask==1'b1 || IM_cs==`IM_R_CLK || IM_cs==`IM_R_PIXEL || IM_cs==`IM_PIC_DONE || IM_cs==`IM_W_CLK), (IM_cs==`IM_W_PIXEL)};
	
	always @(*)begin
		case(write_row_format_offset_sel)
			2'b1_0  : write_row_format_offset = `IM_A_2D_SIZE'd0;
			2'b1_1  : write_row_format_offset = `IM_A_2D_SIZE'd0;
			2'b0_1  : write_row_format_offset = {8'd0, flag_2sec|flag_200msec};
			default : write_row_format_offset = `IM_A_2D_SIZE'dx;
		endcase
	end
	
	assign write_row_format_base = {write_row[8:7] & 2'b01, write_row[6:0]};
	
	assign write_row_format = write_row_format_base + write_row_format_offset;
	
	
	assign write_column_format_offset_sel = {(&size_mask==1'b1 || IM_cs==`IM_R_CLK || IM_cs==`IM_W_PIXEL || IM_cs==`IM_PIC_DONE), (IM_cs==`IM_R_PIXEL && count==`STATE_COUNT_BIT'd4), IM_cs==`IM_W_CLK};
	
	always @(*)begin
		case(write_column_format_offset_sel)
			3'b1_0_0 : write_column_format_offset = (flag_200msec && !(&size_mask)) ? {8'd0, flag_200msec} : `IM_A_2D_SIZE'd0;
			3'b1_1_0 : write_column_format_offset = `IM_A_2D_SIZE'd0;
			3'b0_1_0 : write_column_format_offset = {8'd0, flag_2sec};
			3'b1_0_1 : write_column_format_offset = {4'd0, count};
			3'b0_0_1 : write_column_format_offset = {4'd0, count};
			default  : write_column_format_offset = `IM_A_2D_SIZE'dx;
		endcase
	end
	
	assign write_column_format_base = {write_column[8:7] & 2'b01, write_column[6:0]};
	
	assign write_column_format = write_column_format_base + write_column_format_offset;
	
	
	assign IM_A_write_format = {3'd0, write_row_format, write_column_format[7:0]};
	
	//--------------------------------------------- IM_A write row, column format -------------------------------------
	
	//--------------------------------------------- output IM_A  -----------------------------------------------------
	always @(posedge clk or posedge reset)begin
		if(reset)begin
			o_IM_A <= `IM_A_LENGTH'd0;
		end
		else begin
			o_IM_A <= o_IM_A_nxt; 
		end
	end
	
	always @(*)begin
		case(IM_cs) 
			`IM_HEADER  : begin
							o_IM_A_nxt = {17'd0, count};	
						  end
			`IM_START	: begin	
							o_IM_A_nxt = i_pic_init_addr + IM_A_read_format;
						  end
			
			`IM_R_PIXEL	: begin
							if(count==`STATE_COUNT_BIT'd4)begin
								o_IM_A_nxt = i_FB_init_addr + IM_A_write_format;
							end
							else begin
								o_IM_A_nxt = i_pic_init_addr + IM_A_read_format;
							end
						  end
		
			`IM_W_PIXEL	: begin
							if(count==`STATE_COUNT_BIT'd2)begin
								o_IM_A_nxt = i_pic_init_addr + IM_A_read_format;
							end
							else begin
								o_IM_A_nxt = i_FB_init_addr + IM_A_write_format;
							end
						  end
			
			`IM_PIC_DONE: begin
							o_IM_A_nxt = i_FB_init_addr + IM_A_write_format;
						  end
			
			`IM_R_CLK	: begin
							o_IM_A_nxt = i_FB_init_addr + IM_A_write_format;
						  end
			
			`IM_W_CLK	: begin
							o_IM_A_nxt = i_FB_init_addr + IM_A_write_format;
						  end
			
			default		: begin
							o_IM_A_nxt = `IM_A_LENGTH'd0;
						  end
		endcase
	end
	//--------------------------------------------- output IM_A  -----------------------------------------------------
	
endmodule 
