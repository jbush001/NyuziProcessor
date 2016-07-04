//
// Copyright 2016 Jeff Bush
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
// This test validates a feature where the emulator can map its
// system memory as a shared memory file that can be mapped into
// other emulators or test programs representing a host processor.
//
// For each transfer:
// 1. Host sets the value it wants to transform and sets owner
//    to 1 (coprocessor)
// 2. Client polls on owner. When it sees it is 1, it reads
//    the value, complements it (xor with 0xffffffff) and writes it back.
// 3. Client sets the owner field back to 0.
// 4. Host polls on owner field. When it sees it is 0, it reads the value.
//

#define OWNER_HOST 0
#define OWNER_COPROCESSOR 1

struct mailbox
{
    int owner;
    int value;
};

int main(void)
{
    volatile struct mailbox *mbox = (volatile struct mailbox*) 0x100000;

    mbox->owner = OWNER_HOST;
    while (1)
    {
        while (mbox->owner != OWNER_COPROCESSOR)
            ;

        // Need to update owner after value. Because these are volatile,
        // the compiler will not reorder them.
        mbox->value = ~mbox->value;
        mbox->owner = OWNER_HOST;
        __asm("dflush %0" : : "r" (mbox));
    }
}
