//
// Copyright 2015 Jeff Bush
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

unsigned int * volatile mailbox = (unsigned int*) 0x100000;

//
// This test validates a feature where the emulator can map its
// system memory as a shared memory file that can be mapped into
// other emulators or test programs representing a host processor.
//
// The shared memory mailbox at 0x100000 consists of two fields:
//
// struct mailbox {
//     unsigned int owner;
//     unsigned int value;
// };
//
// The owner field is set to 0 if the host owns it, and 1 if
// the client owns it. For each transaction:
// 1. Host sets the value it wants to transform and sets owner
//    to 1 (coprocessor)
// 2. Client polls on owner. When it sees it is 1, it reads
//    the value, complements it (xor with 0xffffffff) and writes it back.
// 3. Client sets the owner field back to 0.
// 4. Host polls on owner field. When it sees it is 0, it reads the value.
//

int main(void)
{
    mailbox[0] = 0;

    while (1)
    {
        if (mailbox[0] == 1)
        {
            mailbox[1] = ~mailbox[1];
            __sync_synchronize();
            mailbox[0] = 0;
            __asm("dflush %0" : : "r" (mailbox));
        }
    }
}