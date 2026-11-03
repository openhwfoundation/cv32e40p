// Copyright 2024 Dolphin Design
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
// Contributors: Yoann Pruvost, Dolphin Design <yoann.pruvost@dolphin.fr>         //
//               Pascal Gouedo, Dolphin Design <pascal.gouedo@dolphin.fr>         //
//                                                                                //
// Description:  CV32E40P binding for formal code analysis                        //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

bind cv32e40p_formal_top insn_assert u_insn_assert (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    .instr_req_o   (instr_req_o),
    .instr_gnt_i   (instr_gnt_i),
    .instr_rvalid_i(instr_rvalid_i),
    .instr_addr_o  (instr_addr_o),
    .instr_rdata_i (instr_rdata_i)
);

bind cv32e40p_formal_top data_assert u_data_assert (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    .data_req_o   (data_req_o   ),
    .data_gnt_i   (data_gnt_i   ),
    .data_rvalid_i(data_rvalid_i),
    .data_we_o    (data_we_o    ),
    .data_be_o    (data_be_o    ),
    .data_addr_o  (data_addr_o  ),
    .data_wdata_o (data_wdata_o ),
    .data_rdata_i (data_rdata_i )
);

bind cv32e40p_formal_top cv32e40p_assert u_cv32e40p_assert (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .scan_cg_en_i(scan_cg_en_i),

    .boot_addr_i        (boot_addr_i        ),
    .mtvec_addr_i       (mtvec_addr_i       ),
    .hart_id_i          (hart_id_i          ),
    .dm_halt_addr_i     (dm_halt_addr_i     ),
    .dm_exception_addr_i(dm_exception_addr_i),

    .data_type_ex_i(u_cv32e40p_top.core_i.data_type_ex),

    .pc_id_i(u_cv32e40p_top.core_i.pc_id),

    //From controller
    .ctrl_fsm_cs       (u_cv32e40p_top.core_i.id_stage_i.controller_i.ctrl_fsm_cs       ),
    .is_hwlp_body      (u_cv32e40p_top.core_i.id_stage_i.controller_i.is_hwlp_body      ),
    .hwlp_end0_eq_pc   (u_cv32e40p_top.core_i.id_stage_i.controller_i.hwlp_end0_eq_pc   ),
    .hwlp_counter0_gt_1(u_cv32e40p_top.core_i.id_stage_i.controller_i.hwlp_counter0_gt_1),
    .hwlp_end1_eq_pc   (u_cv32e40p_top.core_i.id_stage_i.controller_i.hwlp_end1_eq_pc   ),
    .hwlp_counter1_gt_1(u_cv32e40p_top.core_i.id_stage_i.controller_i.hwlp_counter1_gt_1),
    .jump_done_q       (u_cv32e40p_top.core_i.id_stage_i.controller_i.jump_done_q       )
);

bind cv32e40p_id_stage cv32e40p_ID_assert u_cv32e40p_ID_assert (
    .clk_i(clk),
    .rst_ni(rst_n),

    .alu_op_a_mux_sel            (alu_op_a_mux_sel            ),
    .alu_op_b_mux_sel            (alu_op_b_mux_sel            ),
    .alu_op_c_mux_sel            (alu_op_c_mux_sel            ),
    .alu_bmask_b_mux_sel         (alu_bmask_b_mux_sel         ),
    .ctrl_transfer_target_mux_sel(ctrl_transfer_target_mux_sel)
);

bind cv32e40p_ex_stage cv32e40p_EX_assert u_cv32e40p_EX_assert (
    .clk_i(clk),
    .rst_ni(rst_n),

    .apu_valid       (apu_valid       ),
    .apu_singlecycle (apu_singlecycle ),
    .apu_multicycle  (apu_multicycle  ),
    .regfile_alu_we_i(regfile_alu_we_i),
    .apu_en_i        (apu_en_i        ),
    .regfile_we_lsu  (regfile_we_lsu  ),
    .apu_rvalid_i    (apu_rvalid_i    ),
    .apu_rvalid_q    (apu_rvalid_q    ),
    .data_misaligned_i          (data_misaligned_i          ),
    .data_misaligned_ex_i       (data_misaligned_ex_i       ),
    .data_req_i                 (data_req_i                 ),
    .data_rvalid_i              (data_rvalid_i              ),
    .mulh_active                (mulh_active                ),
    .mult_operator_i            (mult_operator_i            ),
    .ctrl_transfer_insn_in_dec_i(ctrl_transfer_insn_in_dec_i),
    .apu_read_dep_for_jalr_o    (apu_read_dep_for_jalr_o    )
);

bind cv32e40p_controller cv32e40p_controller_assert u_cv32e40p_controller_assert (
    .clk_i (clk   ),
    .rst_ni(rst_n ),

    .data_load_event_i    (data_load_event_i    ),
    .trigger_match_i      (trigger_match_i      ),
    .ebrk_insn_i          (ebrk_insn_i          ),
    .debug_mode_q         (debug_mode_q         ),
    .debug_req_entry_q    (debug_req_entry_q    ),
    .ebrk_force_debug_mode(ebrk_force_debug_mode),
    .debug_force_wakeup_q (debug_force_wakeup_q ),
    .debug_single_step_i  (debug_single_step_i  ),
    .data_err_i           (data_err_i           ),
    .ctrl_fsm_cs          (ctrl_fsm_cs          )
);

bind fpnew_divsqrt_th_32 fpnew_divsqrt_th_32_assert u_fpnew_divsqrt_th_32_assert (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    .op_starting      (op_starting      ),
    .unit_ready_q     (unit_ready_q     ),
    .ex2_inst_wb      (ex2_inst_wb      ),
    .ex2_inst_wb_vld_q(ex2_inst_wb_vld_q)
);
