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

"""Run unit tests against individual verilog modules.

This compiles each one separately, then looks for the string 'PASS'
in the output.
"""

import os
import subprocess
import sys

sys.path.insert(0, '..')
import test_harness

DRIVER_PATH = os.path.join(test_harness.WORK_DIR, 'driver.cpp')
DRIVER_SRC = """
#include <iostream>
#include <stdlib.h>
#include "V$MODULE$.h"
#include "verilated.h"
#include "verilated_vpi.h"
#if VM_TRACE
#include <verilated_vcd_c.h>
#endif
using namespace std;

namespace
{
vluint64_t currentTime = 0;
}

// Called whenever the $time variable is accessed.
double sc_time_stamp()
{
    return currentTime;
}

int main(int argc, char **argv, char **env)
{
    Verilated::commandArgs(argc, argv);
    Verilated::debug(0);

    V$MODULE$ *testbench = new V$MODULE$;

    testbench->__Vclklast__TOP__reset = 0;
    testbench->reset = 1;
    testbench->clk = 0;
    testbench->eval();

#if VM_TRACE // If verilator was invoked with --trace
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    testbench->trace(tfp, 99);
    tfp->open("trace.vcd");
#endif

    while (!Verilated::gotFinish())
    {
        if (currentTime == 4)
            testbench->reset = 0;

        testbench->clk = !testbench->clk;
        testbench->eval();
#if VM_TRACE
        tfp->dump(currentTime); // Create waveform trace for this timestamp
#endif

        currentTime++;
    }

#if VM_TRACE
    tfp->close();
#endif

    testbench->final();
    delete testbench;

    return 0;
}
"""


def run_unit_test(filename, _):
    filestem, _ = os.path.splitext(filename)
    modulename = os.path.basename(filestem)

    verilator_args = [
        'verilator',
        '--unroll-count', '512',
        '--assert',
        '-I' + test_harness.HARDWARE_INCLUDE_DIR,
        '-DSIMULATION=1',
        '-Mdir', test_harness.WORK_DIR,
        '-cc', filename,
        '--exe', DRIVER_PATH
    ]

    if test_harness.DEBUG:
        verilator_args += ['--trace', '--trace-structs']

    try:
        # The 'verilator' command is actually a perl script. Executing it
        # with shell=True is necessary for it to work correctly in all
        # environments.
        subprocess.call(' '.join(verilator_args), stderr=subprocess.STDOUT,
                        shell=True)
    except subprocess.CalledProcessError as exc:
        raise test_harness.TestException(
            'Verilation failed:\n' + exc.output.decode())

    with open(DRIVER_PATH, 'w') as output_file:
        output_file.write(DRIVER_SRC.replace('$MODULE$', modulename))

    make_args = [
        'make',
        'CXXFLAGS=-Wno-parentheses-equality',
        '-C', test_harness.WORK_DIR,
        '-f', 'V{}.mk'.format(modulename),
        'V{}'.format(modulename)
    ]

    try:
        subprocess.check_output(make_args, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as exc:
        raise test_harness.TestException(
            'Build failed:\n' + exc.output.decode())

    model_args = [
        os.path.join(test_harness.WORK_DIR, 'V' + modulename)
    ]

    try:
        result = test_harness.run_test_with_timeout(model_args, 60)
    except subprocess.CalledProcessError as exc:
        raise test_harness.TestException(
            'Build failed:\n' + exc.output.decode())

    if 'PASS' not in result:
        raise test_harness.TestException('test failed:\n' + result)

test_harness.register_tests(run_unit_test,
                            test_harness.find_files(('.sv', '.v')), ['verilator'])
test_harness.execute_tests()
