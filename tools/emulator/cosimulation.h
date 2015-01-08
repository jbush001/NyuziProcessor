// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//

#ifndef __COSIMULATION_H
#define __COSIMULATION_H

#include "core.h"

int runCosim(Core *core, int verbose);
void cosimSetScalarReg(Core *core, uint32_t pc, int reg, uint32_t value);
void cosimSetVectorReg(Core *core, uint32_t pc, int reg, int mask, const uint32_t value[16]);
void cosimWriteBlock(Core *core, uint32_t pc, uint32_t address, int mask, const uint32_t values[16]);
void cosimWriteMemory(Core *core, uint32_t pc, uint32_t address, size_t size, uint32_t value);

#endif
