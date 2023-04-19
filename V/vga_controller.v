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
///////// ////                     
reg [23:0] bgr_data;
wire VGA_CLK_n;
wire [7:0] index;
wire [23:0] bgr_data_raw;
wire cBLANK_n,cHS,cVS,rst;

// sdram stuff
reg		[4:0]			write_count;
reg		[ADDR_W-1:0]	address;
wire					max_address;
reg [8:0] length;

//assign max_address = address >= 25'd76800;

assign index = readdata;
// assign index = 8'hb9;

////
assign rst = ~iRST_n;
wire		[10:0]	Current_X;
video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(cHS),
                              .VS(cVS),
															.oCurrent_X(Current_X));
////

//////////////////////////

// synchronize VGA clock to be every 8 SDRAM clocks
// 25 Hz --> 200 Hz
reg [4:0] clock_phase;
/*
reg  [31:0]          cal_data,clk_cnt;

always@(posedge sdram_clk)
  if (!iRST_n)
		clk_cnt <= 32'b0;
  else  
		clk_cnt <= clk_cnt + 32'b1;
*/
always@(posedge sdram_clk)
begin
	if (!iRST_n || !done) begin
		write_count <= 5'b0;
		read_state <= 4'b0;
		read <= 1'b0;
    clock_phase <= 5'b0;
	end else begin
    case (read_state)
      0 : begin //idle
        address <= {ADDR_W{1'b0}};
				length <= 9'b0;

				if (done) begin
          read_state <= 4;
					//cal_data <= clk_cnt;
        end
      end
      4 : begin //read
				read <= 1;
				if (!write_count[3])
					write_count <= write_count + 1'b1;
        
      	read_state <= 5;
      end
      5 : begin //latch read data
        read <= 0;

				if (!write_count[3])
					write_count <= write_count + 5'b1;

				read_state <= 6;
			end
      6 : begin //finish compare one data
        if (write_count[3])
        begin
          write_count <= 5'b0;
          read_state <= 7;
        end else
          write_count <= write_count + 1'b1;
      end
      7 : begin
        if (length >= 76800) begin
          address <= {ADDR_W{1'b0}};
          read_state <= 9;
					length <= 9'b0;
        end else begin
          address <= address + 1'b1;
					read_state <= 4;
					length <= length + 8;
        end
      end
      9 : read_state <= 9;
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
	.clock ( iVGA_CLK ),
	.q ( bgr_data_raw)
);

assign VGA_CLK_n = ~iVGA_CLK;

//always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;

//////latch valid data at falling edge;
always@(posedge VGA_CLK_n) 
begin
	if (!iRST_n || (cHS==1'b0 && cVS==1'b0)) begin
     bgr_data<=24'h000000;
	end else begin
  	bgr_data <= bgr_data_raw;
	end
end
wire [23:0] mbgr_data;
wire [7:0]  mVGA_B,mVGA_G,mVGA_R;
assign mbgr_data=bgr_data;
assign mVGA_B=mbgr_data[23:16];
assign mVGA_G=mbgr_data[15:8]; 
assign mVGA_R=mbgr_data[7:0];

assign oVGA_B=(Current_X>0)?mVGA_B[7:4]:0;
assign oVGA_G=(Current_X>0)?mVGA_G[7:4]:0;
assign oVGA_R=(Current_X>0)?mVGA_R[7:4]:0;

///////////////////
//////Delay the iHD, iVD,iDEN for one clock cycle;
always@(negedge iVGA_CLK)
begin
  oHS<=cHS;
  oVS<=cVS;
  oBLANK_n<=cBLANK_n;
end

endmodule
