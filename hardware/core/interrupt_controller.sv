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
// Dispatches interrupts to threads.
// Much functionality is stubbed in here. Features that should be implemented:
// - Inter-CPU/inter-thread interrupts
// - Multiple external interrupts with prioritization
// - Level/edge triggered external interrupts
// - Wake thread on interrupt
// - Currently dispatches external interrupts only on thread 0. Should enable
//   load balancing somehow...
//
module interrupt_controller
    #(parameter BASE_ADDRESS = 0,
    parameter NUM_INTERRUPTS = 16)
    (input                                      clk,
    input                                       reset,

    // IO bus interface
    io_bus_interface.slave                      io_bus,

    // From external interface
    input [NUM_INTERRUPTS - 1:0]                interrupt_req,

    // To cores
    output logic[`TOTAL_THREADS - 1:0]          ic_thread_en,
    output logic[`TOTAL_THREADS - 1:0]          ic_interrupt_pending,
    output                                      processor_halt);

    logic[NUM_INTERRUPTS - 1:0] trigger_type;
    logic[NUM_INTERRUPTS - 1:0] interrupt_latched;
    logic[NUM_INTERRUPTS - 1:0] interrupt_pending;
    logic[NUM_INTERRUPTS - 1:0] interrupt_thread_mask[`TOTAL_THREADS];
    logic[NUM_INTERRUPTS - 1:0] interrupt_req_prev;
    logic[NUM_INTERRUPTS - 1:0] interrupt_ack;

    assign interrupt_ack = (io_bus.write_en && io_bus.address == BASE_ADDRESS + 12)
        ? io_bus.write_data[NUM_INTERRUPTS - 1:0] : 0;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            ic_thread_en <= 1;
            // XXX hardcoded for now so only thread 0 dispatches interrupts
            interrupt_thread_mask[0] <= {NUM_INTERRUPTS{1'b1}};
            for (int i = 1; i < `TOTAL_THREADS; i++)
                interrupt_thread_mask[i] <= '0;

            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            interrupt_latched <= '0;
            io_bus.read_data <= '0;
            trigger_type <= '0;
            // End of automatics
        end
        else
        begin
            if (io_bus.write_en)
            begin
                case (io_bus.address)
                    // Thread enable flag handling. This is limited to 32 threads.
                    // To add more, put the next 32 bits in subsequent io addresses.
                    BASE_ADDRESS: // resume thread
                        ic_thread_en <= ic_thread_en | io_bus.write_data[`TOTAL_THREADS - 1:0];

                    BASE_ADDRESS + 4: // halt thread
                        ic_thread_en <= ic_thread_en & ~io_bus.write_data[`TOTAL_THREADS - 1:0];

                    BASE_ADDRESS + 8: // Trigger type
                        trigger_type <= io_bus.write_data[NUM_INTERRUPTS - 1:0];
                endcase

                // If address is >= 16, set the thread mask
                // XXX only supports 16 threads (four cores) currently. Need to renumber
                // registers again to make room for more.
                if (io_bus.address >= BASE_ADDRESS + 16 && io_bus.address < BASE_ADDRESS + 48)
                begin
                    interrupt_thread_mask[io_bus.address - 16] <=
                        io_bus.write_data[NUM_INTERRUPTS - 1:0];
                end
            end

            // Read logic
            io_bus.read_data <= 32'(interrupt_pending[io_bus.address - BASE_ADDRESS]);

            // Note: if an ack occurs the same cycle a new edge comes, this one wins.
            interrupt_latched <= (interrupt_latched & ~interrupt_ack)
                | (interrupt_req & ~interrupt_req_prev);
            interrupt_req_prev <= interrupt_req;
        end
    end

    assign processor_halt = ic_thread_en == 0;

    // If trigger type bit is set, level triggered, else edge triggered
    assign interrupt_pending = (trigger_type & interrupt_req)
        | (~trigger_type & interrupt_latched);

    genvar thread_idx;
    generate
        for (thread_idx = 0; thread_idx < `TOTAL_THREADS; thread_idx++)
        begin : core_int_gen
            assign ic_interrupt_pending[thread_idx] = |(interrupt_pending
                & interrupt_thread_mask[thread_idx]);
        end
    endgenerate
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// verilog-auto-reset-widths:unbased
// End:
