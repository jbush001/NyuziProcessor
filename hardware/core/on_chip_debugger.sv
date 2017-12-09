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
// On chip debugger (OCD) controller.
//
// This acts as an interface between an external host and the cores and exposes
// debugging functionality like reading and writing memory and registers.
// It works by allowing the host to inject instructions into a core's
// instruction pipeline, and enabling bidirectional data transfer between the
// host and target.
//
// This is experimental and a work in progress.
//
//  Limitations:
//  - If an instruction has to be rolled back (for example, cache miss), this
//    will not automatically restart it. There is no way for the host to know
//    this has happened.
//  - If the instruction queue is full when this attempts to inject one, the
//    instruction will be lost.
//  - When the halt signal is asserted, the processor will stop fetching new
//    instructions, but any instructions already in the pipeline or in instruction
//    queues will complete over subsequent cycles.
//  - As such, there's no way to immediately halt when an exception occurs.
//  - There's no provision for single stepping.
//  - This can't execute in "monitor mode," as the processor must be halted for it
//    to work.
//  - Halting between two issues of an uninterruptable instruction (sync memory op,
//    or I/O memory transfer), can put the processor into a bad state.
//  - Halting during a multi-cycle instruction (scatter/gather memory access)
//    causes undefined behavior.
//

module on_chip_debugger
    (input                          clk,
    input                           reset,

    // JTAG interface
    jtag_interface.target            jtag,

    // To/From Cores
    output logic                    dbg_halt,
    output local_thread_idx_t       dbg_thread,
    output core_id_t                dbg_core,
    output scalar_t                 dbg_instruction_inject,
    output logic                    dbg_instruction_inject_en,
    output scalar_t                 dbg_data_from_host,
    output logic                    dbg_data_update,
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
        INST_IDCODE = 4'd0,
        INST_EXTEST = 4'd1,
        INST_INTEST = 4'd2,
        INST_CONTROL = 4'd3,
        INST_INJECT_INST = 4'd4,
        INST_TRANSFER_DATA = 4'd5,
        INST_BYPASS = 4'd15
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

    // When dbg_data_update is asserted, the JTAG_DATA control register
    // will receive the value that was shifted into the TRANSFER_DATA
    // JTAG register.
    assign dbg_data_from_host = data_shift_reg;
    assign dbg_data_update = update_dr && instruction == INST_TRANSFER_DATA;

    always @(posedge clk)
    begin
        if (capture_dr)
        begin
            case (instruction)
                INST_IDCODE: data_shift_reg <= `JTAG_ID;
                INST_CONTROL: data_shift_reg <= 32'(control);
                INST_TRANSFER_DATA: data_shift_reg <= data_to_host;
                default: data_shift_reg <= '0;
            endcase
        end
        else if (shift_dr)
        begin
            case (instruction)
                INST_BYPASS: data_shift_reg <= 32'(jtag.tdi);
                INST_CONTROL: data_shift_reg <= 32'({jtag.tdi, data_shift_reg[$bits(debug_control_t) - 1:1]});
                // Default covers any 32 bit transfer (most instructions)
                default: data_shift_reg <= 32'({jtag.tdi, data_shift_reg[31:1]});
            endcase
        end
        else if (update_dr)
        begin
            if (instruction == INST_INJECT_INST)
                dbg_instruction_inject <= data_shift_reg;
        end
    end
endmodule
