//
// Copyright 2016-2017 Jeff Bush
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

void console_init(void *base_address, unsigned int width, unsigned int height);
void console_set_colors(unsigned int foreground, unsigned int background);
void console_clear(void);
void console_putc_at(unsigned int column, unsigned int row, char character);
void console_scroll_up(void);
void console_set_pos(unsigned int col, unsigned int row);
void console_newline(void);
void console_putc(char c);
void console_puts(const char *str);
void console_set_pos(unsigned int col, unsigned int row);
int console_read_char(void);
int console_read_line(char *buffer, int maxlength);

#ifdef __cplusplus
}
#endif
