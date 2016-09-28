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

//
// Programmable interrupt timer
//

module timer
    #(parameter BASE_ADDRESS = 0)

    (input                    clk,
    input                     reset,

    // IO bus interface
    io_bus_interface.slave    io_bus,

    // Interrupt
    output logic              timer_interrupt);

    logic[31:0] counter;

    assign io_bus.read_data = '0;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            counter <= '0;
            timer_interrupt <= '0;
            // End of automatics
        end
        else
        begin
            if (io_bus.write_en && io_bus.address == BASE_ADDRESS)
                counter <= io_bus.write_data;
            else if (counter != 0)
                counter <= counter - 1;

            timer_interrupt <= counter == 0;
        end
    end
endmodule
