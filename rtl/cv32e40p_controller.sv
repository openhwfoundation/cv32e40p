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
// Engineer:       Matthias Baer - baermatt@student.ethz.ch                   //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Robert Balas - balasr@iis.ee.ethz.ch                       //
//                 Andrea Bettati - andrea.bettati@studenti.unipr.it          //
//                                                                            //
// Design Name:    Main controller                                            //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Main CPU controller of the processor                       //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_controller import cv32e40p_pkg::*;
#(
  parameter COREV_CLUSTER = 0,
  parameter COREV_PULP    = 0,
  parameter FPU           = 0
)
(
  input  logic        clk,                        // Gated clock
  input  logic        clk_ungated_i,              // Ungated clock
  input  logic        rst_n,

  input  logic        fetch_enable_i,             // Start the decoding
  output logic        ctrl_busy_o,                // Core is busy processing instructions
  output logic        is_decoding_o,              // Core is in decoding state
  input  logic        is_fetch_failed_i,

  // decoder related signals
  output logic        deassert_we_o,              // deassert write enable for next instruction

  input  logic        illegal_insn_i,             // decoder encountered an invalid instruction
  input  logic        ecall_insn_i,               // decoder encountered an ecall instruction
  input  logic        mret_insn_i,                // decoder encountered an mret instruction
  input  logic        uret_insn_i,                // decoder encountered an uret instruction

  input  logic        dret_insn_i,                // decoder encountered an dret instruction

  input  logic        mret_dec_i,
  input  logic        uret_dec_i,
  input  logic        dret_dec_i,

  input  logic        wfi_i,                      // decoder wants to execute a WFI
  input  logic        ebrk_insn_i,                // decoder encountered an ebreak instruction
  input  logic        fencei_insn_i,              // decoder encountered an fence.i instruction
  input  logic        csr_status_i,               // decoder encountered an csr status instruction

  output logic        hwlp_mask_o,                // prevent writes on the hwloop instructions in case interrupt are taken

  // from IF/ID pipeline
  input  logic        instr_valid_i,              // instruction coming from IF/ID pipeline is valid

  // from prefetcher
  output logic        instr_req_o,                // Start fetching instructions

  // to prefetcher
  output logic        pc_set_o,                   // jump to address set by pc_mux
  output logic [3:0]  pc_mux_o,                   // Selector in the Fetch stage to select the rigth PC (normal, jump ...)
  output logic [2:0]  exc_pc_mux_o,               // Selects target PC for exception
  output logic [1:0]  trap_addr_mux_o,            // Selects trap address base

  // HWLoop signls
  input  logic [31:0]       pc_id_i,

  // from hwloop_regs
  input  logic [1:0] [31:0] hwlp_start_addr_i,
  input  logic [1:0] [31:0] hwlp_end_addr_i,
  input  logic [1:0] [31:0] hwlp_counter_i,

  // to hwloop_regs
  output logic [1:0]        hwlp_dec_cnt_o,

  output logic              hwlp_jump_o,
  output logic [31:0]       hwlp_targ_addr_o,

  // LSU
  input  logic        data_req_ex_i,              // data memory access is currently performed in EX stage
  input  logic        data_we_ex_i,
  input  logic        data_misaligned_i,
  input  logic        data_load_event_i,
  input  logic        data_err_i,
  output logic        data_err_ack_o,

  // from ALU
  input  logic        mult_multicycle_i,          // multiplier is taken multiple cycles and uses op c as storage

  // APU dependency checks
  input  logic        apu_en_i,
  input  logic        apu_read_dep_i,
  input  logic        apu_read_dep_for_jalr_i,
  input  logic        apu_write_dep_i,

  output logic        apu_stall_o,

  // jump/branch signals
  input  logic        branch_taken_ex_i,          // branch taken signal from EX ALU
  input  logic [1:0]  ctrl_transfer_insn_in_id_i,               // jump is being calculated in ALU
  input  logic [1:0]  ctrl_transfer_insn_in_dec_i,              // jump is being calculated in ALU

  // Interrupt Controller Signals
  input  logic        irq_req_ctrl_i,
  input  logic        irq_sec_ctrl_i,
  input  logic [4:0]  irq_id_ctrl_i,
  input  logic        irq_wu_ctrl_i,
  input  PrivLvl_t    current_priv_lvl_i,

  output logic        irq_ack_o,
  output logic [4:0]  irq_id_o,

  output logic [4:0]  exc_cause_o,

  // Debug Signal
  output logic         debug_mode_o,
  output logic [2:0]   debug_cause_o,
  output logic         debug_csr_save_o,
  input  logic         debug_req_i,
  input  logic         debug_single_step_i,
  input  logic         debug_ebreakm_i,
  input  logic         debug_ebreaku_i,
  input  logic         trigger_match_i,
  output logic         debug_p_elw_no_sleep_o,
  output logic         debug_wfi_no_sleep_o,
  output logic         debug_havereset_o,
  output logic         debug_running_o,
  output logic         debug_halted_o,

  // Wakeup Signal
  output logic        wake_from_sleep_o,

  output logic        csr_save_if_o,
  output logic        csr_save_id_o,
  output logic        csr_save_ex_o,
  output logic [5:0]  csr_cause_o,
  output logic        csr_irq_sec_o,
  output logic        csr_restore_mret_id_o,
  output logic        csr_restore_uret_id_o,

  output logic        csr_restore_dret_id_o,

  output logic        csr_save_cause_o,


  // Regfile target
  input  logic        regfile_we_id_i,            // currently decoded we enable
  input  logic [5:0]  regfile_alu_waddr_id_i,     // currently decoded target address

  // Forwarding signals from regfile
  input  logic        regfile_we_ex_i,            // FW: write enable from  EX stage
  input  logic [5:0]  regfile_waddr_ex_i,         // FW: write address from EX stage
  input  logic        regfile_we_wb_i,            // FW: write enable from  WB stage
  input  logic        regfile_alu_we_fw_i,        // FW: ALU/MUL write enable from  EX stage

  // forwarding signals
  output logic [1:0]  operand_a_fw_mux_sel_o,     // regfile ra data selector form ID stage
  output logic [1:0]  operand_b_fw_mux_sel_o,     // regfile rb data selector form ID stage
  output logic [1:0]  operand_c_fw_mux_sel_o,     // regfile rc data selector form ID stage

  // forwarding detection signals
  input logic         reg_d_ex_is_reg_a_i,
  input logic         reg_d_ex_is_reg_b_i,
  input logic         reg_d_ex_is_reg_c_i,
  input logic         reg_d_wb_is_reg_a_i,
  input logic         reg_d_wb_is_reg_b_i,
  input logic         reg_d_wb_is_reg_c_i,
  input logic         reg_d_alu_is_reg_a_i,
  input logic         reg_d_alu_is_reg_b_i,
  input logic         reg_d_alu_is_reg_c_i,

  // stall signals
  output logic        halt_if_o,
  output logic        halt_id_o,

  output logic        misaligned_stall_o,
  output logic        jr_stall_o,
  output logic        load_stall_o,

  input  logic        id_ready_i,                 // ID stage is ready
  input  logic        id_valid_i,                 // ID stage is valid

  input  logic        ex_valid_i,                 // EX stage is done

  input  logic        wb_ready_i,                 // WB stage is ready

  // Performance Counters
  output logic        perf_pipeline_stall_o       // stall due to cv.elw extra cycles
);

  // FSM state encoding
  ctrl_state_e ctrl_fsm_cs, ctrl_fsm_ns;

  // Debug state
  debug_state_e debug_fsm_cs, debug_fsm_ns;

  logic jump_done, jump_done_q, jump_in_dec, branch_in_id;

  logic data_err_q;

  logic debug_mode_q, debug_mode_n;
  logic ebrk_force_debug_mode;
  logic is_hwlp_body;
  logic illegal_insn_q, illegal_insn_n;
  logic debug_req_entry_q, debug_req_entry_n;
  logic debug_force_wakeup_q, debug_force_wakeup_n;

  logic hwlp_end0_eq_pc;
  logic hwlp_end1_eq_pc;
  logic hwlp_counter0_gt_1;
  logic hwlp_counter1_gt_1;
  logic hwlp_counter0_eq_1;
  logic hwlp_counter1_eq_1;
  logic hwlp_counter0_eq_0;
  logic hwlp_counter1_eq_0;
  logic hwlp_end0_eq_pc_plus4;
  logic hwlp_end1_eq_pc_plus4;
  logic hwlp_start0_leq_pc;
  logic hwlp_start1_leq_pc;
  logic hwlp_end0_geq_pc;
  logic hwlp_end1_geq_pc;
  // Auxiliary signals to make hwlp_jump_o last only one cycle (converting it into a pulse)
  logic hwlp_end_4_id_d, hwlp_end_4_id_q;

  logic debug_req_q;
  logic debug_req_pending;

  // qualify wfi vs nosleep locally 
  logic wfi_active;


  ////////////////////////////////////////////////////////////////////////////////////////////
  //   ____ ___  ____  _____    ____ ___  _   _ _____ ____   ___  _     _     _____ ____    //
  //  / ___/ _ \|  _ \| ____|  / ___/ _ \| \ | |_   _|  _ \ / _ \| |   | |   | ____|  _ \   //
  // | |  | | | | |_) |  _|   | |  | | | |  \| | | | | |_) | | | | |   | |   |  _| | |_) |  //
  // | |__| |_| |  _ <| |___  | |__| |_| | |\  | | | |  _ <| |_| | |___| |___| |___|  _ <   //
  //  \____\___/|_| \_\_____|  \____\___/|_| \_| |_| |_| \_\\___/|_____|_____|_____|_| \_\  //
  //                                                                                        //
  ////////////////////////////////////////////////////////////////////////////////////////////

  always_comb
  begin
    // Default values

    instr_req_o            = 1'b1;

    data_err_ack_o         = 1'b0;

    csr_save_if_o          = 1'b0;
    csr_save_id_o          = 1'b0;
    csr_save_ex_o          = 1'b0;
    csr_restore_mret_id_o  = 1'b0;
    csr_restore_uret_id_o  = 1'b0;

    csr_restore_dret_id_o  = 1'b0;

    csr_save_cause_o       = 1'b0;

    exc_cause_o            = '0;
    exc_pc_mux_o           = EXC_PC_IRQ;
    trap_addr_mux_o        = TRAP_MACHINE;

    csr_cause_o            = '0;
    csr_irq_sec_o          = 1'b0;

    pc_mux_o               = PC_BOOT;
    pc_set_o               = 1'b0;
    jump_done              = jump_done_q;

    ctrl_fsm_ns            = ctrl_fsm_cs;

    ctrl_busy_o            = 1'b1;

    halt_if_o              = 1'b0;
    halt_id_o              = 1'b0;
    is_decoding_o          = 1'b0;
    irq_ack_o              = 1'b0;
    irq_id_o               = 5'b0;

    jump_in_dec            = ctrl_transfer_insn_in_dec_i == BRANCH_JALR || ctrl_transfer_insn_in_dec_i == BRANCH_JAL;

    branch_in_id           = ctrl_transfer_insn_in_id_i == BRANCH_COND;

    ebrk_force_debug_mode  = (debug_ebreakm_i && current_priv_lvl_i == PRIV_LVL_M) ||
                             (debug_ebreaku_i && current_priv_lvl_i == PRIV_LVL_U);
    debug_csr_save_o       = 1'b0;
    debug_cause_o          = DBG_CAUSE_EBREAK;
    debug_mode_n           = debug_mode_q;

    illegal_insn_n         = illegal_insn_q;
    // a trap towards the debug unit is generated when one of the
    // following conditions are true:
    // - ebreak instruction encountered
    // - single-stepping mode enabled
    // - illegal instruction exception and IIE bit is set
    // - IRQ and INTE bit is set and no exception is currently running
    // - Debuger requests halt

    debug_req_entry_n       = debug_req_entry_q;

    debug_force_wakeup_n    = debug_force_wakeup_q;

    perf_pipeline_stall_o   = 1'b0;

    hwlp_mask_o             = 1'b0;

    hwlp_dec_cnt_o          = '0;
    hwlp_end_4_id_d         = 1'b0;

    // When the controller tells to hwlp-jump, the prefetcher does not always jump immediately,
    // but the aligner immediately modifies pc_id to HWLP_BEGIN. This condition on hwlp_targ_addr_o
    // ensures that the target is kept constant even if pc_id is no more HWLP_END
    hwlp_targ_addr_o        = ((hwlp_start1_leq_pc && hwlp_end1_geq_pc) && !(hwlp_start0_leq_pc && hwlp_end0_geq_pc)) ? hwlp_start_addr_i[1] : hwlp_start_addr_i[0];

    unique case (ctrl_fsm_cs)
      // We were just reset, wait for fetch_enable
      RESET:
      begin
        is_decoding_o = 1'b0;
        instr_req_o   = 1'b0;
        if (fetch_enable_i == 1'b1)
        begin
          ctrl_fsm_ns = BOOT_SET;
        end
      end

      // copy boot address to instr fetch address
      BOOT_SET:
      begin
        is_decoding_o = 1'b0;
        instr_req_o   = 1'b1;
        pc_mux_o      = PC_BOOT;
        pc_set_o      = 1'b1;
        if (debug_req_pending) begin
            ctrl_fsm_ns = DBG_TAKEN_IF;
            debug_force_wakeup_n = 1'b1;
        end else begin
            ctrl_fsm_ns   = FIRST_FETCH;
        end
      end

      WAIT_SLEEP:
      begin
        is_decoding_o = 1'b0;
        ctrl_busy_o   = 1'b0;
        instr_req_o   = 1'b0;
        halt_if_o     = 1'b1;
        halt_id_o     = 1'b1;
        ctrl_fsm_ns   = SLEEP;
      end

      // instruction in if_stage is already valid
      SLEEP:
      begin
        // we begin execution when an
        // interrupt has arrived
        is_decoding_o = 1'b0;
        instr_req_o   = 1'b0;
        halt_if_o     = 1'b1;
        halt_id_o     = 1'b1;

        // normal execution flow
        // in debug mode or single step mode we leave immediately (wfi=nop)
        if (wake_from_sleep_o) begin
          if (debug_req_pending) begin
              ctrl_fsm_ns = DBG_TAKEN_IF;
              debug_force_wakeup_n = 1'b1;
          end else begin
              ctrl_fsm_ns  = FIRST_FETCH;
          end
        end else begin
          ctrl_busy_o = 1'b0;
        end
      end

      FIRST_FETCH:
      begin
        is_decoding_o = 1'b0;

        // ID stage is always ready
        ctrl_fsm_ns = DECODE;

        // handle interrupts
        if (irq_req_ctrl_i && ~(debug_req_pending || debug_mode_q)) begin
          // This assumes that the pipeline is always flushed before
          // going to sleep.
          // Debug mode takes precedence over irq (see DECODE:)

          // Taken IRQ
          halt_if_o         = 1'b1;
          halt_id_o         = 1'b1;

          pc_set_o          = 1'b1;
          pc_mux_o          = PC_EXCEPTION;
          exc_pc_mux_o      = EXC_PC_IRQ;
          exc_cause_o       = irq_id_ctrl_i;
          csr_irq_sec_o     = irq_sec_ctrl_i;

          // IRQ interface
          irq_ack_o         = 1'b1;
          irq_id_o          = irq_id_ctrl_i;

          if (irq_sec_ctrl_i)
            trap_addr_mux_o  = TRAP_MACHINE;
          else
            trap_addr_mux_o  = current_priv_lvl_i == PRIV_LVL_U ? TRAP_USER : TRAP_MACHINE;

          csr_save_cause_o  = 1'b1;
          csr_cause_o       = {1'b1,irq_id_ctrl_i};
          csr_save_if_o     = 1'b1;
        end
      end

      DECODE:
      begin

          if (branch_taken_ex_i)
          begin //taken branch
            // there is a branch in the EX stage that is taken

            is_decoding_o = 1'b0;

            pc_mux_o      = PC_BRANCH;
            pc_set_o      = 1'b1;

            // if we want to debug, flush the pipeline
            // the current_pc_if will take the value of the next instruction to
            // be executed (NPC)

          end  //taken branch

          else if (data_err_i)
          begin //data error
            // the current LW or SW have been blocked by the PMP

            is_decoding_o     = 1'b0;
            halt_if_o         = 1'b1;
            halt_id_o         = 1'b1;
            csr_save_ex_o     = 1'b1;
            csr_save_cause_o  = 1'b1;
            data_err_ack_o    = 1'b1;
            //no jump in this stage as we have to wait one cycle to go to Machine Mode

            csr_cause_o       = {1'b0, data_we_ex_i ? EXC_CAUSE_STORE_FAULT : EXC_CAUSE_LOAD_FAULT};
            ctrl_fsm_ns       = FLUSH_WB;

          end  //data error

          else if (is_fetch_failed_i)
          begin

            // the current instruction has been blocked by the PMP

            is_decoding_o     = 1'b0;
            halt_id_o         = 1'b1;
            halt_if_o         = 1'b1;
            csr_save_if_o     = 1'b1;
            csr_save_cause_o  = !debug_mode_q;

            //no jump in this stage as we have to wait one cycle to go to Machine Mode

            csr_cause_o       = {1'b0, EXC_CAUSE_INSTR_FAULT};
            ctrl_fsm_ns       = FLUSH_WB;


          end
          // decode and execute instructions only if the current conditional
          // branch in the EX stage is either not taken, or there is no
          // conditional branch in the EX stage
          else if (instr_valid_i) //valid block
          begin: blk_decode_level1 // now analyze the current instruction in the ID stage

            is_decoding_o = 1'b1;
            illegal_insn_n = 1'b0;

            if ( (debug_req_pending || trigger_match_i) & ~debug_mode_q )
              begin
                //Serving the debug
                is_decoding_o     = COREV_PULP ? 1'b0 : 1'b1;
                halt_if_o         = 1'b1;
                halt_id_o         = 1'b1;
                ctrl_fsm_ns       = DBG_FLUSH;
                debug_req_entry_n = 1'b1;
              end
            else if (irq_req_ctrl_i && ~debug_mode_q)
              begin
                // Taken IRQ
                hwlp_mask_o       = COREV_PULP ? 1'b1 : 1'b0;

                is_decoding_o     = 1'b0;
                halt_if_o         = 1'b1;
                halt_id_o         = 1'b1;

                pc_set_o          = 1'b1;
                pc_mux_o          = PC_EXCEPTION;
                exc_pc_mux_o      = EXC_PC_IRQ;
                exc_cause_o       = irq_id_ctrl_i;
                csr_irq_sec_o     = irq_sec_ctrl_i;

                // IRQ interface
                irq_ack_o         = 1'b1;
                irq_id_o          = irq_id_ctrl_i;

                if (irq_sec_ctrl_i)
                  trap_addr_mux_o  = TRAP_MACHINE;
                else
                  trap_addr_mux_o  = current_priv_lvl_i == PRIV_LVL_U ? TRAP_USER : TRAP_MACHINE;

                csr_save_cause_o  = 1'b1;
                csr_cause_o       = {1'b1,irq_id_ctrl_i};
                csr_save_id_o     = 1'b1;
              end
            else
              begin

                if (illegal_insn_i) begin

                  halt_if_o         = 1'b1;
                  halt_id_o         = 1'b0;
                  ctrl_fsm_ns       = id_ready_i ? FLUSH_EX : DECODE;
                  illegal_insn_n    = 1'b1;

                end else begin

                  //decoding block
                  unique case (1'b1)

                    jump_in_dec: begin
                    // handle unconditional jumps
                    // we can jump directly since we know the address already
                    // we don't need to worry about conditional branches here as they
                    // will be evaluated in the EX stage
                      pc_mux_o = PC_JUMP;
                      // if there is a jr stall, wait for it to be gone
                      if ((~jr_stall_o) && (~jump_done_q)) begin
                        pc_set_o    = 1'b1;
                        jump_done   = 1'b1;
                      end
                    end

                    ebrk_insn_i: begin
                      halt_if_o     = 1'b1;
                      halt_id_o     = 1'b0;

                      if (debug_mode_q)
                        // we got back to the park loop in the debug rom
                        ctrl_fsm_ns = DBG_FLUSH;

                      else if (ebrk_force_debug_mode) begin
                        // debug module commands us to enter debug mode anyway
                        ctrl_fsm_ns  = DBG_FLUSH;
                      end else begin
                        // otherwise just a normal ebreak exception
                        ctrl_fsm_ns = id_ready_i ? FLUSH_EX : DECODE;
                      end

                    end

                    wfi_active: begin
                      halt_if_o     = 1'b1;
                      halt_id_o     = 1'b0;
                      ctrl_fsm_ns           = id_ready_i ? FLUSH_EX : DECODE;
                    end

                    ecall_insn_i: begin
                      halt_if_o     = 1'b1;
                      halt_id_o     = 1'b0;
                      ctrl_fsm_ns           = id_ready_i ? FLUSH_EX : DECODE;
                    end

                    fencei_insn_i: begin
                      halt_if_o     = 1'b1;
                      halt_id_o     = 1'b0;
                      ctrl_fsm_ns           = id_ready_i ? FLUSH_EX : DECODE;
                    end

                    mret_insn_i | uret_insn_i | dret_insn_i: begin
                      halt_if_o     = 1'b1;
                      halt_id_o     = 1'b0;
                      ctrl_fsm_ns           = id_ready_i ? FLUSH_EX : DECODE;
                    end

                    csr_status_i: begin
                      halt_if_o     = 1'b1;
                      if (~id_ready_i) begin
                        ctrl_fsm_ns = DECODE;
                      end else begin
                        ctrl_fsm_ns = FLUSH_EX;
                        if (hwlp_end0_eq_pc) begin
                          hwlp_dec_cnt_o[0] = 1'b1;
                        end
                        if (hwlp_end1_eq_pc) begin
                          hwlp_dec_cnt_o[1] = 1'b1;
                        end
                      end
                    end

                    data_load_event_i: begin
                      ctrl_fsm_ns   = id_ready_i ? ELW_EXE : DECODE;
                      halt_if_o     = 1'b1;
                    end

                    default: begin

                      if(is_hwlp_body) begin
                        //we are at the inside of an HWloop, thus change state

                        //We stay here in case we returned from the second last instruction, otherwise the next cycle
                        //in DECODE_HWLOOP we miss to jump, we jump at PC_END.
                        //This way looses a cycle but it's a corner case of returning from exceptions or interrupts

                        ctrl_fsm_ns  = hwlp_end0_eq_pc_plus4 || hwlp_end1_eq_pc_plus4 ? DECODE : DECODE_HWLOOP;

                        // we can be at the end of HWloop due to a return from interrupt or ecall or ebreak or exceptions
                        if (hwlp_end0_eq_pc && hwlp_counter0_gt_1) begin
                          pc_mux_o         = PC_HWLOOP;
                          if (~jump_done_q) begin
                            pc_set_o          = 1'b1;
                            // Keep the instruction and the related address in the Aligner if
                            // ID is stalled during a jump
                            jump_done         = 1'b1;
                            hwlp_dec_cnt_o[0] = 1'b1;
                          end
                        end
                        if (hwlp_end1_eq_pc && hwlp_counter1_gt_1) begin
                          pc_mux_o         = PC_HWLOOP;
                          if (~jump_done_q) begin
                            pc_set_o          = 1'b1;
                            // Keep the instruction and the related address in the Aligner if
                            // ID is stalled during a jump
                            jump_done         = 1'b1;
                            hwlp_dec_cnt_o[1] = 1'b1;
                          end
                        end
                      end

                      if (hwlp_end0_eq_pc && hwlp_counter0_eq_1) begin
                        hwlp_dec_cnt_o[0] = 1'b1;
                      end
                      if (hwlp_end1_eq_pc && hwlp_counter1_eq_1) begin
                        hwlp_dec_cnt_o[1] = 1'b1;
                      end

                    end

                  endcase // unique case (1'b1)
                end

                if (debug_single_step_i & ~debug_mode_q) begin
                    // prevent any more instructions from executing
                    halt_if_o = 1'b1;

                    // we don't handle dret here because its should be illegal
                    // anyway in this context

                    // illegal, ecall, ebrk and xrettransition to later to a DBG
                    // state since we need the return address which is
                    // determined later

                    if (id_ready_i) begin
                    // make sure the current instruction has been executed
                        unique case(1'b1)

                        illegal_insn_i | ecall_insn_i:
                        begin
                            ctrl_fsm_ns = FLUSH_EX;
                        end

                        (~ebrk_force_debug_mode & ebrk_insn_i):
                        begin
                            ctrl_fsm_ns = FLUSH_EX;
                        end

                        mret_insn_i | uret_insn_i:
                        begin
                            ctrl_fsm_ns = FLUSH_EX;
                        end

                        branch_in_id:
                        begin
                            ctrl_fsm_ns    = DBG_WAIT_BRANCH;
                        end

                        default:
                            // regular instruction or ebrk force debug
                            ctrl_fsm_ns = DBG_FLUSH;
                        endcase // unique case (1'b1)
                    end
                end

              end // else: !if (irq_req_ctrl_i && ~debug_mode_q)

          end  //valid block
          else begin
            is_decoding_o         = 1'b0;
            perf_pipeline_stall_o = data_load_event_i;
          end
      end

      DECODE_HWLOOP:
      begin
        if (COREV_PULP) begin
          if (instr_valid_i) // valid block
          begin // now analyze the current instruction in the ID stage

            is_decoding_o = 1'b1;

            if ( (debug_req_pending || trigger_match_i) & ~debug_mode_q )
              begin
                //Serving the debug
                is_decoding_o     = COREV_PULP ? 1'b0 : 1'b1;
                halt_if_o         = 1'b1;
                halt_id_o         = 1'b1;
                ctrl_fsm_ns       = DBG_FLUSH;
                debug_req_entry_n = 1'b1;
             end
            else if (irq_req_ctrl_i && ~debug_mode_q)
              begin
                // Taken IRQ
                hwlp_mask_o       = COREV_PULP ? 1'b1 : 1'b0;

                is_decoding_o     = 1'b0;
                halt_if_o         = 1'b1;
                halt_id_o         = 1'b1;

                pc_set_o          = 1'b1;
                pc_mux_o          = PC_EXCEPTION;
                exc_pc_mux_o      = EXC_PC_IRQ;
                exc_cause_o       = irq_id_ctrl_i;
                csr_irq_sec_o     = irq_sec_ctrl_i;

                // IRQ interface
                irq_ack_o         = 1'b1;
                irq_id_o          = irq_id_ctrl_i;

                if (irq_sec_ctrl_i)
                  trap_addr_mux_o  = TRAP_MACHINE;
                else
                  trap_addr_mux_o  = current_priv_lvl_i == PRIV_LVL_U ? TRAP_USER : TRAP_MACHINE;

                csr_save_cause_o  = 1'b1;
                csr_cause_o       = {1'b1,irq_id_ctrl_i};
                csr_save_id_o     = 1'b1;

                ctrl_fsm_ns       = DECODE;
              end
            else
              begin

                if (illegal_insn_i) begin

                  halt_if_o         = 1'b1;
                  halt_id_o         = 1'b1;
                  ctrl_fsm_ns       = FLUSH_EX;
                  illegal_insn_n    = 1'b1;

                end else begin

                  //decoding block
                  unique case (1'b1)

                    ebrk_insn_i: begin
                      halt_if_o     = 1'b1;
                      halt_id_o     = 1'b0;

                      if (debug_mode_q)
                        // we got back to the park loop in the debug rom
                        ctrl_fsm_ns = DBG_FLUSH;

                      else if (ebrk_force_debug_mode)
                        // debug module commands us to enter debug mode anyway
                        ctrl_fsm_ns  = DBG_FLUSH;

                      else begin
                        // otherwise just a normal ebreak exception
                        ctrl_fsm_ns = id_ready_i ? FLUSH_EX : DECODE_HWLOOP;
                      end

                    end

                    ecall_insn_i: begin
                      halt_if_o     = 1'b1;
                      halt_id_o     = 1'b0;
                      ctrl_fsm_ns   = id_ready_i ? FLUSH_EX : DECODE_HWLOOP;
                    end

                    csr_status_i: begin
                      halt_if_o     = 1'b1;
                      if (~id_ready_i) begin
                        ctrl_fsm_ns = DECODE_HWLOOP;
                      end else begin
                        ctrl_fsm_ns = FLUSH_EX;
                        if (hwlp_end0_eq_pc) begin
                          hwlp_dec_cnt_o[0] = 1'b1;
                        end
                        if (hwlp_end1_eq_pc) begin
                          hwlp_dec_cnt_o[1] = 1'b1;
                        end
                      end
                    end

                    data_load_event_i: begin
                      ctrl_fsm_ns   = id_ready_i ? ELW_EXE : DECODE_HWLOOP;
                      halt_if_o     = 1'b1;
                    end

                    default: begin

                       // we can be at the end of HWloop due to a return from interrupt or ecall or ebreak or exceptions
                      if(hwlp_end1_eq_pc_plus4) begin
                          if(hwlp_counter1_gt_1) begin
                            hwlp_end_4_id_d  = 1'b1;
                            hwlp_targ_addr_o = hwlp_start_addr_i[1];
                            ctrl_fsm_ns      = DECODE_HWLOOP;
                          end else
                            ctrl_fsm_ns      = is_hwlp_body ? DECODE_HWLOOP : DECODE;
                      end

                      if(hwlp_end0_eq_pc_plus4) begin
                          if(hwlp_counter0_gt_1) begin
                            hwlp_end_4_id_d  = 1'b1;
                            hwlp_targ_addr_o = hwlp_start_addr_i[0];
                            ctrl_fsm_ns      = DECODE_HWLOOP;
                          end else
                            ctrl_fsm_ns      = is_hwlp_body ? DECODE_HWLOOP : DECODE;
                      end

                      hwlp_dec_cnt_o[0] = hwlp_end0_eq_pc && !hwlp_counter0_eq_0;
                      hwlp_dec_cnt_o[1] = hwlp_end1_eq_pc && !hwlp_counter1_eq_0;

                    end
                  endcase // unique case (1'b1)
                end // else: !if(illegal_insn_i)

                if (debug_single_step_i & ~debug_mode_q) begin
                    // prevent any more instructions from executing
                    halt_if_o = 1'b1;

                    // we don't handle dret here because its should be illegal
                    // anyway in this context

                    // illegal, ecall, ebrk and xrettransition to later to a DBG
                    // state since we need the return address which is
                    // determined later

                    if (id_ready_i) begin
                    // make sure the current instruction has been executed
                        unique case(1'b1)

                        illegal_insn_i | ecall_insn_i:
                        begin
                            ctrl_fsm_ns = FLUSH_EX;
                        end

                        (~ebrk_force_debug_mode & ebrk_insn_i):
                        begin
                            ctrl_fsm_ns = FLUSH_EX;
                        end

                        mret_insn_i | uret_insn_i:
                        begin
                            ctrl_fsm_ns = FLUSH_EX;
                        end

                        branch_in_id:
                        begin
                            ctrl_fsm_ns = DBG_WAIT_BRANCH;
                        end

                        default:
                            // regular instruction or ebrk force debug
                            ctrl_fsm_ns = DBG_FLUSH;
                        endcase // unique case (1'b1)
                    end
                end // if (debug_single_step_i & ~debug_mode_q)

              end // else: !if (irq_req_ctrl_i && ~debug_mode_q)

          end // block: blk_decode_level1 : valid block
          else begin
            is_decoding_o         = 1'b0;
            perf_pipeline_stall_o = data_load_event_i;
          end
        end
      end

      // flush the pipeline, insert NOP into EX stage
      FLUSH_EX:
      begin
        is_decoding_o = 1'b0;

        halt_if_o = 1'b1;
        halt_id_o = 1'b1;

        if (data_err_i)
        begin //data error
            // the current LW or SW have been blocked by the PMP
            csr_save_ex_o     = 1'b1;
            csr_save_cause_o  = 1'b1;
            data_err_ack_o    = 1'b1;
            //no jump in this stage as we have to wait one cycle to go to Machine Mode
            csr_cause_o       = {1'b0, data_we_ex_i ? EXC_CAUSE_STORE_FAULT : EXC_CAUSE_LOAD_FAULT};
            ctrl_fsm_ns       = FLUSH_WB;
            //putting illegal to 0 as if it was 1, the core is going to jump to the exception of the EX stage,
            //so the illegal was never executed
            illegal_insn_n    = 1'b0;
        end  //data erro
        else if (ex_valid_i) begin
          //check done to prevent data harzard in the CSR registers
          ctrl_fsm_ns = FLUSH_WB;

          if(illegal_insn_q) begin
            csr_save_id_o     = 1'b1;
            csr_save_cause_o  = !debug_mode_q;
            csr_cause_o       = {1'b0, EXC_CAUSE_ILLEGAL_INSN};
          end else begin
            unique case (1'b1)
              ebrk_insn_i: begin
                csr_save_id_o     = 1'b1;
                csr_save_cause_o  = 1'b1;
                csr_cause_o       = {1'b0, EXC_CAUSE_BREAKPOINT};
              end
              ecall_insn_i: begin
                csr_save_id_o     = 1'b1;
                csr_save_cause_o  = !debug_mode_q;
                csr_cause_o       = {1'b0, current_priv_lvl_i == PRIV_LVL_U ? EXC_CAUSE_ECALL_UMODE : EXC_CAUSE_ECALL_MMODE};
              end
              default:;
            endcase // unique case (1'b1)
          end

        end
      end

      IRQ_FLUSH_ELW:
      begin
        if (COREV_CLUSTER == 1'b1) begin
          is_decoding_o = 1'b0;

          halt_if_o     = 1'b1;
          halt_id_o     = 1'b1;

          ctrl_fsm_ns   = DECODE;

          perf_pipeline_stall_o = data_load_event_i;

          if (irq_req_ctrl_i && ~(debug_req_pending || debug_mode_q)) begin
            // Taken IRQ
            is_decoding_o     = 1'b0;
            halt_if_o         = 1'b1;
            halt_id_o         = 1'b1;

            pc_set_o          = 1'b1;
            pc_mux_o          = PC_EXCEPTION;
            exc_pc_mux_o      = EXC_PC_IRQ;
            exc_cause_o       = irq_id_ctrl_i;
            csr_irq_sec_o     = irq_sec_ctrl_i;

            // IRQ interface
            irq_ack_o         = 1'b1;
            irq_id_o          = irq_id_ctrl_i;

            if (irq_sec_ctrl_i)
              trap_addr_mux_o  = TRAP_MACHINE;
            else
              trap_addr_mux_o  = current_priv_lvl_i == PRIV_LVL_U ? TRAP_USER : TRAP_MACHINE;

            csr_save_cause_o  = 1'b1;
            csr_cause_o       = {1'b1,irq_id_ctrl_i};
            csr_save_id_o     = 1'b1;
          end
        end
      end

      ELW_EXE:
      begin
        if (COREV_CLUSTER == 1'b1) begin
          is_decoding_o = 1'b0;

          halt_if_o   = 1'b1;
          halt_id_o   = 1'b1;

          //if we are here, a cv.elw is executing now in the EX stage
          //or if an interrupt has been received
          //the ID stage contains the PC_ID of the cv.elw, therefore halt_id is set to invalid the instruction
          //If an interrupt occurs, we replay the ELW
          //No needs to check irq_int_req_i since in the EX stage there is only the cv.elw, no CSR pendings
          if(id_ready_i)
            ctrl_fsm_ns = ((debug_req_pending || trigger_match_i) & ~debug_mode_q) ? DBG_FLUSH : IRQ_FLUSH_ELW;
            // if from the ELW EXE we go to IRQ_FLUSH_ELW, it is assumed that if there was an IRQ req together with the grant and IE was valid, then
            // there must be no hazard due to xIE
          else
            ctrl_fsm_ns = ELW_EXE;

          perf_pipeline_stall_o = data_load_event_i;
        end
      end

      // flush the pipeline, insert NOP into EX and WB stage
      FLUSH_WB:
      begin
        is_decoding_o = 1'b0;

        halt_if_o = 1'b1;
        halt_id_o = 1'b1;

        ctrl_fsm_ns = DECODE;

        if(data_err_q) begin
            //PMP data_error
            pc_mux_o              = PC_EXCEPTION;
            pc_set_o              = 1'b1;
            trap_addr_mux_o       = TRAP_MACHINE;
            //little hack during testing
            exc_pc_mux_o          = EXC_PC_EXCEPTION;
            exc_cause_o           = data_we_ex_i ? EXC_CAUSE_LOAD_FAULT : EXC_CAUSE_STORE_FAULT;

        end
        else if (is_fetch_failed_i) begin
            //instruction fetch error
            pc_mux_o              = PC_EXCEPTION;
            pc_set_o              = 1'b1;
            trap_addr_mux_o       = TRAP_MACHINE;
            exc_pc_mux_o          = debug_mode_q ? EXC_PC_DBE : EXC_PC_EXCEPTION;
            exc_cause_o           = EXC_CAUSE_INSTR_FAULT;

        end
        else begin
          if(illegal_insn_q) begin
              //exceptions
              pc_mux_o              = PC_EXCEPTION;
              pc_set_o              = 1'b1;
              trap_addr_mux_o       = TRAP_MACHINE;
              exc_pc_mux_o          = debug_mode_q ? EXC_PC_DBE : EXC_PC_EXCEPTION;
              illegal_insn_n        = 1'b0;
              if (debug_single_step_i && ~debug_mode_q)
                  ctrl_fsm_ns = DBG_TAKEN_IF;
          end else begin
            unique case(1'b1)
              ebrk_insn_i: begin
                  //ebreak
                  pc_mux_o              = PC_EXCEPTION;
                  pc_set_o              = 1'b1;
                  trap_addr_mux_o       = TRAP_MACHINE;
                  exc_pc_mux_o          = EXC_PC_EXCEPTION;

                  if (debug_single_step_i && ~debug_mode_q)
                      ctrl_fsm_ns = DBG_TAKEN_IF;
              end
              ecall_insn_i: begin
                  //ecall
                  pc_mux_o              = PC_EXCEPTION;
                  pc_set_o              = 1'b1;
                  trap_addr_mux_o       = TRAP_MACHINE;
                  exc_pc_mux_o          = debug_mode_q ? EXC_PC_DBE : EXC_PC_EXCEPTION;

                  if (debug_single_step_i && ~debug_mode_q)
                      ctrl_fsm_ns = DBG_TAKEN_IF;
              end

              mret_insn_i: begin
                 csr_restore_mret_id_o =  !debug_mode_q;
                 ctrl_fsm_ns           = XRET_JUMP;
              end
              uret_insn_i: begin
                 csr_restore_uret_id_o =  !debug_mode_q;
                 ctrl_fsm_ns           = XRET_JUMP;
              end
              dret_insn_i: begin
                  csr_restore_dret_id_o = 1'b1;
                  ctrl_fsm_ns           = XRET_JUMP;
              end

              csr_status_i: begin
                if ((hwlp_end0_eq_pc && !hwlp_counter0_eq_0) ||
                    (hwlp_end1_eq_pc && !hwlp_counter1_eq_0)) begin
                  pc_mux_o = PC_HWLOOP;
                  pc_set_o = 1'b1;
                end
              end

              wfi_i: begin
                  if ( debug_req_pending) begin
                      ctrl_fsm_ns = DBG_TAKEN_IF;
                      debug_force_wakeup_n = 1'b1;
                  end else begin
                    ctrl_fsm_ns = WAIT_SLEEP;
                  end
              end
              fencei_insn_i: begin
                  // we just jump to instruction after the fence.i since that
                  // forces the instruction cache to refetch
                  pc_mux_o              = PC_FENCEI;
                  pc_set_o              = 1'b1;
              end
              default:;
            endcase
          end
        end

      end

      XRET_JUMP:
      begin
        is_decoding_o = 1'b0;
        ctrl_fsm_ns   = DECODE;
        unique case(1'b1)
          mret_dec_i: begin
              //mret
              pc_mux_o              = debug_mode_q ? PC_EXCEPTION : PC_MRET;
              pc_set_o              = 1'b1;
              exc_pc_mux_o          = EXC_PC_DBE; // only used if in debug_mode
          end
          uret_dec_i: begin
              //uret
              pc_mux_o              = debug_mode_q ? PC_EXCEPTION : PC_URET;
              pc_set_o              = 1'b1;
              exc_pc_mux_o          = EXC_PC_DBE; // only used if in debug_mode
          end
          dret_dec_i: begin
              //dret
              // this case is only reachable while in debug_mode
              pc_mux_o              = PC_DRET;
              pc_set_o              = 1'b1;
              debug_mode_n          = 1'b0;
          end
          default:;
        endcase

        if (debug_single_step_i && ~debug_mode_q) begin
          ctrl_fsm_ns = DBG_TAKEN_IF;
        end
      end

      // a branch was in ID when trying to go to debug rom. Wait until we can
      // determine branch target address (for saving into dpc) before proceeding
      DBG_WAIT_BRANCH:
      begin
        is_decoding_o = 1'b0;
        halt_if_o = 1'b1;

        if (branch_taken_ex_i) begin
          // there is a branch in the EX stage that is taken
          pc_mux_o = PC_BRANCH;
          pc_set_o = 1'b1;
        end

        ctrl_fsm_ns = DBG_FLUSH;
      end

      // We enter this state when we encounter
      // 1. ebreak during debug mode
      // 2. trigger match
      // 3. ebreak with forced entry into debug mode (ebreakm or ebreaku set).
      // 4. halt request during decode
      // Regular ebreak's go through FLUSH_EX and FLUSH_WB.
      // For 1. we don't update dcsr and dpc while for 2., 3., & 4. we do
      // dpc is set to the address of ebreak and trigger match
      // not to the next instruction's (which is why we save the pc in id).
      DBG_TAKEN_ID:
      begin
        is_decoding_o     = 1'b0;
        pc_set_o          = 1'b1;
        pc_mux_o          = PC_EXCEPTION;
        exc_pc_mux_o      = EXC_PC_DBD;
        // If not in debug mode then save cause and dpc csrs
        // else it was an ebreak in debug mode, so don't update csrs
        if (~debug_mode_q) begin
            csr_save_cause_o = 1'b1;
            csr_save_id_o    = 1'b1;
            debug_csr_save_o = 1'b1;
            if (trigger_match_i)
                debug_cause_o = DBG_CAUSE_TRIGGER; // pri 4 (highest)
            else if (ebrk_force_debug_mode & ebrk_insn_i)
                debug_cause_o = DBG_CAUSE_EBREAK; // pri 3
            else if (debug_req_entry_q)
                debug_cause_o = DBG_CAUSE_HALTREQ;// pri 2 and 1

        end
        debug_req_entry_n  = 1'b0;
        ctrl_fsm_ns        = DECODE;
        debug_mode_n       = 1'b1;
      end

      // We enter this state for single stepping
      // DPC is set the next instruction to be executed/fetched
      DBG_TAKEN_IF:
      begin
        is_decoding_o     = 1'b0;
        pc_set_o          = 1'b1;
        pc_mux_o          = PC_EXCEPTION;
        exc_pc_mux_o      = EXC_PC_DBD;
        csr_save_cause_o  = 1'b1;
        debug_csr_save_o  = 1'b1;
        if (debug_force_wakeup_q) 
            debug_cause_o = DBG_CAUSE_HALTREQ;
        else if (debug_single_step_i)
            debug_cause_o = DBG_CAUSE_STEP; // pri 0
        csr_save_if_o   = 1'b1;
        ctrl_fsm_ns     = DECODE;
        debug_mode_n    = 1'b1;
        debug_force_wakeup_n = 1'b0;
      end


      DBG_FLUSH:
      begin
        is_decoding_o = 1'b0;

        halt_if_o   = 1'b1;
        halt_id_o   = 1'b1;

        perf_pipeline_stall_o = data_load_event_i;

        if (data_err_i)
        begin //data error
            // the current LW or SW have been blocked by the PMP
            csr_save_ex_o     = 1'b1;
            csr_save_cause_o  = 1'b1;
            data_err_ack_o    = 1'b1;
            //no jump in this stage as we have to wait one cycle to go to Machine Mode
            csr_cause_o       = {1'b0, data_we_ex_i ? EXC_CAUSE_STORE_FAULT : EXC_CAUSE_LOAD_FAULT};
            ctrl_fsm_ns       = FLUSH_WB;
        end  //data error
        else begin
          if(debug_mode_q                          |
             trigger_match_i                       |
             (ebrk_force_debug_mode & ebrk_insn_i) |
             data_load_event_i                     |
             debug_req_entry_q                     )
            begin
              ctrl_fsm_ns = DBG_TAKEN_ID;
            end else
            begin
              // else must be debug_single_step_i
              ctrl_fsm_ns = DBG_TAKEN_IF;
            end
        end
      end
      // Debug end

      default: begin
        is_decoding_o = 1'b0;
        instr_req_o = 1'b0;
        ctrl_fsm_ns = RESET;
      end
    endcase
  end



generate
  if(COREV_PULP) begin : gen_hwlp
    //////////////////////////////////////////////////////////////////////////////
    // Convert hwlp_jump_o to a pulse
    //////////////////////////////////////////////////////////////////////////////

    // hwlp_jump_o should last one cycle only, as the prefetcher
    // reacts immediately. If it last more cycles, the prefetcher
    // goes on requesting HWLP_BEGIN more than one time (wrong!).
    // This signal is not controlled by id_ready because otherwise,
    // in case of stall, the jump would happen at the end of the stall.

    // Make hwlp_jump_o last only one cycle
    assign hwlp_jump_o = (hwlp_end_4_id_d && !hwlp_end_4_id_q) ? 1'b1 : 1'b0;

    always_ff @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
        hwlp_end_4_id_q <= 1'b0;
      end else begin
        hwlp_end_4_id_q <= hwlp_end_4_id_d;
      end
    end

    assign hwlp_end0_eq_pc         = hwlp_end_addr_i[0] == pc_id_i + 4;   // Equivalent to hwlp_end_addr_i[0] - 4 == pc_id_i
    assign hwlp_end1_eq_pc         = hwlp_end_addr_i[1] == pc_id_i + 4;   // Equivalent to hwlp_end_addr_i[1] - 4 == pc_id_i
    assign hwlp_counter0_gt_1      = hwlp_counter_i[0] > 1;
    assign hwlp_counter1_gt_1      = hwlp_counter_i[1] > 1;
    assign hwlp_counter0_eq_1      = hwlp_counter_i[0] == 1;
    assign hwlp_counter1_eq_1      = hwlp_counter_i[1] == 1;
    assign hwlp_counter0_eq_0      = hwlp_counter_i[0] == 0;
    assign hwlp_counter1_eq_0      = hwlp_counter_i[1] == 0;
    assign hwlp_end0_eq_pc_plus4   = hwlp_end_addr_i[0] == pc_id_i + 8;   // Equivalent to hwlp_end_addr_i[0] - 4 == pc_id_i + 4
    assign hwlp_end1_eq_pc_plus4   = hwlp_end_addr_i[1] == pc_id_i + 8;   // Equivalent to hwlp_end_addr_i[1] - 4 == pc_id_i + 4
    assign hwlp_start0_leq_pc      = hwlp_start_addr_i[0] <= pc_id_i;
    assign hwlp_start1_leq_pc      = hwlp_start_addr_i[1] <= pc_id_i;
    assign hwlp_end0_geq_pc        = hwlp_end_addr_i[0] >= pc_id_i + 4;   // Equivalent to hwlp_end_addr_i[0] - 4 >= pc_id_i
    assign hwlp_end1_geq_pc        = hwlp_end_addr_i[1] >= pc_id_i + 4;   // Equivalent to hwlp_end_addr_i[1] - 4 >= pc_id_i;
    assign is_hwlp_body            = ((hwlp_start0_leq_pc && hwlp_end0_geq_pc) && hwlp_counter0_gt_1) ||  ((hwlp_start1_leq_pc && hwlp_end1_geq_pc) && hwlp_counter1_gt_1);

  end else begin : gen_no_hwlp

    assign hwlp_jump_o             = 1'b0;
    assign hwlp_end_4_id_q         = 1'b0;
    assign hwlp_end0_eq_pc         = 1'b0;
    assign hwlp_end1_eq_pc         = 1'b0;
    assign hwlp_counter0_gt_1      = 1'b0;
    assign hwlp_counter1_gt_1      = 1'b0;
    assign hwlp_counter0_eq_1      = 1'b0;
    assign hwlp_counter1_eq_1      = 1'b0;
    assign hwlp_counter0_eq_0      = 1'b0;
    assign hwlp_counter1_eq_0      = 1'b0;
    assign hwlp_end0_eq_pc_plus4   = 1'b0;
    assign hwlp_end1_eq_pc_plus4   = 1'b0;
    assign hwlp_start0_leq_pc      = 1'b0;
    assign hwlp_start1_leq_pc      = 1'b0;
    assign hwlp_end0_geq_pc        = 1'b0;
    assign hwlp_end1_geq_pc        = 1'b0;
    assign is_hwlp_body            = 1'b0;

  end

endgenerate

  /////////////////////////////////////////////////////////////
  //  ____  _        _ _    ____            _             _  //
  // / ___|| |_ __ _| | |  / ___|___  _ __ | |_ _ __ ___ | | //
  // \___ \| __/ _` | | | | |   / _ \| '_ \| __| '__/ _ \| | //
  //  ___) | || (_| | | | | |__| (_) | | | | |_| | | (_) | | //
  // |____/ \__\__,_|_|_|  \____\___/|_| |_|\__|_|  \___/|_| //
  //                                                         //
  /////////////////////////////////////////////////////////////
  always_comb
  begin
    load_stall_o   = 1'b0;
    deassert_we_o  = 1'b0;

    // deassert WE when the core is not decoding instructions
    if (~is_decoding_o)
      deassert_we_o = 1'b1;

    // deassert WE in case of illegal instruction
    if (illegal_insn_i)
      deassert_we_o = 1'b1;

    // Stall because of load operation
    if (
          ( (data_req_ex_i == 1'b1) && (regfile_we_ex_i == 1'b1) ||
           (wb_ready_i == 1'b0) && (regfile_we_wb_i == 1'b1)
          ) &&
          ( (reg_d_ex_is_reg_a_i == 1'b1) || (reg_d_ex_is_reg_b_i == 1'b1) || (reg_d_ex_is_reg_c_i == 1'b1) ||
            (is_decoding_o && (regfile_we_id_i && !data_misaligned_i) && (regfile_waddr_ex_i == regfile_alu_waddr_id_i)) )
       )
    begin
      deassert_we_o   = 1'b1;
      load_stall_o    = 1'b1;
    end

    // Stall because of jr path
    // - always stall if a result is to be forwarded to the PC
    // we don't care about in which state the ctrl_fsm is as we deassert_we
    // anyway when we are not in DECODE
    if ((ctrl_transfer_insn_in_dec_i == BRANCH_JALR) &&
        (((regfile_we_wb_i == 1'b1) && (reg_d_wb_is_reg_a_i == 1'b1)) ||
         ((regfile_we_ex_i == 1'b1) && (reg_d_ex_is_reg_a_i == 1'b1)) ||
         ((regfile_alu_we_fw_i == 1'b1) && (reg_d_alu_is_reg_a_i == 1'b1)) ||
         ((FPU == 1) && (apu_read_dep_for_jalr_i == 1'b1))

        )
       )
    begin
      jr_stall_o      = 1'b1;
      deassert_we_o   = 1'b1;
    end
    else
    begin
      jr_stall_o     = 1'b0;
    end
  end


  // stall because of misaligned data access
  assign misaligned_stall_o = data_misaligned_i;

  // APU dependency stalls (data hazards)
  assign apu_stall_o = apu_read_dep_i | (apu_write_dep_i & ~apu_en_i);

  // Forwarding control unit
  always_comb
  begin
    // default assignements
    operand_a_fw_mux_sel_o = SEL_REGFILE;
    operand_b_fw_mux_sel_o = SEL_REGFILE;
    operand_c_fw_mux_sel_o = SEL_REGFILE;

    // Forwarding WB -> ID
    if (regfile_we_wb_i == 1'b1)
    begin
      if (reg_d_wb_is_reg_a_i == 1'b1)
        operand_a_fw_mux_sel_o = SEL_FW_WB;
      if (reg_d_wb_is_reg_b_i == 1'b1)
        operand_b_fw_mux_sel_o = SEL_FW_WB;
      if (reg_d_wb_is_reg_c_i == 1'b1)
        operand_c_fw_mux_sel_o = SEL_FW_WB;
    end

    // Forwarding EX -> ID
    if (regfile_alu_we_fw_i == 1'b1)
    begin
     if (reg_d_alu_is_reg_a_i == 1'b1)
       operand_a_fw_mux_sel_o = SEL_FW_EX;
     if (reg_d_alu_is_reg_b_i == 1'b1)
       operand_b_fw_mux_sel_o = SEL_FW_EX;
     if (reg_d_alu_is_reg_c_i == 1'b1)
       operand_c_fw_mux_sel_o = SEL_FW_EX;
    end

    // for misaligned memory accesses
    if (data_misaligned_i)
    begin
      operand_a_fw_mux_sel_o  = SEL_FW_EX;
      operand_b_fw_mux_sel_o  = SEL_REGFILE;
    end else if (mult_multicycle_i) begin
      operand_c_fw_mux_sel_o  = SEL_FW_EX;
    end
  end

  // update registers
  always_ff @(posedge clk , negedge rst_n)
  begin : UPDATE_REGS
    if ( rst_n == 1'b0 )
    begin
      ctrl_fsm_cs        <= RESET;
      jump_done_q        <= 1'b0;
      data_err_q         <= 1'b0;

      debug_mode_q       <= 1'b0;
      illegal_insn_q     <= 1'b0;

      debug_req_entry_q  <= 1'b0;
      debug_force_wakeup_q <= 1'b0;
    end
    else
    begin
      ctrl_fsm_cs        <= ctrl_fsm_ns;

      // clear when id is valid (no instruction incoming)
      jump_done_q        <= jump_done & (~id_ready_i);

      data_err_q         <= data_err_i;

      debug_mode_q       <= debug_mode_n;

      illegal_insn_q     <= illegal_insn_n;

      debug_req_entry_q  <= debug_req_entry_n;
      debug_force_wakeup_q <= debug_force_wakeup_n;
    end
  end

  // wakeup from sleep conditions
  assign wake_from_sleep_o = irq_wu_ctrl_i || debug_req_pending || debug_mode_q;

  // debug mode
  assign debug_mode_o = debug_mode_q;
  assign debug_req_pending = debug_req_i || debug_req_q;

  // Do not let cv.elw cause core_sleep_o during debug
  assign debug_p_elw_no_sleep_o = debug_mode_q || debug_req_q || debug_single_step_i || trigger_match_i;

  // Do not let WFI cause core_sleep_o (but treat as NOP):
  //
  // - During debug
  // - For PULP Cluster (only cv.elw can trigger sleep)

  assign debug_wfi_no_sleep_o = debug_mode_q || debug_req_pending || debug_single_step_i || trigger_match_i || COREV_CLUSTER;

  // Gate off wfi 
  assign wfi_active = wfi_i & ~debug_wfi_no_sleep_o;

  // sticky version of debug_req (must be on clk_ungated_i such that incoming pulse before core is enabled is not missed)
  always_ff @(posedge clk_ungated_i, negedge rst_n)
    if ( !rst_n )
      debug_req_q <= 1'b0;
    else
      if( debug_req_i )
        debug_req_q <= 1'b1;
      else if( debug_mode_q )
        debug_req_q <= 1'b0;

  // Debug state FSM
  always_ff @(posedge clk , negedge rst_n)
  begin
    if ( rst_n == 1'b0 )
    begin
      debug_fsm_cs <= HAVERESET;
    end
    else
    begin
      debug_fsm_cs <= debug_fsm_ns;
    end
  end

  always_comb
  begin
    debug_fsm_ns = debug_fsm_cs;

    case (debug_fsm_cs)
      HAVERESET:
      begin
        if (debug_mode_n || (ctrl_fsm_ns == FIRST_FETCH)) begin
          if (debug_mode_n) begin
            debug_fsm_ns = HALTED;
          end else begin
            debug_fsm_ns = RUNNING;
          end
        end
      end

      RUNNING:
      begin
        if (debug_mode_n) begin
          debug_fsm_ns = HALTED;
        end
      end

      HALTED:
      begin
        if (!debug_mode_n) begin
          debug_fsm_ns = RUNNING;
        end
      end

      default: begin
        debug_fsm_ns = HAVERESET;
      end
    endcase
  end

  assign debug_havereset_o = debug_fsm_cs[HAVERESET_INDEX];
  assign debug_running_o = debug_fsm_cs[RUNNING_INDEX];
  assign debug_halted_o = debug_fsm_cs[HALTED_INDEX];

  //----------------------------------------------------------------------------
  // Assertions
  //----------------------------------------------------------------------------

`ifdef CV32E40P_ASSERT_ON

  // make sure that taken branches do not happen back-to-back, as this is not
  // possible without branch prediction in the IF stage
  assert property (
    @(posedge clk) (branch_taken_ex_i) |=> (~branch_taken_ex_i) ) else $warning("Two branches back-to-back are taken");

  // ELW_EXE and IRQ_FLUSH_ELW states are only used for COREV_CLUSTER = 1
  property p_pulp_cluster_only_states;
     @(posedge clk) (1'b1) |-> ( !((COREV_CLUSTER == 1'b0) && ((ctrl_fsm_cs == ELW_EXE) || (ctrl_fsm_cs == IRQ_FLUSH_ELW))) );
  endproperty

  a_pulp_cluster_only_states : assert property(p_pulp_cluster_only_states);

  // WAIT_SLEEP and SLEEP states are never used for COREV_CLUSTER = 1
  property p_pulp_cluster_excluded_states;
     @(posedge clk) (1'b1) |-> ( !((COREV_CLUSTER == 1'b1) && ((ctrl_fsm_cs == SLEEP) || (ctrl_fsm_cs == WAIT_SLEEP))) );
  endproperty

  a_pulp_cluster_excluded_states : assert property(p_pulp_cluster_excluded_states);

  generate
  if (COREV_PULP) begin : gen_pulp_xpulp_assertions

    // HWLoop 0 and 1 having target address constraints
    property p_hwlp_same_target_address;
       @(posedge clk) (hwlp_counter_i[1] > 1 && hwlp_counter_i[0] > 1 && pc_id_i >= hwlp_start_addr_i[0] && pc_id_i <= hwlp_end_addr_i[0] - 4) |-> ( hwlp_end_addr_i[1] - 4 >= hwlp_end_addr_i[0] - 4 + 8 );
    endproperty

    a_hwlp_same_target_address : assert property(p_hwlp_same_target_address) else $warning("%t, HWLoops target address do not respect constraints", $time);

  end else begin : gen_no_pulp_xpulp_assertions

    property p_no_hwlp;
       @(posedge clk) (1'b1) |-> ((pc_mux_o != PC_HWLOOP) && (ctrl_fsm_cs != DECODE_HWLOOP) &&
                                  (hwlp_mask_o == 1'b0) && (is_hwlp_body == 'b0) &&
                                  (hwlp_start_addr_i == 'b0) && (hwlp_end_addr_i == 'b0) && (hwlp_counter_i[1] == 32'b0) && (hwlp_counter_i[0] == 32'b0) &&
                                  (hwlp_dec_cnt_o == 2'b0) && (hwlp_jump_o == 1'b0) && (hwlp_targ_addr_o == 32'b0) &&
                                  (hwlp_end0_eq_pc == 1'b0) && (hwlp_end1_eq_pc == 1'b0) && (hwlp_counter0_gt_1 == 1'b0) && (hwlp_counter1_gt_1 == 1'b0) &&
                                  (hwlp_counter0_eq_1 == 1'b0) && (hwlp_counter1_eq_1 == 1'b0) &&
                                  (hwlp_end0_eq_pc_plus4 == 1'b0) && (hwlp_end1_eq_pc_plus4 == 1'b0) && (hwlp_start0_leq_pc == 0) && (hwlp_start1_leq_pc == 0) &&
                                  (hwlp_end0_geq_pc == 1'b0) && (hwlp_end1_geq_pc == 1'b0) && (hwlp_end_4_id_d == 1'b0) && (hwlp_end_4_id_q == 1'b0));
    endproperty

    a_no_hwlp : assert property(p_no_hwlp);

  end
  endgenerate

  // Ensure DBG_TAKEN_IF can only be enterred if in single step mode or woken
  // up from sleep by debug_req_i
         
  a_single_step_dbg_taken_if : assert property (@(posedge clk)  disable iff (!rst_n)  (ctrl_fsm_ns==DBG_TAKEN_IF) |-> ((~debug_mode_q && debug_single_step_i) || debug_force_wakeup_n));

  // Ensure DBG_FLUSH state is only one cycle. This implies that cause is either trigger, debug_req_entry, or ebreak
  a_dbg_flush : assert property (@(posedge clk)  disable iff (!rst_n)  (ctrl_fsm_cs==DBG_FLUSH) |-> (ctrl_fsm_ns!=DBG_FLUSH) );

  // Ensure that debug state outputs are one-hot
  a_debug_state_onehot : assert property (@(posedge clk) $onehot({debug_havereset_o, debug_running_o, debug_halted_o}));

  // Ensure that debug_halted_o equals debug_mode_q
  a_debug_halted_equals_debug_mode : assert property (@(posedge clk) disable iff (!rst_n) (1'b1) |-> (debug_mode_q == debug_halted_o));

  // Ensure ID always ready in FIRST_FETCH state
  a_first_fetch_id_ready : assert property (@(posedge clk) disable iff (!rst_n) (ctrl_fsm_cs == FIRST_FETCH) |-> (id_ready_i == 1'b1));

  // Ensure that the only way to get to DBG_TAKEN_IF from DBG_FLUSH is if debug_single_step_i is asserted
  a_dbg_flush_to_taken_if : assert property (@(posedge clk) disable iff (!rst_n) (ctrl_fsm_cs == DBG_FLUSH) && (ctrl_fsm_ns == DBG_TAKEN_IF) |-> debug_single_step_i);

`endif

endmodule // cv32e40p_controller
