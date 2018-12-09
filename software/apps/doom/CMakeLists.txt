#
# Copyright 2018 Jeff Bush
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

project(doom)
include(nyuzi)

add_nyuzi_executable(doom
    DISPLAY_WIDTH 640 DISPLAY_HEIGHT 400
    MEMORY_SIZE 0x4000000
    FS_IMAGE_FILES DOOM1.WAD
    SOURCES
    doomdef.c
    doomstat.c
    dstrings.c
    i_system.c
    i_sound.c
    i_video.c
    i_net.c
    tables.c
    f_finale.c
    f_wipe.c
    d_main.c
    d_net.c
    d_items.c
    g_game.c
    m_menu.c
    m_misc.c
    m_argv.c
    m_bbox.c
    m_fixed.c
    m_swap.c
    m_cheat.c
    m_random.c
    am_map.c
    p_ceilng.c
    p_doors.c
    p_enemy.c
    p_floor.c
    p_inter.c
    p_lights.c
    p_map.c
    p_maputl.c
    p_plats.c
    p_pspr.c
    p_setup.c
    p_sight.c
    p_spec.c
    p_switch.c
    p_mobj.c
    p_telept.c
    p_tick.c
    p_saveg.c
    p_user.c
    r_bsp.c
    r_data.c
    r_draw.c
    r_main.c
    r_plane.c
    r_segs.c
    r_sky.c
    r_things.c
    w_wad.c
    wi_stuff.c
    v_video.c
    st_lib.c
    st_stuff.c
    hu_stuff.c
    hu_lib.c
    s_sound.c
    z_zone.c
    info.c
    sounds.c
    i_main.c)

# Lots of warnings in this code :)
target_compile_options(doom PRIVATE -Wno-error)

target_link_libraries(doom
    c
    os-bare)
