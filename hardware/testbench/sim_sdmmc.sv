// 
// Copyright 2015 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

//
// Simulates SPI mode SD card 
// XXX this is work in progress and is missing many commands
//

module sim_sdmmc(
	input            sd_sclk,
	input            sd_di,
	input            sd_cs_n,
	output logic     sd_do);

	localparam MAX_BLOCK_DEVICE_SIZE = 'h800000;
	localparam INIT_CLOCKS = 72;

	typedef enum int {
		SD_INIT_WAIT_FOR_CLOCKS,
		SD_IDLE,
		SD_RECEIVE_COMMAND,
		SD_WAIT_READ_RESPONSE,
		SD_SEND_RESULT,
		SD_DO_READ
	} sd_state_t;

	logic[1000:0] filename;
	logic[7:0] block_device_data[MAX_BLOCK_DEVICE_SIZE];
	int shift_count;
	logic[7:0] mosi_byte_nxt;	// Master Out Slave In
	logic[7:0] mosi_byte_ff;
	logic[7:0] miso_byte;		// Master In Slave Out
	sd_state_t current_state;
	int state_count;
	int read_address;
	int block_length;
	int init_clock_count;
	logic card_reset;
	logic[7:0] command[6];
	int command_length;
	logic[7:0] command_result;

	initial
	begin
		// Load data
		if ($value$plusargs("block=%s", filename) != 0)
		begin
			integer fd;
			int offset;

			fd = $fopen(filename, "rb");
			if (fd == 0)
			begin
				$display("couldn't open block device");
				$finish;
			end

			offset = 0;
			while (!$feof(fd))
			begin
				block_device_data[offset] = $fgetc(fd);
				offset++;
				if (offset >= MAX_BLOCK_DEVICE_SIZE)
				begin
					$display("block device too large, change MAX_BLOCK_DEVICE_SIZE");
					$finish;
				end
			end

			$fclose(fd);
			
			$display("read %0d into block device", offset - 1);
		end	

		current_state = SD_INIT_WAIT_FOR_CLOCKS;
		mosi_byte_ff = 0;
		shift_count = 0;
		init_clock_count = 0;
		card_reset = 0;
		miso_byte = 'hff;
	end
	
	assign mosi_byte_nxt = { mosi_byte_ff[6:0], sd_di };

	// Shift out data on the falling edge of SD clock
	always_ff @(negedge sd_sclk)
		sd_do <= miso_byte[7 - shift_count];

	task process_receive_byte;
		mosi_byte_ff <= 0;	// Helpful for debugging
		shift_count <= 0;
		case (current_state)
			SD_INIT_WAIT_FOR_CLOCKS:
			begin
				$display("command sent to SD card before initialized");
				$finish;
			end
		
			SD_IDLE:
			begin
				if (mosi_byte_nxt[7:6] == 2'b01)
				begin
					current_state <= SD_RECEIVE_COMMAND;
					command[0] <= mosi_byte_nxt;
					command_length <= 1;
				end
			end

			SD_RECEIVE_COMMAND:
			begin
				command[command_length] <= mosi_byte_nxt;
				if (command_length == 5)
				begin
					case (command[0])
						'h40:	// CMD0, reset
						begin
							card_reset <= 1;
							current_state <= SD_SEND_RESULT;
							command_result <= 1;
						end
					
						'h41:	// CMD1, initialize
						begin
							current_state <= SD_SEND_RESULT;
							command_result <= 0;
						end

						'h57:	// CMD17, read
						begin
							assert(card_reset);
							current_state <= SD_WAIT_READ_RESPONSE;
							state_count <= $random() & 'hf;	// Simulate random delay
							command_result <= 1;
							read_address <= { command[1], command[2], command[3], command[4] } 
								* block_length;
							miso_byte <= 'hff;	// wait
						end
					
						'h56:	// CMD16, Set block length
						begin
							assert(card_reset);
							state_count <= 5;
							current_state <= SD_SEND_RESULT;
							block_length <= { command[1], command[2], command[3], command[4] };
						end		
						
						default:
						begin
							$display("invalid command %02x", command[0]);
							current_state <= SD_IDLE;
						end					
					endcase
				end
				else
					command_length <= command_length + 1;
			end

			SD_SEND_RESULT:
			begin
				miso_byte <= command_result;
				current_state <= SD_IDLE;
			end

			SD_WAIT_READ_RESPONSE:
			begin	
				if (state_count == 0)
				begin
					current_state <= SD_DO_READ;
					miso_byte <= 0;
					state_count <= block_length + 2;	// block length + 2 checksum bytes
				end
				else
					state_count <= state_count - 1;
			end

			SD_DO_READ:
			begin
				state_count <= state_count - 1;
				if (state_count <= 2)
				begin
					// Transmit 16 bit checksum (ignored)
					miso_byte <= 'hff;
				end
				else
				begin
					read_address <= read_address + 1;
					miso_byte <= block_device_data[read_address];
				end
				
				if (state_count == 0)
					current_state <= SD_IDLE;
			end
		endcase	
	endtask

	always_ff @(posedge sd_sclk)
	begin
		if (sd_cs_n && current_state == SD_INIT_WAIT_FOR_CLOCKS)
		begin
			init_clock_count <= init_clock_count + 1;
			if (init_clock_count >= INIT_CLOCKS)
				current_state <= SD_IDLE;
		end
		else if (!sd_cs_n)
		begin
			assert(shift_count <= 7);
			if (shift_count == 7)
			begin
				miso_byte <= 'hff;	// Default, process_receive_byte may change
				process_receive_byte;
			end
			else
			begin
				shift_count <= shift_count + 1;
				mosi_byte_ff <= mosi_byte_nxt;	
			end
		end
		else
			shift_count <= 0;	// Cancel byte if SD is deasserted
	end
endmodule


