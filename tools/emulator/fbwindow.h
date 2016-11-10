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

#ifndef FBWINDOW_H
#define FBWINDOW_H

#include "processor.h"

int init_frame_buffer(uint32_t width, uint32_t height);
void update_frame_buffer(struct processor*);
void poll_fb_window_event(void);
void enable_frame_buffer(bool enable);
void set_frame_buffer_address(uint32_t address);

extern uint32_t screen_refresh_rate;

#endif
