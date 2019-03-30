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

// Native functions defined in jtag_socket.cpp
import "DPI-C" function int open_jtag_socket(input int port);
import "DPI-C" function int poll_jtag_request(output bit[31:0] instructionLength,
    output bit[31:0] instruction, output bit[31:0] dataLength, output bit[63:0] data);
import "DPI-C" function void send_jtag_response(input bit[31:0] instruction, input bit[63:0] data);

//
// This simulates a JTAG host. It proxies messages from an external test program
// over a socket. It uses DPI to call into native code (jtag_socket.cpp) that polls
// the socket for new messages.
//

module sim_jtag
    (input                     clk,
    jtag_interface.host        jtag);

    typedef enum int {
        JTAG_RESET,
        JTAG_IDLE,
        JTAG_SELECT_DR_SCAN,
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
    logic need_ir_shift;
    logic need_dr_shift;
    logic need_reset;

    initial
    begin
        int jtag_port;
        if ($value$plusargs("jtag_port=%d", jtag_port) != 0)
            control_port_open = open_jtag_socket(jtag_port);
        else
            control_port_open = 0;

        state_ff = JTAG_RESET;
        data_shift = '0;
        instruction_shift = '0;
        need_dr_shift = '0;
        need_ir_shift = '0;
        need_reset = '0;
        shift_count = '0;
        divider_count = 0;
    end

    always @(posedge clk)
    begin
        if (divider_count == 0)
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

    always @(posedge jtag.tck)
    begin
        if (control_port_open != 0 && !need_ir_shift && !need_dr_shift && !need_reset)
        begin
            // Check if we have a new messsage request in the socket
            // from the test harness
            if (poll_jtag_request(instruction_length, instruction,
                data_length, data) != 0)
            begin
                // Ensure test harness doesn't send bad lengths (these are unsigned)
                assert(instruction_length <= 32);
                assert(data_length <= MAX_DATA_LEN);

                // Specifying a zero length will cause the corresponding register
                // not to be shifted.
                if (instruction_length != 0)
                    need_ir_shift <= 1;

                if (data_length != 0)
                    need_dr_shift <= 1;

                if (instruction_length == 0 && data_length == 0)
                    need_reset <= 1;
            end
        end

        // Should not have need_reset set if there is a rest to send an IR
        // or DR register.
        assert(!need_reset || !(need_ir_shift || need_dr_shift));

        state_ff <= state_nxt;
        case (state_ff)
            JTAG_SELECT_DR_SCAN:
            begin
                // Should not enter this state unless we have something to do.
                assert(need_ir_shift || need_dr_shift || need_reset);
            end

            JTAG_CAPTURE_DR:
            begin
                shift_count <= data_length;
                data_shift <= data;
            end

            JTAG_SHIFT_DR:
            begin
                data_shift <= (data_shift >> 1) | (MAX_DATA_LEN'(jtag.tdi)
                    << (data_length - 1));
                shift_count <= shift_count - 1;
                assert(need_dr_shift);
                assert(shift_count > 0);
            end

            JTAG_UPDATE_DR:
            begin
                assert(shift_count == 0);
                send_jtag_response(instruction_shift, data_shift);
                need_dr_shift <= 0;
            end

            JTAG_SELECT_IR_SCAN:
            begin
                // Shouldn't get to this state unless we are about
                // to shift in a new IR or going to reset state.
                assert(need_ir_shift || need_reset);
                assert(!(need_ir_shift && need_reset));

                if (need_reset)
                begin
                    need_reset <= 0;
                    send_jtag_response(0, 0);
                end
            end

            JTAG_CAPTURE_IR:
            begin
                shift_count <= instruction_length;
                instruction_shift <= instruction;
            end

            JTAG_SHIFT_IR:
            begin
                instruction_shift <= (instruction_shift >> 1)
                    | (MAX_INSTRUCTION_LEN'(jtag.tdi)
                    << (instruction_length - 1));
                shift_count <= shift_count - 1;
                assert(need_ir_shift);
                assert(shift_count > 0);
            end

            JTAG_UPDATE_IR:
            begin
                assert(shift_count == 0);
                need_ir_shift <= 0;
                if (!need_dr_shift)
                begin
                    // There was an instruction, but no data
                    send_jtag_response(instruction_shift, 0);
                end
            end
        endcase
    end

    // The FSM is structured so it will always make progress if this returns 0.
    function random_transition();
        random_transition = ($random() & 1) == 0;
    endfunction

    always_comb
    begin
        state_nxt = state_ff;
        jtag.trst_n = 1;
        case (state_ff)
            JTAG_RESET:
            begin
                jtag.trst_n = 0;
                state_nxt = JTAG_IDLE;
                tms_nxt = 0;  // Go to idle state
            end

            JTAG_IDLE:
            begin
                // We may be here because already shifted the IR and
                // randomly returned to idle, or because we haven't shifted
                // the IR yet.
                if (need_ir_shift || need_dr_shift || need_reset)
                begin
                    state_nxt = JTAG_SELECT_DR_SCAN;
                    tms_nxt = 1;
                end
                else
                    tms_nxt = 0;
            end

            JTAG_SELECT_DR_SCAN:
            begin
                if (need_ir_shift || need_reset)
                begin
                    // Have to shift IR first
                    state_nxt = JTAG_SELECT_IR_SCAN;
                    tms_nxt = 1;
                end
                else
                begin
                    state_nxt = JTAG_CAPTURE_DR;
                    tms_nxt = 0;
                end
            end

            JTAG_CAPTURE_DR:
            begin
                if (random_transition())
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_EXIT1_DR;
                end
                else
                begin
                    tms_nxt = 0;
                    state_nxt = JTAG_SHIFT_DR;
                end
            end

            JTAG_SHIFT_DR:
            begin
                if (shift_count == 1 || random_transition())
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_EXIT1_DR;
                end
                else
                    tms_nxt = 0;
            end

            JTAG_EXIT1_DR:
            begin
                if (shift_count == 0 && !random_transition())
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_UPDATE_DR;
                end
                else
                begin
                    tms_nxt = 0;
                    state_nxt = JTAG_PAUSE_DR;
                end
            end

            JTAG_PAUSE_DR:
            begin
                if (random_transition())
                    tms_nxt = 0;
                else
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_EXIT2_DR;
                end
            end

            JTAG_EXIT2_DR:
            begin
                if (shift_count != 0)
                begin
                    tms_nxt = 0;
                    state_nxt = JTAG_SHIFT_DR;
                end
                else
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_UPDATE_DR;
                end
            end

            JTAG_UPDATE_DR:
            begin
                // XXX Since we always shift DR last and won't check for a new
                // message until back in idle, we always have to go back to idle.
                // This does not exercise the transition back to DR_SCAN.
                tms_nxt = 0;
                state_nxt = JTAG_IDLE;
            end

            JTAG_SELECT_IR_SCAN:
            begin
                if (need_ir_shift)
                begin
                    tms_nxt = 0;
                    state_nxt = JTAG_CAPTURE_IR;
                end
                else
                begin
                    // Reset
                    tms_nxt = 1;
                    state_nxt = JTAG_RESET;

                end
            end

            JTAG_CAPTURE_IR:
            begin
                if (random_transition())
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_EXIT1_IR;
                end
                else
                begin
                    tms_nxt = 0;
                    state_nxt = JTAG_SHIFT_IR;
                end
            end

            JTAG_SHIFT_IR:
            begin
                if (shift_count == 1 || random_transition())
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_EXIT1_IR;
                end
                else
                    tms_nxt = 0;
            end

            JTAG_EXIT1_IR:
            begin
                if (shift_count == 0 && !random_transition())
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_UPDATE_IR;
                end
                else
                begin
                    tms_nxt = 0;
                    state_nxt = JTAG_PAUSE_IR;
                end
            end

            JTAG_PAUSE_IR:
            begin
                if (random_transition())
                    tms_nxt = 0;
                else
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_EXIT2_IR;
                end
            end

            JTAG_EXIT2_IR:
            begin
                if (shift_count != 0)
                begin
                    tms_nxt = 0;
                    state_nxt = JTAG_SHIFT_IR;
                end
                else
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_UPDATE_IR;
                end
            end

            JTAG_UPDATE_IR:
            begin
                if (!need_dr_shift || random_transition())
                begin
                    tms_nxt = 0;
                    state_nxt = JTAG_IDLE;
                end
                else
                begin
                    tms_nxt = 1;
                    state_nxt = JTAG_SELECT_DR_SCAN;
                end
            end

            default:
                state_nxt = JTAG_RESET;
        endcase
    end
endmodule
