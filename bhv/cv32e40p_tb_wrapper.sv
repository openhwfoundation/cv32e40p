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
// Contributors: Davide Schiavone, OpenHW Group <davide@openhwgroup.org>          //
//               Yoann Pruvost, Dolphin Design <yoann.pruvost@dolphin.fr>         //
//                                                                                //
// Description:  Test-bench wrapper for cv32e40p_top, tracer and and rvfi_tracer  //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

`ifdef CV32E40P_ASSERT_ON
`include "cv32e40p_prefetch_controller_sva.sv"
`endif

`ifdef CV32E40P_CORE_LOG
`include "cv32e40p_core_log.sv"
`endif

`ifdef CV32E40P_APU_TRACE
`include "cv32e40p_apu_tracer.sv"
`endif

`ifdef CV32E40P_TRACE_EXECUTION
`include "cv32e40p_tracer.sv"
`endif

`ifdef CV32E40P_RVFI
`include "cv32e40p_rvfi.sv"
`endif

`ifdef CV32E40P_RVFI_TRACE_EXECUTION
`include "cv32e40p_rvfi_trace.sv"
`endif

module cv32e40p_tb_wrapper
  import cv32e40p_pkg::*;
#(
    parameter COREV_PULP = 0, // PULP ISA Extension (incl. custom CSRs and hardware loop, excl. cv.elw)
    parameter COREV_CLUSTER = 0,  // PULP Cluster interface (incl. cv.elw)
    parameter FPU = 0,  // Floating Point Unit (interfaced via APU interface)
    parameter FPU_ADDMUL_LAT = 0,  // Floating-Point ADDition/MULtiplication computing lane pipeline registers number
    parameter FPU_OTHERS_LAT = 0,  // Floating-Point COMParison/CONVersion computing lanes pipeline registers number
    parameter ZFINX = 0,  // Float-in-General Purpose registers
    parameter NUM_MHPMCOUNTERS = 1
) (
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,

    input logic pulp_clock_en_i,  // PULP clock enable (only used if COREV_CLUSTER = 1)
    input logic scan_cg_en_i,  // Enable all clock gates for testing

    // Core ID, Cluster ID, debug mode halt address and boot address are considered more or less static
    input logic [31:0] boot_addr_i,
    input logic [31:0] mtvec_addr_i,
    input logic [31:0] dm_halt_addr_i,
    input logic [31:0] hart_id_i,
    input logic [31:0] dm_exception_addr_i,

    // Instruction memory interface
    output logic        instr_req_o,
    input  logic        instr_gnt_i,
    input  logic        instr_rvalid_i,
    output logic [31:0] instr_addr_o,
    input  logic [31:0] instr_rdata_i,

    // Data memory interface
    output logic        data_req_o,
    input  logic        data_gnt_i,
    input  logic        data_rvalid_i,
    output logic        data_we_o,
    output logic [ 3:0] data_be_o,
    output logic [31:0] data_addr_o,
    output logic [31:0] data_wdata_o,
    input  logic [31:0] data_rdata_i,

    // Interrupt inputs
    input  logic [31:0] irq_i,  // CLINT interrupts + CLINT extension interrupts
    output logic        irq_ack_o,
    output logic [ 4:0] irq_id_o,

    // Debug Interface
    input  logic debug_req_i,
    output logic debug_havereset_o,
    output logic debug_running_o,
    output logic debug_halted_o,

    // CPU Control Signals
    input  logic fetch_enable_i,
    output logic core_sleep_o
);

`ifdef CV32E40P_ASSERT_ON

  // RTL Assertions
  bind cv32e40p_prefetch_controller:
      cv32e40p_top_i.core_i.if_stage_i.prefetch_buffer_i.prefetch_controller_i
      cv32e40p_prefetch_controller_sva
      #(
      .DEPTH          (DEPTH),
      .COREV_PULP     (COREV_PULP),
      .PULP_OBI       (PULP_OBI),
      .FIFO_ADDR_DEPTH(FIFO_ADDR_DEPTH)
  ) prefetch_controller_sva (.*);

`endif  // CV32E40P_ASSERT_ON

`ifdef CV32E40P_CORE_LOG
  cv32e40p_core_log #(
      .COREV_PULP      (COREV_PULP),
      .COREV_CLUSTER   (COREV_CLUSTER),
      .FPU             (FPU),
      .ZFINX           (ZFINX),
      .NUM_MHPMCOUNTERS(NUM_MHPMCOUNTERS)
  ) core_log_i (
      .clk_i             (cv32e40p_top_i.core_i.id_stage_i.clk),
      .is_decoding_i     (cv32e40p_top_i.core_i.id_stage_i.is_decoding_o),
      .illegal_insn_dec_i(cv32e40p_top_i.core_i.id_stage_i.illegal_insn_dec),
      .hart_id_i         (cv32e40p_top_i.core_i.hart_id_i),
      .pc_id_i           (cv32e40p_top_i.core_i.pc_id)
  );
`endif  // CV32E40P_CORE_LOG

`ifdef CV32E40P_APU_TRACE
  cv32e40p_apu_tracer apu_tracer_i (
      .clk_i       (cv32e40p_top_i.core_i.clk_i),
      .rst_n       (cv32e40p_top_i.core_i.rst_ni),
      .hart_id_i   (cv32e40p_top_i.core_i.hart_id_i),
      .apu_valid_i (cv32e40p_top_i.core_i.ex_stage_i.apu_valid),
      .apu_waddr_i (cv32e40p_top_i.core_i.ex_stage_i.apu_waddr),
      .apu_result_i(cv32e40p_top_i.core_i.ex_stage_i.apu_result)
  );
`endif

`ifdef CV32E40P_TRACE_EXECUTION
  cv32e40p_tracer #(
      .FPU  (FPU),
      .ZFINX(ZFINX)
  ) tracer_i (
      .clk_i(cv32e40p_top_i.core_i.clk_i),  // always-running clock for tracing
      .rst_n(cv32e40p_top_i.core_i.rst_ni),

      .hart_id_i(cv32e40p_top_i.core_i.hart_id_i),

      .pc                (cv32e40p_top_i.core_i.id_stage_i.pc_id_i),
      .instr             (cv32e40p_top_i.core_i.id_stage_i.instr),
      .controller_state_i(cv32e40p_top_i.core_i.id_stage_i.controller_i.ctrl_fsm_cs),
      .compressed        (cv32e40p_top_i.core_i.id_stage_i.is_compressed_i),
      .id_valid          (cv32e40p_top_i.core_i.id_stage_i.id_valid_o),
      .is_decoding       (cv32e40p_top_i.core_i.id_stage_i.is_decoding_o),
      .is_illegal        (cv32e40p_top_i.core_i.id_stage_i.illegal_insn_dec),
      .trigger_match     (cv32e40p_top_i.core_i.id_stage_i.trigger_match_i),
      .rs1_value         (cv32e40p_top_i.core_i.id_stage_i.operand_a_fw_id),
      .rs2_value         (cv32e40p_top_i.core_i.id_stage_i.operand_b_fw_id),
      .rs3_value         (cv32e40p_top_i.core_i.id_stage_i.alu_operand_c),
      .rs2_value_vec     (cv32e40p_top_i.core_i.id_stage_i.alu_operand_b),

      .rs1_is_fp(cv32e40p_top_i.core_i.id_stage_i.regfile_fp_a),
      .rs2_is_fp(cv32e40p_top_i.core_i.id_stage_i.regfile_fp_b),
      .rs3_is_fp(cv32e40p_top_i.core_i.id_stage_i.regfile_fp_c),
      .rd_is_fp (cv32e40p_top_i.core_i.id_stage_i.regfile_fp_d),

      .ex_valid    (cv32e40p_top_i.core_i.ex_valid),
      .ex_reg_addr (cv32e40p_top_i.core_i.regfile_alu_waddr_fw),
      .ex_reg_we   (cv32e40p_top_i.core_i.regfile_alu_we_fw),
      .ex_reg_wdata(cv32e40p_top_i.core_i.regfile_alu_wdata_fw),

      .ex_data_addr   (cv32e40p_top_i.core_i.data_addr_o),
      .ex_data_req    (cv32e40p_top_i.core_i.data_req_o),
      .ex_data_gnt    (cv32e40p_top_i.core_i.data_gnt_i),
      .ex_data_we     (cv32e40p_top_i.core_i.data_we_o),
      .ex_data_wdata  (cv32e40p_top_i.core_i.data_wdata_o),
      .data_misaligned(cv32e40p_top_i.core_i.data_misaligned),

      .ebrk_insn(cv32e40p_top_i.core_i.id_stage_i.ebrk_insn_dec),
      .debug_mode(cv32e40p_top_i.core_i.debug_mode),
      .ebrk_force_debug_mode(cv32e40p_top_i.core_i.id_stage_i.controller_i.ebrk_force_debug_mode),

      .wb_bypass(cv32e40p_top_i.core_i.ex_stage_i.branch_in_ex_i),

      .wb_valid    (cv32e40p_top_i.core_i.wb_valid),
      .wb_reg_addr (cv32e40p_top_i.core_i.regfile_waddr_fw_wb_o),
      .wb_reg_we   (cv32e40p_top_i.core_i.regfile_we_wb),
      .wb_reg_wdata(cv32e40p_top_i.core_i.regfile_wdata),

      .imm_u_type       (cv32e40p_top_i.core_i.id_stage_i.imm_u_type),
      .imm_uj_type      (cv32e40p_top_i.core_i.id_stage_i.imm_uj_type),
      .imm_i_type       (cv32e40p_top_i.core_i.id_stage_i.imm_i_type),
      .imm_iz_type      (cv32e40p_top_i.core_i.id_stage_i.imm_iz_type[11:0]),
      .imm_z_type       (cv32e40p_top_i.core_i.id_stage_i.imm_z_type),
      .imm_s_type       (cv32e40p_top_i.core_i.id_stage_i.imm_s_type),
      .imm_sb_type      (cv32e40p_top_i.core_i.id_stage_i.imm_sb_type),
      .imm_s2_type      (cv32e40p_top_i.core_i.id_stage_i.imm_s2_type),
      .imm_s3_type      (cv32e40p_top_i.core_i.id_stage_i.imm_s3_type),
      .imm_vs_type      (cv32e40p_top_i.core_i.id_stage_i.imm_vs_type),
      .imm_vu_type      (cv32e40p_top_i.core_i.id_stage_i.imm_vu_type),
      .imm_shuffle_type (cv32e40p_top_i.core_i.id_stage_i.imm_shuffle_type),
      .imm_clip_type    (cv32e40p_top_i.core_i.id_stage_i.instr[11:7]),
      .apu_en_i         (cv32e40p_top_i.apu_req),
      .apu_singlecycle_i(cv32e40p_top_i.core_i.ex_stage_i.apu_singlecycle),
      .apu_multicycle_i (cv32e40p_top_i.core_i.ex_stage_i.apu_multicycle),
      .apu_rvalid_i     (cv32e40p_top_i.core_i.ex_stage_i.apu_valid)
  );
`endif

`ifdef CV32E40P_RVFI
  logic [1:0][31:0] hwlp_start_q;
  logic [1:0][31:0] hwlp_end_q;
  logic [1:0][31:0] hwlp_counter_q;
  logic [1:0][31:0] hwlp_counter_n;
  generate
    if (COREV_PULP) begin
      assign hwlp_start_q   = cv32e40p_top_i.core_i.id_stage_i.gen_hwloop_regs.hwloop_regs_i.hwlp_start_q  ;
      assign hwlp_end_q = cv32e40p_top_i.core_i.id_stage_i.gen_hwloop_regs.hwloop_regs_i.hwlp_end_q;
      assign hwlp_counter_q = cv32e40p_top_i.core_i.id_stage_i.gen_hwloop_regs.hwloop_regs_i.hwlp_counter_q;
      assign hwlp_counter_n = cv32e40p_top_i.core_i.id_stage_i.gen_hwloop_regs.hwloop_regs_i.hwlp_counter_n;
    end else begin
      assign hwlp_start_q   = '0;
      assign hwlp_end_q     = '0;
      assign hwlp_counter_q = '0;
      assign hwlp_counter_n = '0;
    end
  endgenerate

  cv32e40p_rvfi #(
      .FPU(FPU),
      .ZFINX(ZFINX),
      .NUM_MHPMCOUNTERS(NUM_MHPMCOUNTERS)
  ) rvfi_i (
      .clk_i (cv32e40p_top_i.core_i.clk_i),
      .rst_ni(cv32e40p_top_i.core_i.rst_ni),

      .is_decoding_i    (cv32e40p_top_i.core_i.id_stage_i.is_decoding_o),
      .is_illegal_i     (cv32e40p_top_i.core_i.id_stage_i.illegal_insn_dec),
      .trigger_match_i  (cv32e40p_top_i.core_i.id_stage_i.trigger_match_i),
      .data_misaligned_i(cv32e40p_top_i.core_i.data_misaligned),
      .lsu_data_we_ex_i (cv32e40p_top_i.core_i.data_we_ex),
      .debug_mode_i     (cv32e40p_top_i.core_i.debug_mode),
      .debug_cause_i    (cv32e40p_top_i.core_i.debug_cause),
      //// Instr IF probes ////
      .instr_req_i      (cv32e40p_top_i.core_i.instr_req_o),
      .instr_grant_i    (cv32e40p_top_i.core_i.instr_gnt_i),
      .instr_rvalid_i   (cv32e40p_top_i.core_i.instr_rvalid_i),
      .prefetch_req_i   (cv32e40p_top_i.core_i.instr_req_int),
      .pc_set_i         (cv32e40p_top_i.core_i.pc_set),

      .instr_valid_id_i    (cv32e40p_top_i.core_i.instr_valid_id),
      .instr_rdata_id_i    (cv32e40p_top_i.core_i.instr_rdata_id),
      .is_fetch_failed_id_i(cv32e40p_top_i.core_i.is_fetch_failed_id),
      .instr_req_int_i     (cv32e40p_top_i.core_i.instr_req_int),
      .clear_instr_valid_i (cv32e40p_top_i.core_i.clear_instr_valid),
      //// IF probes ////
      .instr_valid_if_i    (cv32e40p_top_i.core_i.if_stage_i.instr_valid),
      .if_valid_i          (cv32e40p_top_i.core_i.if_stage_i.if_valid),
      .if_ready_i          (cv32e40p_top_i.core_i.if_stage_i.if_ready),
      .instr_if_i          (cv32e40p_top_i.core_i.if_stage_i.instr_aligned),
      .pc_if_i             (cv32e40p_top_i.core_i.pc_if),
      //// ID probes ////
      .pc_id_i             (cv32e40p_top_i.core_i.id_stage_i.pc_id_i),
      .id_valid_i          (cv32e40p_top_i.core_i.id_stage_i.id_valid_o),
      .id_ready_i          (cv32e40p_top_i.core_i.id_stage_i.id_ready_o),

      .rs1_addr_id_i     (cv32e40p_top_i.core_i.id_stage_i.regfile_addr_ra_id),
      .rs2_addr_id_i     (cv32e40p_top_i.core_i.id_stage_i.regfile_addr_rb_id),
      .rs3_addr_id_i     (cv32e40p_top_i.core_i.id_stage_i.regfile_addr_rc_id),
      .operand_a_fw_id_i (cv32e40p_top_i.core_i.id_stage_i.operand_a_fw_id),
      .operand_b_fw_id_i (cv32e40p_top_i.core_i.id_stage_i.operand_b_fw_id),
      .operand_c_fw_id_i (cv32e40p_top_i.core_i.id_stage_i.operand_c_fw_id),
      // .instr         (cv32e40p_top_i.core_i.id_stage_i.instr     ),
      .is_compressed_id_i(cv32e40p_top_i.core_i.id_stage_i.is_compressed_i),
      .ebrk_insn_dec_i   (cv32e40p_top_i.core_i.id_stage_i.ebrk_insn_dec),
      .ecall_insn_dec_i  (cv32e40p_top_i.core_i.id_stage_i.ecall_insn_dec),
      .mret_insn_dec_i   (cv32e40p_top_i.core_i.id_stage_i.mret_insn_dec),
      .mret_dec_i        (cv32e40p_top_i.core_i.id_stage_i.mret_dec),

      .csr_cause_i     (cv32e40p_top_i.core_i.csr_cause),
      .debug_csr_save_i(cv32e40p_top_i.core_i.debug_csr_save),

      // HWLOOP regs
      .hwlp_start_q_i  (hwlp_start_q),
      .hwlp_end_q_i    (hwlp_end_q),
      .hwlp_counter_q_i(hwlp_counter_q),
      .hwlp_counter_n_i(hwlp_counter_n),

      .minstret_i         (cv32e40p_top_i.core_i.id_stage_i.minstret),
      //// EX probes ////
      .ex_valid_i         (cv32e40p_top_i.core_i.ex_valid),
      .ex_ready_i         (cv32e40p_top_i.core_i.ex_ready),
      .ex_reg_addr_i      (cv32e40p_top_i.core_i.regfile_alu_waddr_fw),
      .ex_reg_we_i        (cv32e40p_top_i.core_i.regfile_alu_we_fw),
      .ex_reg_wdata_i     (cv32e40p_top_i.core_i.regfile_alu_wdata_fw),
      .apu_en_ex_i        (cv32e40p_top_i.core_i.apu_en_ex),
      .apu_singlecycle_i  (cv32e40p_top_i.core_i.ex_stage_i.apu_singlecycle),
      .apu_multicycle_i   (cv32e40p_top_i.core_i.ex_stage_i.apu_multicycle),
      .wb_contention_lsu_i(cv32e40p_top_i.core_i.ex_stage_i.wb_contention_lsu),
      .wb_contention_i    (cv32e40p_top_i.core_i.ex_stage_i.wb_contention),
      .regfile_we_lsu_i   (cv32e40p_top_i.core_i.ex_stage_i.regfile_we_lsu),
      // .rf_we_alu_i    (cv32e40p_top_i.core_i.id_stage_i.regfile_alu_we_fw_i),
      // .rf_addr_alu_i  (cv32e40p_top_i.core_i.id_stage_i.regfile_alu_waddr_fw_i),
      // .rf_wdata_alu_i (cv32e40p_top_i.core_i.id_stage_i.regfile_alu_wdata_fw_i),

      .mult_ready_i        (cv32e40p_top_i.core_i.ex_stage_i.mult_ready),
      .alu_ready_i         (cv32e40p_top_i.core_i.ex_stage_i.alu_ready),
      //// WB probes ////
      .wb_valid_i          (cv32e40p_top_i.core_i.wb_valid),
      .wb_ready_i          (cv32e40p_top_i.core_i.lsu_ready_wb),
      //// LSU probes ////
      .data_we_ex_i        (cv32e40p_top_i.core_i.data_we_ex),
      .data_atop_ex_i      (cv32e40p_top_i.core_i.data_atop_ex),
      .data_type_ex_i      (cv32e40p_top_i.core_i.data_type_ex),
      .alu_operand_c_ex_i  (cv32e40p_top_i.core_i.alu_operand_c_ex),
      .data_reg_offset_ex_i(cv32e40p_top_i.core_i.data_reg_offset_ex),
      .data_load_event_ex_i(cv32e40p_top_i.core_i.data_load_event_ex),
      .data_sign_ext_ex_i  (cv32e40p_top_i.core_i.data_sign_ext_ex),
      .lsu_rdata_i         (cv32e40p_top_i.core_i.lsu_rdata),
      .data_req_ex_i       (cv32e40p_top_i.core_i.data_req_ex),
      .alu_operand_a_ex_i  (cv32e40p_top_i.core_i.alu_operand_a_ex),
      .alu_operand_b_ex_i  (cv32e40p_top_i.core_i.alu_operand_b_ex),
      .useincr_addr_ex_i   (cv32e40p_top_i.core_i.useincr_addr_ex),
      .data_misaligned_ex_i(cv32e40p_top_i.core_i.data_misaligned_ex),
      .p_elw_start_i       (cv32e40p_top_i.core_i.p_elw_start),
      .p_elw_finish_i      (cv32e40p_top_i.core_i.p_elw_finish),
      .lsu_ready_ex_i      (cv32e40p_top_i.core_i.lsu_ready_ex),
      .lsu_ready_wb_i      (cv32e40p_top_i.core_i.lsu_ready_wb),

      .lsu_data_be_i(cv32e40p_top_i.core_i.load_store_unit_i.data_be),

      .data_req_pmp_i(cv32e40p_top_i.core_i.data_req_pmp),
      .data_gnt_pmp_i(cv32e40p_top_i.core_i.data_gnt_pmp),
      .data_rvalid_i(cv32e40p_top_i.core_i.data_rvalid_i),
      .data_err_pmp_i(cv32e40p_top_i.core_i.data_err_pmp),
      .data_addr_pmp_i(cv32e40p_top_i.core_i.data_addr_pmp),
      .data_we_i(cv32e40p_top_i.core_i.data_we_o),
      .data_atop_i(cv32e40p_top_i.core_i.data_atop_o),
      .data_be_i(cv32e40p_top_i.core_i.data_be_o),
      .data_wdata_i(cv32e40p_top_i.core_i.data_wdata_o),
      .data_rdata_i(cv32e40p_top_i.core_i.data_rdata_i),
      // Register writes
      .rf_we_wb_i(cv32e40p_top_i.core_i.id_stage_i.regfile_we_wb_i),
      .rf_addr_wb_i(cv32e40p_top_i.core_i.id_stage_i.regfile_waddr_wb_i),
      .rf_wdata_wb_i(cv32e40p_top_i.core_i.id_stage_i.regfile_wdata_wb_i),
      .regfile_alu_we_ex_i(cv32e40p_top_i.core_i.id_stage_i.regfile_alu_we_ex_o),

      // APU
      .apu_req_i   (cv32e40p_top_i.core_i.apu_req_o),
      .apu_gnt_i   (cv32e40p_top_i.core_i.apu_gnt_i),
      .apu_rvalid_i(cv32e40p_top_i.core_i.ex_stage_i.apu_valid),

      // Controller FSM probes
      .ctrl_fsm_cs_i(cv32e40p_top_i.core_i.id_stage_i.controller_i.ctrl_fsm_cs),
      .pc_mux_i     (cv32e40p_top_i.core_i.id_stage_i.controller_i.pc_mux_o),
      .exc_pc_mux_i (cv32e40p_top_i.core_i.id_stage_i.controller_i.exc_pc_mux_o),

      //CSR
      .csr_addr_i     (cv32e40p_top_i.core_i.cs_registers_i.csr_addr_i),
      .csr_we_i       (cv32e40p_top_i.core_i.cs_registers_i.csr_we_int),
      .csr_wdata_int_i(cv32e40p_top_i.core_i.cs_registers_i.csr_wdata_int),

      .csr_fregs_we_i(cv32e40p_top_i.core_i.cs_registers_i.fregs_we_i),

      .csr_mstatus_n_i   (cv32e40p_top_i.core_i.cs_registers_i.mstatus_n),
      .csr_mstatus_q_i   (cv32e40p_top_i.core_i.cs_registers_i.mstatus_q),
      .csr_mstatus_fs_n_i(cv32e40p_top_i.core_i.cs_registers_i.mstatus_fs_n),
      .csr_mstatus_fs_q_i(cv32e40p_top_i.core_i.cs_registers_i.mstatus_fs_q),

      .csr_misa_n_i(cv32e40p_top_i.core_i.cs_registers_i.MISA_VALUE),  // WARL
      .csr_misa_q_i(cv32e40p_top_i.core_i.cs_registers_i.MISA_VALUE),

      .csr_tdata1_n_i           (cv32e40p_top_i.core_i.cs_registers_i.tmatch_control_rdata),//csr_wdata_int                                   ),
      .csr_tdata1_q_i           (cv32e40p_top_i.core_i.cs_registers_i.tmatch_control_rdata),//gen_trigger_regs.tmatch_control_exec_q          ),
      .csr_tdata1_we_i(cv32e40p_top_i.core_i.cs_registers_i.gen_trigger_regs.tmatch_control_we),

      .csr_tdata2_n_i           (cv32e40p_top_i.core_i.cs_registers_i.tmatch_value_rdata),//csr_wdata_int                                   ),
      .csr_tdata2_q_i           (cv32e40p_top_i.core_i.cs_registers_i.tmatch_value_rdata),//gen_trigger_regs.tmatch_control_exec_q          ),
      .csr_tdata2_we_i(cv32e40p_top_i.core_i.cs_registers_i.gen_trigger_regs.tmatch_value_we),

      .csr_tinfo_n_i({16'h0, cv32e40p_top_i.core_i.cs_registers_i.tinfo_types}),
      .csr_tinfo_q_i({16'h0, cv32e40p_top_i.core_i.cs_registers_i.tinfo_types}),

      .csr_mie_n_i       (cv32e40p_top_i.core_i.cs_registers_i.mie_n),
      .csr_mie_q_i       (cv32e40p_top_i.core_i.cs_registers_i.mie_q),
      .csr_mie_we_i      (cv32e40p_top_i.core_i.cs_registers_i.csr_mie_we),
      .csr_mtvec_n_i     (cv32e40p_top_i.core_i.cs_registers_i.mtvec_n),
      .csr_mtvec_q_i     (cv32e40p_top_i.core_i.cs_registers_i.mtvec_q),
      .csr_mtvec_mode_n_i(cv32e40p_top_i.core_i.cs_registers_i.mtvec_mode_n),
      .csr_mtvec_mode_q_i(cv32e40p_top_i.core_i.cs_registers_i.mtvec_mode_q),

      .csr_mcountinhibit_q_i (cv32e40p_top_i.core_i.cs_registers_i.mcountinhibit_q),
      .csr_mcountinhibit_n_i (cv32e40p_top_i.core_i.cs_registers_i.mcountinhibit_n),
      .csr_mcountinhibit_we_i(cv32e40p_top_i.core_i.cs_registers_i.mcountinhibit_we),

      .csr_mhpmevent_n_i(cv32e40p_top_i.core_i.cs_registers_i.mhpmevent_n),
      .csr_mhpmevent_q_i(cv32e40p_top_i.core_i.cs_registers_i.mhpmevent_q),
      .csr_mhpmevent_we_i(cv32e40p_top_i.core_i.cs_registers_i.mhpmevent_we),
      .csr_mscratch_q_i(cv32e40p_top_i.core_i.cs_registers_i.mscratch_q),
      .csr_mscratch_n_i(cv32e40p_top_i.core_i.cs_registers_i.mscratch_n),
      .csr_mepc_q_i(cv32e40p_top_i.core_i.cs_registers_i.mepc_q),
      .csr_mepc_n_i(cv32e40p_top_i.core_i.cs_registers_i.mepc_n),
      .csr_mcause_q_i(cv32e40p_top_i.core_i.cs_registers_i.mcause_q),
      .csr_mcause_n_i(cv32e40p_top_i.core_i.cs_registers_i.mcause_n),
      .csr_mip_n_i(cv32e40p_top_i.core_i.cs_registers_i.mip),
      .csr_mip_q_i(cv32e40p_top_i.core_i.cs_registers_i.mip),
      .csr_mip_we_i('0),  //(cv32e40p_top_i.core_i.cs_registers_i.mip)


      .csr_dcsr_q_i(cv32e40p_top_i.core_i.cs_registers_i.dcsr_q),
      .csr_dcsr_n_i(cv32e40p_top_i.core_i.cs_registers_i.dcsr_n),

      .csr_dpc_n_i(cv32e40p_top_i.core_i.cs_registers_i.depc_n),
      .csr_dpc_q_i(cv32e40p_top_i.core_i.cs_registers_i.depc_q),
      .csr_dpc_we_i('0),  //cv32e40p_top_i.core_i.cs_registers_i.),
      .csr_dscratch0_n_i(cv32e40p_top_i.core_i.cs_registers_i.dscratch0_n),
      .csr_dscratch0_q_i(cv32e40p_top_i.core_i.cs_registers_i.dscratch0_q),
      .csr_dscratch0_we_i('0),  //cv32e40p_top_i.core_i.cs_registers_i.),

      .csr_dscratch1_n_i(cv32e40p_top_i.core_i.cs_registers_i.dscratch1_n),
      .csr_dscratch1_q_i(cv32e40p_top_i.core_i.cs_registers_i.dscratch1_q),
      .csr_dscratch1_we_i('0),  //cv32e40p_top_i.core_i.cs_registers_i.),

      .csr_mhpmcounter_q_i          (cv32e40p_top_i.core_i.cs_registers_i.mhpmcounter_q),
      .csr_mhpmcounter_write_lower_i(cv32e40p_top_i.core_i.cs_registers_i.mhpmcounter_write_lower),
      .csr_mhpmcounter_write_upper_i(cv32e40p_top_i.core_i.cs_registers_i.mhpmcounter_write_upper),

      .csr_mvendorid_i({
        MVENDORID_BANK, MVENDORID_OFFSET
      }),  //TODO: get this from the design instead of the pkg
      .csr_marchid_i(MARCHID),  //TODO: get this from the design instead of the pkg

      .csr_fcsr_fflags_n_i (cv32e40p_top_i.core_i.cs_registers_i.fflags_n),
      .csr_fcsr_fflags_q_i (cv32e40p_top_i.core_i.cs_registers_i.fflags_q),
      .csr_fcsr_fflags_we_i(cv32e40p_top_i.core_i.cs_registers_i.fflags_we_i),
      .csr_fcsr_frm_n_i    (cv32e40p_top_i.core_i.cs_registers_i.frm_n),
      .csr_fcsr_frm_q_i    (cv32e40p_top_i.core_i.cs_registers_i.frm_q)
  );
`endif

`ifdef CV32E40P_RVFI_TRACE_EXECUTION
  bind cv32e40p_rvfi: rvfi_i cv32e40p_rvfi_trace #(
      .FPU  (FPU),
      .ZFINX(ZFINX)
  ) cv32e40p_tracer_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .hart_id_i(cv32e40p_top_i.core_i.hart_id_i),

      .imm_s3_type(cv32e40p_top_i.core_i.id_stage_i.imm_s3_type),

      .rvfi_valid(rvfi_valid),
      .rvfi_insn(rvfi_insn),
      .rvfi_start_cycle(rvfi_start_cycle),
      .rvfi_start_time(rvfi_start_time),
      .rvfi_stop_cycle(rvfi_stop_cycle),
      .rvfi_stop_time(rvfi_stop_time),
      .rvfi_pc_rdata(rvfi_pc_rdata),
      .rvfi_trap(rvfi_trap),
      .rvfi_rd_addr(rvfi_rd_addr),
      .rvfi_rd_wdata(rvfi_rd_wdata),
      .rvfi_frd_wvalid(rvfi_frd_wvalid),
      .rvfi_frd_addr(rvfi_frd_addr),
      .rvfi_frd_wdata(rvfi_frd_wdata),
      .rvfi_2_rd(rvfi_2_rd),
      .rvfi_rs1_addr(rvfi_rs1_addr),
      .rvfi_rs2_addr(rvfi_rs2_addr),
      .rvfi_rs3_addr(rvfi_rs3_addr),
      .rvfi_rs1_rdata(rvfi_rs1_rdata),
      .rvfi_rs2_rdata(rvfi_rs2_rdata),
      .rvfi_rs3_rdata(rvfi_rs3_rdata),
      .rvfi_frs1_addr(rvfi_frs1_addr),
      .rvfi_frs2_addr(rvfi_frs2_addr),
      .rvfi_frs3_addr(rvfi_frs3_addr),
      .rvfi_frs1_rvalid(rvfi_frs1_rvalid),
      .rvfi_frs2_rvalid(rvfi_frs2_rvalid),
      .rvfi_frs3_rvalid(rvfi_frs3_rvalid),
      .rvfi_frs1_rdata(rvfi_frs1_rdata),
      .rvfi_frs2_rdata(rvfi_frs2_rdata),
      .rvfi_frs3_rdata(rvfi_frs3_rdata),
      .rvfi_mem_addr(rvfi_mem_addr),
      .rvfi_mem_rmask(rvfi_mem_rmask),
      .rvfi_mem_wmask(rvfi_mem_wmask),
      .rvfi_mem_rdata(rvfi_mem_rdata),
      .rvfi_mem_wdata(rvfi_mem_wdata)
  );
`endif
  // Instantiate the Core and the optinal FPU
  cv32e40p_top #(
      .COREV_PULP      (COREV_PULP),
      .COREV_CLUSTER   (COREV_CLUSTER),
      .FPU             (FPU),
      .FPU_ADDMUL_LAT  (FPU_ADDMUL_LAT),
      .FPU_OTHERS_LAT  (FPU_OTHERS_LAT),
      .ZFINX           (ZFINX),
      .NUM_MHPMCOUNTERS(NUM_MHPMCOUNTERS)
  ) cv32e40p_top_i (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .pulp_clock_en_i(pulp_clock_en_i),
      .scan_cg_en_i   (scan_cg_en_i),

      .boot_addr_i        (boot_addr_i),
      .mtvec_addr_i       (mtvec_addr_i),
      .dm_halt_addr_i     (dm_halt_addr_i),
      .hart_id_i          (hart_id_i),
      .dm_exception_addr_i(dm_exception_addr_i),

      .instr_req_o   (instr_req_o),
      .instr_gnt_i   (instr_gnt_i),
      .instr_rvalid_i(instr_rvalid_i),
      .instr_addr_o  (instr_addr_o),
      .instr_rdata_i (instr_rdata_i),

      .data_req_o   (data_req_o),
      .data_gnt_i   (data_gnt_i),
      .data_rvalid_i(data_rvalid_i),
      .data_we_o    (data_we_o),
      .data_be_o    (data_be_o),
      .data_addr_o  (data_addr_o),
      .data_wdata_o (data_wdata_o),
      .data_rdata_i (data_rdata_i),

      .irq_i    (irq_i),
      .irq_ack_o(irq_ack_o),
      .irq_id_o (irq_id_o),

      .debug_req_i      (debug_req_i),
      .debug_havereset_o(debug_havereset_o),
      .debug_running_o  (debug_running_o),
      .debug_halted_o   (debug_halted_o),

      .fetch_enable_i(fetch_enable_i),
      .core_sleep_o  (core_sleep_o)
  );

endmodule
