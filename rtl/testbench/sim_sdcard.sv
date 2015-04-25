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

module sim_sdcard(
	input            sd_sclk,
	input            sd_di,
	input            sd_cs_n,
	output logic     sd_do,	
	input            sd_wp_n);

	localparam MAX_BLOCK_DEVICE_SIZE = 'h800000;

	typedef enum logic[3:0] {
		SD_IDLE,
		SD_SET_READ_ADDRESS,
		SD_SET_BLOCK_LENGTH,
		SD_WAIT_READ_RESPONSE,
		SD_SEND_RESULT,
		SD_DO_READ
	} sd_state_t;

	logic[1000:0] filename;
	logic[31:0] block_device_data[MAX_BLOCK_DEVICE_SIZE];
	int block_device_read_offset;
	int shift_count;
	logic[7:0] mosi_byte_nxt;	// Master Out Slave In
	logic[7:0] mosi_byte_ff;
	logic[7:0] miso_byte;		// Master In Slave Out
	sd_state_t current_state;
	int state_count;
	int block_address;
	int block_length;

	initial
	begin
		// Load data
		if ($value$plusargs("block=%s", filename))
		begin
			integer fd;
			int offset;

			fd = $fopen(filename, "rb");
			offset = 0;
			while (!$feof(fd))
			begin
				block_device_data[offset][7:0] = $fgetc(fd);
				block_device_data[offset][15:8] = $fgetc(fd);
				block_device_data[offset][23:16] = $fgetc(fd);
				block_device_data[offset][31:24] = $fgetc(fd);
				offset++;
				
				if (offset >= MAX_BLOCK_DEVICE_SIZE)
				begin
					$display("block device too large, change MAX_BLOCK_DEVICE_SIZE");
					$finish;
				end
			end

			$fclose(fd);
			$display("read %0d into block device", offset * 4);
			block_device_read_offset = 0;
		end	
		
		current_state = SD_IDLE;
		mosi_byte_ff = 0;
		shift_count = 0;
	end

	always_comb
	begin
		if (current_state == SD_WAIT_READ_RESPONSE)
		begin
			if (state_count == 0)
				miso_byte = 0;	// Signal ready
			else
				miso_byte = 'hff; // Signal wait
		end
		else if (current_state == SD_SEND_RESULT)
			miso_byte = 0;	// Success (not busy)
		else
		begin
			if (state_count == 0)
				miso_byte = 'hff; // Checksum
			else
				miso_byte = block_device_data[block_address / 4][(block_address & 3)+:2];
		end
	end
	
	assign mosi_byte_nxt = { mosi_byte_ff[6:0], sd_di };

	// Shift out data on the falling edge of SD clock
	always_ff @(negedge sd_sclk)
		sd_do <= miso_byte[7 - shift_count];

	always_ff @(posedge sd_sclk)
	begin
		if (!sd_cs_n)
		begin
			assert(shift_count <= 7);
			if (shift_count == 7)
			begin
				mosi_byte_ff <= 0;	// Helpful for debugging
				shift_count <= 0;
				case (current_state)
					SD_IDLE:
					begin
						case (mosi_byte_nxt)
							'h57:	// CMD17, READ
							begin
								state_count <= 5;
								current_state <= SD_SET_READ_ADDRESS;
							end
							
							'h56:	// CMD16, Set block length
							begin
								state_count <= 5;
								current_state <= SD_SET_BLOCK_LENGTH;
							end
						endcase
					end
					
					SD_SET_READ_ADDRESS:
					begin
						if (state_count == 1)
						begin
							// Ignore checksum byte
							current_state <= SD_WAIT_READ_RESPONSE;
							state_count <= $random() & 'hf;	// Simulate random delay
						end
						else
						begin
							block_address <= (block_address << 8) | mosi_byte_nxt;
							state_count <= state_count - 1;
						end
					end

					SD_SET_BLOCK_LENGTH:
					begin
						if (state_count == 1)
						begin
							// Ignore checksum byte
							current_state <= SD_SEND_RESULT;
						end
						else
						begin
							state_count <= state_count - 1;
							block_length <= (block_length << 8) | mosi_byte_nxt;
						end
					end

					SD_SEND_RESULT:
						current_state <= SD_IDLE;

					SD_WAIT_READ_RESPONSE:
					begin	
						if (state_count == 0)
						begin
							current_state <= SD_DO_READ;
							state_count <= block_length;
						end
						else
							state_count <= state_count - 1;
					end
					
					SD_DO_READ:
					begin
						if (state_count == 0)
						begin
							// Ignore checksum byte
							current_state <= SD_IDLE;
						end
						else
						begin
							block_address <= block_address + 1;
							state_count <= state_count - 1;
						end
					end
				endcase
			end
			else
			begin
				shift_count <= shift_count + 1;
				mosi_byte_ff <= mosi_byte_nxt;	
			end
		end
	end
endmodule


