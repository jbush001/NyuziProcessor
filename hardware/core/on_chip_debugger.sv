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

`include "defines.svh"

import defines::*;

//
// On chip debugger (OCD) controller.
//
// This is experimental and a work in progress.
//
// This acts as an interface between an external JTAG host and the cores
// and exposes debugging functionality like reading and writing memory
// and registers. It works by allowing the host to inject instructions
// into a core's execution pipeline, and facilitating bidirectional data
// transfer between the host and target.
//
// There are two distinct types of signals labeled 'instruction' in this
// module: the contents of the JTAG instruction register, which determines
// the data register that is being transferred, and the machine instruction
// that is injected into the execution pipeline. Usually when comments
// refer to instructions, they mean the latter.
//
//  Limitations:
//  - If an instruction has to be rolled back (for example, cache miss), this
//    will not automatically restart it. The debugger should query the
//    status of the instruction and reissue it.
//  - If the instruction queue is full when this attempts to inject one, the
//    instruction will be lost. There's no way to detect this.
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

    jtag_interface.target           jtag,

    // To/From Cores
    output logic                    ocd_halt,
    output local_thread_idx_t       ocd_thread,
    output core_id_t                ocd_core,
    output scalar_t                 ocd_inject_inst,
    output logic                    ocd_inject_en,
    output scalar_t                 ocd_data_from_host,
    output logic                    ocd_data_update,
    input scalar_t                  data_to_host,
    input                           injected_complete,
    input                           injected_rollback);

    // JEDEC Standard Manufacturer's Identification Code standard, JEP-106
    // These constants are specified in config.sv
    localparam JTAG_IDCODE = {
        4'(`JTAG_PART_VERSION),
        16'(`JTAG_PART_NUMBER),
        11'(`JTAG_MANUFACTURER_ID),
        1'b1
    };

    typedef enum logic[1:0] {
        READY = 2'd0,
        ISSUED = 2'd1,
        ROLLED_BACK = 2'd2
    } machine_inst_status_t;

    typedef struct packed {
        core_id_t core;
        local_thread_idx_t thread;
        logic halt;
    } debug_control_t;

    typedef enum logic[3:0] {
        INST_IDCODE = 4'd0,
        INST_EXTEST = 4'd1,
        INST_INTEST = 4'd2,
        INST_CONTROL = 4'd3,
        INST_INJECT_INST = 4'd4,
        INST_TRANSFER_DATA = 4'd5,
        INST_STATUS = 4'd6,
        INST_BYPASS = 4'd15
    } jtag_instruction_t;

    logic data_shift_val;
    logic[31:0] data_shift_reg;
    debug_control_t control;
    machine_inst_status_t machine_inst_status;
    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    logic               capture_dr;             // From jtag_tap_controller of jtag_tap_controller.v
    logic [3:0]         jtag_instruction;       // From jtag_tap_controller of jtag_tap_controller.v
    logic               shift_dr;               // From jtag_tap_controller of jtag_tap_controller.v
    logic               update_dr;              // From jtag_tap_controller of jtag_tap_controller.v
    logic               update_ir;              // From jtag_tap_controller of jtag_tap_controller.v
    // End of automatics

    assign ocd_halt = control.halt;
    assign ocd_thread = control.thread;
    assign ocd_core = control.core;

    jtag_tap_controller #(.INSTRUCTION_WIDTH(4)) jtag_tap_controller(
        .jtag(jtag),
        .*);

    assign data_shift_val = data_shift_reg[0];
    assign ocd_inject_en = update_dr && jtag_instruction == INST_INJECT_INST;

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            control <= '0;
            machine_inst_status <= READY;
        end
        else
        begin
            if (update_dr && jtag_instruction == INST_CONTROL)
                control <= debug_control_t'(data_shift_reg);

            // Only one of these can be asserted
            assert($onehot0({injected_rollback, injected_complete}));

            if (injected_rollback)
                machine_inst_status <= ROLLED_BACK;
            else if (injected_complete)
                machine_inst_status <= READY;
            else if (update_dr && jtag_instruction == INST_INJECT_INST)
                machine_inst_status <= ISSUED;
        end
    end

    // When ocd_data_update is asserted, the JTAG_DATA control register
    // will receive the value that was shifted into the TRANSFER_DATA
    // JTAG register.
    assign ocd_data_from_host = data_shift_reg;
    assign ocd_data_update = update_dr && jtag_instruction == INST_TRANSFER_DATA;

    always @(posedge clk)
    begin
        if (capture_dr)
        begin
            unique case (jtag_instruction)
                INST_IDCODE: data_shift_reg <= JTAG_IDCODE;
                INST_CONTROL: data_shift_reg <= 32'(control);
                INST_TRANSFER_DATA: data_shift_reg <= data_to_host;
                INST_STATUS: data_shift_reg <= 32'(machine_inst_status);
                default: data_shift_reg <= '0;
            endcase
        end
        else if (shift_dr)
        begin
            unique case (jtag_instruction)
                INST_BYPASS: data_shift_reg <= 32'(jtag.tdi);
                INST_CONTROL: data_shift_reg <= 32'({jtag.tdi, data_shift_reg[$bits(debug_control_t) - 1:1]});
                INST_STATUS: data_shift_reg <= 32'({jtag.tdi, data_shift_reg[$bits(machine_inst_status_t) - 1:1]});
                // Default covers any 32 bit transfer (most instructions)
                default: data_shift_reg <= 32'({jtag.tdi, data_shift_reg[31:1]});
            endcase
        end
        else if (update_dr)
        begin
            if (jtag_instruction == INST_INJECT_INST)
                ocd_inject_inst <= data_shift_reg;
        end
    end
endmodule
