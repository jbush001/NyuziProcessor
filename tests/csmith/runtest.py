#!/usr/bin/env python3
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

'''
This uses the Csmith random program generate to validate the compiler. It first
compiles and executes the program using the host system. The program outputs
a checksum of its data structures. It then compiles and executes it under
the emulator. It compares the output to that produced by the host and flags
an error if they don't match.
'''


import re
import subprocess
import sys

sys.path.insert(0, '..')
import test_harness

VERSION_RE = re.compile(r'csmith (?P<version>[0-9\.]+)')
CHECKSUM_RE = re.compile(r'checksum = (?P<checksum>[0-9A-Fa-f]+)')


@test_harness.test(['emulator'])
def run_csmith_test(_, target):
    # Find version of csmith
    result = subprocess.check_output(['csmith', '-v']).decode()
    got = VERSION_RE.search(result)
    if not got:
        raise test_harness.TestException(
            'Could not determine csmith version ' + result)

    version_str = got.group('version')
    csmith_include = '-I/usr/local/include/csmith-' + version_str

    for x in range(100):
        source_file = 'test%04d.c' % x
        print('running ' + source_file)

        # Disable packed structs because we don't support unaligned accesses.
        # Disable longlong to avoid incompatibilities between 32-bit Nyuzi
        # and 64-bit hosts.
        subprocess.check_call(['csmith', '-o', source_file, '--no-longlong',
                               '--no-packed-struct'])

        # Compile and run on host
        subprocess.check_call(
            ['cc', '-w', source_file, '-o', 'obj/a.out', csmith_include])
        result = subprocess.check_output('obj/a.out').decode()

        got = CHECKSUM_RE.search(result)
        if not got:
            raise test_harness.TestException('no checksum in host output')

        host_checksum = int(got.group('checksum'), 16)
        print('host checksum %08x' % host_checksum)

        # Compile and run under emulator
        test_harness.build_program([source_file], cflags=[csmith_include])
        result = test_harness.run_program(target)
        got = CHECKSUM_RE.search(result)
        if not got:
            raise test_harness.TestException('no checksum in host output')

        emulator_checksum = int(got.group('checksum'), 16)
        print('emulator checksum %08x' % emulator_checksum)
        if host_checksum != emulator_checksum:
            raise test_harness.TestException('checksum mismatch')

        print('PASS')

test_harness.execute_tests()
