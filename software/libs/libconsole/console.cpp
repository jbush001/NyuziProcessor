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

#include <stdio.h>
#include <string.h>
#include <keyboard.h>
#include "console.h"
#include "font.h"

#define BLINK_INTERVAL 0x80000
#define TAB_WIDTH 8

static unsigned int current_col;
static unsigned int current_row;
static unsigned int *frame_buffer;
static unsigned int fb_width;
static unsigned int fb_height;
static unsigned int fg_color;
static unsigned int bg_color;
static unsigned int num_cols;
static unsigned int num_rows;
static unsigned int cursor_timer;
static unsigned int cursor_state;

void console_init(void *base_address, unsigned int width, unsigned int height)
{
    frame_buffer = static_cast<unsigned int*>(base_address);
    fb_width = width;
    fb_height = height;
    num_cols = width / GLYPH_WIDTH;
    num_rows = height / (GLYPH_HEIGHT * 2);
    bg_color = 0;
    fg_color = 0xffffffff;
    current_col = 0;
    current_row = 0;
    console_clear();
}

void console_set_colors(unsigned int foreground, unsigned int background)
{
    bg_color = background;
    fg_color = foreground;
}

void console_clear(void)
{
    unsigned int total_pixels = fb_width * fb_height;
    unsigned int *fb_ptr = frame_buffer;
    while (total_pixels--)
        *fb_ptr++ = bg_color;
}

void console_putc_at(unsigned int column, unsigned int row, char character)
{
    const unsigned char *glyph_data;
    unsigned int *dest_row_ptr;
    unsigned int shift;

    if (character < LOW_CHAR || character > HIGH_CHAR)
        character = '?';
    dest_row_ptr = frame_buffer + (column * GLYPH_WIDTH
        + row * fb_width * GLYPH_HEIGHT * 2);
    glyph_data = &FONT_DATA[(character - LOW_CHAR) * GLYPH_HEIGHT];
    for (unsigned int y = 0; y < 8; y++)
    {
        shift = glyph_data[y];
        for (unsigned int x = 0; x < 8; x++)
        {
            if (shift & 0x80)
            {
                dest_row_ptr[x] = fg_color;
                dest_row_ptr[x + fb_width] = fg_color;
            }
            else
            {
                dest_row_ptr[x] = bg_color;
                dest_row_ptr[x + fb_width] = bg_color;
            }

            shift <<= 1;
        }

        dest_row_ptr += fb_width * 2;
    }
}

void console_scroll_up(void)
{
    unsigned int total_pixels;
    unsigned int *fb_ptr;

    memcpy(frame_buffer, frame_buffer + fb_width * GLYPH_HEIGHT * 2,
           fb_width * (fb_height - GLYPH_HEIGHT * 2) * sizeof(unsigned int));

    // Clear bottom row
    total_pixels = fb_width * GLYPH_HEIGHT * 2;
    fb_ptr = frame_buffer + fb_width * (fb_height - GLYPH_HEIGHT * 2);
    while (total_pixels--)
        *fb_ptr++ = bg_color;
}

void console_newline(void)
{
    current_col = 0;
    if (++current_row == num_rows)
    {
        current_row--;
        console_scroll_up();
    }
}

void console_putc(char c)
{
    if (c == '\n')
    {
        console_newline();
        return;
    }
    else if (c == '\t')
    {
        current_col = (current_col - (current_col % TAB_WIDTH)) + TAB_WIDTH;
        if (current_col >= num_cols)
            console_newline();

        return;
    }
    else if (c == 8)
    {
        if (current_col == 0)
        {
            if (current_row > 0)
            {
                current_row--;
                current_col = num_cols - 1;
            }
        }
        else
            current_col--;

        console_putc_at(current_col, current_row, ' ');
        return;
    }

    console_putc_at(current_col, current_row, c);

    if (++current_col == num_cols)
        console_newline();
}

void console_puts(const char *str)
{
    const char *c;

    for (c = str; *c; c++)
        console_putc(*c);
}

void console_set_pos(unsigned int col, unsigned int row)
{
    if (col >= num_cols)
        col = num_cols - 1;

    if (row >= num_rows)
        row = num_rows  - 1;

    current_col = col;
    current_row = row;
}

static void invert_cursor(void)
{
    unsigned int *dest_row_ptr = frame_buffer + (current_col * GLYPH_WIDTH
        + current_row * fb_width * GLYPH_HEIGHT * 2);
    for (int row = 0; row < GLYPH_HEIGHT * 2; row++)
    {
        for (int col = 0; col < GLYPH_WIDTH; col++)
            dest_row_ptr[col] ^= (fg_color ^ bg_color);

        dest_row_ptr += fb_width;
    }
}

int console_read_char(void)
{
    unsigned int code;

    for (;;)
    {
        if (++cursor_timer == BLINK_INTERVAL)
        {
            invert_cursor();
            cursor_state = !cursor_state;
            cursor_timer = 0;
        }

        code = poll_keyboard();
        if ((code != 0xffffffff) && (code & KBD_PRESSED))
            break;
    }

    if (cursor_state)
    {
        invert_cursor();
        cursor_state = 0;
    }

    return code & 0xff;
}

int console_read_line(char *buffer, int max_length)
{
    int current_offset = 0;

    for (;;)
    {
        int c = console_read_char();
        if (c == '\n')
        {
            // Newline
            console_putc(c);
            break;
        }
        else if (c == '\b')
        {
            // Backspace
            if (current_offset > 0)
            {
                current_offset--;
                console_putc(c);
            }
        }
        else if (c < 128)
        {
            if (current_offset < max_length)
            {
                buffer[current_offset++] = c;
                console_putc(c);
            }
        }
    }

	buffer[current_offset] = '\0';

    return current_offset;
}

