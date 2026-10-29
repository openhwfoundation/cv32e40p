// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Renzo Andri - andrire@student.ethz.ch                      //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    Instruction Decode Stage                                   //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decode stage of the core. It decodes the instructions      //
//                 and hosts the register file.                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_id_stage
  import cv32e40p_pkg::*;
  import cv32e40p_apu_core_pkg::*;
#(
    parameter COREV_PULP =  1,  // PULP ISA Extension (including PULP specific CSRs and hardware loop, excluding cv.elw)
    parameter COREV_CLUSTER = 0,
    parameter N_HWLP = 2,
    parameter N_HWLP_BITS = $clog2(N_HWLP),
    parameter PULP_SECURE = 0,
    parameter USE_PMP = 0,
    parameter A_EXTENSION = 0,
    parameter APU = 0,
    parameter FPU = 0,
    parameter FPU_ADDMUL_LAT = 0,
    parameter FPU_OTHERS_LAT = 0,
    parameter ZFINX = 0,
    parameter APU_NARGS_CPU = 3,
    parameter APU_WOP_CPU = 6,
    parameter APU_NDSFLAGS_CPU = 15,
    parameter APU_NUSFLAGS_CPU = 5,
    parameter DEBUG_TRIGGER_EN = 1
) (
    input logic clk,  // Gated clock
    input logic clk_ungated_i,  // Ungated clock
    input logic rst_n,

    input logic scan_cg_en_i,

    input  logic fetch_enable_i,
    output logic ctrl_busy_o,
    output logic is_decoding_o,

    // Interface to IF stage
    input  logic        instr_valid_i,
    input  logic [31:0] instr_rdata_i,  // comes from pipeline of IF stage
    output logic        instr_req_o,
    input  logic        is_compressed_i,
    input  logic        illegal_c_insn_i,

    // Jumps and branches
    output logic        branch_in_ex_o,
    input  logic        branch_decision_i,
    output logic [31:0] jump_target_o,
    output logic [ 1:0] ctrl_transfer_insn_in_dec_o,

    // IF and ID stage signals
    output logic       clear_instr_valid_o,
    output logic       pc_set_o,
    output logic [3:0] pc_mux_o,
    output logic [2:0] exc_pc_mux_o,
    output logic [1:0] trap_addr_mux_o,


    input logic is_fetch_failed_i,

    input logic [31:0] pc_id_i,

    // Stalls
    output logic halt_if_o,  // controller requests a halt of the IF stage

    output logic id_ready_o,  // ID stage is ready for the next instruction
    input  logic ex_ready_i,  // EX stage is ready for the next instruction
    input  logic wb_ready_i,  // WB stage is ready for the next instruction

    output logic id_valid_o,  // ID stage is done
    input  logic ex_valid_i,  // EX stage is done

    // Pipeline ID/EX
    output logic [31:0] pc_ex_o,

    output logic [31:0] alu_operand_a_ex_o,
    output logic [31:0] alu_operand_b_ex_o,
    output logic [31:0] alu_operand_c_ex_o,
    output logic [ 4:0] bmask_a_ex_o,
    output logic [ 4:0] bmask_b_ex_o,
    output logic [ 1:0] imm_vec_ext_ex_o,
    output logic [ 1:0] alu_vec_mode_ex_o,

    output logic [5:0] regfile_waddr_ex_o,
    output logic       regfile_we_ex_o,

    output logic [5:0] regfile_alu_waddr_ex_o,
    output logic       regfile_alu_we_ex_o,

    // ALU
    output logic              alu_en_ex_o,
    output alu_opcode_e       alu_operator_ex_o,
    output logic              alu_is_clpx_ex_o,
    output logic              alu_is_subrot_ex_o,
    output logic        [1:0] alu_clpx_shift_ex_o,

    // MUL
    output mul_opcode_e        mult_operator_ex_o,
    output logic        [31:0] mult_operand_a_ex_o,
    output logic        [31:0] mult_operand_b_ex_o,
    output logic        [31:0] mult_operand_c_ex_o,
    output logic               mult_en_ex_o,
    output logic               mult_sel_subword_ex_o,
    output logic        [ 1:0] mult_signed_mode_ex_o,
    output logic        [ 4:0] mult_imm_ex_o,

    output logic [31:0] mult_dot_op_a_ex_o,
    output logic [31:0] mult_dot_op_b_ex_o,
    output logic [31:0] mult_dot_op_c_ex_o,
    output logic [ 1:0] mult_dot_signed_ex_o,
    output logic        mult_is_clpx_ex_o,
    output logic [ 1:0] mult_clpx_shift_ex_o,
    output logic        mult_clpx_img_ex_o,

    // APU
    output logic                              apu_en_ex_o,
    output logic [     APU_WOP_CPU-1:0]       apu_op_ex_o,
    output logic [                 1:0]       apu_lat_ex_o,
    output logic [   APU_NARGS_CPU-1:0][31:0] apu_operands_ex_o,
    output logic [APU_NDSFLAGS_CPU-1:0]       apu_flags_ex_o,
    output logic [                 5:0]       apu_waddr_ex_o,

    output logic [2:0][5:0] apu_read_regs_o,
    output logic [2:0]      apu_read_regs_valid_o,
    input  logic            apu_read_dep_i,
    input  logic            apu_read_dep_for_jalr_i,
    output logic [1:0][5:0] apu_write_regs_o,
    output logic [1:0]      apu_write_regs_valid_o,
    input  logic            apu_write_dep_i,
    output logic            apu_perf_dep_o,
    input  logic            apu_busy_i,

    input logic            fs_off_i,
    input logic [C_RM-1:0] frm_i,

    // CSR ID/EX
    output logic              csr_access_ex_o,
    output csr_opcode_e       csr_op_ex_o,
    input  PrivLvl_t          current_priv_lvl_i,
    output logic              csr_irq_sec_o,
    output logic        [5:0] csr_cause_o,
    output logic              csr_save_if_o,
    output logic              csr_save_id_o,
    output logic              csr_save_ex_o,
    output logic              csr_restore_mret_id_o,
    output logic              csr_restore_uret_id_o,
    output logic              csr_restore_dret_id_o,
    output logic              csr_save_cause_o,

    // hwloop signals
    output logic [N_HWLP-1:0][31:0] hwlp_start_o,
    output logic [N_HWLP-1:0][31:0] hwlp_end_o,
    output logic [N_HWLP-1:0][31:0] hwlp_cnt_o,
    output logic                    hwlp_jump_o,
    output logic [      31:0]       hwlp_target_o,

    // Interface to load store unit
    output logic       data_req_ex_o,
    output logic       data_we_ex_o,
    output logic [1:0] data_type_ex_o,
    output logic [1:0] data_sign_ext_ex_o,
    output logic [1:0] data_reg_offset_ex_o,
    output logic       data_load_event_ex_o,

    output logic data_misaligned_ex_o,

    output logic prepost_useincr_ex_o,
    input  logic data_misaligned_i,
    input  logic data_err_i,
    output logic data_err_ack_o,

    output logic [5:0] atop_ex_o,

    // Interrupt signals
    input  logic [31:0] irq_i,
    input  logic        irq_sec_i,
    input  logic [31:0] mie_bypass_i,  // MIE CSR (bypass)
    output logic [31:0] mip_o,  // MIP CSR
    input  logic        m_irq_enable_i,
    input  logic        u_irq_enable_i,
    output logic        irq_ack_o,
    output logic [ 4:0] irq_id_o,
    output logic [ 4:0] exc_cause_o,

    // Debug Signal
    output logic       debug_mode_o,
    output logic [2:0] debug_cause_o,
    output logic       debug_csr_save_o,
    input  logic       debug_req_i,
    input  logic       debug_single_step_i,
    input  logic       debug_ebreakm_i,
    input  logic       debug_ebreaku_i,
    input  logic       trigger_match_i,
    output logic       debug_p_elw_no_sleep_o,
    output logic       debug_havereset_o,
    output logic       debug_running_o,
    output logic       debug_halted_o,

    // Wakeup Signal
    output logic wake_from_sleep_o,

    // Forward Signals
    input logic [5:0] regfile_waddr_wb_i,
    input logic regfile_we_wb_i,
    input logic regfile_we_wb_power_i,
    input  logic [31:0] regfile_wdata_wb_i, // From wb_stage: selects data from data memory, ex_stage result and sp rdata

    input logic [ 5:0] regfile_alu_waddr_fw_i,
    input logic        regfile_alu_we_fw_i,
    input logic        regfile_alu_we_fw_power_i,
    input logic [31:0] regfile_alu_wdata_fw_i,

    // from ALU
    input  logic        mult_multicycle_i,    // when we need multiple cycles in the multiplier and use op c as storage

    // Performance Counters
    output logic mhpmevent_minstret_o,
    output logic mhpmevent_load_o,
    output logic mhpmevent_store_o,
    output logic mhpmevent_jump_o,
    output logic mhpmevent_branch_o,
    output logic mhpmevent_branch_taken_o,
    output logic mhpmevent_compressed_o,
    output logic mhpmevent_jr_stall_o,
    output logic mhpmevent_imiss_o,
    output logic mhpmevent_ld_stall_o,
    output logic mhpmevent_pipe_stall_o,

    input logic        perf_imiss_i,
    input logic [31:0] mcounteren_i
);

  // Source/Destination register instruction index
  localparam REG_S1_MSB = 19;
  localparam REG_S1_LSB = 15;

  localparam REG_S2_MSB = 24;
  localparam REG_S2_LSB = 20;

  localparam REG_S4_MSB = 31;
  localparam REG_S4_LSB = 27;

  localparam REG_D_MSB = 11;
  localparam REG_D_LSB = 7;

  logic [31:0] instr;


  // Decoder/Controller ID stage internal signals
  logic        deassert_we;

  logic        illegal_insn_dec;
  logic        ebrk_insn_dec;
  logic        mret_insn_dec;
  logic        uret_insn_dec;

  logic        dret_insn_dec;

  logic        ecall_insn_dec;
  logic        wfi_insn_dec;

  logic        fencei_insn_dec;

  logic        rega_used_dec;
  logic        regb_used_dec;
  logic        regc_used_dec;

  logic        branch_taken_ex;
  logic [ 1:0] ctrl_transfer_insn_in_id;
  logic [ 1:0] ctrl_transfer_insn_in_dec;

  logic        misaligned_stall;
  logic        jr_stall;
  logic        load_stall;
  logic        csr_apu_stall;
  logic        hwlp_mask;
  logic        halt_id;
  logic        halt_if;

  logic        debug_wfi_no_sleep;

  // Immediate decoding and sign extension
  logic [31:0] imm_i_type;
  logic [31:0] imm_iz_type;
  logic [31:0] imm_s_type;
  logic [31:0] imm_sb_type;
  logic [31:0] imm_u_type;
  logic [31:0] imm_uj_type;
  logic [31:0] imm_z_type;
  logic [31:0] imm_s2_type;
  logic [31:0] imm_bi_type;
  logic [31:0] imm_s3_type;
  logic [31:0] imm_vs_type;
  logic [31:0] imm_vu_type;
  logic [31:0] imm_shuffleb_type;
  logic [31:0] imm_shuffleh_type;
  logic [31:0] imm_shuffle_type;
  logic [31:0] imm_clip_type;

  logic [31:0] imm_a;  // contains the immediate for operand b
  logic [31:0] imm_b;  // contains the immediate for operand b

  logic [31:0] jump_target;  // calculated jump target (-> EX -> IF)

  // Signals running between controller and int_controller
  logic        irq_req_ctrl;
  logic        irq_sec_ctrl;
  logic        irq_wu_ctrl;
  logic [ 4:0] irq_id_ctrl;

  // Register file interface
  logic [ 5:0] regfile_addr_ra_id;
  logic [ 5:0] regfile_addr_rb_id;
  logic [ 5:0] regfile_addr_rc_id;

  logic        regfile_fp_a;
  logic        regfile_fp_b;
  logic        regfile_fp_c;
  logic        regfile_fp_d;

  logic [ 5:0] regfile_waddr_id;
  logic [ 5:0] regfile_alu_waddr_id;
  logic regfile_alu_we_id, regfile_alu_we_dec_id;

  logic [31:0] regfile_data_ra_id;
  logic [31:0] regfile_data_rb_id;
  logic [31:0] regfile_data_rc_id;

  // ALU Control
  logic alu_en;
  alu_opcode_e alu_operator;
  logic [2:0] alu_op_a_mux_sel;
  logic [2:0] alu_op_b_mux_sel;
  logic [1:0] alu_op_c_mux_sel;
  logic [1:0] regc_mux;

  logic [0:0] imm_a_mux_sel;
  logic [3:0] imm_b_mux_sel;
  logic [1:0] ctrl_transfer_target_mux_sel;

  // Multiplier Control
  mul_opcode_e mult_operator;  // multiplication operation selection
  logic mult_en;  // multiplication is used instead of ALU
  logic mult_int_en;  // use integer multiplier
  logic mult_sel_subword;  // Select a subword when doing multiplications
  logic [1:0]  mult_signed_mode; // Signed mode multiplication at the output of the controller, and before the pipe registers
  logic mult_dot_en;  // use dot product
  logic [1:0] mult_dot_signed;  // Signed mode dot products (can be mixed types)

  // FPU signals
  logic [cv32e40p_fpu_pkg::FP_FORMAT_BITS-1:0] fpu_src_fmt;
  logic [cv32e40p_fpu_pkg::FP_FORMAT_BITS-1:0] fpu_dst_fmt;
  logic [cv32e40p_fpu_pkg::INT_FORMAT_BITS-1:0] fpu_int_fmt;

  // APU signals
  logic apu_en;
  logic [APU_WOP_CPU-1:0] apu_op;
  logic [1:0] apu_lat;
  logic [APU_NARGS_CPU-1:0][31:0] apu_operands;
  logic [APU_NDSFLAGS_CPU-1:0] apu_flags;
  logic [5:0] apu_waddr;

  logic [2:0][5:0] apu_read_regs;
  logic [2:0] apu_read_regs_valid;
  logic [1:0][5:0] apu_write_regs;
  logic [1:0] apu_write_regs_valid;

  logic apu_stall;
  logic [2:0] fp_rnd_mode;

  // Register Write Control
  logic regfile_we_id;
  logic regfile_alu_waddr_mux_sel;

  // Data Memory Control
  logic data_we_id;
  logic [1:0] data_type_id;
  logic [1:0] data_sign_ext_id;
  logic [1:0] data_reg_offset_id;
  logic data_req_id;
  logic data_load_event_id;

  // Atomic memory instruction
  logic [5:0] atop_id;

  // hwloop signals
  logic [N_HWLP_BITS-1:0] hwlp_regid;
  logic [2:0] hwlp_we, hwlp_we_masked;
  logic        [       1:0] hwlp_target_mux_sel;
  logic        [       1:0] hwlp_start_mux_sel;
  logic                     hwlp_cnt_mux_sel;

  logic        [      31:0] hwlp_start;
  logic        [      31:0] hwlp_end;
  logic        [      31:0] hwlp_cnt;
  logic        [N_HWLP-1:0] hwlp_dec_cnt;
  logic                     hwlp_valid;

  // CSR control
  logic                     csr_access;
  csr_opcode_e              csr_op;
  logic                     csr_status;

  logic                     prepost_useincr;

  // Forwarding
  logic        [       1:0] operand_a_fw_mux_sel;
  logic        [       1:0] operand_b_fw_mux_sel;
  logic        [       1:0] operand_c_fw_mux_sel;
  logic        [      31:0] operand_a_fw_id;
  logic        [      31:0] operand_b_fw_id;
  logic        [      31:0] operand_c_fw_id;

  logic [31:0] operand_b, operand_b_vec;
  logic [31:0] operand_c, operand_c_vec;

  logic [31:0] alu_operand_a;
  logic [31:0] alu_operand_b;
  logic [31:0] alu_operand_c;

  // Immediates for ID
  logic [ 0:0] bmask_a_mux;
  logic [ 1:0] bmask_b_mux;
  logic        alu_bmask_a_mux_sel;
  logic        alu_bmask_b_mux_sel;
  logic [ 0:0] mult_imm_mux;

  logic [ 4:0] bmask_a_id_imm;
  logic [ 4:0] bmask_b_id_imm;
  logic [ 4:0] bmask_a_id;
  logic [ 4:0] bmask_b_id;
  logic [ 1:0] imm_vec_ext_id;
  logic [ 4:0] mult_imm_id;

  logic        alu_vec;
  logic [ 1:0] alu_vec_mode;
  logic        scalar_replication;
  logic        scalar_replication_c;

  // Forwarding detection signals
  logic        reg_d_ex_is_reg_a_id;
  logic        reg_d_ex_is_reg_b_id;
  logic        reg_d_ex_is_reg_c_id;
  logic        reg_d_wb_is_reg_a_id;
  logic        reg_d_wb_is_reg_b_id;
  logic        reg_d_wb_is_reg_c_id;
  logic        reg_d_alu_is_reg_a_id;
  logic        reg_d_alu_is_reg_b_id;
  logic        reg_d_alu_is_reg_c_id;

  logic is_clpx, is_subrot;

  logic mret_dec;
  logic uret_dec;
  logic dret_dec;

  // Performance counters
  logic id_valid_q;
  logic minstret;
  logic perf_pipeline_stall;

  assign instr = instr_rdata_i;


  // immediate extraction and sign extension
  assign imm_i_type = {{20{instr[31]}}, instr[31:20]};
  assign imm_iz_type = {20'b0, instr[31:20]};
  assign imm_s_type = {{20{instr[31]}}, instr[31:25], instr[11:7]};
  assign imm_sb_type = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
  assign imm_u_type = {instr[31:12], 12'b0};
  assign imm_uj_type = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

  // immediate for CSR manipulatin (zero extended)
  assign imm_z_type = {27'b0, instr[REG_S1_MSB:REG_S1_LSB]};

  assign imm_s2_type = {27'b0, instr[24:20]};
  assign imm_bi_type = {{27{instr[24]}}, instr[24:20]};
  assign imm_s3_type = {27'b0, instr[29:25]};
  assign imm_vs_type = {{26{instr[24]}}, instr[24:20], instr[25]};
  assign imm_vu_type = {26'b0, instr[24:20], instr[25]};

  // same format as rS2 for shuffle needs, expands immediate
  assign imm_shuffleb_type = {
    6'b0, instr[28:27], 6'b0, instr[24:23], 6'b0, instr[22:21], 6'b0, instr[20], instr[25]
  };
  assign imm_shuffleh_type = {15'h0, instr[20], 15'h0, instr[25]};

  // clipping immediate, uses a small barrel shifter to pre-process the
  // immediate and an adder to subtract 1
  // The end result is a mask that has 1's set in the lower part
  assign imm_clip_type = (32'h1 << instr[24:20]) - 1;

  //---------------------------------------------------------------------------
  // source register selection regfile_fp_x=1 <=> CV32E40P_REG_x is a FP-register
  //---------------------------------------------------------------------------
  assign regfile_addr_ra_id = {regfile_fp_a, instr[REG_S1_MSB:REG_S1_LSB]};
  assign regfile_addr_rb_id = {regfile_fp_b, instr[REG_S2_MSB:REG_S2_LSB]};

  // register C mux
  always_comb begin
    unique case (regc_mux)
      REGC_ZERO: regfile_addr_rc_id = '0;
      REGC_RD:   regfile_addr_rc_id = {regfile_fp_c, instr[REG_D_MSB:REG_D_LSB]};
      REGC_S1:   regfile_addr_rc_id = {regfile_fp_c, instr[REG_S1_MSB:REG_S1_LSB]};
      REGC_S4:   regfile_addr_rc_id = {regfile_fp_c, instr[REG_S4_MSB:REG_S4_LSB]};
    endcase
  end

  //---------------------------------------------------------------------------
  // destination registers regfile_fp_d=1 <=> REG_D is a FP-register
  //---------------------------------------------------------------------------
  assign regfile_waddr_id = {regfile_fp_d, instr[REG_D_MSB:REG_D_LSB]};

  // Second Register Write Address Selection
  // Used for prepost load/store and multiplier
  assign regfile_alu_waddr_id = regfile_alu_waddr_mux_sel ? regfile_waddr_id : regfile_addr_ra_id;

  // Forwarding control signals
  assign reg_d_ex_is_reg_a_id  = (regfile_waddr_ex_o     == regfile_addr_ra_id) && (rega_used_dec == 1'b1) && (regfile_addr_ra_id != '0);
  assign reg_d_ex_is_reg_b_id  = (regfile_waddr_ex_o     == regfile_addr_rb_id) && (regb_used_dec == 1'b1) && (regfile_addr_rb_id != '0);
  assign reg_d_ex_is_reg_c_id  = (regfile_waddr_ex_o     == regfile_addr_rc_id) && (regc_used_dec == 1'b1) && (regfile_addr_rc_id != '0);
  assign reg_d_wb_is_reg_a_id  = (regfile_waddr_wb_i     == regfile_addr_ra_id) && (rega_used_dec == 1'b1) && (regfile_addr_ra_id != '0);
  assign reg_d_wb_is_reg_b_id  = (regfile_waddr_wb_i     == regfile_addr_rb_id) && (regb_used_dec == 1'b1) && (regfile_addr_rb_id != '0);
  assign reg_d_wb_is_reg_c_id  = (regfile_waddr_wb_i     == regfile_addr_rc_id) && (regc_used_dec == 1'b1) && (regfile_addr_rc_id != '0);
  assign reg_d_alu_is_reg_a_id = (regfile_alu_waddr_fw_i == regfile_addr_ra_id) && (rega_used_dec == 1'b1) && (regfile_addr_ra_id != '0);
  assign reg_d_alu_is_reg_b_id = (regfile_alu_waddr_fw_i == regfile_addr_rb_id) && (regb_used_dec == 1'b1) && (regfile_addr_rb_id != '0);
  assign reg_d_alu_is_reg_c_id = (regfile_alu_waddr_fw_i == regfile_addr_rc_id) && (regc_used_dec == 1'b1) && (regfile_addr_rc_id != '0);


  // kill instruction in the IF/ID stage by setting the instr_valid_id control
  // signal to 0 for instructions that are done
  assign clear_instr_valid_o = id_ready_o | halt_id | branch_taken_ex;

  assign branch_taken_ex = branch_in_ex_o && branch_decision_i;


  assign mult_en = mult_int_en | mult_dot_en;


  //////////////////////////////////////////////////////////////////
  //      _                         _____                    _    //
  //     | |_   _ _ __ ___  _ __   |_   _|_ _ _ __ __ _  ___| |_  //
  //  _  | | | | | '_ ` _ \| '_ \    | |/ _` | '__/ _` |/ _ \ __| //
  // | |_| | |_| | | | | | | |_) |   | | (_| | | | (_| |  __/ |_  //
  //  \___/ \__,_|_| |_| |_| .__/    |_|\__,_|_|  \__, |\___|\__| //
  //                       |_|                    |___/           //
  //////////////////////////////////////////////////////////////////

  always_comb begin : jump_target_mux
    unique case (ctrl_transfer_target_mux_sel)
      JT_JAL:  jump_target = pc_id_i + imm_uj_type;
      JT_COND: jump_target = pc_id_i + imm_sb_type;

      // JALR: Cannot forward RS1, since the path is too long
      JT_JALR: jump_target = regfile_data_ra_id + imm_i_type;
      default: jump_target = regfile_data_ra_id + imm_i_type;
    endcase
  end

  assign jump_target_o = jump_target;


  ////////////////////////////////////////////////////////
  //   ___                                 _      _     //
  //  / _ \ _ __   ___ _ __ __ _ _ __   __| |    / \    //
  // | | | | '_ \ / _ \ '__/ _` | '_ \ / _` |   / _ \   //
  // | |_| | |_) |  __/ | | (_| | | | | (_| |  / ___ \  //
  //  \___/| .__/ \___|_|  \__,_|_| |_|\__,_| /_/   \_\ //
  //       |_|                                          //
  ////////////////////////////////////////////////////////

  // ALU_Op_a Mux
  always_comb begin : alu_operand_a_mux
    case (alu_op_a_mux_sel)
      OP_A_REGA_OR_FWD: alu_operand_a = operand_a_fw_id;
      OP_A_REGB_OR_FWD: alu_operand_a = operand_b_fw_id;
      OP_A_REGC_OR_FWD: alu_operand_a = operand_c_fw_id;
      OP_A_CURRPC:      alu_operand_a = pc_id_i;
      OP_A_IMM:         alu_operand_a = imm_a;
      default:          alu_operand_a = operand_a_fw_id;
    endcase
    ;  // case (alu_op_a_mux_sel)
  end

  always_comb begin : immediate_a_mux
    unique case (imm_a_mux_sel)
      IMMA_Z:    imm_a = imm_z_type;
      IMMA_ZERO: imm_a = '0;
    endcase
  end

  // Operand a forwarding mux
  always_comb begin : operand_a_fw_mux
    case (operand_a_fw_mux_sel)
      SEL_FW_EX:   operand_a_fw_id = regfile_alu_wdata_fw_i;
      SEL_FW_WB:   operand_a_fw_id = regfile_wdata_wb_i;
      SEL_REGFILE: operand_a_fw_id = regfile_data_ra_id;
      default:     operand_a_fw_id = regfile_data_ra_id;
    endcase
    ;  // case (operand_a_fw_mux_sel)
  end

  //////////////////////////////////////////////////////
  //   ___                                 _   ____   //
  //  / _ \ _ __   ___ _ __ __ _ _ __   __| | | __ )  //
  // | | | | '_ \ / _ \ '__/ _` | '_ \ / _` | |  _ \  //
  // | |_| | |_) |  __/ | | (_| | | | | (_| | | |_) | //
  //  \___/| .__/ \___|_|  \__,_|_| |_|\__,_| |____/  //
  //       |_|                                        //
  //////////////////////////////////////////////////////

  // Immediate Mux for operand B
  always_comb begin : immediate_b_mux
    unique case (imm_b_mux_sel)
      IMMB_I:      imm_b = imm_i_type;
      IMMB_S:      imm_b = imm_s_type;
      IMMB_U:      imm_b = imm_u_type;
      IMMB_PCINCR: imm_b = is_compressed_i ? 32'h2 : 32'h4;
      IMMB_S2:     imm_b = imm_s2_type;
      IMMB_BI:     imm_b = imm_bi_type;
      IMMB_S3:     imm_b = imm_s3_type;
      IMMB_VS:     imm_b = imm_vs_type;
      IMMB_VU:     imm_b = imm_vu_type;
      IMMB_SHUF:   imm_b = imm_shuffle_type;
      IMMB_CLIP:   imm_b = {1'b0, imm_clip_type[31:1]};
      default:     imm_b = imm_i_type;
    endcase
  end

  // ALU_Op_b Mux
  always_comb begin : alu_operand_b_mux
    case (alu_op_b_mux_sel)
      OP_B_REGA_OR_FWD: operand_b = operand_a_fw_id;
      OP_B_REGB_OR_FWD: operand_b = operand_b_fw_id;
      OP_B_REGC_OR_FWD: operand_b = operand_c_fw_id;
      OP_B_IMM:         operand_b = imm_b;
      OP_B_BMASK:       operand_b = $unsigned(operand_b_fw_id[4:0]);
      default:          operand_b = operand_b_fw_id;
    endcase  // case (alu_op_b_mux_sel)
  end


  // scalar replication for operand B and shuffle type
  always_comb begin
    if (alu_vec_mode == VEC_MODE8) begin
      operand_b_vec    = {4{operand_b[7:0]}};
      imm_shuffle_type = imm_shuffleb_type;
    end else begin
      operand_b_vec    = {2{operand_b[15:0]}};
      imm_shuffle_type = imm_shuffleh_type;
    end
  end

  // choose normal or scalar replicated version of operand b
  assign alu_operand_b = (scalar_replication == 1'b1) ? operand_b_vec : operand_b;


  // Operand b forwarding mux
  always_comb begin : operand_b_fw_mux
    case (operand_b_fw_mux_sel)
      SEL_FW_EX:   operand_b_fw_id = regfile_alu_wdata_fw_i;
      SEL_FW_WB:   operand_b_fw_id = regfile_wdata_wb_i;
      SEL_REGFILE: operand_b_fw_id = regfile_data_rb_id;
      default:     operand_b_fw_id = regfile_data_rb_id;
    endcase
    ;  // case (operand_b_fw_mux_sel)
  end


  //////////////////////////////////////////////////////
  //   ___                                 _    ____  //
  //  / _ \ _ __   ___ _ __ __ _ _ __   __| |  / ___| //
  // | | | | '_ \ / _ \ '__/ _` | '_ \ / _` | | |     //
  // | |_| | |_) |  __/ | | (_| | | | | (_| | | |___  //
  //  \___/| .__/ \___|_|  \__,_|_| |_|\__,_|  \____| //
  //       |_|                                        //
  //////////////////////////////////////////////////////

  // ALU OP C Mux
  always_comb begin : alu_operand_c_mux
    case (alu_op_c_mux_sel)
      OP_C_REGC_OR_FWD: operand_c = operand_c_fw_id;
      OP_C_REGB_OR_FWD: operand_c = operand_b_fw_id;
      OP_C_JT:          operand_c = jump_target;
      default:          operand_c = operand_c_fw_id;
    endcase  // case (alu_op_c_mux_sel)
  end


  // scalar replication for operand C and shuffle type
  always_comb begin
    if (alu_vec_mode == VEC_MODE8) begin
      operand_c_vec = {4{operand_c[7:0]}};
    end else begin
      operand_c_vec = {2{operand_c[15:0]}};
    end
  end

  // choose normal or scalar replicated version of operand b
  assign alu_operand_c = (scalar_replication_c == 1'b1) ? operand_c_vec : operand_c;


  // Operand c forwarding mux
  always_comb begin : operand_c_fw_mux
    case (operand_c_fw_mux_sel)
      SEL_FW_EX:   operand_c_fw_id = regfile_alu_wdata_fw_i;
      SEL_FW_WB:   operand_c_fw_id = regfile_wdata_wb_i;
      SEL_REGFILE: operand_c_fw_id = regfile_data_rc_id;
      default:     operand_c_fw_id = regfile_data_rc_id;
    endcase
    ;  // case (operand_c_fw_mux_sel)
  end


  ///////////////////////////////////////////////////////////////////////////
  //  ___                              _ _       _              ___ ____   //
  // |_ _|_ __ ___  _ __ ___   ___  __| (_) __ _| |_ ___  ___  |_ _|  _ \  //
  //  | || '_ ` _ \| '_ ` _ \ / _ \/ _` | |/ _` | __/ _ \/ __|  | || | | | //
  //  | || | | | | | | | | | |  __/ (_| | | (_| | ||  __/\__ \  | || |_| | //
  // |___|_| |_| |_|_| |_| |_|\___|\__,_|_|\__,_|\__\___||___/ |___|____/  //
  //                                                                       //
  ///////////////////////////////////////////////////////////////////////////

  always_comb begin
    unique case (bmask_a_mux)
      BMASK_A_ZERO: bmask_a_id_imm = '0;
      BMASK_A_S3:   bmask_a_id_imm = imm_s3_type[4:0];
    endcase
  end
  always_comb begin
    unique case (bmask_b_mux)
      BMASK_B_ZERO: bmask_b_id_imm = '0;
      BMASK_B_ONE:  bmask_b_id_imm = 5'd1;
      BMASK_B_S2:   bmask_b_id_imm = imm_s2_type[4:0];
      BMASK_B_S3:   bmask_b_id_imm = imm_s3_type[4:0];
    endcase
  end

  always_comb begin
    unique case (alu_bmask_a_mux_sel)
      BMASK_A_IMM: bmask_a_id = bmask_a_id_imm;
      BMASK_A_REG: bmask_a_id = operand_b_fw_id[9:5];
    endcase
  end
  always_comb begin
    unique case (alu_bmask_b_mux_sel)
      BMASK_B_IMM: bmask_b_id = bmask_b_id_imm;
      BMASK_B_REG: bmask_b_id = operand_b_fw_id[4:0];
    endcase
  end

  generate
    if (!COREV_PULP) begin
      assign imm_vec_ext_id = imm_vu_type[1:0];
    end else begin
      assign imm_vec_ext_id = (alu_vec) ? imm_vu_type[1:0] : 2'b0;
    end
  endgenerate

  always_comb begin
    unique case (mult_imm_mux)
      MIMM_ZERO: mult_imm_id = '0;
      MIMM_S3:   mult_imm_id = imm_s3_type[4:0];
    endcase
  end

  /////////////////////////////
  // APU operand assignment  //
  /////////////////////////////
  // read regs
  generate
    if (APU == 1) begin : gen_apu

      if (APU_NARGS_CPU >= 1) assign apu_operands[0] = alu_operand_a;
      if (APU_NARGS_CPU >= 2) assign apu_operands[1] = alu_operand_b;
      if (APU_NARGS_CPU >= 3) assign apu_operands[2] = alu_operand_c;

      // write reg
      assign apu_waddr = regfile_alu_waddr_id;

      // flags
      assign apu_flags = (FPU == 1) ? {fpu_int_fmt, fpu_src_fmt, fpu_dst_fmt, fp_rnd_mode} : '0;

      // dependency checks
      always_comb begin
        unique case (alu_op_a_mux_sel)
          OP_A_CURRPC: begin
            if (ctrl_transfer_target_mux_sel == JT_JALR) begin
              apu_read_regs[0]       = regfile_addr_ra_id;
              apu_read_regs_valid[0] = 1'b1;
            end else begin
              apu_read_regs[0]       = regfile_addr_ra_id;
              apu_read_regs_valid[0] = 1'b0;
            end
          end  // OP_A_CURRPC:
          OP_A_REGA_OR_FWD: begin
            apu_read_regs[0]       = regfile_addr_ra_id;
            apu_read_regs_valid[0] = 1'b1;
          end  // OP_A_REGA_OR_FWD:
          OP_A_REGB_OR_FWD, OP_A_REGC_OR_FWD: begin
            apu_read_regs[0]       = regfile_addr_rb_id;
            apu_read_regs_valid[0] = 1'b1;
          end
          default: begin
            apu_read_regs[0]       = regfile_addr_ra_id;
            apu_read_regs_valid[0] = 1'b0;
          end
        endcase
      end

      always_comb begin
        unique case (alu_op_b_mux_sel)
          OP_B_REGA_OR_FWD: begin
            apu_read_regs[1]       = regfile_addr_ra_id;
            apu_read_regs_valid[1] = 1'b1;
          end
          OP_B_REGB_OR_FWD, OP_B_BMASK: begin
            apu_read_regs[1]       = regfile_addr_rb_id;
            apu_read_regs_valid[1] = 1'b1;
          end
          OP_B_REGC_OR_FWD: begin
            apu_read_regs[1]       = regfile_addr_rc_id;
            apu_read_regs_valid[1] = 1'b1;
          end
          OP_B_IMM: begin
            if (alu_bmask_b_mux_sel == BMASK_B_REG) begin
              apu_read_regs[1]       = regfile_addr_rb_id;
              apu_read_regs_valid[1] = 1'b1;
            end else begin
              apu_read_regs[1]       = regfile_addr_rb_id;
              apu_read_regs_valid[1] = 1'b0;
            end
          end
          default: begin
            apu_read_regs[1]       = regfile_addr_rb_id;
            apu_read_regs_valid[1] = 1'b0;
          end
        endcase
      end

      always_comb begin
        unique case (alu_op_c_mux_sel)
          OP_C_REGB_OR_FWD: begin
            apu_read_regs[2]       = regfile_addr_rb_id;
            apu_read_regs_valid[2] = 1'b1;
          end
          OP_C_REGC_OR_FWD: begin
            if ((alu_op_a_mux_sel != OP_A_REGC_OR_FWD) && (ctrl_transfer_target_mux_sel != JT_JALR) &&
                !((alu_op_b_mux_sel == OP_B_IMM) && (alu_bmask_b_mux_sel == BMASK_B_REG)) &&
                !(alu_op_b_mux_sel == OP_B_BMASK)) begin
              apu_read_regs[2]       = regfile_addr_rc_id;
              apu_read_regs_valid[2] = 1'b1;
            end else begin
              apu_read_regs[2]       = regfile_addr_rc_id;
              apu_read_regs_valid[2] = 1'b0;
            end
          end
          default: begin
            apu_read_regs[2]       = regfile_addr_rc_id;
            apu_read_regs_valid[2] = 1'b0;
          end
        endcase
      end

      assign apu_write_regs[0]       = regfile_alu_waddr_id;
      assign apu_write_regs_valid[0] = regfile_alu_we_id;

      assign apu_write_regs[1]       = regfile_waddr_id;
      assign apu_write_regs_valid[1] = regfile_we_id;

      assign apu_read_regs_o         = apu_read_regs;
      assign apu_read_regs_valid_o   = apu_read_regs_valid;

      assign apu_write_regs_o        = apu_write_regs;
      assign apu_write_regs_valid_o  = apu_write_regs_valid;
    end else begin : gen_no_apu
      for (genvar i = 0; i < APU_NARGS_CPU; i++) begin : gen_apu_tie_off
        assign apu_operands[i] = '0;
      end

      assign apu_read_regs          = '0;
      assign apu_read_regs_valid    = '0;
      assign apu_write_regs         = '0;
      assign apu_write_regs_valid   = '0;
      assign apu_waddr              = '0;
      assign apu_flags              = '0;
      assign apu_write_regs_o       = '0;
      assign apu_read_regs_o        = '0;
      assign apu_write_regs_valid_o = '0;
      assign apu_read_regs_valid_o  = '0;
    end
  endgenerate

  assign apu_perf_dep_o = apu_stall;
  // stall when we access the CSR after a multicycle APU instruction or
  // if a CSR access comes after a floating-point load (e.g., FLW) - we could stall only on MSTATUS CSR access but
  // being conservative here
  assign csr_apu_stall  = (csr_access & ((apu_en_ex_o & (apu_lat_ex_o[1] == 1'b1) | apu_busy_i) |
                                         (data_req_ex_o & ~data_we_ex_o & regfile_waddr_ex_o[5])));

  /////////////////////////////////////////////////////////
  //  ____  _____ ____ ___ ____ _____ _____ ____  ____   //
  // |  _ \| ____/ ___|_ _/ ___|_   _| ____|  _ \/ ___|  //
  // | |_) |  _|| |  _ | |\___ \ | | |  _| | |_) \___ \  //
  // |  _ <| |__| |_| || | ___) || | | |___|  _ < ___) | //
  // |_| \_\_____\____|___|____/ |_| |_____|_| \_\____/  //
  //                                                     //
  /////////////////////////////////////////////////////////

  cv32e40p_register_file #(
      .ADDR_WIDTH(6),
      .DATA_WIDTH(32),
      .FPU       (FPU),
      .ZFINX     (ZFINX)
  ) register_file_i (
      .clk  (clk),
      .rst_n(rst_n),

      .scan_cg_en_i(scan_cg_en_i),

      // Read port a
      .raddr_a_i(regfile_addr_ra_id),
      .rdata_a_o(regfile_data_ra_id),

      // Read port b
      .raddr_b_i(regfile_addr_rb_id),
      .rdata_b_o(regfile_data_rb_id),

      // Read port c
      .raddr_c_i(regfile_addr_rc_id),
      .rdata_c_o(regfile_data_rc_id),

      // Write port a
      .waddr_a_i(regfile_waddr_wb_i),
      .wdata_a_i(regfile_wdata_wb_i),
      .we_a_i   (regfile_we_wb_power_i),

      // Write port b
      .waddr_b_i(regfile_alu_waddr_fw_i),
      .wdata_b_i(regfile_alu_wdata_fw_i),
      .we_b_i   (regfile_alu_we_fw_power_i)
  );


  ///////////////////////////////////////////////
  //  ____  _____ ____ ___  ____  _____ ____   //
  // |  _ \| ____/ ___/ _ \|  _ \| ____|  _ \  //
  // | | | |  _|| |  | | | | | | |  _| | |_) | //
  // | |_| | |__| |__| |_| | |_| | |___|  _ <  //
  // |____/|_____\____\___/|____/|_____|_| \_\ //
  //                                           //
  ///////////////////////////////////////////////

  cv32e40p_decoder #(
      .COREV_PULP      (COREV_PULP),
      .COREV_CLUSTER   (COREV_CLUSTER),
      .A_EXTENSION     (A_EXTENSION),
      .FPU             (FPU),
      .FPU_ADDMUL_LAT  (FPU_ADDMUL_LAT),
      .FPU_OTHERS_LAT  (FPU_OTHERS_LAT),
      .ZFINX           (ZFINX),
      .PULP_SECURE     (PULP_SECURE),
      .USE_PMP         (USE_PMP),
      .APU_WOP_CPU     (APU_WOP_CPU),
      .DEBUG_TRIGGER_EN(DEBUG_TRIGGER_EN)
  ) decoder_i (
      // controller related signals
      .deassert_we_i(deassert_we),

      .illegal_insn_o(illegal_insn_dec),
      .ebrk_insn_o   (ebrk_insn_dec),

      .mret_insn_o(mret_insn_dec),
      .uret_insn_o(uret_insn_dec),
      .dret_insn_o(dret_insn_dec),

      .mret_dec_o(mret_dec),
      .uret_dec_o(uret_dec),
      .dret_dec_o(dret_dec),

      .ecall_insn_o(ecall_insn_dec),
      .wfi_o       (wfi_insn_dec),

      .fencei_insn_o(fencei_insn_dec),

      .rega_used_o(rega_used_dec),
      .regb_used_o(regb_used_dec),
      .regc_used_o(regc_used_dec),

      .reg_fp_a_o(regfile_fp_a),
      .reg_fp_b_o(regfile_fp_b),
      .reg_fp_c_o(regfile_fp_c),
      .reg_fp_d_o(regfile_fp_d),

      .bmask_a_mux_o        (bmask_a_mux),
      .bmask_b_mux_o        (bmask_b_mux),
      .alu_bmask_a_mux_sel_o(alu_bmask_a_mux_sel),
      .alu_bmask_b_mux_sel_o(alu_bmask_b_mux_sel),

      // from IF/ID pipeline
      .instr_rdata_i   (instr),
      .illegal_c_insn_i(illegal_c_insn_i),

      // ALU signals
      .alu_en_o              (alu_en),
      .alu_operator_o        (alu_operator),
      .alu_op_a_mux_sel_o    (alu_op_a_mux_sel),
      .alu_op_b_mux_sel_o    (alu_op_b_mux_sel),
      .alu_op_c_mux_sel_o    (alu_op_c_mux_sel),
      .alu_vec_o             (alu_vec),
      .alu_vec_mode_o        (alu_vec_mode),
      .scalar_replication_o  (scalar_replication),
      .scalar_replication_c_o(scalar_replication_c),
      .imm_a_mux_sel_o       (imm_a_mux_sel),
      .imm_b_mux_sel_o       (imm_b_mux_sel),
      .regc_mux_o            (regc_mux),
      .is_clpx_o             (is_clpx),
      .is_subrot_o           (is_subrot),

      // MUL signals
      .mult_operator_o   (mult_operator),
      .mult_int_en_o     (mult_int_en),
      .mult_sel_subword_o(mult_sel_subword),
      .mult_signed_mode_o(mult_signed_mode),
      .mult_imm_mux_o    (mult_imm_mux),
      .mult_dot_en_o     (mult_dot_en),
      .mult_dot_signed_o (mult_dot_signed),

      // FPU / APU signals
      .fs_off_i     (fs_off_i),
      .frm_i        (frm_i),
      .fpu_src_fmt_o(fpu_src_fmt),
      .fpu_dst_fmt_o(fpu_dst_fmt),
      .fpu_int_fmt_o(fpu_int_fmt),
      .apu_en_o     (apu_en),
      .apu_op_o     (apu_op),
      .apu_lat_o    (apu_lat),
      .fp_rnd_mode_o(fp_rnd_mode),

      // Register file control signals
      .regfile_mem_we_o       (regfile_we_id),
      .regfile_alu_we_o       (regfile_alu_we_id),
      .regfile_alu_we_dec_o   (regfile_alu_we_dec_id),
      .regfile_alu_waddr_sel_o(regfile_alu_waddr_mux_sel),

      // CSR control signals
      .csr_access_o      (csr_access),
      .csr_status_o      (csr_status),
      .csr_op_o          (csr_op),
      .current_priv_lvl_i(current_priv_lvl_i),

      // Data bus interface
      .data_req_o           (data_req_id),
      .data_we_o            (data_we_id),
      .prepost_useincr_o    (prepost_useincr),
      .data_type_o          (data_type_id),
      .data_sign_extension_o(data_sign_ext_id),
      .data_reg_offset_o    (data_reg_offset_id),
      .data_load_event_o    (data_load_event_id),

      // Atomic memory access
      .atop_o(atop_id),

      // hwloop signals
      .hwlp_we_o            (hwlp_we),
      .hwlp_target_mux_sel_o(hwlp_target_mux_sel),
      .hwlp_start_mux_sel_o (hwlp_start_mux_sel),
      .hwlp_cnt_mux_sel_o   (hwlp_cnt_mux_sel),

      // debug mode
      .debug_mode_i        (debug_mode_o),
      .debug_wfi_no_sleep_i(debug_wfi_no_sleep),

      // jump/branches
      .ctrl_transfer_insn_in_dec_o   (ctrl_transfer_insn_in_dec_o),
      .ctrl_transfer_insn_in_id_o    (ctrl_transfer_insn_in_id),
      .ctrl_transfer_target_mux_sel_o(ctrl_transfer_target_mux_sel),

      // HPM related control signals
      .mcounteren_i(mcounteren_i)

  );

  ////////////////////////////////////////////////////////////////////
  //    ____ ___  _   _ _____ ____   ___  _     _     _____ ____    //
  //   / ___/ _ \| \ | |_   _|  _ \ / _ \| |   | |   | ____|  _ \   //
  //  | |  | | | |  \| | | | | |_) | | | | |   | |   |  _| | |_) |  //
  //  | |__| |_| | |\  | | | |  _ <| |_| | |___| |___| |___|  _ <   //
  //   \____\___/|_| \_| |_| |_| \_\\___/|_____|_____|_____|_| \_\  //
  //                                                                //
  ////////////////////////////////////////////////////////////////////

  cv32e40p_controller #(
      .COREV_CLUSTER(COREV_CLUSTER),
      .COREV_PULP   (COREV_PULP),
      .FPU          (FPU)
  ) controller_i (
      .clk          (clk),  // Gated clock
      .clk_ungated_i(clk_ungated_i),  // Ungated clock
      .rst_n        (rst_n),

      .fetch_enable_i   (fetch_enable_i),
      .ctrl_busy_o      (ctrl_busy_o),
      .is_decoding_o    (is_decoding_o),
      .is_fetch_failed_i(is_fetch_failed_i),

      // decoder related signals
      .deassert_we_o(deassert_we),

      .illegal_insn_i(illegal_insn_dec),
      .ecall_insn_i  (ecall_insn_dec),
      .mret_insn_i   (mret_insn_dec),
      .uret_insn_i   (uret_insn_dec),

      .dret_insn_i(dret_insn_dec),

      .mret_dec_i(mret_dec),
      .uret_dec_i(uret_dec),
      .dret_dec_i(dret_dec),


      .wfi_i        (wfi_insn_dec),
      .ebrk_insn_i  (ebrk_insn_dec),
      .fencei_insn_i(fencei_insn_dec),
      .csr_status_i (csr_status),

      .hwlp_mask_o(hwlp_mask),

      // from IF/ID pipeline
      .instr_valid_i(instr_valid_i),

      // from prefetcher
      .instr_req_o(instr_req_o),

      // to prefetcher
      .pc_set_o       (pc_set_o),
      .pc_mux_o       (pc_mux_o),
      .exc_pc_mux_o   (exc_pc_mux_o),
      .exc_cause_o    (exc_cause_o),
      .trap_addr_mux_o(trap_addr_mux_o),

      // HWLoop signls
      .pc_id_i(pc_id_i),

      .hwlp_start_addr_i(hwlp_start_o),
      .hwlp_end_addr_i  (hwlp_end_o),
      .hwlp_counter_i   (hwlp_cnt_o),
      .hwlp_dec_cnt_o   (hwlp_dec_cnt),

      .hwlp_jump_o     (hwlp_jump_o),
      .hwlp_targ_addr_o(hwlp_target_o),

      // LSU
      .data_req_ex_i    (data_req_ex_o),
      .data_we_ex_i     (data_we_ex_o),
      .data_misaligned_i(data_misaligned_i),
      .data_load_event_i(data_load_event_id),
      .data_err_i       (data_err_i),
      .data_err_ack_o   (data_err_ack_o),

      // ALU
      .mult_multicycle_i(mult_multicycle_i),

      // APU
      .apu_en_i               (apu_en),
      .apu_read_dep_i         (apu_read_dep_i),
      .apu_read_dep_for_jalr_i(apu_read_dep_for_jalr_i),
      .apu_write_dep_i        (apu_write_dep_i),

      .apu_stall_o(apu_stall),

      // jump/branch control
      .branch_taken_ex_i          (branch_taken_ex),
      .ctrl_transfer_insn_in_id_i (ctrl_transfer_insn_in_id),
      .ctrl_transfer_insn_in_dec_i(ctrl_transfer_insn_in_dec_o),

      // Interrupt signals
      .irq_wu_ctrl_i     (irq_wu_ctrl),
      .irq_req_ctrl_i    (irq_req_ctrl),
      .irq_sec_ctrl_i    (irq_sec_ctrl),
      .irq_id_ctrl_i     (irq_id_ctrl),
      .current_priv_lvl_i(current_priv_lvl_i),
      .irq_ack_o         (irq_ack_o),
      .irq_id_o          (irq_id_o),

      // Debug Signal
      .debug_mode_o          (debug_mode_o),
      .debug_cause_o         (debug_cause_o),
      .debug_csr_save_o      (debug_csr_save_o),
      .debug_req_i           (debug_req_i),
      .debug_single_step_i   (debug_single_step_i),
      .debug_ebreakm_i       (debug_ebreakm_i),
      .debug_ebreaku_i       (debug_ebreaku_i),
      .trigger_match_i       (trigger_match_i),
      .debug_p_elw_no_sleep_o(debug_p_elw_no_sleep_o),
      .debug_wfi_no_sleep_o  (debug_wfi_no_sleep),
      .debug_havereset_o     (debug_havereset_o),
      .debug_running_o       (debug_running_o),
      .debug_halted_o        (debug_halted_o),

      // Wakeup Signal
      .wake_from_sleep_o(wake_from_sleep_o),

      // CSR Controller Signals
      .csr_save_cause_o     (csr_save_cause_o),
      .csr_cause_o          (csr_cause_o),
      .csr_save_if_o        (csr_save_if_o),
      .csr_save_id_o        (csr_save_id_o),
      .csr_save_ex_o        (csr_save_ex_o),
      .csr_restore_mret_id_o(csr_restore_mret_id_o),
      .csr_restore_uret_id_o(csr_restore_uret_id_o),

      .csr_restore_dret_id_o(csr_restore_dret_id_o),

      .csr_irq_sec_o(csr_irq_sec_o),

      // Write targets from ID
      .regfile_we_id_i       (regfile_alu_we_dec_id),
      .regfile_alu_waddr_id_i(regfile_alu_waddr_id),

      // Forwarding signals from regfile
      .regfile_we_ex_i   (regfile_we_ex_o),
      .regfile_waddr_ex_i(regfile_waddr_ex_o),
      .regfile_we_wb_i   (regfile_we_wb_i),

      // regfile port 2
      .regfile_alu_we_fw_i(regfile_alu_we_fw_i),

      // Forwarding detection signals
      .reg_d_ex_is_reg_a_i (reg_d_ex_is_reg_a_id),
      .reg_d_ex_is_reg_b_i (reg_d_ex_is_reg_b_id),
      .reg_d_ex_is_reg_c_i (reg_d_ex_is_reg_c_id),
      .reg_d_wb_is_reg_a_i (reg_d_wb_is_reg_a_id),
      .reg_d_wb_is_reg_b_i (reg_d_wb_is_reg_b_id),
      .reg_d_wb_is_reg_c_i (reg_d_wb_is_reg_c_id),
      .reg_d_alu_is_reg_a_i(reg_d_alu_is_reg_a_id),
      .reg_d_alu_is_reg_b_i(reg_d_alu_is_reg_b_id),
      .reg_d_alu_is_reg_c_i(reg_d_alu_is_reg_c_id),

      // Forwarding signals
      .operand_a_fw_mux_sel_o(operand_a_fw_mux_sel),
      .operand_b_fw_mux_sel_o(operand_b_fw_mux_sel),
      .operand_c_fw_mux_sel_o(operand_c_fw_mux_sel),

      // Stall signals
      .halt_if_o(halt_if),
      .halt_id_o(halt_id),

      .misaligned_stall_o(misaligned_stall),
      .jr_stall_o        (jr_stall),
      .load_stall_o      (load_stall),

      .id_ready_i(id_ready_o),
      .id_valid_i(id_valid_o),

      .ex_valid_i(ex_valid_i),

      .wb_ready_i(wb_ready_i),

      // Performance Counters
      .perf_pipeline_stall_o(perf_pipeline_stall)
  );


  ////////////////////////////////////////////////////////////////////////
  //  _____      _       _____             _             _ _            //
  // |_   _|    | |     /  __ \           | |           | | |           //
  //   | | _ __ | |_    | /  \/ ___  _ __ | |_ _ __ ___ | | | ___ _ __  //
  //   | || '_ \| __|   | |    / _ \| '_ \| __| '__/ _ \| | |/ _ \ '__| //
  //  _| || | | | |_ _  | \__/\ (_) | | | | |_| | | (_) | | |  __/ |    //
  //  \___/_| |_|\__(_)  \____/\___/|_| |_|\__|_|  \___/|_|_|\___|_|    //
  //                                                                    //
  ////////////////////////////////////////////////////////////////////////

  cv32e40p_int_controller #(
      .PULP_SECURE(PULP_SECURE)
  ) int_controller_i (
      .clk  (clk),
      .rst_n(rst_n),

      // External interrupt lines
      .irq_i    (irq_i),
      .irq_sec_i(irq_sec_i),

      // To cv32e40p_controller
      .irq_req_ctrl_o(irq_req_ctrl),
      .irq_sec_ctrl_o(irq_sec_ctrl),
      .irq_id_ctrl_o (irq_id_ctrl),
      .irq_wu_ctrl_o (irq_wu_ctrl),

      // To/from with cv32e40p_cs_registers
      .mie_bypass_i      (mie_bypass_i),
      .mip_o             (mip_o),
      .m_ie_i            (m_irq_enable_i),
      .u_ie_i            (u_irq_enable_i),
      .current_priv_lvl_i(current_priv_lvl_i)
  );

  generate
    if (COREV_PULP) begin : gen_hwloop_regs

      ///////////////////////////////////////////////
      //  _   ___        ___     ___   ___  ____   //
      // | | | \ \      / / |   / _ \ / _ \|  _ \  //
      // | |_| |\ \ /\ / /| |  | | | | | | | |_) | //
      // |  _  | \ V  V / | |__| |_| | |_| |  __/  //
      // |_| |_|  \_/\_/  |_____\___/ \___/|_|     //
      //                                           //
      ///////////////////////////////////////////////


      cv32e40p_hwloop_regs #(
          .N_REGS(N_HWLP)
      ) hwloop_regs_i (
          .clk  (clk),
          .rst_n(rst_n),

          // from ID
          .hwlp_start_data_i(hwlp_start),
          .hwlp_end_data_i  (hwlp_end),
          .hwlp_cnt_data_i  (hwlp_cnt),
          .hwlp_we_i        (hwlp_we_masked),
          .hwlp_regid_i     (hwlp_regid),

          // from controller
          .valid_i(hwlp_valid),

          // to hwloop controller
          .hwlp_start_addr_o(hwlp_start_o),
          .hwlp_end_addr_o  (hwlp_end_o),
          .hwlp_counter_o   (hwlp_cnt_o),

          // from hwloop controller
          .hwlp_dec_cnt_i(hwlp_dec_cnt)
      );

      assign hwlp_valid = instr_valid_i & clear_instr_valid_o;

      // hwloop register id
      assign hwlp_regid = instr[7];  // rd contains hwloop register id

      // hwloop target mux
      always_comb begin
        case (hwlp_target_mux_sel)
          2'b00:   hwlp_end = pc_id_i + {imm_iz_type[29:0], 2'b0};
          2'b01:   hwlp_end = pc_id_i + {imm_z_type[29:0], 2'b0};
          2'b10:   hwlp_end = operand_a_fw_id;
          default: hwlp_end = operand_a_fw_id;
        endcase
      end

      // hwloop start mux
      always_comb begin
        case (hwlp_start_mux_sel)
          2'b00:   hwlp_start = hwlp_end;  // for PC + I imm
          2'b01:   hwlp_start = pc_id_i + 4;  // for next PC
          2'b10:   hwlp_start = operand_a_fw_id;
          default: hwlp_start = operand_a_fw_id;
        endcase
      end

      // hwloop cnt mux
      always_comb begin : hwlp_cnt_mux
        case (hwlp_cnt_mux_sel)
          1'b0: hwlp_cnt = imm_iz_type;
          1'b1: hwlp_cnt = operand_a_fw_id;
        endcase
        ;
      end

      /*
        when hwlp_mask is 1, the controller is about to take an interrupt
        the xEPC is going to have the hwloop instruction PC, therefore, do not update the
        hwloop registers to make clear that the instruction hasn't been executed.
        Although it may not be a HW bugs causing uninteded behaviours,
        it helps verifications processes when checking the hwloop regs
      */
      assign hwlp_we_masked = hwlp_we & ~{3{hwlp_mask}} & {3{id_ready_o}};

    end else begin : gen_no_hwloop_regs

      assign hwlp_start_o   = 'b0;
      assign hwlp_end_o     = 'b0;
      assign hwlp_cnt_o     = 'b0;
      assign hwlp_valid     = 'b0;
      assign hwlp_we_masked = 'b0;
      assign hwlp_start     = 'b0;
      assign hwlp_end       = 'b0;
      assign hwlp_cnt       = 'b0;
      assign hwlp_regid     = 'b0;

    end
  endgenerate


  /////////////////////////////////////////////////////////////////////////////////
  //   ___ ____        _______  __  ____ ___ ____  _____ _     ___ _   _ _____   //
  //  |_ _|  _ \      | ____\ \/ / |  _ \_ _|  _ \| ____| |   |_ _| \ | | ____|  //
  //   | || | | |_____|  _|  \  /  | |_) | || |_) |  _| | |    | ||  \| |  _|    //
  //   | || |_| |_____| |___ /  \  |  __/| ||  __/| |___| |___ | || |\  | |___   //
  //  |___|____/      |_____/_/\_\ |_|  |___|_|   |_____|_____|___|_| \_|_____|  //
  //                                                                             //
  /////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk, negedge rst_n) begin : ID_EX_PIPE_REGISTERS
    if (rst_n == 1'b0) begin
      alu_en_ex_o            <= '0;
      alu_operator_ex_o      <= ALU_SLTU;
      alu_operand_a_ex_o     <= '0;
      alu_operand_b_ex_o     <= '0;
      alu_operand_c_ex_o     <= '0;
      bmask_a_ex_o           <= '0;
      bmask_b_ex_o           <= '0;
      imm_vec_ext_ex_o       <= '0;
      alu_vec_mode_ex_o      <= '0;
      alu_clpx_shift_ex_o    <= 2'b0;
      alu_is_clpx_ex_o       <= 1'b0;
      alu_is_subrot_ex_o     <= 1'b0;

      mult_operator_ex_o     <= MUL_MAC32;
      mult_operand_a_ex_o    <= '0;
      mult_operand_b_ex_o    <= '0;
      mult_operand_c_ex_o    <= '0;
      mult_en_ex_o           <= 1'b0;
      mult_sel_subword_ex_o  <= 1'b0;
      mult_signed_mode_ex_o  <= 2'b00;
      mult_imm_ex_o          <= '0;

      mult_dot_op_a_ex_o     <= '0;
      mult_dot_op_b_ex_o     <= '0;
      mult_dot_op_c_ex_o     <= '0;
      mult_dot_signed_ex_o   <= '0;
      mult_is_clpx_ex_o      <= 1'b0;
      mult_clpx_shift_ex_o   <= 2'b0;
      mult_clpx_img_ex_o     <= 1'b0;

      apu_en_ex_o            <= '0;
      apu_op_ex_o            <= '0;
      apu_lat_ex_o           <= '0;
      apu_operands_ex_o[0]   <= '0;
      apu_operands_ex_o[1]   <= '0;
      apu_operands_ex_o[2]   <= '0;
      apu_flags_ex_o         <= '0;
      apu_waddr_ex_o         <= '0;


      regfile_waddr_ex_o     <= 6'b0;
      regfile_we_ex_o        <= 1'b0;

      regfile_alu_waddr_ex_o <= 6'b0;
      regfile_alu_we_ex_o    <= 1'b0;
      prepost_useincr_ex_o   <= 1'b0;

      csr_access_ex_o        <= 1'b0;
      csr_op_ex_o            <= CSR_OP_READ;

      data_we_ex_o           <= 1'b0;
      data_type_ex_o         <= 2'b0;
      data_sign_ext_ex_o     <= 2'b0;
      data_reg_offset_ex_o   <= 2'b0;
      data_req_ex_o          <= 1'b0;
      data_load_event_ex_o   <= 1'b0;
      atop_ex_o              <= 5'b0;

      data_misaligned_ex_o   <= 1'b0;

      pc_ex_o                <= '0;

      branch_in_ex_o         <= 1'b0;

    end else if (data_misaligned_i) begin
      // misaligned data access case
      if (ex_ready_i) begin  // misaligned access case, only unstall alu operands

        // if we are using post increments, then we have to use the
        // original value of the register for the second memory access
        // => keep it stalled
        if (prepost_useincr_ex_o == 1'b1) begin
          alu_operand_a_ex_o <= operand_a_fw_id;
        end

        alu_operand_b_ex_o   <= 32'h4;
        regfile_alu_we_ex_o  <= 1'b0;
        prepost_useincr_ex_o <= 1'b1;

        data_misaligned_ex_o <= 1'b1;
      end
    end else if (mult_multicycle_i) begin
      mult_operand_c_ex_o <= operand_c_fw_id;
    end else begin
      // normal pipeline unstall case

      if (id_valid_o) begin  // unstall the whole pipeline
        alu_en_ex_o <= alu_en;
        if (alu_en) begin
          alu_operator_ex_o  <= alu_operator;
          alu_operand_a_ex_o <= alu_operand_a;
          if (alu_op_b_mux_sel == OP_B_REGB_OR_FWD && (alu_operator == ALU_CLIP || alu_operator == ALU_CLIPU)) begin
            alu_operand_b_ex_o <= {1'b0, alu_operand_b[30:0]};
          end else begin
            alu_operand_b_ex_o <= alu_operand_b;
          end
          alu_operand_c_ex_o  <= alu_operand_c;
          bmask_a_ex_o        <= bmask_a_id;
          bmask_b_ex_o        <= bmask_b_id;
          imm_vec_ext_ex_o    <= imm_vec_ext_id;
          alu_vec_mode_ex_o   <= alu_vec_mode;
          alu_is_clpx_ex_o    <= is_clpx;
          alu_clpx_shift_ex_o <= instr[14:13];
          alu_is_subrot_ex_o  <= is_subrot;
        end

        mult_en_ex_o <= mult_en;
        if (mult_int_en) begin
          mult_operator_ex_o    <= mult_operator;
          mult_sel_subword_ex_o <= mult_sel_subword;
          mult_signed_mode_ex_o <= mult_signed_mode;
          mult_operand_a_ex_o   <= alu_operand_a;
          mult_operand_b_ex_o   <= alu_operand_b;
          mult_operand_c_ex_o   <= alu_operand_c;
          mult_imm_ex_o         <= mult_imm_id;
        end
        if (mult_dot_en) begin
          mult_operator_ex_o   <= mult_operator;
          mult_dot_signed_ex_o <= mult_dot_signed;
          mult_dot_op_a_ex_o   <= alu_operand_a;
          mult_dot_op_b_ex_o   <= alu_operand_b;
          mult_dot_op_c_ex_o   <= alu_operand_c;
          mult_is_clpx_ex_o    <= is_clpx;
          mult_clpx_shift_ex_o <= instr[14:13];
          mult_clpx_img_ex_o   <= instr[25];
        end

        // APU pipeline
        apu_en_ex_o <= apu_en;
        if (apu_en) begin
          apu_op_ex_o       <= apu_op;
          apu_lat_ex_o      <= apu_lat;
          apu_operands_ex_o <= apu_operands;
          apu_flags_ex_o    <= apu_flags;
          apu_waddr_ex_o    <= apu_waddr;
        end

        regfile_we_ex_o <= regfile_we_id;
        if (regfile_we_id) begin
          regfile_waddr_ex_o <= regfile_waddr_id;
        end

        regfile_alu_we_ex_o <= regfile_alu_we_id;
        if (regfile_alu_we_id) begin
          regfile_alu_waddr_ex_o <= regfile_alu_waddr_id;
        end

        prepost_useincr_ex_o <= prepost_useincr;

        csr_access_ex_o      <= csr_access;
        csr_op_ex_o          <= csr_op;

        data_req_ex_o        <= data_req_id;
        if (data_req_id) begin  // only needed for LSU when there is an active request
          data_we_ex_o         <= data_we_id;
          data_type_ex_o       <= data_type_id;
          data_sign_ext_ex_o   <= data_sign_ext_id;
          data_reg_offset_ex_o <= data_reg_offset_id;
          data_load_event_ex_o <= data_load_event_id;
          atop_ex_o            <= atop_id;
        end else begin
          data_load_event_ex_o <= 1'b0;
        end

        data_misaligned_ex_o <= 1'b0;

        if ((ctrl_transfer_insn_in_id == BRANCH_COND) || data_req_id) begin
          pc_ex_o <= pc_id_i;
        end

        branch_in_ex_o <= ctrl_transfer_insn_in_id == BRANCH_COND;
      end else if (ex_ready_i) begin
        // EX stage is ready but we don't have a new instruction for it,
        // so we set all write enables to 0, but unstall the pipe

        regfile_we_ex_o      <= 1'b0;

        regfile_alu_we_ex_o  <= 1'b0;

        csr_op_ex_o          <= CSR_OP_READ;

        data_req_ex_o        <= 1'b0;

        data_load_event_ex_o <= 1'b0;

        data_misaligned_ex_o <= 1'b0;

        branch_in_ex_o       <= 1'b0;

        apu_en_ex_o          <= 1'b0;

        alu_operator_ex_o    <= ALU_SLTU;

        mult_en_ex_o         <= 1'b0;

        alu_en_ex_o          <= 1'b1;

      end else if (csr_access_ex_o) begin
        //In the EX stage there was a CSR access, to avoid multiple
        //writes to the RF, disable regfile_alu_we_ex_o.
        //Not doing it can overwrite the RF file with the currennt CSR value rather than the old one
        regfile_alu_we_ex_o <= 1'b0;
      end
    end
  end

  // Performance Counter Events

  // Illegal/ebreak/ecall are never counted as retired instructions. Note that actually issued instructions
  // are being counted; the manner in which CSR instructions access the performance counters guarantees
  // that this count will correspond to the retired isntructions count.
  assign minstret = id_valid_o && is_decoding_o && !(illegal_insn_dec || ebrk_insn_dec || ecall_insn_dec);

  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      id_valid_q               <= 1'b0;
      mhpmevent_minstret_o     <= 1'b0;
      mhpmevent_load_o         <= 1'b0;
      mhpmevent_store_o        <= 1'b0;
      mhpmevent_jump_o         <= 1'b0;
      mhpmevent_branch_o       <= 1'b0;
      mhpmevent_compressed_o   <= 1'b0;
      mhpmevent_branch_taken_o <= 1'b0;
      mhpmevent_jr_stall_o     <= 1'b0;
      mhpmevent_imiss_o        <= 1'b0;
      mhpmevent_ld_stall_o     <= 1'b0;
      mhpmevent_pipe_stall_o   <= 1'b0;
    end else begin
      // Helper signal
      id_valid_q <= id_valid_o;
      // ID stage counts
      mhpmevent_minstret_o <= minstret;
      mhpmevent_load_o <= minstret && data_req_id && !data_we_id;
      mhpmevent_store_o <= minstret && data_req_id && data_we_id;
      mhpmevent_jump_o           <= minstret && ((ctrl_transfer_insn_in_id == BRANCH_JAL) || (ctrl_transfer_insn_in_id == BRANCH_JALR));
      mhpmevent_branch_o <= minstret && (ctrl_transfer_insn_in_id == BRANCH_COND);
      mhpmevent_compressed_o <= minstret && is_compressed_i;
      // EX stage count
      mhpmevent_branch_taken_o <= mhpmevent_branch_o && branch_decision_i;
      // IF stage count
      mhpmevent_imiss_o <= perf_imiss_i;
      // Jump-register-hazard; do not count stall on flushed instructions (id_valid_q used to only count first cycle)
      mhpmevent_jr_stall_o <= jr_stall && !halt_id && id_valid_q;
      // Load-use-hazard; do not count stall on flushed instructions (id_valid_q used to only count first cycle)
      mhpmevent_ld_stall_o <= load_stall && !halt_id && id_valid_q;
      // ELW
      mhpmevent_pipe_stall_o <= perf_pipeline_stall;
    end
  end

  // stall control
  assign id_ready_o = ((~misaligned_stall) & (~jr_stall) & (~load_stall) & (~apu_stall) & (~csr_apu_stall) & ex_ready_i);
  assign id_valid_o = (~halt_id) & id_ready_o;
  assign halt_if_o = halt_if;


  //----------------------------------------------------------------------------
  // Assertions
  //----------------------------------------------------------------------------
`ifdef CV32E40P_ASSERT_ON

  always_comb begin
    if (FPU == 1) begin
      assert (APU_NDSFLAGS_CPU >= C_RM+2*cv32e40p_fpu_pkg::FP_FORMAT_BITS+cv32e40p_fpu_pkg::INT_FORMAT_BITS)
      else
        $error("[apu] APU_NDSFLAGS_CPU APU flagbits is smaller than %0d",
               C_RM + 2 * cv32e40p_fpu_pkg::FP_FORMAT_BITS + cv32e40p_fpu_pkg::INT_FORMAT_BITS);
    end
  end

  // make sure that branch decision is valid when jumping
  a_br_decision :
  assert property (@(posedge clk) (branch_in_ex_o) |-> (branch_decision_i !== 1'bx))
  else begin
    $warning("%t, Branch decision is X in module %m", $time);
    $stop;
  end

  // the instruction delivered to the ID stage should always be valid
  a_valid_instr :
  assert property (@(posedge clk) (instr_valid_i & (~illegal_c_insn_i)) |-> (!$isunknown(instr)))
  else $warning("%t, Instruction is valid, but has at least one X", $time);

  // Check that instruction after taken branch is flushed (more should actually be flushed, but that is not checked here)
  // and that EX stage is ready to receive flushed instruction immediately
  property p_branch_taken_ex;
    @(posedge clk) disable iff (!rst_n) (branch_taken_ex == 1'b1) |-> ((ex_ready_i == 1'b1) &&
                                                                          (alu_en == 1'b0) && (apu_en == 1'b0) &&
                                                                          (mult_en == 1'b0) && (mult_int_en == 1'b0) &&
                                                                          (mult_dot_en == 1'b0) && (regfile_we_id == 1'b0) &&
                                                                          (regfile_alu_we_id == 1'b0) && (data_req_id == 1'b0));
  endproperty

  a_branch_taken_ex :
  assert property (p_branch_taken_ex);

  // Check that if IRQ PC update does not coincide with IRQ related CSR write
  // MIE is excluded from the check because it has a bypass.
  property p_irq_csr;
    @(posedge clk) disable iff (!rst_n) (pc_set_o && (pc_mux_o == PC_EXCEPTION) && ((exc_pc_mux_o == EXC_PC_EXCEPTION) || (exc_pc_mux_o == EXC_PC_IRQ)) &&
                                            csr_access_ex_o && (csr_op_ex_o != CSR_OP_READ)) |->
                                           ((alu_operand_b_ex_o[11:0] != CSR_MSTATUS) && (alu_operand_b_ex_o[11:0] != CSR_USTATUS) &&
                                            (alu_operand_b_ex_o[11:0] != CSR_MEPC) && (alu_operand_b_ex_o[11:0] != CSR_UEPC) &&
                                            (alu_operand_b_ex_o[11:0] != CSR_MCAUSE) && (alu_operand_b_ex_o[11:0] != CSR_UCAUSE) &&
                                            (alu_operand_b_ex_o[11:0] != CSR_MTVEC) && (alu_operand_b_ex_o[11:0] != CSR_UTVEC));
  endproperty

  a_irq_csr :
  assert property (p_irq_csr);

  // Check that xret does not coincide with CSR write (to avoid using wrong return address)
  // This check is more strict than really needed; a CSR instruction would be allowed in EX as long
  // as its write action happens before the xret CSR usage
  property p_xret_csr;
    @(posedge clk) disable iff (!rst_n) (pc_set_o && ((pc_mux_o == PC_MRET) || (pc_mux_o == PC_URET) || (pc_mux_o == PC_DRET))) |->
                                           (!(csr_access_ex_o && (csr_op_ex_o != CSR_OP_READ)));
  endproperty

  a_xret_csr :
  assert property (p_xret_csr);

  generate
    if (!A_EXTENSION) begin : gen_no_a_extension_assertions

      // Check that A extension opcodes are decoded as illegal when A extension not enabled
      property p_illegal_0;
        @(posedge clk) disable iff (!rst_n) (instr[6:0] == OPCODE_AMO) |-> (illegal_insn_dec == 'b1);
      endproperty

      a_illegal_0 :
      assert property (p_illegal_0);

    end
  endgenerate

  generate
    if (!COREV_PULP) begin : gen_no_pulp_xpulp_assertions

      // Check that PULP extension opcodes are decoded as illegal when PULP extension is not enabled
      property p_illegal_1;
        @(posedge clk) disable iff (!rst_n) ((instr[6:0] == OPCODE_CUSTOM_0) || (instr[6:0] == OPCODE_CUSTOM_1) ||
                                             (instr[6:0] == OPCODE_CUSTOM_2) || (instr[6:0] == OPCODE_CUSTOM_3))
                                            |-> (illegal_insn_dec == 'b1);
      endproperty

      a_illegal_1 :
      assert property (p_illegal_1);

      // Check that certain ALU operations are not used when PULP extension is not enabled
      property p_alu_op;
        @(posedge clk) disable iff (!rst_n) (1'b1) |-> ( (alu_operator != ALU_ADDU ) && (alu_operator != ALU_SUBU ) &&
                                                           (alu_operator != ALU_ADDR ) && (alu_operator != ALU_SUBR ) &&
                                                           (alu_operator != ALU_ADDUR) && (alu_operator != ALU_SUBUR) &&
                                                           (alu_operator != ALU_ROR) && (alu_operator != ALU_BEXT) &&
                                                           (alu_operator != ALU_BEXTU) && (alu_operator != ALU_BINS) &&
                                                           (alu_operator != ALU_BCLR) && (alu_operator != ALU_BSET) &&
                                                           (alu_operator != ALU_BREV) && (alu_operator != ALU_FF1) &&
                                                           (alu_operator != ALU_FL1) && (alu_operator != ALU_CNT) &&
                                                           (alu_operator != ALU_CLB) && (alu_operator != ALU_EXTS) &&
                                                           (alu_operator != ALU_EXT) && (alu_operator != ALU_LES) &&
                                                           (alu_operator != ALU_LEU) && (alu_operator != ALU_GTS) &&
                                                           (alu_operator != ALU_GTU) && (alu_operator != ALU_SLETS) &&
                                                           (alu_operator != ALU_SLETU) && (alu_operator != ALU_ABS) &&
                                                           (alu_operator != ALU_CLIP) && (alu_operator != ALU_CLIPU) &&
                                                           (alu_operator != ALU_INS) && (alu_operator != ALU_MIN) &&
                                                           (alu_operator != ALU_MINU) && (alu_operator != ALU_MAX) &&
                                                           (alu_operator != ALU_MAXU) && (alu_operator != ALU_SHUF) &&
                                                           (alu_operator != ALU_SHUF2) && (alu_operator != ALU_PCKLO) &&
                                                           (alu_operator != ALU_PCKHI) );
      endproperty

      a_alu_op :
      assert property (p_alu_op);

      // Check that certain vector modes are not used when PULP extension is not enabled
      property p_vector_mode;
        @(posedge clk) disable iff (!rst_n) (1'b1) |-> ( (alu_vec_mode != VEC_MODE8 ) && (alu_vec_mode != VEC_MODE16 ) );
      endproperty

      a_vector_mode :
      assert property (p_vector_mode);

      // Check that certain multiplier operations are not used when PULP extension is not enabled
      property p_mul_op;
        @(posedge clk) disable iff (!rst_n) (mult_int_en == 1'b1) |-> ( (mult_operator != MUL_MSU32) && (mult_operator != MUL_I) &&
                                                                         (mult_operator != MUL_IR) && (mult_operator != MUL_DOT8) &&
                                                                         (mult_operator != MUL_DOT16) );
      endproperty

      a_mul_op :
      assert property (p_mul_op);

    end
  endgenerate

  // Check that illegal instruction has no other side effects
  property p_illegal_2;
    @(posedge clk) disable iff (!rst_n) (illegal_insn_dec == 1'b1) |-> !(ebrk_insn_dec || mret_insn_dec || uret_insn_dec || dret_insn_dec ||
                                                                            ecall_insn_dec || wfi_insn_dec || fencei_insn_dec ||
                                                                            alu_en || mult_int_en || mult_dot_en || apu_en ||
                                                                            regfile_we_id || regfile_alu_we_id ||
                                                                            csr_op != CSR_OP_READ || data_req_id);
  endproperty

  a_illegal_2 :
  assert property (p_illegal_2);

`endif

endmodule  // cv32e40p_id_stage
