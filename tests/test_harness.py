#
# Copyright 2011-2015 Jeff Bush
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

"""Utility functions for functional tests.

This is imported into test runner scripts in subdirectories under this one.
"""

import argparse
import binascii
import configparser
import hashlib
import os
import random
import re
import shutil
import subprocess
import sys
import threading
import traceback

TEST_DIR = os.path.dirname(os.path.abspath(__file__))

# Read configuration file. This is written by the build system.
# It contains paths to dependencies of the tests, and allows
# them to operate no matter where the build directory is.
config = configparser.ConfigParser()
config.read(os.path.join(TEST_DIR, 'tests.conf'))
default_config = config['DEFAULT']
BIN_DIR = default_config['TOOL_BIN_DIR']
LIB_DIR = default_config['LIB_DIR']
KERNEL_DIR = default_config['KERNEL_DIR']
WORK_DIR = default_config['WORK_DIR']
LIB_INCLUDE_DIR = default_config['LIB_INCLUDE_DIR']
COMPILER_BIN_DIR = default_config['COMPILER_BIN_DIR']
HARDWARE_INCLUDE_DIR = default_config['HARDWARE_INCLUDE_DIR']

ELF_FILE = os.path.join(WORK_DIR, 'program.elf')
HEX_FILE = os.path.join(WORK_DIR, 'program.hex')
ALL_TARGETS = ['verilator', 'emulator']
DEFAULT_TARGETS = ['verilator', 'emulator']
VSIM_PATH = os.path.join(BIN_DIR, 'nyuzi_vsim')
EMULATOR_PATH = os.path.join(BIN_DIR, 'nyuzi_emulator')
SERIAL_BOOT_PATH = os.path.join(BIN_DIR, 'serial_boot')

class TestException(Exception):
    """This exception is raised for test failures"""
    pass

parser = argparse.ArgumentParser()
parser.add_argument('--target', dest='target',
                    help='restrict to only executing tests on this target',
                    nargs=1)
parser.add_argument('--debug', action='store_true',
                    help='enable verbose output to debug test failures')
parser.add_argument('--list', action='store_true',
                    help='list availble tests')
parser.add_argument('names', nargs=argparse.REMAINDER,
                    help='names of specific tests to run')
test_args = parser.parse_args()
DEBUG = test_args.debug


def build_program(source_files, image_type='bare-metal', opt_level='-O3', cflags=None):
    """Compile and or assemble one or more files.

    If there are any .c files in the list, this will link in crt0, libc,
    and libos libraries. It converts the binary to a hex file that can be
    loaded into memory.

    Args:
        source_files: list (string)
            Files to compile, which can be C/C++ or assembly files.
        image_type: string
            Can be:
            - 'bare-metal', Runs standalone, but with elf linkage
            - 'raw', Has no header and is linked at address 0
            - 'user', ELF binary linked at 0x1000, linked against kernel libs
        opt_level: string
            Optimization level (-O0, -O1, -O2, or -O3)
        cflags: list (string)
            Additional command line flags to pass to C compiler.

    Returns:
        string Name of hex file created

    Raises:
        TestException if compilation failed, will contain compiler output
    """
    assert isinstance(source_files, list)
    compiler_args = [os.path.join(COMPILER_BIN_DIR, 'clang'),
                     '-o', ELF_FILE,
                     '-w',
                     opt_level,
                     '-I', TEST_DIR]    # To include asm_macros.h

    if cflags:
        compiler_args += cflags

    if image_type == 'raw':
        compiler_args += ['-Wl,--script,' + os.path.join(TEST_DIR, 'one-segment.ld') + ',--oformat,binary']
    elif image_type == 'user':
        compiler_args += ['-Wl,--image-base=0x1000']

    compiler_args += source_files

    if any(name.endswith(('.c', '.cpp')) for name in source_files):
        compiler_args += ['-I' + os.path.join(LIB_INCLUDE_DIR, 'libc/include'),
                          '-I' + os.path.join(LIB_INCLUDE_DIR, 'libos'),
                          os.path.join(LIB_DIR, 'libc/libc.a')]
        if image_type == 'user':
            compiler_args += [os.path.join(LIB_DIR, 'libos/kernel/libos-kern.a')]
        else:
            compiler_args += [os.path.join(LIB_DIR, 'libos/bare-metal/libos-bare.a')]

    try:
        subprocess.check_output(compiler_args, stderr=subprocess.STDOUT)
        if image_type == 'raw':
            dump_hex(input_file=ELF_FILE, output_file=HEX_FILE)
            return HEX_FILE

        if image_type == 'bare-metal':
            subprocess.check_output([os.path.join(COMPILER_BIN_DIR, 'elf2hex'), '-o', HEX_FILE, ELF_FILE],
                                    stderr=subprocess.STDOUT)
            return HEX_FILE

        return ELF_FILE
    except subprocess.CalledProcessError as exc:
        raise TestException('Compilation failed:\n' + exc.output.decode())

def kill_gently(process):
    """Kill a process, giving a chance to terminate cleanly.

    Give process a chance to terminate normally, then kill it
    forcefully if it doesn't respond after a few seconds.
    This allows the emulator to clean up, including restoring
    the terminal state.

    Args:
        process: Popen

    Returns:
        nothing

    Raises:
        nothing
    """

    process.terminate()
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        # Process may be hung
        process.kill()

class TimedProcessRunner(threading.Thread):
    """Run a process, but throw an exception if it takes too long."""

    def __init__(self):
        threading.Thread.__init__(self)
        self.finished = threading.Event()
        self.daemon = True  # Kill watchdog if we exit
        self.process = None
        self.timeout = 0

    def communicate(self, process, timeout, input=None):
        """Call process.communicate() with timeout.

        Args:
            process: Popen
                The subprcess to run, which should be created with Popen.
            timeout: number
                How long to wait, in seconds.
            input: string
                If specified, this will be sent to the processes standard
                input.

        Returns:
            string The collected standard out that was printed by this process.

        Raises:
            TestException if the process times out.
        """

        self.timeout = timeout
        self.process = process
        self.start()  # Start watchdog
        result = self.process.communicate(input=input)
        if self.finished.is_set():
            raise TestException('Test timed out')
        else:
            self.finished.set()  # Stop watchdog

        return result

    # Watchdog thread kills process if it runs too long
    def run(self):
        if not self.finished.wait(self.timeout):
            # Timed out
            self.finished.set()
            kill_gently(self.process)


def run_test_with_timeout(args, timeout):
    """Run program specified by args with timeout.

    If it does not complete in time, throw a TestException. If it
    returns a non-zero result, it will also throw a TestException.

    Args:
        args: list
            A list of string arguments, the first being the path to the
            executable
        timeout: number
            Timeout in seconds.

    Returns:
        string All data printed to stdout by the process.

    Raises:
        TestException if the test fails or times out.
    """

    process = subprocess.Popen(args, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)
    output, _ = TimedProcessRunner().communicate(process, timeout)
    if process.poll():
        # Non-zero return code. Probably target program crash.
        raise TestException(
            'Process returned error: ' + output.decode())

    return output.decode()


def reset_fpga():
    args = ['quartus_stp', '-t', os.path.join(TEST_DIR, 'reset_altera.tcl')]

    try:
        subprocess.check_output(args)
    except subprocess.CalledProcessError as exc:
        raise TestException(
            'Failed to reset dev board:\n' + exc.output.decode())


def run_program(
        target='emulator',
        block_device=None,
        dump_file=None,
        dump_base=None,
        dump_length=None,
        timeout=60,
        flush_l2=False,
        trace=False,
        executable=None):
    """Run test program.

    This uses the hex file produced by build_program.

    Args:
        target: string
            Which target will run the program. Can be 'verilator'
            or 'emulator'.
        block_device: string
            Relative path to a file that contains a filesystem image.
            If passed, contents will appear as a virtual SDMMC device.
        dump_file: string
            Path to a file to write memory contents into after
            execution completes.
        dump_base: number
            if dump_file is specified, base physical memory address to start
            writing mempry from.
        dump_length: number
            number of bytes of memory to write to dump_file

    Returns:
        string Output from program, anything written to virtual serial device,
        as a string.

    Raises:
        TestException if emulated program crashes or the program cannot
        execute for some other reason.
    """
    if not executable:
        executable = HEX_FILE

    if target == 'emulator':
        args = [EMULATOR_PATH]
        args += ['-a']  # Enable thread scheduling randomization by default
        if block_device:
            args += ['-b', block_device]

        if dump_file:
            args += ['-d', dump_file + ',' +
                     hex(dump_base) + ',' + hex(dump_length)]

        args += [executable]
        output = run_test_with_timeout(args, timeout)
    elif target == 'verilator':
        random_seed = random.randint(0, 0xffffffff)
        if DEBUG:
            print('random seed is ' + random_seed)

        args = [
            VSIM_PATH,
            '+bin=' + executable,
            '+verilator+rand+reset+2',
            '+verilator+seed+' + str(random_seed)
        ]
        if block_device:
            args += ['+block=' + block_device]

        if dump_file:
            args += ['+memdumpfile=' + dump_file,
                     '+memdumpbase=' + hex(dump_base)[2:],
                     '+memdumplen=' + hex(dump_length)[2:]]

        if flush_l2:
            args += ['+autoflushl2=1']

        if trace:
            args += ['+trace']

        output = run_test_with_timeout(args, timeout)
        if '***HALTED***' not in output:
            raise TestException(output + '\nProgram did not halt normally')
    elif target == 'fpga':
        if block_device:
            args += [block_device]

        if dump_file:
            raise TestException('dump file is not supported on FPGA')

        if flush_l2:
            raise TestException('flush_l2 is not supported on FPGA')

        if 'SERIAL_PORT' not in os.environ:
            raise TestException(
                'Need to set SERIAL_PORT to device path in environment')

        args = [
            SERIAL_BOOT_PATH,
            os.environ['SERIAL_PORT'],
            executable
        ]

        reset_fpga()

        output = run_test_with_timeout(args, timeout)
    else:
        raise TestException('Unknown execution target')

    if DEBUG:
        print('Program Output:\n' + output)

    return output


def run_kernel(
        target='emulator',
        timeout=60):
    """Run test program as a user space program under the kernel.

    This uses the elf file produced by build_program. The kernel reads
    the file 'program.elf' from the filesystem. This will build a filesystem
    with that image automatically.

    Args:
        target: string
            Which target to execute on. Can be 'verilator' or 'emulator'.

    Returns:
        string Output from program, anything written to virtual serial device

    Raises:
        TestException if emulated program crashes or the program cannot
        execute for some other reason.
    """
    block_file = os.path.join(WORK_DIR, 'fsimage.bin')
    subprocess.check_output([os.path.join(BIN_DIR, 'mkfs'), block_file, ELF_FILE],
                            stderr=subprocess.STDOUT)

    output = run_program(target=target, block_device=block_file,
                         timeout=timeout, executable=KERNEL_DIR +
                         '/kernel.hex')

    if DEBUG:
        print('Program Output:\n' + output)

    return output


def assert_files_equal(file1, file2, error_msg='file mismatch'):
    """Read two files and throw a TestException if they are not the same

    Args:
        file1: string
            relative path to first file
        file2: string
            relative path to second file
        error_msg: string
            If there is a file mismatch, prepend this to error output

    Returns:
        Nothing

    Raises:
        TestException if the files don't match. Exception test contains
        details about where the mismatch occurred.
    """

    bufsize = 0x1000
    block_offset = 0
    with open(file1, 'rb') as fp1, open(file2, 'rb') as fp2:
        while True:
            block1 = bytearray(fp1.read(bufsize))
            block2 = bytearray(fp2.read(bufsize))
            if len(block1) < len(block2):
                raise TestException(error_msg + ': file1 shorter than file2')
            elif len(block1) > len(block2):
                raise TestException(error_msg + ': file1 longer than file2')

            if block1 != block2:
                for offset, (val1, val2) in enumerate(zip(block1, block2)):
                    if val1 != val2:
                        # Show the difference
                        exception_text = error_msg + ':\n'
                        rounded_offset = offset & ~15
                        exception_text += '{:08x} '.format(block_offset +
                                                           rounded_offset)
                        for lineoffs in range(16):
                            exception_text += '{:02x}'.format(
                                block1[rounded_offset + lineoffs])

                        exception_text += '\n{:08x} '.format(
                            block_offset + rounded_offset)
                        for lineoffs in range(16):
                            exception_text += '{:02x}'.format(
                                block2[rounded_offset + lineoffs])

                        exception_text += '\n         '
                        for lineoffs in range(16):
                            if block1[rounded_offset + lineoffs] \
                                    != block2[rounded_offset + lineoffs]:
                                exception_text += '^^'
                            else:
                                exception_text += '  '

                        raise TestException(exception_text)

            if not block1:
                return

            block_offset += len(block1)


registered_tests = []


def register_tests(func, names, targets=None):
    """Add a list of tests to be run when execute_tests is called.

    This function can be called multiple times, it will append passed
    tests to the existing list.

    Args:
        func: function
            A function that will be called for each of the elements
            in the names list.
        names: list(string)
            List of tests to run.

    Returns:
        Nothing

    Raises:
        Nothing
     """

    global registered_tests
    if not targets:
        targets = ALL_TARGETS[:]

    registered_tests += [(func, name, targets) for name in names]


def test(param=None):
    """decorator @test automatically registers test to be run.

    Args:
        param: list(string)
            optional list of targets that are valid for this test
    """
    if callable(param):
        # If the test decorator is used without a target list,
        # this will just pass the function as the parameter.
        # Run all targtes
        register_tests(param, [param.__name__], ALL_TARGETS)
        return param

    # decorator is called with a list of targets. Return
    # a fuction that will be called on the actual function.
    def register_func(func):
        register_tests(func, [func.__name__], param)

    return register_func


def find_files(extensions):
    """Find all files in the current directory that have the passed extensions.

    Args:
        extensions: list
            File extensions, each starting with a dot. For example
            ['.c', '.cpp']

    Returns:
        list (string) Filenames.

    Raises:
        Nothing
    """

    return [fname for fname in os.listdir('.') if fname.endswith(extensions)]

COLOR_RED = '[\x1b[31m'
COLOR_GREEN = '[\x1b[32m'
COLOR_NONE = '\x1b[0m]'
OUTPUT_ALIGN = 50


def execute_tests():
    """All tests are called from here.

    Run all tests that have been registered with the register_tests functions
    and report results. If this fails, it will call sys.exit with a non-zero status.

    Args:
        None

    Returns:
        Nothing

    Raises:
        Nothing
    """

    global DEBUG

    if test_args.list:
        for _, param, targets in registered_tests:
            print(param + ': ' + ', '.join(targets))

        return

    if test_args.target:
        targets_to_run = test_args.target
    else:
        targets_to_run = DEFAULT_TARGETS

    # Filter based on names and targets
    if test_args.names:
        tests_to_run = []
        for requested in test_args.names:
            for func, param, targets in registered_tests:
                if param == requested:
                    tests_to_run += [(func, param, targets)]
                    break
            else:
                print('Unknown test ' + requested)
                sys.exit(1)
    else:
        tests_to_run = registered_tests

    test_run_count = 0
    test_pass_count = 0
    failing_tests = []
    for func, param, targets in tests_to_run:
        for target in targets:
            if target not in targets_to_run:
                continue

            label = param + ' (' + target + ')'
            print(label + (' ' * (OUTPUT_ALIGN - len(label))), end='')
            try:
                # Clean out working directory and re-create
                shutil.rmtree(path=WORK_DIR, ignore_errors=True)
                os.makedirs(WORK_DIR)

                test_run_count += 1
                sys.stdout.flush()
                func(param, target)
                print(COLOR_GREEN + 'PASS' + COLOR_NONE)
                test_pass_count += 1
            except KeyboardInterrupt:
                sys.exit(1)
            except TestException as exc:
                print(COLOR_RED + 'FAIL' + COLOR_NONE)
                failing_tests += [(param, target, exc.args[0])]
            except Exception as exc:  # pylint: disable=W0703
                print(COLOR_RED + 'FAIL' + COLOR_NONE)
                failing_tests += [(param, target, 'Test threw exception:\n' +
                                   traceback.format_exc())]

    if failing_tests:
        print('Failing tests:')
        for name, target, output in failing_tests:
            print('{} ({})'.format(name, target))
            print(output)

    print('{}/{} tests failed'.format(test_run_count - test_pass_count,
                                      test_run_count))
    if failing_tests != []:
        sys.exit(1)

CHECK_PREFIX = 'CHECK: '
CHECKN_PREFIX = 'CHECKN: '


def check_result(source_file, program_output):
    """Check output of a program based on embedded comments in source code.

    For each pattern in a source file that begins with 'CHECK: ', search
    to see if the regular expression that follows it occurs in program_output.
    The strings must occur in order, but this ignores anything between them.
    If there is a pattern 'CHECKN: ', the test will fail if the string *does*
    occur in the output.

    Args:
        source_file: string
            relative path to a source file that contains patterns

    Returns:
        Nothing

    Raises:
        TestException if a string is not found.
    """

    output_offset = 0
    line_num = 1
    found_check_lines = False
    with open(source_file, 'r') as infile:
        for line in infile:
            chkoffs = line.find(CHECK_PREFIX)
            if chkoffs != -1:
                found_check_lines = True
                expected = line[chkoffs + len(CHECK_PREFIX):].strip()
                if DEBUG:
                    print('searching for pattern "' + expected + '", line '
                          + str(line_num))

                regexp = re.compile(expected)
                got = regexp.search(program_output, output_offset)
                if got:
                    output_offset = got.end()
                else:
                    error = 'FAIL: line ' + \
                        str(line_num) + ' expected string ' + \
                        expected + ' was not found\n'
                    error += 'searching here:' + program_output[output_offset:]
                    raise TestException(error)
            else:
                chkoffs = line.find(CHECKN_PREFIX)
                if chkoffs != -1:
                    found_check_lines = True
                    nexpected = line[chkoffs + len(CHECKN_PREFIX):].strip()
                    if DEBUG:
                        print('ensuring absence of pattern "' + nexpected +
                            '", line ' + str(line_num))

                    regexp = re.compile(nexpected)
                    got = regexp.search(program_output, output_offset)
                    if got:
                        error = 'FAIL: line ' + \
                            str(line_num) + ' string ' + \
                            nexpected + ' should not be here:\n'
                        error += program_output
                        raise TestException(error)

            line_num += 1

    if not found_check_lines:
        raise TestException('FAIL: no lines with CHECK: were found')

    return True


def dump_hex(output_file, input_file):
    """Read binary input file and encode as hexadecimal file.

    Each line of the output file is 4 bytes.

    Args:
        output_file: string
            Path of hex file to to write
        input_file: string
            Path of binary file to read

    Returns:
        Nothing

    Raises:
        IOError if there is a problem reading or writing files.
    """

    with open(input_file, 'rb') as ifile, open(output_file, 'wb') as ofile:
        while True:
            word = ifile.read(4)
            if not word:
                break

            ofile.write(binascii.hexlify(word))
            ofile.write(b'\n')


def endian_swap(value):
    """"Given a 32-bit integer value, swap it to the opposite endianness.

    Args:
        value: number
            Value to swap

    Returns:
        number Endian swapped result
    """

    return (((value >> 24) & 0xff) | ((value >> 8) & 0xff00)
            | ((value << 8) & 0xff0000) | (value << 24))


def _run_generic_test(name, target):
    """Compile a file, run the program, and call check_result on it.

    check_result will match expected strings in the source
    file with the programs output.

    Args:
        name: string
            Filename of the file to run, expected to be in the same
            directory is the runtest script
        target: string
            Name of the target (e.g. emulator, verilator)

    Returns:
        Nothing

    Raises:
        TestException if the test fails.
    """

    build_program([name])
    result = run_program(target)
    check_result(name, result)


def register_generic_test(name, targets=None):
    """Register a test without a custom test handler function.

    This will compile the passed filename, then use check_result to validate
    it against comment strings embedded in the file. It runs it both in
    verilator and emulator configurations.

    Args:
        names: list
            Source file names. Each is compiled as a separate test.

    Returns:
        Nothing

    Raises:
        Nothing
    """
    if not targets:
        targets = ALL_TARGETS[:]

    register_tests(_run_generic_test, name, targets)


def _run_generic_assembly_test(name, target):
    build_program([name])
    result = run_program(target)
    if 'PASS' not in result or 'FAIL' in result:
        raise TestException('Test failed ' + result)


def register_generic_assembly_tests(tests, targets=None):
    """Register a test written in assembler without a custom test handler.

    This will assemble the passed program, then look for PASS or FAIL
    strings. It runs it both in verilator and emulator configurations.

    Args:
        tests: list (string)
            list of source file names. Each is assembled as a
            separate test.

    Returns:
        Nothing

    Raises:
        Nothing
    """

    if not targets:
        targets = ALL_TARGETS[:]

    register_tests(_run_generic_assembly_test, tests, targets)


def register_render_test(name, source_files, expected_hash, targets=None):
    """Register a test that renders graphics.

    This will compile the source files, run the program, then compute a
    hash of memory starting at 2M, which is expected to be a framebuffer
    with the format 640x480x32bpp. This hash will be compared to a reference
    value to ensure the output is pixel accurate.

    Args:
        name: string
            Display name of the test in test result output
        source_files: list (string)
            List of source files to compile (unlike other calls, these
            are all compiled into one executable, this call only registers
            one test, not multiple).
        expected_hash: string
            this is an ASCII hex string of that the computed hash.

    Returns:
        Nothing

    Raises:
        Nothing
    """

    # This closure captures parameters source_files and
    # expected_checksum.
    def run_render_test(_, target):
        RAW_FB_DUMP_FILE = os.path.join(WORK_DIR, 'fb.bin')
        PNG_DUMP_FILE = os.path.join(WORK_DIR, 'actual-output.png')

        render_cflags = [
            '-I' + os.path.join(LIB_INCLUDE_DIR, 'librender'),
            os.path.join(LIB_DIR, 'librender/librender.a'),
            '-ffast-math'
        ]

        build_program(source_files=source_files,
                      cflags=render_cflags)
        run_program(target=target,
                    dump_file=RAW_FB_DUMP_FILE,
                    dump_base=0x200000,
                    dump_length=0x12c000,
                    flush_l2=True)
        with open(RAW_FB_DUMP_FILE, 'rb') as f:
            contents = f.read()

        sha = hashlib.sha1()
        sha.update(contents)
        actual_hash = sha.hexdigest()
        if actual_hash != expected_hash:
            subprocess.check_output(['convert', '-depth', '8', '-size',
                                     '640x480', 'rgba:' + RAW_FB_DUMP_FILE, PNG_DUMP_FILE])
            raise TestException('render test failed, bad checksum ' + str(actual_hash)
                                + ' output image written to ' + PNG_DUMP_FILE)

    register_tests(run_render_test, [name], targets)
