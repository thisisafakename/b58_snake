// UPDATED 07/18/2017
// 1:22 p.m.

module tron (
    CLOCK_50,                           //    On Board 50 MHz
    // Your inputs and outputs here
    KEY,
    SW,
    // The ports below are for the VGA output.  Do not change.
    VGA_CLK,                            //    VGA Clock
    VGA_HS,                             //    VGA H_SYNC
    VGA_VS,                             //    VGA V_SYNC
    VGA_BLANK_N,                        //    VGA BLANK
    VGA_SYNC_N,                         //    VGA SYNC
    VGA_R,                              //    VGA Red[9:0]
    VGA_G,                              //    VGA Green[9:0]
    VGA_B,                              //    VGA Blue[9:0]
    HEX0,
    HEX1,
    HEX2,
    HEX3
    );

    input       CLOCK_50;               //    50 MHz
    input       [17:0] SW;
    input       [3:0] KEY;

    // Declare your inputs and outputs here
    // Do not change the following outputs
    output      VGA_CLK;                //    VGA Clock
    output      VGA_HS;                 //    VGA H_SYNC
    output      VGA_VS;                 //    VGA V_SYNC
    output      VGA_BLANK_N;            //    VGA BLANK
    output      VGA_SYNC_N;             //    VGA SYNC
    output      [9:0] VGA_R;            //    VGA Red[9:0]
    output      [9:0] VGA_G;            //    VGA Green[9:0]
    output      [9:0] VGA_B;            //    VGA Blue[9:0]
    output [6:0] HEX0, HEX1, HEX2, HEX3;
    wire resetn;
    assign resetn = KEY[0];

    // Create the colour, x, y and writeEn wires that are inputs to the controller.
   wire [2:0] colourSnakeA, colourSnakeB;
   assign colourSnakeA = 3'b001;
   assign colourSnakeB = 3'b100;
   wire [7:0] x;
   wire [6:0] y;
   wire writeEn;
   wire clk_out;
   rate_divider one_sec(SW[17], CLOCK_50, clk_out);
   reg  [1:0] cord [7:0][6:0];



   // Create an Instance of a VGA controller - there can be only one!
   // Define the number of colours as well as the initial background
   // image file (.MIF) for the controller.
   vga_adapter VGA(
        .resetn(resetn),
        .clock(CLOCK_50),
        .colour(colourSnakeA),
        .x(x),
        .y(y),
        .plot(writeEn),
        /* Signals for the DAC to drive the monitor. */
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK(VGA_BLANK_N),
        .VGA_SYNC(VGA_SYNC_N),
    .VGA_CLK(VGA_CLK));
    defparam VGA.RESOLUTION = "160x120";
    defparam VGA.MONOCHROME = "FALSE";
    defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
    defparam VGA.BACKGROUND_IMAGE = "tron.mif";

    // Put your code here. Your code should produce signals x,y,colour and writeEn/plot
    // for the VGA controller, in addition to any other functionality your design may require.
    // Instansiate datapathxin
    wire [1:0] xposoff, yposoff;


	always@(posedge CLOCK_50) begin
        // initializes the position that we start at in the game board
			cord[x][y] = 1;
		end



    // instansiates the datapath module
    tron_datapath d0(
        .clk(clk_out),
        .coordsX(x), // output
        .coordsY(y), // output
        .xOffset(xposoff),
        .yOffset(yposoff),
        .resetn(KEY[3]));

    // Instansiate FSM control module
    tron_control c0(
        .clk(CLOCK_50),
		.SW(SW[3:0]),
        .go(!KEY[2]),
        .resetn(KEY[3]),
        .xOffset(xposoff), // output
        .yOffset(yposoff), //output
        .plot(writeEn));

    // instantiates the timecount module
    timeCount count(
       .SW(1'b1),
       .CLOCK_50(CLOCK_50),
       .HEX0(HEX0),
       .HEX1(HEX1),
       .HEX2(HEX2),
       .HEX3(HEX3));

   // checks if reset is on
   // iterates through the 2D array positions
   // declares the genvar values
    always@(posedge CLOCK_50) begin: check reset
        if (reset) begin: rest_screen 
            colour <= 3'b000
            genvar y_pos, x_pos;
            generate
               for (y_pos = 18; y_pos < 107; y_pos ++) {
                   begin: y_position
                       for (x_pos = 11; x_pos < 148; x_pos ++) {
                           begin: x_position
                                x <= x_pos
                                y <= y_pos
                           end
                   end
               }
            endgenerate

        end
    end





endmodule



module tron_datapath(
    input clk,
    output [7:0] coordsX,
	output [6:0] coordsY,
    input [1:0] xOffset,
    input  [1:0] yOffset,
    input resetn
    );

    reg [7:0] y_coordinate;
    reg [7:0] x_coordinate;

    initial begin
    	x_coordinate = 8'd25;
    	y_coordinate = 7'd25;
    end

    always @(posedge clk) begin

        // setup x coordinate
		if (xOffset == 2'b01)begin
			x_coordinate <= x_coordinate + 1'b1;
		end
		else if (xOffset == 2'b10) begin
			x_coordinate <= x_coordinate - 1'b1;
		end
		if (yOffset == 2'b01)begin
			y_coordinate <= y_coordinate + 1'b1;
		end
		else if (yOffset == 2'b10) begin
			y_coordinate <= y_coordinate - 1'b1;
		end
        //
	end
    assign coordsY = y_coordinate;
    assign coordsX = x_coordinate;
endmodule



module tron_control(// THIS IS THE FSM AND ALSO GIVES X,Y OFFSETS
    input clk,
    input resetn,
	input [3:0] SW,
    input go,
    output reg [1:0] xOffset,
    output reg [1:0] yOffset,
    output plot);

    reg [2:0] current_state, next_state;
    localparam  down = 2'b00,
                right      = 2'b01,
                up      = 2'b10,
                left      = 2'b11;




    always@(posedge clk)
    begin: position_draw


        //
        //
        case (current_state)
            up: begin: turn_table_1
			case (SW[3:0])
				4'b0001: next_state = right;
				4'b1000: next_state = left;
				default: next_state = up;
			endcase
					  end
			right: begin: turn_table_2
				case (SW[3:0])
					4'b0010: next_state = up;
					4'b0100: next_state = down;
					default: next_state = right;
				 endcase
			end
            down: begin: turn_table_3
				case (SW[3:0])
					4'b0001: next_state = right;
					4'b1000: next_state = left;
					default: next_state = down;
			    endcase
            end
            left: begin: turn_table_4
				case (SW[3:0])
					4'b0100: next_state = down;
					4'b0010: next_state = up;
					default: next_state = left;
				endcase
            end
            default: next_state = up;
        endcase
        //
        //

    end

    // plot
    assign plot = 1;
    // assign offset
    always@(*)
    begin: make_output

        //
        //
        case(current_state)
            up: begin
				xOffset <= 2'b00;
				yOffset <= 2'b01;
			end
			right: begin
				xOffset <= 2'b01;
				yOffset <= 2'b00;
		    end
            down: begin
                xOffset <= 2'b00;
                yOffset <= 2'b10;
		    end
            left: begin
				yOffset <= 2'b00;
				xOffset <= 2'b10;
			end
            default: begin
				xOffset <= 2'b00;
				yOffset <= 2'b00;
			end
        endcase
        //
        //


    end
    always@(posedge clk)
    begin: state_FFs
        if(!resetn) // goto resting if reset
            current_state <= down;
        else
            current_state <= next_state;
    end

endmodule
