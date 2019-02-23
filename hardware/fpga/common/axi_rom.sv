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
// Read only memory that uses AMBA AXI bus interface
//

module axi_rom
    #(parameter FILENAME = "")

    (input                      clk,
    input                       reset,

    // AXI interface
    axi4_interface.slave        axi_bus);

    localparam MAX_SIZE = 'h2000;

    logic[29:0] burst_address;
    logic[7:0] burst_count;
    logic burst_active;

    logic[31:0] rom_data[MAX_SIZE];

    initial
    begin
        // This is used during *synthesis* to load the contents of ROM memory.
        $readmemh(FILENAME, rom_data);
    end

    assign axi_bus.s_wready = 1;
    assign axi_bus.s_bvalid = 1;
    assign axi_bus.s_awready = 1;
    assign axi_bus.s_arready = !burst_active;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            burst_active <= 0;
            axi_bus.s_rvalid <= 0;
        end
        else if (burst_active)
        begin
            if (burst_count == 0 && axi_bus.m_rready)
            begin
                // End of burst
                axi_bus.s_rvalid <= 0;
                burst_active <= 0;
            end
            else
            begin
                axi_bus.s_rvalid <= 1;
                axi_bus.s_rdata <= rom_data[burst_address[$clog2(MAX_SIZE) - 1:0]];
                if (axi_bus.m_rready)
                begin
                    burst_address <= burst_address + 30'd1;
                    burst_count <= burst_count - 8'd1;
                end
            end
        end
        else if (axi_bus.m_arvalid)
        begin
            // Start a new burst
            burst_active <= 1;
            burst_address <= axi_bus.m_araddr[31:2];
            burst_count <= axi_bus.m_arlen + 8'd1;
        end
    end
endmodule
