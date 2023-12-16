`define CS_WIDTH 4

module Control_v4(
    clk,
    reset,
    PIC_Write_Done,
    CR_Done,
    clk_200ms,
    clk_odd,
    clk_even,
    clk_19,
    IM_Q,
    Control_CS,
    PIC_size,
    PIC_addr,
    FB_addr,
    INIT_time,
    PIC_num
);

input clk;
input reset;
input PIC_Write_Done;
input CR_Done;
input clk_200ms;
input clk_odd;
input clk_even;
input clk_19;
input [23:0]IM_Q;

output [`CS_WIDTH-1:0]Control_CS;
output [2:0]PIC_size,PIC_num;
output [19:0]FB_addr,PIC_addr;
output [23:0]INIT_time;

localparam INITIAL0 =`CS_WIDTH'd8 ;
localparam INITIAL1 =`CS_WIDTH'd9 ;

localparam READ_INIT_TIME =`CS_WIDTH'd0 ;
localparam READ_FB_ADDR =`CS_WIDTH'd1 ;
localparam READ_PHOTO_NUM =`CS_WIDTH'd2 ;
localparam READ_PIC_ADDR =`CS_WIDTH'd3 ;
localparam READ_PIC_SIZE =`CS_WIDTH'd4 ;

localparam PIC_DRAW = `CS_WIDTH'd5 ;
localparam CR_DRAW = `CS_WIDTH'd6 ;

localparam IDLE0 =`CS_WIDTH'd7 ;
localparam IDLE1 =`CS_WIDTH'd10 ;
localparam IDLE2 =`CS_WIDTH'd11 ;
localparam IDLE3 =`CS_WIDTH'd12 ;
localparam IDLE4 =`CS_WIDTH'd13 ;
localparam IDLE5 =`CS_WIDTH'd14 ;

reg [`CS_WIDTH-1:0]Control_CS,Control_NS;

reg [2:0]PIC_size,PIC_num;
reg [19:0]FB_addr,PIC_addr;
reg [23:0]INIT_time;

reg [2:0]PIC_size_NS,PIC_num_NS;
reg [19:0]FB_addr_NS,PIC_addr_NS;
reg [23:0]INIT_time_NS;

always @(posedge clk or posedge reset) begin
    if(reset)begin
        Control_CS<=INITIAL0;
    end
    else begin
        Control_CS<=Control_NS;
    end
end

always @(*) begin
    case(Control_CS)
    INITIAL0:begin
        Control_NS=INITIAL1;
    end
    INITIAL1:begin
        Control_NS=READ_INIT_TIME;
    end
    READ_INIT_TIME:begin
        Control_NS=READ_FB_ADDR;
    end
    READ_FB_ADDR:begin
        Control_NS=READ_PHOTO_NUM;
    end
    READ_PHOTO_NUM:begin
        Control_NS=READ_PIC_ADDR;
    end
    READ_PIC_ADDR:begin
        Control_NS=READ_PIC_SIZE;
    end
    READ_PIC_SIZE:begin
        Control_NS=(|PIC_size_NS)?IDLE1:Control_CS;
    end
    IDLE1:begin
        Control_NS=PIC_DRAW;
    end
    PIC_DRAW:begin
        Control_NS=(PIC_Write_Done)?CR_DRAW:Control_CS;
    end
    CR_DRAW:begin
        Control_NS=(CR_Done)?IDLE0:Control_CS;
    end
    IDLE0:begin
        Control_NS=(clk_200ms)? IDLE2:
                   (clk_even) ? IDLE3:
                   (clk_odd)  ? CR_DRAW:
                   Control_CS; 
    end
    IDLE2:begin
        Control_NS=IDLE1;
    end
    IDLE3:begin
        Control_NS=IDLE4;
    end
    IDLE4:begin
        Control_NS=IDLE5;
    end
    IDLE5:begin
        Control_NS=READ_PIC_ADDR;
    end
    default:begin
        Control_NS=INITIAL0;
    end
    endcase
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        INIT_time<=24'd0;
        FB_addr<=20'd0;
        PIC_num<=3'd0;
        PIC_addr<=20'd0;
        PIC_size<=3'd0;
    end
    else begin
        INIT_time<=INIT_time_NS;
        FB_addr<=FB_addr_NS;
        PIC_num<=PIC_num_NS;
        PIC_addr<=PIC_addr_NS;
        PIC_size<=PIC_size_NS; 
    end
end

always @(*) begin
    case(Control_CS)
    READ_INIT_TIME:begin
        INIT_time_NS=IM_Q;
        FB_addr_NS=FB_addr;
        PIC_num_NS=PIC_num;
        PIC_addr_NS=PIC_addr;
        PIC_size_NS=PIC_size;
    end
    READ_FB_ADDR:begin
        INIT_time_NS=INIT_time;
        FB_addr_NS=IM_Q[19:0];
        PIC_num_NS=PIC_num;
        PIC_addr_NS=PIC_addr;
        PIC_size_NS=PIC_size;
    end
    READ_PHOTO_NUM:begin
        INIT_time_NS=INIT_time;
        FB_addr_NS=FB_addr;
        PIC_num_NS=IM_Q[2:0];
        PIC_addr_NS=PIC_addr;
        PIC_size_NS=PIC_size;
    end
    READ_PIC_ADDR:begin
        INIT_time_NS=INIT_time;
        FB_addr_NS=FB_addr;
        PIC_num_NS=PIC_num;
        PIC_addr_NS=IM_Q[19:0];
        PIC_size_NS=PIC_size;
    end
    READ_PIC_SIZE:begin
        INIT_time_NS=INIT_time;
        FB_addr_NS=FB_addr;
        PIC_num_NS=PIC_num;
        PIC_addr_NS=PIC_addr;
        PIC_size_NS=IM_Q[9:7];
    end
    IDLE0:begin
        INIT_time_NS=INIT_time;
        FB_addr_NS=FB_addr;
        PIC_num_NS=PIC_num;
        PIC_addr_NS=PIC_addr;
        PIC_size_NS=(clk_19)?3'd0:PIC_size;
    end
    default:begin
        INIT_time_NS=INIT_time;
        FB_addr_NS=FB_addr;
        PIC_num_NS=PIC_num;
        PIC_addr_NS=PIC_addr;
        PIC_size_NS=PIC_size;
    end
    endcase
end


endmodule