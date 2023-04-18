/* SPDX-License-Identifier: MIT
 *
 * SdramFifoManager
 *
 * Reference code from Terasic Technologies under permission as per license in main
 * file--for use only in Terasic Development Boards and Altera Development Kits made
 * by Terasic
 *
 * Copyright (c) 2023 Thomas Makin, Zachary Robinson, Alex Skeldon, George Fang
 *
 */

module SdramFifoManager (
	in_clk,
	in_reset,
	in_button,
	write,
	writedata,
	readdata,
	c_state,
	same,
	done
);

parameter	ADDR_W	=	25;
parameter	DATA_W	=	16;

// control inputs
input					in_clk;
input					in_reset;
input					in_button;

// data lines
output					write;
output	[DATA_W-1:0]	writedata;
input	[DATA_W-1:0]	readdata;

// states
output         			same;
output	[3:0] 			c_state;
output					done;

// signal defs
reg		[1:0]			pre_button;
reg						trigger;
reg		[3:0]			c_state;		
reg						write;
reg		[ADDR_W-1:0]	address;  
reg		[DATA_W-1:0]	writedata;
reg		[4:0]			write_count;
wire					max_address;
wire					same;
wire	[7:0]			current_rom_output;
reg		[18:0]			ADDR;
reg						done;
reg		[31:0]			cal_data, clk_cnt;

assign max_address = address >= 76800;
assign same = readdata == writedata;

// incr addr on clock and reset to 0 on reset
always @(posedge in_clk, negedge in_reset)
begin
	// write regardless lol
	if (!in_reset)
		ADDR<=19'd0;
	else
		ADDR<=ADDR+1;
end

// instantiate rom
img_data	img_data_inst	(	.address ( ADDR ),
								.clock ( in_clk ),
								.q ( current_rom_output )
							);

always @(posedge in_clk) begin
	if (!in_reset)
		clk_cnt <= 32'b0;
	else  
		clk_cnt <= clk_cnt + 32'b1;
end

always @(posedge in_clk) begin
	if (!in_reset) begin 
		pre_button <= 2'b11;
		trigger <= 1'b0;
		write_count <= 5'b0;
		c_state <= 4'b0;
		write <= 1'b0;
		writedata <= 16'b0;
		done <= 0;
	end else begin
		pre_button <= {pre_button[0], in_button};
		trigger <= !pre_button[0] && pre_button[1];

		case (c_state)
			0 : begin //idle
				done <= 1'b0;
				address <= { ADDR_W{ 1'b0 } };

				if (trigger) begin
					c_state <= 4'd1;
					cal_data<=clk_cnt;
				end
			end
			1 : begin //write
				if (write_count[3]) begin
					write_count <= 5'b0;
					write <= 1'b1;
					writedata <= current_rom_output;
					c_state <= 4'd2;
				end else
					write_count <= write_count + 1'b1;
			end
			2 : begin //finish write one data
					write <= 1'b0;
					c_state <= 4'd3;
				end
			3 : begin
				if (max_address) //finish write all(burst) 
				begin
					address <=  { ADDR_W{ 1'b0 } };
					c_state <= 4'd10;
				end
			else //write the next data
				begin
					address <= address + 1'b1;
					c_state <= 4'd1;
				end
			end
				
			10 : c_state <= 4'd11;
			11 : done <= 1'b1;
			default : c_state <= 4'd0;
		endcase
	end
end

endmodule
