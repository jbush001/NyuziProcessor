//
// Copyright 2017 Jeff Bush
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

import "DPI-C" function int init_jtag_socket(input int port);
import "DPI-C" function int poll_jtag_message(output bit[31:0] instructionLength,
    output bit[31:0] instruction, output bit[31:0] dataLength, output bit[63:0] data);
import "DPI-C" function int send_jtag_response(input bit[63:0] data);

//
// This simulates a JTAG host. It proxies messages from an external test program
// over a socket. It uses DPI to call into native code (jtag_socket.cpp) that polls
// the socket for new messages.
//

module sim_jtag
    (input                     clk,
    input                      reset,
    jtag_interface.master      jtag);

    typedef enum int {
        JTAG_RESET,
        JTAG_IDLE,
        JTAG_SELECT_DR_SCAN1,
        JTAG_SELECT_DR_SCAN2,
        JTAG_CAPTURE_DR,
        JTAG_SHIFT_DR,
        JTAG_EXIT1_DR,
        JTAG_PAUSE_DR,
        JTAG_EXIT2_DR,
        JTAG_UPDATE_DR,
        JTAG_SELECT_IR_SCAN,
        JTAG_CAPTURE_IR,
        JTAG_SHIFT_IR,
        JTAG_EXIT1_IR,
        JTAG_PAUSE_IR,
        JTAG_EXIT2_IR,
        JTAG_UPDATE_IR
    } jtag_state_t;

    localparam MAX_DATA_LEN = 64;
    localparam MAX_INSTRUCTION_LEN = 32;
    localparam CLOCK_DIVISOR = 7;

    int control_port_open;
    bit[31:0] instruction_length;
    bit[MAX_INSTRUCTION_LEN - 1:0] instruction;
    bit[31:0] data_length;
    bit[MAX_DATA_LEN - 1:0] data;
    bit[MAX_INSTRUCTION_LEN - 1:0] instruction_shift;
    bit[MAX_DATA_LEN - 1:0] data_shift;
    int shift_count;
    jtag_state_t state_ff = JTAG_RESET;
    jtag_state_t state_nxt;
    int divider_count;
    logic tms_nxt;

    initial
    begin
	// XXX workaround: if jtag_port is less than 64 bits, the
	// generated program will crash with a stack clobber assert.
	// This happens even if jtag port is a module level variable.
        logic[63:0] jtag_port;
        if ($value$plusargs("jtag_port=%d", jtag_port) != 0)
            control_port_open = init_jtag_socket(32'(jtag_port));
        else
            control_port_open = 0;
    end

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            divider_count <= 0;
        else if (divider_count == 0)
        begin
            jtag.tck <= !jtag.tck;
            divider_count <= CLOCK_DIVISOR;
        end
        else
            divider_count <= divider_count - 1;
    end

    // Set up outgoing signals on falling edge
    always @(negedge jtag.tck)
    begin
        if (state_ff == JTAG_SHIFT_DR)
            jtag.tdo <= data_shift[0];
        else
            jtag.tdo <= instruction_shift[0];

        jtag.tms <= tms_nxt;
    end

    always @(posedge jtag.tck, posedge reset)
    begin
        if (reset)
            state_ff <= JTAG_RESET;
        else
        begin
            state_ff <= state_nxt;
            case (state_ff)
                JTAG_CAPTURE_DR:
                begin
                    shift_count <= data_length;
                    data_shift <= data;
                end

                JTAG_CAPTURE_IR:
                begin
                    shift_count <= instruction_length;
                    instruction_shift <= instruction;
                end

                JTAG_SHIFT_DR:
                begin
                    data_shift <= (data_shift >> 1) | (MAX_DATA_LEN'(jtag.tdi)
                        << (data_length - 1));
                    shift_count <= shift_count - 1;
                end

                JTAG_SHIFT_IR:
                begin
                    instruction_shift <= (instruction_shift >> 1)
                        | (MAX_INSTRUCTION_LEN'(jtag.tdi)
                        << (instruction_length - 1));
                    shift_count <= shift_count - 1;
                end
            endcase
        end
    end

    always_comb
    begin
        state_nxt = state_ff;
        jtag.trst = 0;
        case (state_ff)
            JTAG_RESET:
            begin
                jtag.trst = 1;
                state_nxt = JTAG_IDLE;
                tms_nxt = 0;  // Go to idle state
            end

            JTAG_IDLE:
            begin
                if (control_port_open != 0)
                begin
                    if (poll_jtag_message(instruction_length, instruction, data_length, data) != 0)
                    begin
                        state_nxt = JTAG_SELECT_DR_SCAN1;
                        tms_nxt = 1;
                    end
                    else
                        tms_nxt = 0;
                end
                else
                    tms_nxt = 0;
            end

            // First time we go through this state, we jump to IR scan to load
            // the instruction
            JTAG_SELECT_DR_SCAN1:
            begin
                state_nxt = JTAG_SELECT_IR_SCAN;
                tms_nxt = 1;
            end

            // Go through this state again and go through the DR load
            JTAG_SELECT_DR_SCAN2:
            begin
                state_nxt = JTAG_CAPTURE_DR;
                tms_nxt = 0;
            end

            JTAG_CAPTURE_DR:
            begin
                state_nxt = JTAG_SHIFT_DR;
                tms_nxt = 0;
            end

            JTAG_SHIFT_DR:
            begin
                if (shift_count == 1)
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_EXIT1_DR;
                end
                else
                    tms_nxt = 0;
            end

            JTAG_EXIT1_DR:
            begin
                tms_nxt = 0;
                state_nxt = JTAG_PAUSE_DR;
            end

            JTAG_PAUSE_DR:
            begin
                tms_nxt = 1;
                state_nxt = JTAG_EXIT2_DR;
            end

            JTAG_EXIT2_DR:
            begin
                tms_nxt = 1;
                state_nxt = JTAG_UPDATE_DR;
            end

            JTAG_UPDATE_DR:
            begin
                tms_nxt = 0;
                send_jtag_response(data_shift);
                state_nxt = JTAG_IDLE;
            end

            JTAG_SELECT_IR_SCAN:
            begin
                tms_nxt = 0;
                state_nxt = JTAG_CAPTURE_IR;
            end

            JTAG_CAPTURE_IR:
            begin
                tms_nxt = 0;
                state_nxt = JTAG_SHIFT_IR;
            end

            JTAG_SHIFT_IR:
            begin
                if (shift_count == 1)
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_EXIT1_IR;
                end
                else
                    tms_nxt = 0;
            end

            JTAG_EXIT1_IR:
            begin
                tms_nxt = 0;
                state_nxt = JTAG_PAUSE_IR;
            end

            JTAG_PAUSE_IR:
            begin
                tms_nxt = 1;
                state_nxt = JTAG_EXIT2_IR;
            end

            JTAG_EXIT2_IR:
            begin
                tms_nxt = 1;
                state_nxt = JTAG_UPDATE_IR;
            end

            JTAG_UPDATE_IR:
            begin
                tms_nxt = 1;
                state_nxt = JTAG_SELECT_DR_SCAN2;
            end

            default:
                state_nxt = JTAG_RESET;
        endcase
    end
endmodule
