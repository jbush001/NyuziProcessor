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

#ifndef __PROTOCOL_H
#define __PROTOCOL_H

enum message_type
{
    LOAD_MEMORY_REQ = 0xc0,
    LOAD_MEMORY_ACK,
    EXECUTE_REQ,
    EXECUTE_ACK,
    PING_REQ,
    PING_ACK,
    CLEAR_MEMORY_REQ,
    CLEAR_MEMORY_ACK,
    BAD_COMMAND
};

#endif
