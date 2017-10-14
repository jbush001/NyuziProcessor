//
// Copyright 2011-2015 Jeff Bush
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

`include "defines.sv"

import defines::*;

//
// A single instruction pipeline with L1 instruction & data caches and L2
// interface logic.
//

module core
    #(parameter CORE_ID = '0,
    parameter RESET_PC = '0,
    parameter NUM_INTERRUPTS = 16)

    (input                                 clk,
    input                                  reset,
    input local_thread_bitmap_t            thread_en,
    input [NUM_INTERRUPTS - 1:0]           interrupt_req,

    // From l1_l2_interface
    input                                  l2_ready,
    input                                  l2_response_valid,
    input l2rsp_packet_t                   l2_response,

    // To l1_l2_interface
    output logic                           l2i_request_valid,
    output l2req_packet_t                  l2i_request,

    // From io_request_queue
    input                                  ii_ready,
    input                                  ii_response_valid,
    input iorsp_packet_t                   ii_response,

    // To io_request_queue
    output logic                           ior_request_valid,
    output ioreq_packet_t                  ior_request,

    // To performance_counters
    output logic [CORE_PERF_EVENTS - 1:0]  core_perf_events);

    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    scalar_t            cr_creg_read_val;       // From control_registers of control_registers.v
    logic [ASID_WIDTH-1:0] cr_current_asid [`THREADS_PER_CORE];// From control_registers of control_registers.v
    scalar_t            cr_eret_address [`THREADS_PER_CORE];// From control_registers of control_registers.v
    subcycle_t          cr_eret_subcycle [`THREADS_PER_CORE];// From control_registers of control_registers.v
    local_thread_bitmap_t cr_interrupt_en;      // From control_registers of control_registers.v
    logic [`THREADS_PER_CORE-1:0] cr_interrupt_pending;// From control_registers of control_registers.v
    logic               cr_mmu_en [`THREADS_PER_CORE];// From control_registers of control_registers.v
    logic               cr_supervisor_en [`THREADS_PER_CORE];// From control_registers of control_registers.v
    scalar_t            cr_tlb_miss_handler;    // From control_registers of control_registers.v
    scalar_t            cr_trap_handler;        // From control_registers of control_registers.v
    logic               dd_cache_miss;          // From dcache_data_stage of dcache_data_stage.v
    cache_line_index_t  dd_cache_miss_addr;     // From dcache_data_stage of dcache_data_stage.v
    logic               dd_cache_miss_sync;     // From dcache_data_stage of dcache_data_stage.v
    local_thread_idx_t  dd_cache_miss_thread_idx;// From dcache_data_stage of dcache_data_stage.v
    control_register_t  dd_creg_index;          // From dcache_data_stage of dcache_data_stage.v
    logic               dd_creg_read_en;        // From dcache_data_stage of dcache_data_stage.v
    logic               dd_creg_write_en;       // From dcache_data_stage of dcache_data_stage.v
    scalar_t            dd_creg_write_val;      // From dcache_data_stage of dcache_data_stage.v
    logic               dd_dinvalidate_en;      // From dcache_data_stage of dcache_data_stage.v
    logic               dd_fault;               // From dcache_data_stage of dcache_data_stage.v
    trap_cause_t        dd_fault_cause;         // From dcache_data_stage of dcache_data_stage.v
    logic               dd_flush_en;            // From dcache_data_stage of dcache_data_stage.v
    logic               dd_iinvalidate_en;      // From dcache_data_stage of dcache_data_stage.v
    decoded_instruction_t dd_instruction;       // From dcache_data_stage of dcache_data_stage.v
    logic               dd_instruction_valid;   // From dcache_data_stage of dcache_data_stage.v
    scalar_t            dd_io_addr;             // From dcache_data_stage of dcache_data_stage.v
    logic               dd_io_read_en;          // From dcache_data_stage of dcache_data_stage.v
    local_thread_idx_t  dd_io_thread_idx;       // From dcache_data_stage of dcache_data_stage.v
    logic               dd_io_write_en;         // From dcache_data_stage of dcache_data_stage.v
    scalar_t            dd_io_write_value;      // From dcache_data_stage of dcache_data_stage.v
    logic               dd_is_io_address;       // From dcache_data_stage of dcache_data_stage.v
    vector_lane_mask_t  dd_lane_mask;           // From dcache_data_stage of dcache_data_stage.v
    cache_line_data_t   dd_load_data;           // From dcache_data_stage of dcache_data_stage.v
    logic               dd_membar_en;           // From dcache_data_stage of dcache_data_stage.v
    logic               dd_perf_dcache_hit;     // From dcache_data_stage of dcache_data_stage.v
    logic               dd_perf_dcache_miss;    // From dcache_data_stage of dcache_data_stage.v
    logic               dd_perf_dtlb_miss;      // From dcache_data_stage of dcache_data_stage.v
    logic               dd_perf_store;          // From dcache_data_stage of dcache_data_stage.v
    l1d_addr_t          dd_request_vaddr;       // From dcache_data_stage of dcache_data_stage.v
    logic               dd_rollback_en;         // From dcache_data_stage of dcache_data_stage.v
    scalar_t            dd_rollback_pc;         // From dcache_data_stage of dcache_data_stage.v
    cache_line_index_t  dd_store_addr;          // From dcache_data_stage of dcache_data_stage.v
    cache_line_index_t  dd_store_bypass_addr;   // From dcache_data_stage of dcache_data_stage.v
    local_thread_idx_t  dd_store_bypass_thread_idx;// From dcache_data_stage of dcache_data_stage.v
    cache_line_data_t   dd_store_data;          // From dcache_data_stage of dcache_data_stage.v
    logic               dd_store_en;            // From dcache_data_stage of dcache_data_stage.v
    logic [CACHE_LINE_BYTES-1:0] dd_store_mask; // From dcache_data_stage of dcache_data_stage.v
    logic               dd_store_sync;          // From dcache_data_stage of dcache_data_stage.v
    local_thread_idx_t  dd_store_thread_idx;    // From dcache_data_stage of dcache_data_stage.v
    subcycle_t          dd_subcycle;            // From dcache_data_stage of dcache_data_stage.v
    logic               dd_suspend_thread;      // From dcache_data_stage of dcache_data_stage.v
    local_thread_bitmap_t dd_sync_load_pending; // From dcache_data_stage of dcache_data_stage.v
    local_thread_idx_t  dd_thread_idx;          // From dcache_data_stage of dcache_data_stage.v
    logic               dd_update_lru_en;       // From dcache_data_stage of dcache_data_stage.v
    l1d_way_idx_t       dd_update_lru_way;      // From dcache_data_stage of dcache_data_stage.v
    l1d_way_idx_t       dt_fill_lru;            // From dcache_tag_stage of dcache_tag_stage.v
    decoded_instruction_t dt_instruction;       // From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_instruction_valid;   // From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_invalidate_tlb_all_en;// From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_invalidate_tlb_en;   // From dcache_tag_stage of dcache_tag_stage.v
    logic [ASID_WIDTH-1:0] dt_itlb_update_asid; // From dcache_tag_stage of dcache_tag_stage.v
    page_index_t        dt_itlb_vpage_idx;      // From dcache_tag_stage of dcache_tag_stage.v
    vector_lane_mask_t  dt_mask_value;          // From dcache_tag_stage of dcache_tag_stage.v
    l1d_addr_t          dt_request_paddr;       // From dcache_tag_stage of dcache_tag_stage.v
    l1d_addr_t          dt_request_vaddr;       // From dcache_tag_stage of dcache_tag_stage.v
    l1d_tag_t           dt_snoop_tag [`L1D_WAYS];// From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_snoop_valid [`L1D_WAYS];// From dcache_tag_stage of dcache_tag_stage.v
    vector_t            dt_store_value;         // From dcache_tag_stage of dcache_tag_stage.v
    subcycle_t          dt_subcycle;            // From dcache_tag_stage of dcache_tag_stage.v
    l1d_tag_t           dt_tag [`L1D_WAYS];     // From dcache_tag_stage of dcache_tag_stage.v
    local_thread_idx_t  dt_thread_idx;          // From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_tlb_hit;             // From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_tlb_present;         // From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_tlb_supervisor;      // From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_tlb_writable;        // From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_update_itlb_en;      // From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_update_itlb_executable;// From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_update_itlb_global;  // From dcache_tag_stage of dcache_tag_stage.v
    page_index_t        dt_update_itlb_ppage_idx;// From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_update_itlb_present; // From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_update_itlb_supervisor;// From dcache_tag_stage of dcache_tag_stage.v
    logic               dt_valid [`L1D_WAYS];   // From dcache_tag_stage of dcache_tag_stage.v
    logic [NUM_VECTOR_LANES-1:0] [7:0] fx1_add_exponent;// From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] fx1_add_result_sign;// From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] [5:0] fx1_ftoi_lshift;// From fp_execute_stage1 of fp_execute_stage1.v
    decoded_instruction_t fx1_instruction;      // From fp_execute_stage1 of fp_execute_stage1.v
    logic               fx1_instruction_valid;  // From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] fx1_logical_subtract;// From fp_execute_stage1 of fp_execute_stage1.v
    vector_lane_mask_t  fx1_mask_value;         // From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] [7:0] fx1_mul_exponent;// From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] fx1_mul_sign;  // From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] [31:0] fx1_multiplicand;// From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] [31:0] fx1_multiplier;// From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] fx1_result_is_inf;// From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] fx1_result_is_nan;// From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] [5:0] fx1_se_align_shift;// From fp_execute_stage1 of fp_execute_stage1.v
    scalar_t [NUM_VECTOR_LANES-1:0] fx1_significand_le;// From fp_execute_stage1 of fp_execute_stage1.v
    scalar_t [NUM_VECTOR_LANES-1:0] fx1_significand_se;// From fp_execute_stage1 of fp_execute_stage1.v
    subcycle_t          fx1_subcycle;           // From fp_execute_stage1 of fp_execute_stage1.v
    local_thread_idx_t  fx1_thread_idx;         // From fp_execute_stage1 of fp_execute_stage1.v
    logic [NUM_VECTOR_LANES-1:0] [7:0] fx2_add_exponent;// From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] fx2_add_result_sign;// From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] [5:0] fx2_ftoi_lshift;// From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] fx2_guard;     // From fp_execute_stage2 of fp_execute_stage2.v
    decoded_instruction_t fx2_instruction;      // From fp_execute_stage2 of fp_execute_stage2.v
    logic               fx2_instruction_valid;  // From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] fx2_logical_subtract;// From fp_execute_stage2 of fp_execute_stage2.v
    vector_lane_mask_t  fx2_mask_value;         // From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] [7:0] fx2_mul_exponent;// From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] fx2_mul_sign;  // From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] fx2_result_is_inf;// From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] fx2_result_is_nan;// From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] fx2_round;     // From fp_execute_stage2 of fp_execute_stage2.v
    scalar_t [NUM_VECTOR_LANES-1:0] fx2_significand_le;// From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] [63:0] fx2_significand_product;// From fp_execute_stage2 of fp_execute_stage2.v
    scalar_t [NUM_VECTOR_LANES-1:0] fx2_significand_se;// From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] fx2_sticky;    // From fp_execute_stage2 of fp_execute_stage2.v
    subcycle_t          fx2_subcycle;           // From fp_execute_stage2 of fp_execute_stage2.v
    local_thread_idx_t  fx2_thread_idx;         // From fp_execute_stage2 of fp_execute_stage2.v
    logic [NUM_VECTOR_LANES-1:0] [7:0] fx3_add_exponent;// From fp_execute_stage3 of fp_execute_stage3.v
    logic [NUM_VECTOR_LANES-1:0] fx3_add_result_sign;// From fp_execute_stage3 of fp_execute_stage3.v
    scalar_t [NUM_VECTOR_LANES-1:0] fx3_add_significand;// From fp_execute_stage3 of fp_execute_stage3.v
    logic [NUM_VECTOR_LANES-1:0] [5:0] fx3_ftoi_lshift;// From fp_execute_stage3 of fp_execute_stage3.v
    decoded_instruction_t fx3_instruction;      // From fp_execute_stage3 of fp_execute_stage3.v
    logic               fx3_instruction_valid;  // From fp_execute_stage3 of fp_execute_stage3.v
    logic [NUM_VECTOR_LANES-1:0] fx3_logical_subtract;// From fp_execute_stage3 of fp_execute_stage3.v
    vector_lane_mask_t  fx3_mask_value;         // From fp_execute_stage3 of fp_execute_stage3.v
    logic [NUM_VECTOR_LANES-1:0] [7:0] fx3_mul_exponent;// From fp_execute_stage3 of fp_execute_stage3.v
    logic [NUM_VECTOR_LANES-1:0] fx3_mul_sign;  // From fp_execute_stage3 of fp_execute_stage3.v
    logic [NUM_VECTOR_LANES-1:0] fx3_result_is_inf;// From fp_execute_stage3 of fp_execute_stage3.v
    logic [NUM_VECTOR_LANES-1:0] fx3_result_is_nan;// From fp_execute_stage3 of fp_execute_stage3.v
    logic [NUM_VECTOR_LANES-1:0] [63:0] fx3_significand_product;// From fp_execute_stage3 of fp_execute_stage3.v
    subcycle_t          fx3_subcycle;           // From fp_execute_stage3 of fp_execute_stage3.v
    local_thread_idx_t  fx3_thread_idx;         // From fp_execute_stage3 of fp_execute_stage3.v
    logic [NUM_VECTOR_LANES-1:0] [7:0] fx4_add_exponent;// From fp_execute_stage4 of fp_execute_stage4.v
    logic [NUM_VECTOR_LANES-1:0] fx4_add_result_sign;// From fp_execute_stage4 of fp_execute_stage4.v
    logic [NUM_VECTOR_LANES-1:0] [31:0] fx4_add_significand;// From fp_execute_stage4 of fp_execute_stage4.v
    decoded_instruction_t fx4_instruction;      // From fp_execute_stage4 of fp_execute_stage4.v
    logic               fx4_instruction_valid;  // From fp_execute_stage4 of fp_execute_stage4.v
    logic [NUM_VECTOR_LANES-1:0] fx4_logical_subtract;// From fp_execute_stage4 of fp_execute_stage4.v
    vector_lane_mask_t  fx4_mask_value;         // From fp_execute_stage4 of fp_execute_stage4.v
    logic [NUM_VECTOR_LANES-1:0] [7:0] fx4_mul_exponent;// From fp_execute_stage4 of fp_execute_stage4.v
    logic [NUM_VECTOR_LANES-1:0] fx4_mul_sign;  // From fp_execute_stage4 of fp_execute_stage4.v
    logic [NUM_VECTOR_LANES-1:0] [5:0] fx4_norm_shift;// From fp_execute_stage4 of fp_execute_stage4.v
    logic [NUM_VECTOR_LANES-1:0] fx4_result_is_inf;// From fp_execute_stage4 of fp_execute_stage4.v
    logic [NUM_VECTOR_LANES-1:0] fx4_result_is_nan;// From fp_execute_stage4 of fp_execute_stage4.v
    logic [NUM_VECTOR_LANES-1:0] [63:0] fx4_significand_product;// From fp_execute_stage4 of fp_execute_stage4.v
    subcycle_t          fx4_subcycle;           // From fp_execute_stage4 of fp_execute_stage4.v
    local_thread_idx_t  fx4_thread_idx;         // From fp_execute_stage4 of fp_execute_stage4.v
    decoded_instruction_t fx5_instruction;      // From fp_execute_stage5 of fp_execute_stage5.v
    logic               fx5_instruction_valid;  // From fp_execute_stage5 of fp_execute_stage5.v
    vector_lane_mask_t  fx5_mask_value;         // From fp_execute_stage5 of fp_execute_stage5.v
    vector_t            fx5_result;             // From fp_execute_stage5 of fp_execute_stage5.v
    subcycle_t          fx5_subcycle;           // From fp_execute_stage5 of fp_execute_stage5.v
    local_thread_idx_t  fx5_thread_idx;         // From fp_execute_stage5 of fp_execute_stage5.v
    decoded_instruction_t id_instruction;       // From instruction_decode_stage of instruction_decode_stage.v
    logic               id_instruction_valid;   // From instruction_decode_stage of instruction_decode_stage.v
    local_thread_idx_t  id_thread_idx;          // From instruction_decode_stage of instruction_decode_stage.v
    logic               ifd_alignment_fault;    // From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_cache_miss;         // From ifetch_data_stage of ifetch_data_stage.v
    cache_line_index_t  ifd_cache_miss_paddr;   // From ifetch_data_stage of ifetch_data_stage.v
    local_thread_idx_t  ifd_cache_miss_thread_idx;// From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_executable_fault;   // From ifetch_data_stage of ifetch_data_stage.v
    scalar_t            ifd_instruction;        // From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_instruction_valid;  // From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_near_miss;          // From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_page_fault;         // From ifetch_data_stage of ifetch_data_stage.v
    scalar_t            ifd_pc;                 // From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_perf_icache_hit;    // From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_perf_icache_miss;   // From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_perf_itlb_miss;     // From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_supervisor_fault;   // From ifetch_data_stage of ifetch_data_stage.v
    local_thread_idx_t  ifd_thread_idx;         // From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_tlb_miss;           // From ifetch_data_stage of ifetch_data_stage.v
    logic               ifd_update_lru_en;      // From ifetch_data_stage of ifetch_data_stage.v
    l1i_way_idx_t       ifd_update_lru_way;     // From ifetch_data_stage of ifetch_data_stage.v
    l1i_way_idx_t       ift_fill_lru;           // From ifetch_tag_stage of ifetch_tag_stage.v
    logic               ift_instruction_requested;// From ifetch_tag_stage of ifetch_tag_stage.v
    l1i_addr_t          ift_pc_paddr;           // From ifetch_tag_stage of ifetch_tag_stage.v
    scalar_t            ift_pc_vaddr;           // From ifetch_tag_stage of ifetch_tag_stage.v
    l1i_tag_t           ift_tag [`L1I_WAYS];    // From ifetch_tag_stage of ifetch_tag_stage.v
    local_thread_idx_t  ift_thread_idx;         // From ifetch_tag_stage of ifetch_tag_stage.v
    logic               ift_tlb_executable;     // From ifetch_tag_stage of ifetch_tag_stage.v
    logic               ift_tlb_hit;            // From ifetch_tag_stage of ifetch_tag_stage.v
    logic               ift_tlb_present;        // From ifetch_tag_stage of ifetch_tag_stage.v
    logic               ift_tlb_supervisor;     // From ifetch_tag_stage of ifetch_tag_stage.v
    logic               ift_valid [`L1I_WAYS];  // From ifetch_tag_stage of ifetch_tag_stage.v
    local_thread_bitmap_t ior_pending;          // From io_request_queue of io_request_queue.v
    scalar_t            ior_read_value;         // From io_request_queue of io_request_queue.v
    logic               ior_rollback_en;        // From io_request_queue of io_request_queue.v
    local_thread_bitmap_t ior_wake_bitmap;      // From io_request_queue of io_request_queue.v
    decoded_instruction_t ix_instruction;       // From int_execute_stage of int_execute_stage.v
    logic               ix_instruction_valid;   // From int_execute_stage of int_execute_stage.v
    logic               ix_is_eret;             // From int_execute_stage of int_execute_stage.v
    vector_lane_mask_t  ix_mask_value;          // From int_execute_stage of int_execute_stage.v
    logic               ix_perf_cond_branch_not_taken;// From int_execute_stage of int_execute_stage.v
    logic               ix_perf_cond_branch_taken;// From int_execute_stage of int_execute_stage.v
    logic               ix_perf_uncond_branch;  // From int_execute_stage of int_execute_stage.v
    logic               ix_privileged_op_fault; // From int_execute_stage of int_execute_stage.v
    vector_t            ix_result;              // From int_execute_stage of int_execute_stage.v
    logic               ix_rollback_en;         // From int_execute_stage of int_execute_stage.v
    scalar_t            ix_rollback_pc;         // From int_execute_stage of int_execute_stage.v
    subcycle_t          ix_subcycle;            // From int_execute_stage of int_execute_stage.v
    local_thread_idx_t  ix_thread_idx;          // From int_execute_stage of int_execute_stage.v
    logic               l2i_dcache_lru_fill_en; // From l1_l2_interface of l1_l2_interface.v
    l1d_set_idx_t       l2i_dcache_lru_fill_set;// From l1_l2_interface of l1_l2_interface.v
    local_thread_bitmap_t l2i_dcache_wake_bitmap;// From l1_l2_interface of l1_l2_interface.v
    cache_line_data_t   l2i_ddata_update_data;  // From l1_l2_interface of l1_l2_interface.v
    logic               l2i_ddata_update_en;    // From l1_l2_interface of l1_l2_interface.v
    l1d_set_idx_t       l2i_ddata_update_set;   // From l1_l2_interface of l1_l2_interface.v
    l1d_way_idx_t       l2i_ddata_update_way;   // From l1_l2_interface of l1_l2_interface.v
    logic [`L1D_WAYS-1:0] l2i_dtag_update_en_oh;// From l1_l2_interface of l1_l2_interface.v
    l1d_set_idx_t       l2i_dtag_update_set;    // From l1_l2_interface of l1_l2_interface.v
    l1d_tag_t           l2i_dtag_update_tag;    // From l1_l2_interface of l1_l2_interface.v
    logic               l2i_dtag_update_valid;  // From l1_l2_interface of l1_l2_interface.v
    logic               l2i_icache_lru_fill_en; // From l1_l2_interface of l1_l2_interface.v
    l1i_set_idx_t       l2i_icache_lru_fill_set;// From l1_l2_interface of l1_l2_interface.v
    local_thread_bitmap_t l2i_icache_wake_bitmap;// From l1_l2_interface of l1_l2_interface.v
    cache_line_data_t   l2i_idata_update_data;  // From l1_l2_interface of l1_l2_interface.v
    logic               l2i_idata_update_en;    // From l1_l2_interface of l1_l2_interface.v
    l1i_set_idx_t       l2i_idata_update_set;   // From l1_l2_interface of l1_l2_interface.v
    l1i_way_idx_t       l2i_idata_update_way;   // From l1_l2_interface of l1_l2_interface.v
    logic [`L1I_WAYS-1:0] l2i_itag_update_en;   // From l1_l2_interface of l1_l2_interface.v
    l1i_set_idx_t       l2i_itag_update_set;    // From l1_l2_interface of l1_l2_interface.v
    l1i_tag_t           l2i_itag_update_tag;    // From l1_l2_interface of l1_l2_interface.v
    logic               l2i_itag_update_valid;  // From l1_l2_interface of l1_l2_interface.v
    logic               l2i_snoop_en;           // From l1_l2_interface of l1_l2_interface.v
    l1d_set_idx_t       l2i_snoop_set;          // From l1_l2_interface of l1_l2_interface.v
    decoded_instruction_t of_instruction;       // From operand_fetch_stage of operand_fetch_stage.v
    logic               of_instruction_valid;   // From operand_fetch_stage of operand_fetch_stage.v
    vector_lane_mask_t  of_mask_value;          // From operand_fetch_stage of operand_fetch_stage.v
    vector_t            of_operand1;            // From operand_fetch_stage of operand_fetch_stage.v
    vector_t            of_operand2;            // From operand_fetch_stage of operand_fetch_stage.v
    vector_t            of_store_value;         // From operand_fetch_stage of operand_fetch_stage.v
    subcycle_t          of_subcycle;            // From operand_fetch_stage of operand_fetch_stage.v
    local_thread_idx_t  of_thread_idx;          // From operand_fetch_stage of operand_fetch_stage.v
    logic               sq_rollback_en;         // From l1_l2_interface of l1_l2_interface.v
    cache_line_data_t   sq_store_bypass_data;   // From l1_l2_interface of l1_l2_interface.v
    logic [CACHE_LINE_BYTES-1:0] sq_store_bypass_mask;// From l1_l2_interface of l1_l2_interface.v
    logic               sq_store_sync_success;  // From l1_l2_interface of l1_l2_interface.v
    local_thread_bitmap_t sq_sync_store_pending;// From l1_l2_interface of l1_l2_interface.v
    local_thread_bitmap_t ts_fetch_en;          // From thread_select_stage of thread_select_stage.v
    decoded_instruction_t ts_instruction;       // From thread_select_stage of thread_select_stage.v
    logic               ts_instruction_valid;   // From thread_select_stage of thread_select_stage.v
    logic               ts_perf_instruction_issue;// From thread_select_stage of thread_select_stage.v
    subcycle_t          ts_subcycle;            // From thread_select_stage of thread_select_stage.v
    local_thread_idx_t  ts_thread_idx;          // From thread_select_stage of thread_select_stage.v
    logic               wb_perf_instruction_retire;// From writeback_stage of writeback_stage.v
    logic               wb_perf_store_rollback; // From writeback_stage of writeback_stage.v
    logic               wb_rollback_en;         // From writeback_stage of writeback_stage.v
    scalar_t            wb_rollback_pc;         // From writeback_stage of writeback_stage.v
    pipeline_sel_t      wb_rollback_pipeline;   // From writeback_stage of writeback_stage.v
    subcycle_t          wb_rollback_subcycle;   // From writeback_stage of writeback_stage.v
    local_thread_idx_t  wb_rollback_thread_idx; // From writeback_stage of writeback_stage.v
    local_thread_bitmap_t wb_suspend_thread_oh; // From writeback_stage of writeback_stage.v
    logic               wb_trap;                // From writeback_stage of writeback_stage.v
    scalar_t            wb_trap_access_vaddr;   // From writeback_stage of writeback_stage.v
    trap_cause_t        wb_trap_cause;          // From writeback_stage of writeback_stage.v
    scalar_t            wb_trap_pc;             // From writeback_stage of writeback_stage.v
    subcycle_t          wb_trap_subcycle;       // From writeback_stage of writeback_stage.v
    local_thread_idx_t  wb_trap_thread_idx;     // From writeback_stage of writeback_stage.v
    logic               wb_writeback_en;        // From writeback_stage of writeback_stage.v
    logic               wb_writeback_is_last_subcycle;// From writeback_stage of writeback_stage.v
    logic               wb_writeback_is_vector; // From writeback_stage of writeback_stage.v
    vector_lane_mask_t  wb_writeback_mask;      // From writeback_stage of writeback_stage.v
    register_idx_t      wb_writeback_reg;       // From writeback_stage of writeback_stage.v
    local_thread_idx_t  wb_writeback_thread_idx;// From writeback_stage of writeback_stage.v
    vector_t            wb_writeback_value;     // From writeback_stage of writeback_stage.v
    // End of automatics

    //
    // Instruction Execution Pipeline
    //
    ifetch_tag_stage #(.RESET_PC(RESET_PC)) ifetch_tag_stage(.*);
    ifetch_data_stage ifetch_data_stage(.*);
    instruction_decode_stage instruction_decode_stage(.*);
    thread_select_stage thread_select_stage(.*);
    operand_fetch_stage operand_fetch_stage(.*);
    dcache_data_stage dcache_data_stage(.*);
    dcache_tag_stage dcache_tag_stage(.*);
    int_execute_stage int_execute_stage(.*);
    fp_execute_stage1 fp_execute_stage1(.*);
    fp_execute_stage2 fp_execute_stage2(.*);
    fp_execute_stage3 fp_execute_stage3(.*);
    fp_execute_stage4 fp_execute_stage4(.*);
    fp_execute_stage5 fp_execute_stage5(.*);
    writeback_stage writeback_stage(.*);

    control_registers #(
        .CORE_ID(CORE_ID),
        .NUM_INTERRUPTS(NUM_INTERRUPTS)
    ) control_registers(.*);
    l1_l2_interface #(.CORE_ID(CORE_ID)) l1_l2_interface(.*);
    io_request_queue #(.CORE_ID(CORE_ID)) io_request_queue(.*);

    assign core_perf_events = {
        ix_perf_cond_branch_not_taken,
        ix_perf_cond_branch_taken,
        ix_perf_uncond_branch,
        dd_perf_dtlb_miss,
        dd_perf_dcache_hit,
        dd_perf_dcache_miss,
        ifd_perf_itlb_miss,
        ifd_perf_icache_hit,
        ifd_perf_icache_miss,
        ts_perf_instruction_issue,
        wb_perf_instruction_retire,
        dd_perf_store,
        wb_perf_store_rollback
    };
endmodule
