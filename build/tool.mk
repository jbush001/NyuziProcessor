#
# Copyright 2015 Jeff Bush
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

#
# This is included by makefiles that compile tools that run on the host
# machine.
#

BINDIR=$(TOPDIR)/bin
OBJ_DIR=obj

define SRCS_TO_OBJS
	$(addprefix $(OBJ_DIR)/, $(addsuffix .o, $(foreach file, $(SRCS), $(basename $(notdir $(file))))))
endef

define SRCS_TO_DEPS
	$(addprefix $(OBJ_DIR)/, $(addsuffix .d, $(foreach file, $(filter-out %.s, $(SRCS)), $(basename $(notdir $(file))))))
endef

ifneq (,$(findstring clang, $(shell $(CC) --version)))
	# -Weverything is only supported on clang
	WARNINGS =-Weverything -Wno-padded -Wno-float-equal -Wno-covered-switch-default \
		-Wno-switch-enum -Wno-bad-function-cast -Wno-documentation -Wno-documentation-unknown-command \
		-Wno-missing-prototypes -Wno-reserved-id-macro -Werror
else
	WARNINGS=-Wall -W -Werror
endif

CFLAGS=-O3 $(WARNINGS)

$(OBJ_DIR)/%.d: %.c
	@echo "Building dependencies for $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -o $(OBJ_DIR)/$*.d -M -MT $(OBJ_DIR)/$(notdir $(basename $<)).o $<

$(OBJ_DIR)/%.d: %.cpp
	@echo "Building dependencies for $<"
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -o $(OBJ_DIR)/$*.d -M -MT $(OBJ_DIR)/$(notdir $(basename $<)).o $<

$(OBJ_DIR)/%.o : %.cpp
	@echo "Compiling $<"
	@mkdir -p $(OBJ_DIR)
	@gcc $(CFLAGS) -o $@ -c $<

$(OBJ_DIR)/%.o : %.c
	@echo "Compiling $<"
	@mkdir -p $(OBJ_DIR)
	@gcc $(CFLAGS) -o $@ -c $<

