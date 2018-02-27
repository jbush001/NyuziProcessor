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
// Simulates SPI mode SD card. When the simulator is initialized, it opens the
// file specified by the argument +block=<filename>
// https://www.sdcard.org/downloads/pls/pdf/index.php?p=Part1_Physical_Layer_Simplified_Specification_Ver6.00.jpg
//

module sim_sdmmc(
    input            sd_sclk,
    input            sd_cs_n,
    input            sd_di,
    output logic     sd_do);

    localparam INIT_CLOCKS = 72;
    localparam DATA_TOKEN = 8'hfe;
    localparam MAX_BLOCK_LEN = 'd512;

    typedef enum int {
        STATE_INIT_WAIT_FOR_CLOCKS,
        STATE_IDLE,
        STATE_RECEIVE_COMMAND,
        STATE_READ_CMD_RESPONSE,
        STATE_READ_DATA_TOKEN,
        STATE_RESULT,
        STATE_READ_TRANSFER,
        STATE_WRITE_CMD_RESPONSE,
        STATE_WRITE_DATA_TOKEN,
        STATE_WRITE_TRANSFER,
        STATE_WRITE_DATA_RESPONSE
    } sd_state_t;

    // SD commands
    localparam CMD_GO_IDLE_STATE = 0;
    localparam CMD_SEND_OP_COND = 1;
    localparam CMD_SET_BLOCKLEN = 16;
    localparam CMD_READ_SINGLE_BLOCK = 17;
    localparam CMD_WRITE_SINGLE_BLOCK = 24;

    logic[1000:0] filename;
    int shift_count;
    logic[7:0] mosi_byte_nxt;    // Master Out/Slave In
    logic[7:0] mosi_byte_ff;
    logic[7:0] miso_byte;        // Master In/Slave Out
    sd_state_t current_state;
    int state_delay;
    int transfer_address;
    int transfer_count;
    int block_length;
    int init_clock_count;
    logic card_ready;
    logic[7:0] command[6];
    int command_length;
    logic[7:0] command_result;
    logic[7:0] block_buffer[MAX_BLOCK_LEN];
    integer block_fd;

    initial
    begin
        // Load data
        if ($value$plusargs("block=%s", filename) != 0)
        begin
            block_fd = $fopen(filename, "r+");
            if (block_fd == 0)
            begin
                $display("couldn't open block device");
                $finish;
            end
        end
        else
            block_fd = -1;

        current_state = STATE_INIT_WAIT_FOR_CLOCKS;
        mosi_byte_ff = 0;
        shift_count = 0;
        init_clock_count = 0;
        card_ready = 0;
        miso_byte = 'hff;
    end

    final
    begin
        if (block_fd != -1)
            $fclose(block_fd);
    end

    assign mosi_byte_nxt = {mosi_byte_ff[6:0], sd_di};

    // Shift out data on the falling edge of SD clock
    always_ff @(negedge sd_sclk)
        sd_do <= miso_byte[7 - shift_count];

    task process_receive_byte;
        mosi_byte_ff <= 0;    // Helpful for debugging
        shift_count <= 0;

        case (current_state)
            STATE_INIT_WAIT_FOR_CLOCKS:
            begin
                // Bug in this module: shouldn't process commands until
                // initialization
                assert(0);
                $finish;
            end

            STATE_IDLE:
            begin
                if (mosi_byte_nxt[7:6] == 2'b01)
                begin
                    current_state <= STATE_RECEIVE_COMMAND;
                    command[0] <= mosi_byte_nxt;
                    command_length <= 1;
                end
            end

            STATE_RECEIVE_COMMAND:
            begin
                command[command_length] <= mosi_byte_nxt;
                if (command_length == 5)
                begin
                    case (command[0] & 8'h3f)
                        CMD_GO_IDLE_STATE:
                        begin
                            // Still in native SD mode, checksum needs to be correct
                            assert(command[1] == 0);
                            assert(command[2] == 0);
                            assert(command[3] == 0);
                            assert(command[4] == 0);
                            assert(mosi_byte_nxt == 8'h95);

                            // Reset the card
                            card_ready <= 1;
                            current_state <= STATE_RESULT;
                            command_result <= 1;
                        end

                        CMD_SEND_OP_COND:
                        begin
                            current_state <= STATE_RESULT;
                            command_result <= 0;
                        end

                        CMD_READ_SINGLE_BLOCK:
                        begin
                            assert(card_ready);
                            current_state <= STATE_READ_CMD_RESPONSE;
                            state_delay <= $random() & 'h7;    // Simulate random delay
                            command_result <= 1;
                            miso_byte <= 'hff;    // wait
                            transfer_count <= 0;

`ifdef VERILATOR
                            $c("fseek(VL_CVT_I_FP(", block_fd, "), ",
                                {command[1], command[2], command[3], command[4]} * block_length,
                                ", SEEK_SET);");
                            $c("fread(", block_buffer, ", 1, ", block_length, ", VL_CVT_I_FP(", block_fd, "));");
`else
                            // May require tweaking for other simulators...
                            $fseek(block_fd, {command[1], command[2], command[3], command[4]}
                                * block_length, 0);
                            $fread(block_fd, block_buffer, 0, block_length);
`endif
                        end

                        CMD_SET_BLOCKLEN:
                        begin
                            assert(card_ready);
                            state_delay <= 5;
                            current_state <= STATE_RESULT;
                            block_length <= {command[1], command[2], command[3], command[4]};
                            if (block_length > MAX_BLOCK_LEN)
                            begin
                                $display("CMD_SET_BLOCKLEN: block size is too large. Modify MAX_BLOCK_LEN in sim_sdmmc.sv");
                                $finish;
                            end
                        end

                        CMD_WRITE_SINGLE_BLOCK:
                        begin
                            assert(card_ready);
                            current_state <= STATE_WRITE_CMD_RESPONSE;
                            state_delay <= $random() & 'h7;    // Simulate random delay
                            command_result <= 1;
                            transfer_address <= {command[1], command[2], command[3], command[4]}
                                * block_length;
                            transfer_count <= 0;
                            miso_byte <= 'hff;    // wait
                        end

                        default:
                        begin
                            $display("invalid command %02x", command[0]);
                            current_state <= STATE_IDLE;
                        end
                    endcase
                end
                else
                    command_length <= command_length + 1;
            end

            STATE_RESULT:
            begin
                miso_byte <= command_result;
                current_state <= STATE_IDLE;
            end

            STATE_READ_CMD_RESPONSE:
            begin
                if (state_delay == 0)
                begin
                    current_state <= STATE_READ_DATA_TOKEN;
                    miso_byte <= 0; // Ready
                    state_delay <= $random() & 'h7;    // Simulate random delay
                end
                else
                    state_delay <= state_delay - 1;
            end

            STATE_READ_DATA_TOKEN:
            begin
                if (state_delay == 0)
                begin
                    current_state <= STATE_READ_TRANSFER;
                    miso_byte <= DATA_TOKEN;
                    state_delay <= block_length + 2;    // block length + 2 checksum bytes
                end
                else
                begin
                    miso_byte <= 8'hff;
                    state_delay <= state_delay - 1;
                end
            end

            STATE_READ_TRANSFER:
            begin
                state_delay <= state_delay - 1;
                if (state_delay <= 2)
                begin
                    // 16 bit checksum (ignored)
                    miso_byte <= 'hff;
                end
                else
                begin
                    transfer_count <= transfer_count + 1;
                    miso_byte <= block_buffer[transfer_count];
                end

                if (state_delay == 0)
                    current_state <= STATE_IDLE;
            end

            STATE_WRITE_CMD_RESPONSE:
            begin
                if (state_delay == 0)
                begin
                    current_state <= STATE_WRITE_DATA_TOKEN;
                    miso_byte <= 0; // Ready
                    state_delay <= $random() & 'h7;    // Simulate random delay
                end
                else
                begin
                    state_delay <= state_delay - 1;
                    miso_byte <= 8'hff;
                end
            end

            STATE_WRITE_DATA_TOKEN:
            begin
                if (mosi_byte_nxt == DATA_TOKEN)
                begin
                    state_delay <= block_length + 1;
                    current_state <= STATE_WRITE_TRANSFER;
                end
            end

            STATE_WRITE_TRANSFER:
            begin
                state_delay <= state_delay - 1;
                if (state_delay > 1)
                begin
                    transfer_count <= transfer_count + 1;
                    assert(transfer_count < block_length);
                    block_buffer[transfer_count] <= mosi_byte_nxt;
                end
                // else ignore checksum from host

                if (state_delay == 0)
                begin
                    assert(transfer_count == block_length);
                    miso_byte <= 8'h05; // Data accepted
                    current_state <= STATE_WRITE_DATA_RESPONSE;
                end
                else
                    miso_byte <= 8'hff;
            end

            STATE_WRITE_DATA_RESPONSE:
            begin
                current_state <= STATE_IDLE;
                miso_byte <= 8'hff;

`ifdef VERILATOR
                // .Verilator doesn't support $fseek
                $c("fseek(VL_CVT_I_FP(", block_fd, "), ", transfer_address, ", SEEK_SET);");
                $c("fwrite(", block_buffer, ", 1, ", block_length, ", VL_CVT_I_FP(",
                    block_fd, "));");
`else
                // May require tweaking for other simulators...
                $fseek(block_fd, transfer_address, 0);
                $fwrite(block_fd, block_buffer, 0, block_length);
`endif
            end
        endcase
    endtask

    // This is 'always' instead of 'always_ff' because there is an initial
    // statement to initialize variables, which is not compatible with
    // always_ff according to SystemVerilog standard (was causing errors
    // on some simulators otherwise).
    always @(posedge sd_sclk)
    begin
        if (current_state == STATE_INIT_WAIT_FOR_CLOCKS)
        begin
            // 6.4.1 "The host shall...start to supply at least 74 SD clocks
            // to the SD card with keeping CMD [DI] line to high. In case of SPI
            // mode, CS shall be held to high during 74 clock cycles."
            if (sd_cs_n && sd_di)
            begin
                init_clock_count <= init_clock_count + 1;
                if (init_clock_count >= INIT_CLOCKS)
                    current_state <= STATE_IDLE;
            end
        end
        else if (!sd_cs_n)
        begin
            assert(shift_count <= 7);
            if (shift_count == 7)
            begin
                miso_byte <= 'hff;    // Default, process_receive_byte may change
                process_receive_byte;
            end
            else
            begin
                shift_count <= shift_count + 1;
                mosi_byte_ff <= mosi_byte_nxt;
            end
        end
        else
            shift_count <= 0;    // Cancel byte if SD is deasserted
    end
endmodule


