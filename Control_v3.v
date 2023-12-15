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