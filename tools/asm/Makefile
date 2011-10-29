OBJDIR=OBJECTS
CFLAGS=-Wall -W -g

SRCS=main.c code_output.c symbol_table.c debug_info.c

OBJS := $(SRCS:%.c=$(OBJDIR)/%.o) $(OBJDIR)/parser.o
DEPS := $(SRCS:%.c=$(OBJDIR)/%.d)

assemble: $(OBJS)
	gcc -g -o $@ $(OBJS)

-include $(DEPS)

$(OBJDIR)/%.o : %.c
	mkdir -p $(dir $@)
	gcc $(CFLAGS) -o $@ -c $<
	gcc $(CFLAGS) -o $(OBJDIR)/$*.d -MM $<

$(OBJDIR)/lex.yy.c:	scanner.l $(OBJDIR)
	flex -o $@ scanner.l
	
$(OBJDIR)/parser.tab.c: $(OBJDIR)/lex.yy.c parser.y $(OBJDIR)
	bison -o $@ --debug parser.y

$(OBJDIR)/parser.o: $(OBJDIR)/parser.tab.c
	gcc -I. $(CFLAGS) -DYYDEBUG=1 -c -o $@ $<

clean:
	rm -rf $(OBJDIR)
	rm -rf assemble

