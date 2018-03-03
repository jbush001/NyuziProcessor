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
        STATE_INIT_WAIT,
        STATE_IDLE,
        STATE_RECEIVE_COMMAND,
        STATE_READ_CMD_RESPONSE,
        STATE_READ_DATA_TOKEN,
        STATE_SEND_R1,
        STATE_SEND_R3,
        STATE_SEND_R7,
        STATE_READ_TRANSFER,
        STATE_WRITE_CMD_RESPONSE,
        STATE_WRITE_DATA_TOKEN,
        STATE_WRITE_TRANSFER,
        STATE_WRITE_DATA_RESPONSE
    } sd_state_t;

    // SD commands
    localparam CMD_GO_IDLE_STATE = 0;
    localparam CMD_SEND_OP_COND = 1;
    localparam CMD_SEND_IF_COND = 8;
    localparam CMD_SET_BLOCKLEN = 16;
    localparam CMD_READ_SINGLE_BLOCK = 17;
    localparam CMD_WRITE_SINGLE_BLOCK = 24;
    localparam CMD_APP_OP_COND = 41;
    localparam CMD_APP_CMD = 55;

    logic[1000:0] filename;
    int shift_count;
    logic[7:0] mosi_byte_nxt;    // Master Out/Slave In
    logic[7:0] mosi_byte_ff;
    logic[7:0] miso_byte;        // Master In/Slave Out
    integer block_fd;
    sd_state_t current_state;
    int state_delay;
    int transfer_address;
    int transfer_count;
    int block_length;
    int init_clock_count;
    logic[7:0] command[6];
    logic in_idle_state;
    logic[7:0] check_pattern;
    logic[3:0] voltage;
    logic is_app_cmd;
    int command_length;
    logic[7:0] block_buffer[MAX_BLOCK_LEN];

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

        current_state = STATE_INIT_WAIT;
        mosi_byte_ff = 0;
        shift_count = 0;
        init_clock_count = 0;
        miso_byte = 'hff;
        in_idle_state = 0;
        block_length = 512;
        is_app_cmd = 0;
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

    task process_command;
        if (is_app_cmd)
        begin
            is_app_cmd <= 0;
            case (command[0] & 8'h3f)
                CMD_APP_OP_COND:
                begin
                    current_state <= STATE_SEND_R3;
                    transfer_count <= 0;
                    in_idle_state <= 0;
                end

                default:
                begin
                    $display("invalid command %d", command[0] & 8'h3f);
                    current_state <= STATE_IDLE;
                end
            endcase
        end
        else
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

                    in_idle_state <= 1;
                    current_state <= STATE_SEND_R1;
                end

                CMD_SEND_OP_COND:
                begin
                    current_state <= STATE_SEND_R1;
                    in_idle_state <= 0;
                end

                CMD_SEND_IF_COND:
                begin
                    current_state <= STATE_SEND_R7;
                    transfer_count <= 0;
                    voltage <= command[3][3:0];
                    check_pattern <= command[4];
                end

                CMD_SET_BLOCKLEN:
                begin
                    if (in_idle_state)
                    begin
                        $display("CMD_SET_BLOCKLEN: card not ready\n");
                        $finish;
                    end

                    block_length <= {command[1], command[2], command[3], command[4]};
                    current_state <= STATE_SEND_R1;
                    if (block_length > MAX_BLOCK_LEN)
                    begin
                        $display("CMD_SET_BLOCKLEN: block size is too large. Modify MAX_BLOCK_LEN in sim_sdmmc.sv");
                        $finish;
                    end
                end

                CMD_READ_SINGLE_BLOCK:
                begin
                    if (in_idle_state)
                    begin
                        $display("CMD_READ_SINGLE_BLOCK: card not ready\n");
                        $finish;
                    end

                    current_state <= STATE_READ_CMD_RESPONSE;
                    state_delay <= $random() & 'h7;    // Simulate random delay
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

                CMD_WRITE_SINGLE_BLOCK:
                begin
                    if (in_idle_state)
                    begin
                        $display("CMD_READ_SINGLE_BLOCK: card not ready\n");
                        $finish;
                    end

                    transfer_address <= {command[1], command[2], command[3], command[4]}
                        * block_length;
                    transfer_count <= 0;
                    current_state <= STATE_WRITE_CMD_RESPONSE;
                    state_delay <= $random() & 'h7;    // Simulate random delay
                end

                CMD_APP_CMD:
                begin
                    is_app_cmd <= 1;
                    current_state <= STATE_SEND_R1;
                end

                default:
                begin
                    $display("invalid command %d", command[0] & 8'h3f);
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    endtask

    task process_receive_byte;
        mosi_byte_ff <= 0;    // Helpful for debugging
        miso_byte <= 'hff;
        shift_count <= 0;

        case (current_state)
            STATE_INIT_WAIT:
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
                    process_command;
                else
                    command_length <= command_length + 1;
            end

            STATE_SEND_R1:
            begin
                miso_byte <= 8'(in_idle_state);
                current_state <= STATE_IDLE;
            end

            // 7.3.2.4
            STATE_SEND_R3:
            begin
                miso_byte <= 0;
                if (transfer_count == 0)
                    miso_byte <= 8'(in_idle_state);
                else if (transfer_count == 4)
                    current_state <= STATE_IDLE;

                transfer_count <= transfer_count + 1;
            end

            // 7.3.2.6
            STATE_SEND_R7:
            begin
                case (transfer_count)
                    0:  miso_byte <= 8'(1);
                    1, 2: miso_byte <= 0;
                    3: miso_byte <= 8'(voltage);
                    4:
                    begin
                        miso_byte <= check_pattern;
                        current_state <= STATE_IDLE;
                    end
                endcase

                transfer_count <= transfer_count + 1;
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
                    state_delay <= state_delay - 1;
            end

            STATE_READ_TRANSFER:
            begin
                if (transfer_count < block_length)
                    miso_byte <= block_buffer[transfer_count];
                else if (transfer_count == block_length + 1)
                    current_state <= STATE_IDLE;

                transfer_count <= transfer_count + 1;
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
                    state_delay <= state_delay - 1;
            end

            STATE_WRITE_DATA_TOKEN:
            begin
                if (mosi_byte_nxt == DATA_TOKEN)
                    current_state <= STATE_WRITE_TRANSFER;
            end

            STATE_WRITE_TRANSFER:
            begin
                if (transfer_count < block_length)
                    block_buffer[transfer_count] <= mosi_byte_nxt;
                else if (transfer_count == block_length + 1)
                begin
                    current_state <= STATE_WRITE_DATA_RESPONSE;
                    miso_byte <= 8'h05; // Data accepted
                end

                transfer_count <= transfer_count + 1;
            end

            STATE_WRITE_DATA_RESPONSE:
            begin
                current_state <= STATE_IDLE;

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
        if (current_state == STATE_INIT_WAIT)
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


