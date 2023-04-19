// ============================================================================
// Copyright (c) 2014 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//   Ver  :| Author            :| Mod. Date :| Changes Made:
//   V1.0 :| Yue Yang          :| 08/25/2014:| Initial Revision
// ============================================================================


module DE0_CV_Default(


	  ///////// CLOCK2 /////////
	  input              CLOCK2_50,

	  ///////// CLOCK3 /////////
	  input              CLOCK3_50,

	  ///////// CLOCK4 /////////
	  inout              CLOCK4_50,

	  ///////// CLOCK /////////
	  input              CLOCK_50,

	  ///////// DRAM /////////
	  output      [12:0] DRAM_ADDR,
	  output      [1:0]  DRAM_BA,
	  output             DRAM_CAS_N,
	  output             DRAM_CKE,
	  output             DRAM_CLK,
	  output             DRAM_CS_N,
	  inout       [15:0] DRAM_DQ,
	  output             DRAM_LDQM,
	  output             DRAM_RAS_N,
	  output             DRAM_UDQM,
	  output             DRAM_WE_N,

	  ///////// GPIO /////////
	  inout       [35:0] GPIO_0,
	  inout       [35:0] GPIO_1,

	  ///////// HEX0 /////////
	  output      [6:0]  HEX0,

	  ///////// HEX1 /////////
	  output      [6:0]  HEX1,

	  ///////// HEX2 /////////
	  output      [6:0]  HEX2,

	  ///////// HEX3 /////////
	  output      [6:0]  HEX3,

	  ///////// HEX4 /////////
	  output      [6:0]  HEX4,

	  ///////// HEX5 /////////
	  output      [6:0]  HEX5,

	  ///////// KEY /////////
	  input       [3:0]  KEY,

	  ///////// LEDR /////////
	  output      [9:0]  LEDR,

	  ///////// PS2 /////////
	  inout              PS2_CLK,
	  inout              PS2_CLK2,
	  inout              PS2_DAT,
	  inout              PS2_DAT2,

	  ///////// RESET /////////
	  input              RESET_N,

	  ///////// SD /////////
	  output             SD_CLK,
	  inout              SD_CMD,
	  inout       [3:0]  SD_DATA,

	  ///////// SW /////////
	  input       [9:0]  SW,

	  ///////// VGA /////////
	  output      [3:0]  VGA_B,
	  output      [3:0]  VGA_G,
	  output             VGA_HS,
	  output      [3:0]  VGA_R,
	  output             VGA_VS
);


//=======================================================
//  REG/WIRE declarations
//=======================================================
wire			VGA_CTRL_CLK;
wire			SDRAM_LOAD_CLK;
wire			DLY_RST;

wire			done;

//=======================================================
//  Structural coding
//=======================================================
// initial //  	         
assign DRAM_DQ 	   =  16'hzzzz;
assign GPIO_0  		=	36'hzzzzzzzz;
assign GPIO_1  		=	36'hzzzzzzzz;

// / //////////////////////////////////////////////
// reset_n and start_n control
reg [31:0]  cont;
always@(posedge CLOCK_50)
cont<=(cont==32'd4_000_001)?32'd0:cont+1'b1;

reg[4:0] sample;
always@(posedge CLOCK_50)
begin
	if(cont==32'd4_000_000)
		sample[4:0]={sample[3:0],KEY[0]};
	else 
		sample[4:0]=sample[4:0];
end

assign test_software_reset_n=(sample[1:0]==2'b10)?1'b0:1'b1;
assign test_global_reset_n   =(sample[3:2]==2'b10)?1'b0:1'b1;
assign test_start_n         =(sample[4:3]==2'b01)?1'b0:1'b1;

wire [2:0] test_result;

//	Reset Delay Timer
Reset_Delay			r0	(	.iCLK(CLOCK_50),
							.oRESET(DLY_RST)
						);
							 
// VGA PLL clock							 
vga_pll           u1    (   .refclk(CLOCK3_50),      //  refclk.clk
						    .rst(~DLY_RST),          //   reset.reset
						    .outclk_0(VGA_CTRL_CLK),  // outclk0.clk
							.outclk_1(SDRAM_LOAD_CLK)
					    );

wire [24:0] read_addr;
wire [3:0]  read_state;
assign mSEG7_DIG[23:12] = read_state;
vga_controller vga_ins	(	.iRST_n(DLY_RST),
					  		.iVGA_CLK(VGA_CTRL_CLK),
							.sdram_clk(SDRAM_LOAD_CLK),
							.done(done),
							.read_state(read_state),
							.readdata(readdata),
							.read(read),
							//.read_addr(read_addr),
							.in_button(test_start_n),
					  		.oHS(VGA_HS),
					  		.oVS(VGA_VS),
					  		.oVGA_B(VGA_B),
					  		.oVGA_G(VGA_G),
					  		.oVGA_R(VGA_R)
						);

wire  [15:0]  writedata;
wire  [15:0]  readdata;
wire          write;
wire          read;
wire          clk_test;

//	SDRAM frame buffer
Sdram_Control	u2	(	//	HOST Side
						.REF_CLK(CLOCK_50),
						.RESET_N(test_software_reset_n),
						//	FIFO Write Side 
						.WR_DATA(writedata),
						.WR(write),
						.WR_ADDR(0),
						.WR_MAX_ADDR(25'h1ffffff),		//	
						.WR_LENGTH(9'h80),
						.WR_LOAD(!test_global_reset_n ),
						.WR_CLK(SDRAM_LOAD_CLK),
						//	FIFO Read Side 
						.RD_DATA(readdata),
						.RD(read),
						.RD_ADDR(0),			//	Read odd field and bypess blanking
						.RD_MAX_ADDR(25'h1ffffff),
						.RD_LENGTH(9'h80),
						.RD_LOAD(!test_global_reset_n ),
						.RD_CLK(SDRAM_LOAD_CLK),
						//	SDRAM Side
						.SA(DRAM_ADDR),
						.BA(DRAM_BA),
						.CS_N(DRAM_CS_N),
						.CKE(DRAM_CKE),
						.RAS_N(DRAM_RAS_N),
						.CAS_N(DRAM_CAS_N),
						.WE_N(DRAM_WE_N),
						.DQ(DRAM_DQ),
						.DQM({DRAM_UDQM,DRAM_LDQM}),
						.SDR_CLK(DRAM_CLK)
					);
							

wire  test_software_reset_n;
wire  test_global_reset_n;
wire  test_start_n;

wire  sdram_test_pass;
wire  sdram_test_fail;
wire  sdram_test_complete;

// pll_test u3	(	.refclk(CLOCK2_50),   //  refclk.clk
// 				.rst(1'b0),      //   reset.reset
// 				.outclk_0(clk_test), // outclk0.clk
// 				.outclk_1()  // outclk1.clk
// 			);

assign clk_test = SDRAM_LOAD_CLK;
	
wire [31:0] rw_addr;
wire [3:0]  c_state;
wire same;

assign LEDR[0] = done;
assign mSEG7_DIG[11:0] = c_state;

SdramFifoManager u4	(	.in_clk(clk_test),
						.in_reset(test_software_reset_n),
						.in_button(test_start_n),
						.write(write),
						.writedata(writedata),
						.readdata(readdata),
						.c_state(c_state),		
						.same(same),
						.done(done)
					);

//7 segment LUT

wire [23:0] mSEG7_DIG;

SEG7_LUT_6 			u5	(	.oSEG0(HEX0),
							   .oSEG1(HEX1),
							   .oSEG2(HEX2),
							   .oSEG3(HEX3),
								.oSEG4(HEX4),
								.oSEG5(HEX5),
							   .iDIG(mSEG7_DIG) );

endmodule
