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