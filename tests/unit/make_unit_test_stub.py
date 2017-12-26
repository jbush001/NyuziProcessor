#!/usr/bin/env python3
#
# Copyright 2017 Jeff Bush
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

"""
Quick and dirty script for making a stub unit test from a verilog module.
Creates declarations for inputs and outputs, a reset block that zeroes
all inputs, and a stub test execution loop.
"""

import sys
import string
import os.path

source_file = sys.argv[1]
modulename = os.path.splitext(os.path.basename(source_file))[0]
output_file = 'test_' + modulename + '.sv'

with open(output_file, 'w') as out:
    out.write('''

`include "defines.sv"

import defines::*;

''')

    out.write('module test_' + modulename + '(input clk, input reset);\n')

    input_names = []
    with open(sys.argv[1]) as f:
        for line in f:
            if 'input' in line or 'output' in line:
                fields = line.split()
                name = fields[-1]
                if name.endswith(','):
                    name = name.rstrip(',')
                elif name.endswith(');'):
                    name = name.rstrip(');')

                if name == 'clk':
                    continue
                elif name == 'reset':
                    continue

                if fields[0] == 'input':
                    input_names += [name]

                if len(fields) == 2:
                    out.write('    logic ' + name + ';\n')
                elif fields[1].startswith('['):
                    out.write('    logic' + ' '.join(fields[1:-1]) + ' ' + name + ';\n')
                else:
                    out.write('    ' + ' '.join(fields[1:-1]) + ' ' + name + ';\n')

    out.write('    int cycle;\n')
    out.write('\n    ' + modulename + ' ' + modulename + '(.*);\n')
    out.write('''
    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
''')

    for net in input_names:
        if '[' in net:
            lbracket = net.find('[')
            rbracket = net.find(']')
            size = net[lbracket + 1:rbracket]
            signalname = net[:lbracket]
            out.write('            for (int i = 0; i < ' + size + '; i++)\n')
            out.write('                ' + signalname + '[i] <= \'0;\n')
            out.write('\n')
        else:
            out.write('            ' + net + ' <= \'0;\n')

    out.write('''        end
        else
        begin
            cycle <= cycle + 1;
            unique case (cycle)

                // test cases...

                0:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
''')
