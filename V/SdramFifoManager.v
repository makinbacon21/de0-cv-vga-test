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
	stupid_write_addr,
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
output  [ADDR_W-1:0]	stupid_write_addr;

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
reg		[18:0]			rom_addr;
reg						done;
reg		[ADDR_W-1:0]	stupid_write_addr;
reg		[31:0]			cal_data, clk_cnt;

assign max_address = address >= 76800;

// instantiate rom
img_data	img_data_inst	(	.address ( rom_addr ),
								.clock ( in_clk ),
								.q ( current_rom_output )
							);

always @(posedge in_clk) begin
	if (!in_reset) begin 
		pre_button <= 2'b11;
		trigger <= 1'b0;
		write_count <= 5'b0;
		c_state <= 4'b0;
		write <= 1'b0;
		writedata <= 16'b0;
		stupid_write_addr <= { ADDR_W{ 1'b0 } };
		done <= 0;
		rom_addr<=19'd0;
	end else begin
		pre_button <= {pre_button[0], in_button};
		trigger <= !pre_button[0] && pre_button[1];

		case (c_state)
			0 : begin //idle
				done <= 1'b0;
				address <= { ADDR_W{ 1'b0 } };

				c_state <= 1;
			end
			1 : begin //write
				write <= 1'b1;
				stupid_write_addr <= address;
				writedata <= current_rom_output;
				c_state <= 4'd2;
				rom_addr<=rom_addr+1;
			end
			2 : begin //finish write one data
					write <= 1'b0;
					c_state <= 4'd3;
				end
			3 : begin
				if (max_address) //finish write all(burst) 
				begin
					address <=  { ADDR_W{ 1'b0 } };
					rom_addr<=19'd0;
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
