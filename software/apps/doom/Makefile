################################################################
#
# $Id:$
#
# $Log:$
#

TOPDIR=../../../

include $(TOPDIR)/build/target.mk

CFLAGS+=-Wno-unused-const-variable
LIBS=-lc -los-bare

SRCS=	doomdef.c		\
		doomstat.c		\
		dstrings.c		\
		i_system.c		\
		i_sound.c		\
		i_video.c		\
		i_net.c			\
		tables.c			\
		f_finale.c		\
		f_wipe.c 		\
		d_main.c			\
		d_net.c			\
		d_items.c		\
		g_game.c			\
		m_menu.c			\
		m_misc.c			\
		m_argv.c  		\
		m_bbox.c			\
		m_fixed.c		\
		m_swap.c			\
		m_cheat.c		\
		m_random.c		\
		am_map.c			\
		p_ceilng.c		\
		p_doors.c		\
		p_enemy.c		\
		p_floor.c		\
		p_inter.c		\
		p_lights.c		\
		p_map.c			\
		p_maputl.c		\
		p_plats.c		\
		p_pspr.c			\
		p_setup.c		\
		p_sight.c		\
		p_spec.c			\
		p_switch.c		\
		p_mobj.c			\
		p_telept.c		\
		p_tick.c			\
		p_saveg.c		\
		p_user.c			\
		r_bsp.c			\
		r_data.c			\
		r_draw.c			\
		r_main.c			\
		r_plane.c		\
		r_segs.c			\
		r_sky.c			\
		r_things.c		\
		w_wad.c			\
		wi_stuff.c		\
		v_video.c		\
		st_lib.c			\
		st_stuff.c		\
		hu_stuff.c		\
		hu_lib.c			\
		s_sound.c		\
		z_zone.c			\
		info.c				\
		sounds.c \
		i_main.c \

OBJS := $(CRT0_BARE) $(SRCS_TO_OBJS)
DEPS := $(SRCS_TO_DEPS)

all: $(OBJ_DIR)/doom.hex fsimage.bin

clean:
	rm -f $(OBJ_DIR)/*

$(OBJ_DIR)/doom.hex: $(OBJS) $(DEPS)
	$(LD) $(OBJS) -o $(OBJ_DIR)/doom.elf $(LIBS) $(LDFLAGS)
	$(ELF2HEX) -o $(OBJ_DIR)/doom.hex -b 0 $(OBJ_DIR)/doom.elf
	$(OBJDUMP) --disassemble $(OBJ_DIR)/doom.elf > doom.lst 2> /dev/null

run: $(OBJ_DIR) $(OBJ_DIR)/doom.hex fsimage.bin
	$(EMULATOR) -f 640x400  -b fsimage.bin obj/doom.hex

debug: $(OBJ_DIR) $(OBJ_DIR)/doom.hex fsimage.bin
	$(EMULATOR) -m gdb -f 640x400  -b fsimage.bin obj/doom.hex &
	$(LLDB) --arch nyuzi $(OBJ_DIR)/doom.elf -o "gdb-remote 8000"

verirun: $(OBJ_DIR)  $(OBJ_DIR)/doom.hex fsimage.bin
	$(VERILATOR) +bin=obj/doom.hex +block=fsimage.bin

fpgarun: $(OBJ_DIR)/doom.hex
	$(SERIAL_BOOT) $(SERIAL_PORT) $(OBJ_DIR)/doom.hex fsimage.bin

fsimage.bin: DOOM1.WAD
	$(MKFS) fsimage.bin DOOM1.WAD

DOOM1.WAD:
	@echo "Need to provide DOOM1.WAD. See README"
	exit 1

-include $(DEPS)

