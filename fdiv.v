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