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

`include "defines.sv"

//
// Top level block for processor. Contains all cores and L2 cache, connects
// to AXI system bus.
//

module nyuzi
    #(parameter RESET_PC = 0)

    (input                      clk,
    input                       reset,
    axi4_interface.master       axi_bus,
    io_bus_interface.master     io_bus,
    output                      processor_halt,
    input                       interrupt_req);

    l2req_packet_t l2i_request[`NUM_CORES];
    logic[`NUM_CORES - 1:0] l2i_request_valid;
    ioreq_packet_t io_request[`NUM_CORES];
    logic[`TOTAL_PERF_EVENTS - 1:0] perf_events;
    logic[`TOTAL_THREADS - 1:0] ic_interrupt_pending;
    logic[`TOTAL_THREADS - 1:0] wb_interrupt_ack;
    io_bus_interface ic_io_bus();
    io_bus_interface perf_io_bus();
    io_bus_interface arbiter_io_bus();
    enum logic[1:0] {
        IO_PERF_COUNTERS,
        IO_INT_CONTROLLER,
        IO_ARBITER
    } io_read_source;

    // XXX AUTOLOGIC not generating these
    l2rsp_packet_t l2_response;
    iorsp_packet_t ia_response;
    interrupt_id_t ic_interrupt_id[`TOTAL_THREADS - 1:0];
    interrupt_id_t _interrupt_id_repacked[`NUM_CORES][`THREADS_PER_CORE];

    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    logic               ia_ready [`NUM_CORES];  // From io_arbiter of io_arbiter.v
    logic [`TOTAL_THREADS-1:0] ic_thread_en;    // From interrupt_controller of interrupt_controller.v
    logic               l2_ready [`NUM_CORES];  // From l2_cache of l2_cache.v
    logic               l2_response_valid;      // From l2_cache of l2_cache.v
    // End of automatics

    initial
    begin
        assert(`NUM_CORES >= 1 && `NUM_CORES <= (1 << `CORE_ID_WIDTH));
    end

    interrupt_controller #(.BASE_ADDRESS('h60)) interrupt_controller(
        .io_bus(ic_io_bus),
        .*);

    l2_cache l2_cache(
        .l2_perf_events(perf_events[`L2_PERF_EVENTS - 1:0]),
        .*);

    always_ff @(posedge clk)
    begin
        if (arbiter_io_bus.address >= 'h130 && arbiter_io_bus.address <= 'h13c)
            io_read_source <= IO_PERF_COUNTERS;
        else if (arbiter_io_bus.address >= 'h60 && arbiter_io_bus.address < 'h100)
            io_read_source <= IO_INT_CONTROLLER;
        else
            io_read_source <= IO_ARBITER;
    end

    assign io_bus.write_en = arbiter_io_bus.write_en;
    assign io_bus.read_en = arbiter_io_bus.read_en;
    assign io_bus.address = arbiter_io_bus.address;
    assign io_bus.write_data = arbiter_io_bus.write_data;

    assign ic_io_bus.write_en = arbiter_io_bus.write_en;
    assign ic_io_bus.read_en = arbiter_io_bus.read_en;
    assign ic_io_bus.address = arbiter_io_bus.address;
    assign ic_io_bus.write_data = arbiter_io_bus.write_data;

    assign perf_io_bus.write_en = arbiter_io_bus.write_en;
    assign perf_io_bus.read_en = arbiter_io_bus.read_en;
    assign perf_io_bus.address = arbiter_io_bus.address;
    assign perf_io_bus.write_data = arbiter_io_bus.write_data;

    always_comb
    begin
        case (io_read_source)
            IO_PERF_COUNTERS: arbiter_io_bus.read_data = perf_io_bus.read_data;
            IO_INT_CONTROLLER: arbiter_io_bus.read_data = ic_io_bus.read_data;
            default: arbiter_io_bus.read_data = io_bus.read_data; // External read
        endcase
    end

    io_arbiter io_arbiter(
        .io_bus(arbiter_io_bus),
        .*);

    performance_counters #(
        .NUM_EVENTS(`TOTAL_PERF_EVENTS),
        .BASE_ADDRESS('h120)
    ) performance_counters(
        .io_bus(perf_io_bus),
        .*);

    genvar thread_idx;
    generate
        for (thread_idx = 0; thread_idx < `TOTAL_THREADS; thread_idx++)
        begin : repack_gen
            assign _interrupt_id_repacked[thread_idx / `THREADS_PER_CORE][thread_idx % `THREADS_PER_CORE] =
                ic_interrupt_id[thread_idx];
        end
    endgenerate


    genvar core_idx;
    generate
        for (core_idx = 0; core_idx < `NUM_CORES; core_idx++)
        begin : core_gen
            core #(.CORE_ID(core_id_t'(core_idx)), .RESET_PC(RESET_PC)) core(
                .l2i_request_valid(l2i_request_valid[core_idx]),
                .l2i_request(l2i_request[core_idx]),
                .l2_ready(l2_ready[core_idx]),
                .ic_thread_en(ic_thread_en[core_idx * `THREADS_PER_CORE+:`THREADS_PER_CORE]),
                .ic_interrupt_pending(ic_interrupt_pending[core_idx * `THREADS_PER_CORE+:`THREADS_PER_CORE]),
                .ic_interrupt_id(_interrupt_id_repacked[core_idx]),
                .wb_interrupt_ack(wb_interrupt_ack[core_idx * `THREADS_PER_CORE+:`THREADS_PER_CORE]),
                .ior_request(io_request[core_idx]),
                .ia_ready(ia_ready[core_idx]),
                .ia_response(ia_response),
                .core_perf_events(perf_events[`L2_PERF_EVENTS + `CORE_PERF_EVENTS * core_idx+:`CORE_PERF_EVENTS]),
                .*);
        end
    endgenerate
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// verilog-auto-reset-widths:unbased
// End:
