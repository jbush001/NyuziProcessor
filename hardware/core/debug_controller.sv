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
// The debug controller acts as an interface between an external
// host and the cores. It allows the host to inject instructions into
// a core's instruction pipeline, and allows bidirectional data transfer
// between the host and target.
//

module debug_controller
    (input                          clk,
    input                           reset,

    // JTAG interface
    jtag_interface.slave            jtag,

    // To/From Cores
    output logic                    dbg_halt,
    output local_thread_idx_t       dbg_thread,
    output core_id_t                dbg_core,
    output scalar_t                 dbg_instruction_inject,
    output logic                    dbg_instruction_inject_en,
    output scalar_t                 dbg_data_from_host,
    input scalar_t                  data_to_host);

    typedef struct packed {
        core_id_t core;
        local_thread_idx_t thread;
        logic halt;
    } debug_control_t;

    logic data_shift_val;
    logic[31:0] data_shift_reg;
    debug_control_t control;
    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    logic               capture_dr;             // From jtag_tap_controller of jtag_tap_controller.v
    logic [3:0]         instruction;            // From jtag_tap_controller of jtag_tap_controller.v
    logic               shift_dr;               // From jtag_tap_controller of jtag_tap_controller.v
    logic               update_dr;              // From jtag_tap_controller of jtag_tap_controller.v
    logic               update_ir;              // From jtag_tap_controller of jtag_tap_controller.v
    // End of automatics

    assign dbg_halt = control.halt;
    assign dbg_thread = control.thread;
    assign dbg_core = control.core;

    jtag_tap_controller #(.INSTRUCTION_WIDTH(4)) jtag_tap_controller(
        .jtag(jtag),
        .*);

    typedef enum logic[3:0] {
        INST_IDCODE = 0,
        INST_EXTEST = 1,
        INST_INTEST = 2,
        INST_CONTROL = 3,
        INST_INJECT_INST = 4,
        INST_READ_DATA = 5,
        INST_WRITE_DATA = 6,
        INST_BYPASS = 15
    } instruction_t;

    assign data_shift_val = data_shift_reg[0];
    assign dbg_instruction_inject_en = update_dr && instruction == INST_INJECT_INST;

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            control <= '0;
        else if (update_dr && instruction == INST_CONTROL)
            control <= debug_control_t'(data_shift_reg);
    end

    always @(posedge clk)
    begin
        if (capture_dr)
        begin
            case (instruction)
                INST_IDCODE: data_shift_reg <= `JTAG_ID;
                INST_CONTROL: data_shift_reg <= 32'(control);
                INST_READ_DATA: data_shift_reg <= data_to_host;
                default: data_shift_reg <= '0;
            endcase
        end
        else if (shift_dr)
        begin
            case (instruction)
                INST_BYPASS: data_shift_reg <= 32'(jtag.tdi);
                INST_CONTROL: data_shift_reg <= 32'({ jtag.tdi, data_shift_reg[$bits(debug_control_t) - 1:1] });
                // Default covers any 32 bit transfer (most instructions)
                default: data_shift_reg <= 32'({ jtag.tdi, data_shift_reg[31:1] });
            endcase
        end
        else if (update_dr)
        begin
            if (instruction == INST_WRITE_DATA)
                dbg_data_from_host <= data_shift_reg;
            else if (instruction == INST_INJECT_INST)
                dbg_instruction_inject <= data_shift_reg;
        end
    end
endmodule
