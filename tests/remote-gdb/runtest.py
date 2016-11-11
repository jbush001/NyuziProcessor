#!/usr/bin/env python
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

import sys
import subprocess
import re
import os
import socket
import time

sys.path.insert(0, '..')
from test_harness import *

class DebugConnection:
    def __init__(self):
        pass

    def __enter__(self):
        for retry in range(3):
            try:
                time.sleep(2)
                self.sock = socket.socket()
                self.sock.connect(('localhost', 8000))
                self.sock.settimeout(3)
                break
            except Exception, e:
                print('socket connect failed, retrying' + str(e))

        return self

    def __exit__(self, type, value, traceback):
        self.sock.close()

    def sendPacket(self, body):
        self.sock.send('$')
        self.sock.send(body)
        self.sock.send('#')

        # Checksum
        self.sock.send('\x00')
        self.sock.send('\x00')


    def receivePacket(self):
        while True:
            leader = self.sock.recv(1)
            if leader == '$':
                break

        contents = ''
        while True:
            c = self.sock.recv(1)
            if c == '#':
                break

            contents += c

        return contents

class EmulatorTarget:
    def __init__(self, hexfile):
        self.hexfile = hexfile

    def __enter__(self):
        emulator_args = [
            BIN_DIR + 'emulator',
            '-m',
            'gdb',
            self.hexfile
        ]

        self.process = subprocess.Popen(emulator_args)
        return self

    def __exit__(self, type, value, traceback):
        self.process.kill()

def run_remote_gdb_test(name):
    hexfile = build_program(['test_program.S'])
    with EmulatorTarget(hexfile) as p, DebugConnection() as d:
        d.sendPacket('A')
        response = d.receivePacket()
        if response != 'OK':
            raise TestException('bad resopnse, got ' + response)

        d.sendPacket('k')

register_tests(run_remote_gdb_test, ['remote_gdb'])
execute_tests()

