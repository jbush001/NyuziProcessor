OBJDIR=OBJECTS
CFLAGS=-Wall -W -g

SRCS=command_interface.c main.c core.c debug_info.c

OBJS := $(SRCS:%.c=$(OBJDIR)/%.o)
DEPS := $(SRCS:%.c=$(OBJDIR)/%.d)

emulator: $(OBJS)
	gcc -g -o $@ $(OBJS)

-include $(DEPS)

$(OBJDIR)/%.o : %.c
	mkdir -p $(dir $@)
	gcc $(CFLAGS) -o $@ -c $<
	gcc $(CFLAGS) -o $(OBJDIR)/$*.d -MM $<

clean:
	rm -rf $(OBJDIR)
	rm -rf emulator

