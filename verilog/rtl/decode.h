// 
// Copyright 2011-2012 Jeff Bush
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

//
// Constants in decode stage output signals
//

`define MASK_SRC_SCALAR1 		3'b000
`define MASK_SRC_SCALAR1_INV 	3'b001
`define MASK_SRC_SCALAR2		3'b010
`define MASK_SRC_SCALAR2_INV	3'b011
`define MASK_SRC_ALL_ONES		3'b100

`define OP2_SRC_SCALAR2			2'b00
`define OP2_SRC_VECTOR2			2'b01
`define OP2_SRC_IMMEDIATE		2'b10
