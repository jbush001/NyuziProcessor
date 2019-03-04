//
// Copyright 2011-2015 Jeff Bush
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
// Top level block for processor. Contains all cores and L2 cache, connects
// to AXI system bus.
//

module nyuzi
    #(parameter RESET_PC = 0,
    parameter NUM_INTERRUPTS = 16)

    (input                          clk,
    input                           reset,
    axi4_interface.master           axi_bus,
    io_bus_interface.master         io_bus,
    jtag_interface.target           jtag,
    input [NUM_INTERRUPTS - 1:0]    interrupt_req);

    l2req_packet_t l2i_request[`NUM_CORES];
    logic[`NUM_CORES - 1:0] l2i_request_valid;
    ioreq_packet_t ior_request[`NUM_CORES];
    logic[`NUM_CORES - 1:0] ior_request_valid;
    logic[TOTAL_THREADS - 1:0] thread_en;
    scalar_t cr_data_to_host[`NUM_CORES];
    scalar_t data_to_host;
    logic[`NUM_CORES - 1:0] core_injected_complete;
    logic[`NUM_CORES - 1:0] core_injected_rollback;
    logic[`NUM_CORES - 1:0][TOTAL_THREADS - 1:0] core_suspend_thread;
    logic[`NUM_CORES - 1:0][TOTAL_THREADS - 1:0] core_resume_thread;
    logic[TOTAL_THREADS - 1:0] thread_suspend_mask;
    logic[TOTAL_THREADS - 1:0] thread_resume_mask;

    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    logic               ii_ready [`NUM_CORES];  // From io_interconnect of io_interconnect.v
    iorsp_packet_t      ii_response;            // From io_interconnect of io_interconnect.v
    logic               ii_response_valid;      // From io_interconnect of io_interconnect.v
    logic               l2_ready [`NUM_CORES];  // From l2_cache of l2_cache.v
    l2rsp_packet_t      l2_response;            // From l2_cache of l2_cache.v
    logic               l2_response_valid;      // From l2_cache of l2_cache.v
    core_id_t           ocd_core;               // From on_chip_debugger of on_chip_debugger.v
    scalar_t            ocd_data_from_host;     // From on_chip_debugger of on_chip_debugger.v
    logic               ocd_data_update;        // From on_chip_debugger of on_chip_debugger.v
    logic               ocd_halt;               // From on_chip_debugger of on_chip_debugger.v
    logic               ocd_inject_en;          // From on_chip_debugger of on_chip_debugger.v
    scalar_t            ocd_inject_inst;        // From on_chip_debugger of on_chip_debugger.v
    local_thread_idx_t  ocd_thread;             // From on_chip_debugger of on_chip_debugger.v
    // End of automatics

    initial
    begin
        // Check config (see config.svh for rules)
        assert(`NUM_CORES >= 1 && `NUM_CORES <= (1 << CORE_ID_WIDTH));
        assert(`L1D_WAYS >= `THREADS_PER_CORE);
        assert(`L1I_WAYS >= `THREADS_PER_CORE);
    end

    // Thread enable
    always @*
    begin
        thread_suspend_mask = '0;
        thread_resume_mask = '0;
        for (int i = 0; i < `NUM_CORES; i++)
        begin
            thread_suspend_mask |= core_suspend_thread[i];
            thread_resume_mask |= core_resume_thread[i];
        end
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            thread_en <= 1;
        else
            thread_en <= (thread_en | thread_resume_mask) & ~thread_suspend_mask;
    end

    l2_cache l2_cache(
        .l2_perf_events(),
        .*);

    io_interconnect io_interconnect(.*);

    on_chip_debugger on_chip_debugger(
        .jtag(jtag),
        .injected_complete(|core_injected_complete),
        .injected_rollback(|core_injected_rollback),
        .*);

    generate
        if (`NUM_CORES > 1)
            assign data_to_host = cr_data_to_host[CORE_ID_WIDTH'(ocd_core)];
        else
            assign data_to_host = cr_data_to_host[0];
    endgenerate

    genvar core_idx;
    generate
        for (core_idx = 0; core_idx < `NUM_CORES; core_idx++)
        begin : core_gen
            core #(
                .CORE_ID(core_id_t'(core_idx)),
                .NUM_INTERRUPTS(NUM_INTERRUPTS),
                .RESET_PC(RESET_PC)
            ) core(
                .l2i_request_valid(l2i_request_valid[core_idx]),
                .l2i_request(l2i_request[core_idx]),
                .l2_ready(l2_ready[core_idx]),
                .thread_en(thread_en[core_idx * `THREADS_PER_CORE+:`THREADS_PER_CORE]),
                .ior_request_valid(ior_request_valid[core_idx]),
                .ior_request(ior_request[core_idx]),
                .ii_ready(ii_ready[core_idx]),
                .ii_response(ii_response),
                .cr_data_to_host(cr_data_to_host[core_idx]),
                .injected_complete(core_injected_complete[core_idx]),
                .injected_rollback(core_injected_rollback[core_idx]),
                .cr_suspend_thread(core_suspend_thread[core_idx]),
                .cr_resume_thread(core_resume_thread[core_idx]),
                .*);
        end
    endgenerate
endmodule
