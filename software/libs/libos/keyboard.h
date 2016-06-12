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


#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define KBD_PRESSED 0x00080000

#define KBD_F1 128
#define KBD_F2 129
#define KBD_F3 130
#define KBD_F4 131
#define KBD_F5 132
#define KBD_F6 133
#define KBD_F7 134
#define KBD_F8 135
#define KBD_F9 136
#define KBD_F10 137
#define KBD_F11 138
#define KBD_F12 139
#define KBD_RIGHTARROW 140
#define KBD_LEFTARROW 141
#define KBD_UPARROW 142
#define KBD_DOWNARROW 143
#define KBD_RSHIFT 144
#define KBD_LSHIFT 145
#define KBD_RALT 146
#define KBD_LALT 147
#define KBD_RCTRL 148
#define KBD_LCTRL 149
#define KBD_DELETE 150

// Return 0xffffffff if no key is pressed
unsigned int poll_keyboard(void);


#ifdef __cplusplus
}
#endif
