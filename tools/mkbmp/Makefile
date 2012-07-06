OBJDIR=OBJECTS
CFLAGS=-Wall -W -g

SRCS=mkbmp.c
LIBS=-lm

OBJS := $(SRCS:%.c=$(OBJDIR)/%.o)
DEPS := $(SRCS:%.c=$(OBJDIR)/%.d)

mkbmp: $(OBJS)
	gcc -g -o $@ $(OBJS) $(LIBS)

-include $(DEPS)

$(OBJDIR)/%.o : %.c
	mkdir -p $(dir $@)
	gcc $(CFLAGS) -o $@ -c $<
	gcc $(CFLAGS) -o $(OBJDIR)/$*.d -MM $<

clean:
	rm -rf $(OBJDIR)
	rm -rf emulator

