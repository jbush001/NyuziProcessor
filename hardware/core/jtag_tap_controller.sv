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

`include "defines.sv"

import defines::*;

//
// JTAG Test Access Point (TAP) controller.
// This contains the JTAG state machine logic.
//

module jtag_tap_controller
    #(parameter INSTRUCTION_WIDTH = 1)

    (input                                  clk,
    input                                   reset,

    // JTAG interface.
    // XXX for now, this assumes these are sychronized into this clock domain.
    jtag_interface.slave                    jtag,

    // Controller interface. data_shift_val is the value to be sent out
    // do when in data mode.
    input                                   data_shift_val,
    output logic                            capture_dr,
    output logic                            shift_dr,
    output logic                            update_dr,
    output logic[INSTRUCTION_WIDTH - 1:0]   instruction,
    output logic                            update_ir);

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

    jtag_state_t state_ff;
    jtag_state_t state_nxt;
    logic last_tck;
    logic tck_rising_edge;
    logic tck_falling_edge;

    always_comb
    begin
        state_nxt = state_ff;
        case (state_ff)
            JTAG_IDLE:
                if (jtag.tms)
                    state_nxt = JTAG_SELECT_DR_SCAN;

            JTAG_SELECT_DR_SCAN:
                if (jtag.tms)
                    state_nxt = JTAG_SELECT_IR_SCAN;
                else
                    state_nxt = JTAG_CAPTURE_DR;

            JTAG_CAPTURE_DR:
                if (jtag.tms)
                    state_nxt = JTAG_EXIT1_DR;
                else
                    state_nxt = JTAG_SHIFT_DR;

            JTAG_SHIFT_DR:
                if (jtag.tms)
                    state_nxt = JTAG_EXIT1_DR;

            JTAG_EXIT1_DR:
                if (jtag.tms)
                    state_nxt = JTAG_UPDATE_DR;
                else
                    state_nxt = JTAG_PAUSE_DR;

            JTAG_PAUSE_DR:
                if (jtag.tms)
                    state_nxt = JTAG_EXIT2_DR;

            JTAG_EXIT2_DR:
                if (jtag.tms)
                    state_nxt = JTAG_UPDATE_DR;
                else
                    state_nxt = JTAG_SHIFT_DR;

            JTAG_UPDATE_DR:
                state_nxt = JTAG_IDLE;

            JTAG_SELECT_IR_SCAN:
                if (jtag.tms)
                    state_nxt = JTAG_IDLE;
                else
                    state_nxt = JTAG_CAPTURE_IR;

            JTAG_CAPTURE_IR:
                if (jtag.tms)
                    state_nxt = JTAG_EXIT1_IR;
                else
                    state_nxt = JTAG_SHIFT_IR;

            JTAG_SHIFT_IR:
                if (jtag.tms)
                    state_nxt = JTAG_EXIT1_IR;

            JTAG_EXIT1_IR:
                if (jtag.tms)
                    state_nxt = JTAG_UPDATE_IR;
                else
                    state_nxt = JTAG_PAUSE_IR;

            JTAG_PAUSE_IR:
                if (jtag.tms)
                    state_nxt = JTAG_EXIT2_IR;

            JTAG_EXIT2_IR:
                if (jtag.tms)
                    state_nxt = JTAG_UPDATE_IR;
                else
                    state_nxt = JTAG_SHIFT_IR;

            JTAG_UPDATE_IR:
                if (jtag.tms)
                    state_nxt = JTAG_SELECT_DR_SCAN;
                else
                    state_nxt = JTAG_IDLE;

            JTAG_RESET:
                if (!jtag.tms)
                    state_nxt = JTAG_IDLE;

            default:
                state_nxt = JTAG_RESET;
        endcase
    end

    assign tck_rising_edge = !last_tck && jtag.tck;
    assign tck_falling_edge = last_tck && !jtag.tck;

    assign update_ir = state_ff == JTAG_UPDATE_IR && tck_rising_edge;
    assign capture_dr = state_ff == JTAG_CAPTURE_DR && tck_rising_edge;
    assign shift_dr = state_ff == JTAG_SHIFT_DR && tck_rising_edge;
    assign update_dr = state_ff == JTAG_UPDATE_DR && tck_rising_edge;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            state_ff <= JTAG_RESET;
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            instruction <= '0;
            jtag.tdo <= '0;
            last_tck <= '0;
            // End of automatics
        end
        else if (!jtag.trst_n)
        begin
            state_ff <= JTAG_RESET;
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            instruction <= '0;
            jtag.tdo <= '0;
            last_tck <= '0;
            // End of automatics
        end
        else
        begin
            last_tck <= jtag.tck;
            if (tck_rising_edge)
            begin
                state_ff <= state_nxt;
                if (state_ff == JTAG_SHIFT_IR)
                    instruction <= { jtag.tdi, instruction[INSTRUCTION_WIDTH - 1:1] };
            end
            else if (tck_falling_edge)
                jtag.tdo <= state_ff == JTAG_SHIFT_IR ? instruction[0] : data_shift_val;
        end
    end
endmodule
