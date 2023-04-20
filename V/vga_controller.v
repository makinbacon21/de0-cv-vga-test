module vga_controller(iRST_n,
                      iVGA_CLK,
                      sdram_clk,
                      done,
                      read_state,
                      readdata,
                      read,
											//read_addr,
                      in_button,
                      oBLANK_n,
                      oHS,
                      oVS,
                      oVGA_B,
                      oVGA_G,
                      oVGA_R,
											oStupidMemAddress,
                     );

parameter	ADDR_W	=	25;
parameter	DATA_W	=	16;

input iRST_n;
input iVGA_CLK;
input sdram_clk;
input done;
input	 [DATA_W-1:0]  readdata;
//input [24:0] read_addr;
input					in_button;
output reg [3:0] read_state;
output reg read;
output reg oBLANK_n;
output reg oHS;
output reg oVS;
output [3:0] oVGA_B;
output [3:0] oVGA_G;  
output [3:0] oVGA_R;      
output		[ADDR_W-1:0]	oStupidMemAddress;                 
///////// ////                     
reg [23:0] bgr_data;
wire VGA_CLK_n;
reg [7:0] index;
wire [23:0] bgr_data_raw;
wire cBLANK_n,cHS,cVS,rst;

// sdram stuff
reg		[4:0]			write_count;
reg		[ADDR_W-1:0]	address;
assign oStupidMemAddress = address;
wire					max_address;
reg [8:0] length;
 
// want to show each line twice
reg line1;

//assign max_address = address >= 25'd76800;

// assign index = readdata;
// assign index = 8'hb9;

////
assign rst = ~iRST_n;
wire		[10:0]	Current_X;
wire		[10:0]	Current_Y;
video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(cHS),
                              .VS(cVS),
															.oCurrent_X(Current_X),
															.oCurrent_Y(Current_Y));
////

//////////////////////////

// synchronize VGA clock to be every 8 SDRAM clocks
// 25 Hz --> 200 Hz
reg [4:0] clock_phase;

reg [1:0] vga_clk_edge_detector;
wire vga_clk_falling;
assign vga_clk_falling = vga_clk_edge_detector[1] && !vga_clk_edge_detector[0];
/*
reg  [31:0]          cal_data,clk_cnt;

always@(posedge sdram_clk)
  if (!iRST_n)
		clk_cnt <= 32'b0;
  else  
		clk_cnt <= clk_cnt + 32'b1;
*/

parameter VIDEO_W	= 640;
parameter VIDEO_H	= 480;

always@(posedge sdram_clk)
begin
	vga_clk_edge_detector <= {vga_clk_edge_detector[0], iVGA_CLK};
	if (!iRST_n || !done) begin
		write_count <= 5'b0;
		read_state <= 4'b0;
		read <= 1'b0;
    clock_phase <= 5'b0;
		line1 <= 0;
	end else begin
    case (read_state)
      0 : begin //idle
        address <= {ADDR_W{1'b0}};
				length <= 9'b0;

				if (done && !oHS && !oVS) begin
          read_state <= 4;
					//cal_data <= clk_cnt;
        end
      end
      4 : begin // start the read operation, pull read high
				read <= 1;
				// if (!write_count[3])
				// 	write_count <= write_count + 1'b1;
        
      	read_state <= 5;
      end
      5 : begin // pull read low again on the next clock; data will be available next statee
        read <= 0;

				// if (!write_count[3])
				// 	write_count <= write_count + 5'b1;

				read_state <= 6;
			end
      6 : begin
				// data is good right now, so we latch it.
 				index <= readdata;
				// index <= Current_Y;
				read_state <= 7;
      end
      7 : begin
				// set new address
				address <= (Current_X / 3) + ((Current_Y / 3) * 320);

				// either way, wait around for a falling vga clock edge when we aren't blank
				if (vga_clk_falling && cBLANK_n) begin 
					read_state <= 4;
				end else begin
					read_state <= 8;
				end
      end
		8 : begin
				if (vga_clk_falling && cBLANK_n) begin 
					read_state <= 4;
				end
		end
      default : read_state <= 0;
    endcase
  end

	//if (done) begin
		// vga clock; latch valid data
		//bgr_data <= bgr_data_raw;
		//read_state <= read_state == 9 ? 0 : read_state;
	//end

  clock_phase <= clock_phase + 1;
  
end

//////Color table output
img_index	img_index_inst (
	.address ( index ),
	.clock ( VGA_CLK_n ),
	.q ( bgr_data_raw)
);

assign VGA_CLK_n = ~iVGA_CLK;

//always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;

//////latch valid data at falling edge;
always@(posedge VGA_CLK_n) 
begin
	bgr_data <= bgr_data_raw;
end
wire [23:0] mbgr_data;
wire [7:0]  mVGA_B,mVGA_G,mVGA_R;
assign mbgr_data=bgr_data;
assign mVGA_B=mbgr_data[23:16];
assign mVGA_G=mbgr_data[15:8]; 
assign mVGA_R=mbgr_data[7:0];

assign oVGA_B=(cBLANK_n)?mVGA_B[7:4]:0;
assign oVGA_G=(cBLANK_n)?mVGA_G[7:4]:0;
assign oVGA_R=(cBLANK_n)?mVGA_R[7:4]:0;

///////////////////
//////Delay the iHD, iVD,iDEN for one clock cycle;
always@(negedge iVGA_CLK)
begin
  oHS<=cHS;
  oVS<=cVS;
  oBLANK_n<=cBLANK_n;
end

endmodule
