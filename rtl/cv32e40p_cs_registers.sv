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
// Engineer:       Sven Stucki - svstucki@student.ethz.ch                     //
//                                                                            //
// Additional contributions by:                                               //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Andrea Bettati - andrea.bettati@studenti.unipr.it          //
//                                                                            //
// Design Name:    Control and Status Registers                               //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Control and Status Registers (CSRs) loosely following the  //
//                 RiscV draft priviledged instruction set spec (v1.9)        //
//                 Added Floating point support                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_cs_registers
  import cv32e40p_pkg::*;
#(
    parameter N_HWLP           = 2,
    parameter APU              = 0,
    parameter A_EXTENSION      = 0,
    parameter FPU              = 0,
    parameter ZFINX            = 0,
    parameter PULP_SECURE      = 0,
    parameter USE_PMP          = 0,
    parameter N_PMP_ENTRIES    = 16,
    parameter NUM_MHPMCOUNTERS = 1,
    parameter COREV_PULP       = 0,
    parameter COREV_CLUSTER    = 0,
    parameter DEBUG_TRIGGER_EN = 1
) (
    // Clock and Reset
    input logic clk,
    input logic rst_n,

    // Hart ID
    input  logic [31:0] hart_id_i,
    output logic [23:0] mtvec_o,
    output logic [23:0] utvec_o,
    output logic [ 1:0] mtvec_mode_o,
    output logic [ 1:0] utvec_mode_o,

    // Used for mtvec address
    input logic [31:0] mtvec_addr_i,
    input logic        csr_mtvec_init_i,

    // Interface to registers (SRAM like)
    input  csr_num_e           csr_addr_i,
    input  logic        [31:0] csr_wdata_i,
    input  csr_opcode_e        csr_op_i,
    output logic        [31:0] csr_rdata_o,

    output logic               fs_off_o,
    output logic [        2:0] frm_o,
    input  logic [C_FFLAG-1:0] fflags_i,
    input  logic               fflags_we_i,
    input  logic               fregs_we_i,

    // Interrupts
    output logic [31:0] mie_bypass_o,
    input  logic [31:0] mip_i,
    output logic        m_irq_enable_o,
    output logic        u_irq_enable_o,

    //csr_irq_sec_i is always 0 if PULP_SECURE is zero
    input  logic        csr_irq_sec_i,
    output logic        sec_lvl_o,
    output logic [31:0] mepc_o,
    output logic [31:0] uepc_o,
    //mcounteren_o is always 0 if PULP_SECURE is zero
    output logic [31:0] mcounteren_o,

    // debug
    input  logic        debug_mode_i,
    input  logic [ 2:0] debug_cause_i,
    input  logic        debug_csr_save_i,
    output logic [31:0] depc_o,
    output logic        debug_single_step_o,
    output logic        debug_ebreakm_o,
    output logic        debug_ebreaku_o,
    output logic        trigger_match_o,


    output logic [N_PMP_ENTRIES-1:0][31:0] pmp_addr_o,
    output logic [N_PMP_ENTRIES-1:0][ 7:0] pmp_cfg_o,

    output PrivLvl_t priv_lvl_o,

    input logic [31:0] pc_if_i,
    input logic [31:0] pc_id_i,
    input logic [31:0] pc_ex_i,

    input logic csr_save_if_i,
    input logic csr_save_id_i,
    input logic csr_save_ex_i,

    input logic csr_restore_mret_i,
    input logic csr_restore_uret_i,

    input logic                    csr_restore_dret_i,
    //coming from controller
    input logic [       5:0]       csr_cause_i,
    //coming from controller
    input logic                    csr_save_cause_i,
    // Hardware loops
    input logic [N_HWLP-1:0][31:0] hwlp_start_i,
    input logic [N_HWLP-1:0][31:0] hwlp_end_i,
    input logic [N_HWLP-1:0][31:0] hwlp_cnt_i,

    // Performance Counters
    input logic mhpmevent_minstret_i,
    input logic mhpmevent_load_i,
    input logic mhpmevent_store_i,
    input logic mhpmevent_jump_i,  // Jump instruction retired (j, jr, jal, jalr)
    input logic mhpmevent_branch_i,  // Branch instruction retired (beq, bne, etc.)
    input logic mhpmevent_branch_taken_i,  // Branch instruction taken
    input logic mhpmevent_compressed_i,
    input logic mhpmevent_jr_stall_i,
    input logic mhpmevent_imiss_i,
    input logic mhpmevent_ld_stall_i,
    input logic mhpmevent_pipe_stall_i,
    input logic apu_typeconflict_i,
    input logic apu_contention_i,
    input logic apu_dep_i,
    input logic apu_wb_i
);

  localparam NUM_HPM_EVENTS = 16;

  localparam MTVEC_MODE = 2'b01;

  localparam MAX_N_PMP_ENTRIES = 16;
  localparam MAX_N_PMP_CFG = 4;
  localparam N_PMP_CFG = N_PMP_ENTRIES % 4 == 0 ? N_PMP_ENTRIES / 4 : N_PMP_ENTRIES / 4 + 1;

  localparam MSTATUS_UIE_BIT = 0;
  localparam MSTATUS_SIE_BIT = 1;
  localparam MSTATUS_MIE_BIT = 3;
  localparam MSTATUS_UPIE_BIT = 4;
  localparam MSTATUS_SPIE_BIT = 5;
  localparam MSTATUS_MPIE_BIT = 7;
  localparam MSTATUS_SPP_BIT = 8;
  localparam MSTATUS_MPP_BIT_LOW = 11;
  localparam MSTATUS_MPP_BIT_HIGH = 12;
  localparam MSTATUS_FS_BIT_LOW = 13;
  localparam MSTATUS_FS_BIT_HIGH = 14;
  localparam MSTATUS_MPRV_BIT = 17;
  localparam MSTATUS_SD_BIT = 31;

  // misa
  localparam logic [1:0] MXL = 2'd1;  // M-XLEN: XLEN in M-Mode for RV32
  localparam logic [31:0] MISA_VALUE = (32'(A_EXTENSION) << 0)  // A - Atomic Instructions extension
  | (1 << 2)  // C - Compressed extension
  | (0 << 3)  // D - Double precision floating-point extension
  | (0 << 4)  // E - RV32E base ISA
  | (32'(FPU == 1 && ZFINX == 0) << 5)  // F - Single precision floating-point extension
  | (1 << 8)  // I - RV32I/64I/128I base ISA
  | (1 << 12)  // M - Integer Multiply/Divide extension
  | (0 << 13)  // N - User level interrupts supported
  | (0 << 18)  // S - Supervisor mode implemented
  | (32'(PULP_SECURE) << 20)  // U - User mode implemented
  | (32'(COREV_PULP || COREV_CLUSTER) << 23)  // X - Non-standard extensions present
  | (32'(MXL) << 30);  // M-XLEN

  // This local parameter when set to 1 makes the Perf Counters not compliant with RISC-V
  // as it does not implement mcycle and minstret
  // but only HPMCOUNTERs (depending on NUM_MHPMCOUNTERS)
  localparam PULP_PERF_COUNTERS = 0;

  typedef struct packed {
    logic [MAX_N_PMP_ENTRIES-1:0][31:0] pmpaddr;
    logic [MAX_N_PMP_CFG-1:0][31:0] pmpcfg_packed;
    logic [MAX_N_PMP_ENTRIES-1:0][7:0] pmpcfg;
  } Pmp_t;

  // CSR update logic
  logic [31:0] csr_wdata_int;
  logic [31:0] csr_rdata_int;
  logic        csr_we_int;

  // FPU 
  logic [C_RM-1:0] frm_q, frm_n;
  logic [C_FFLAG-1:0] fflags_q, fflags_n;
  logic fcsr_update;

  // Interrupt control signals
  logic [31:0] mepc_q, mepc_n;
  logic [31:0] uepc_q, uepc_n;
  // Trigger
  logic [31:0] tmatch_control_rdata;
  logic [31:0] tmatch_value_rdata;
  logic [15:0] tinfo_types;
  // Debug
  Dcsr_t dcsr_q, dcsr_n;
  logic [31:0] depc_q, depc_n;
  logic [31:0] dscratch0_q, dscratch0_n;
  logic [31:0] dscratch1_q, dscratch1_n;
  logic [31:0] mscratch_q, mscratch_n;

  logic [31:0] exception_pc;
  Status_t mstatus_q, mstatus_n;
  logic mstatus_we_int;
  FS_t mstatus_fs_q, mstatus_fs_n;
  FS_t mstatus_fs_fwd;
  logic [5:0] mcause_q, mcause_n;
  logic [5:0] ucause_q, ucause_n;
  logic [23:0] mtvec_n, mtvec_q;
  logic [23:0] utvec_n, utvec_q;
  logic [1:0] mtvec_mode_n, mtvec_mode_q;

  // Forward FS_DIRTY if an older in-flight instruction (e.g. flw in WB) is writing to FPU
  assign mstatus_fs_fwd = (FPU == 1 && ZFINX == 0 && (fregs_we_i || fflags_we_i)) ? FS_DIRTY : mstatus_fs_q;
  logic [1:0] utvec_mode_n, utvec_mode_q;

  logic [31:0] mip;  // Bits are masked according to IRQ_MASK
  logic [31:0] mie_q, mie_n;  // Bits are masked according to IRQ_MASK

  logic [31:0] csr_mie_wdata;
  logic        csr_mie_we;

  logic        is_irq;
  PrivLvl_t priv_lvl_n, priv_lvl_q;
  Pmp_t pmp_reg_q, pmp_reg_n;
  //clock gating for pmp regs
  logic [MAX_N_PMP_ENTRIES-1:0]                        pmpaddr_we;
  logic [MAX_N_PMP_ENTRIES-1:0]                        pmpcfg_we;

  // Performance Counter Signals
  logic [                 31:0][MHPMCOUNTER_WIDTH-1:0] mhpmcounter_q;  // performance counters
  logic [31:0][31:0] mhpmevent_q, mhpmevent_n;  // event enable
  logic [31:0] mcounteren_q, mcounteren_n;  // user mode counter enable
  logic [31:0] mcountinhibit_q, mcountinhibit_n;  // performance counter enable
  logic [NUM_HPM_EVENTS-1:0] hpm_events;  // events for performance counters
  logic [31:0][MHPMCOUNTER_WIDTH-1:0] mhpmcounter_increment;  // increment of mhpmcounter_q
  logic [31:0] mhpmcounter_write_lower;  // write 32 lower bits of mhpmcounter_q
  logic [31:0] mhpmcounter_write_upper;  // write 32 upper bits mhpmcounter_q
  logic [31:0] mhpmcounter_write_increment;  // write increment of mhpmcounter_q

  assign is_irq = csr_cause_i[5];

  // mip CSR
  assign mip = mip_i;

  // mie_n is used instead of mie_q such that a CSR write to the MIE register can
  // affect the instruction immediately following it.

  // MIE CSR operation logic
  always_comb begin
    csr_mie_wdata = csr_wdata_i;
    csr_mie_we    = 1'b1;

    case (csr_op_i)
      CSR_OP_WRITE: csr_mie_wdata = csr_wdata_i;
      CSR_OP_SET:   csr_mie_wdata = csr_wdata_i | mie_q;
      CSR_OP_CLEAR: csr_mie_wdata = (~csr_wdata_i) & mie_q;
      CSR_OP_READ: begin
        csr_mie_wdata = csr_wdata_i;
        csr_mie_we    = 1'b0;
      end
    endcase
  end

  assign mie_bypass_o = ((csr_addr_i == CSR_MIE) && csr_mie_we) ? csr_mie_wdata & IRQ_MASK : mie_q;

  ////////////////////////////////////////////
  //   ____ ____  ____    ____              //
  //  / ___/ ___||  _ \  |  _ \ ___  __ _   //
  // | |   \___ \| |_) | | |_) / _ \/ _` |  //
  // | |___ ___) |  _ <  |  _ <  __/ (_| |  //
  //  \____|____/|_| \_\ |_| \_\___|\__, |  //
  //                                |___/   //
  ////////////////////////////////////////////

  // NOTE!!!: Any new CSR register added in this file must also be
  //   added to the valid CSR register list cv32e40p_decoder.v

  genvar j;


  if (PULP_SECURE == 1) begin : gen_pulp_secure_read_logic
    // read logic
    always_comb begin
      case (csr_addr_i)
        // fcsr: Floating-Point Control and Status Register (frm + fflags).
        CSR_FFLAGS: csr_rdata_int = (FPU == 1) ? {27'b0, fflags_q} : '0;
        CSR_FRM:    csr_rdata_int = (FPU == 1) ? {29'b0, frm_q} : '0;
        CSR_FCSR:   csr_rdata_int = (FPU == 1) ? {24'b0, frm_q, fflags_q} : '0;

        // mstatus
        CSR_MSTATUS:
        csr_rdata_int = {
          14'b0,
          mstatus_q.mprv,
          4'b0,
          mstatus_q.mpp,
          3'b0,
          mstatus_q.mpie,
          2'h0,
          mstatus_q.upie,
          mstatus_q.mie,
          2'h0,
          mstatus_q.uie
        };

        // misa: machine isa register
        CSR_MISA: csr_rdata_int = MISA_VALUE;

        // mie: machine interrupt enable
        CSR_MIE: begin
          csr_rdata_int = mie_q;
        end

        // mtvec: machine trap-handler base address
        CSR_MTVEC: csr_rdata_int = {mtvec_q, 6'h0, mtvec_mode_q};
        // mscratch: machine scratch
        CSR_MSCRATCH: csr_rdata_int = mscratch_q;
        // mepc: exception program counter
        CSR_MEPC: csr_rdata_int = mepc_q;
        // mcause: exception cause
        CSR_MCAUSE: csr_rdata_int = {mcause_q[5], 26'b0, mcause_q[4:0]};
        // mip: interrupt pending
        CSR_MIP: begin
          csr_rdata_int = mip;
        end

        // mhartid: unique hardware thread id
        CSR_MHARTID: csr_rdata_int = hart_id_i;

        // mvendorid: Machine Vendor ID
        CSR_MVENDORID: csr_rdata_int = {MVENDORID_BANK, MVENDORID_OFFSET};

        // marchid: Machine Architecture ID
        CSR_MARCHID: csr_rdata_int = MARCHID;

        // unimplemented, read 0 CSRs
        CSR_MIMPID, CSR_MTVAL: csr_rdata_int = 'b0;

        // mcounteren: Machine Counter-Enable
        CSR_MCOUNTEREN: csr_rdata_int = mcounteren_q;

        CSR_TSELECT, CSR_TDATA3, CSR_MCONTEXT, CSR_SCONTEXT: csr_rdata_int = 'b0;  // Always read 0
        CSR_TDATA1: csr_rdata_int = tmatch_control_rdata;
        CSR_TDATA2: csr_rdata_int = tmatch_value_rdata;
        CSR_TINFO: csr_rdata_int = tinfo_types;

        CSR_DCSR: csr_rdata_int = dcsr_q;  //
        CSR_DPC: csr_rdata_int = depc_q;
        CSR_DSCRATCH0: csr_rdata_int = dscratch0_q;  //
        CSR_DSCRATCH1: csr_rdata_int = dscratch1_q;  //

        // Hardware Performance Monitor
        CSR_MCYCLE,
      CSR_MINSTRET,
      CSR_MHPMCOUNTER3,
      CSR_MHPMCOUNTER4,  CSR_MHPMCOUNTER5,  CSR_MHPMCOUNTER6,  CSR_MHPMCOUNTER7,
      CSR_MHPMCOUNTER8,  CSR_MHPMCOUNTER9,  CSR_MHPMCOUNTER10, CSR_MHPMCOUNTER11,
      CSR_MHPMCOUNTER12, CSR_MHPMCOUNTER13, CSR_MHPMCOUNTER14, CSR_MHPMCOUNTER15,
      CSR_MHPMCOUNTER16, CSR_MHPMCOUNTER17, CSR_MHPMCOUNTER18, CSR_MHPMCOUNTER19,
      CSR_MHPMCOUNTER20, CSR_MHPMCOUNTER21, CSR_MHPMCOUNTER22, CSR_MHPMCOUNTER23,
      CSR_MHPMCOUNTER24, CSR_MHPMCOUNTER25, CSR_MHPMCOUNTER26, CSR_MHPMCOUNTER27,
      CSR_MHPMCOUNTER28, CSR_MHPMCOUNTER29, CSR_MHPMCOUNTER30, CSR_MHPMCOUNTER31,
      CSR_CYCLE,
      CSR_INSTRET,
      CSR_HPMCOUNTER3,
      CSR_HPMCOUNTER4,  CSR_HPMCOUNTER5,  CSR_HPMCOUNTER6,  CSR_HPMCOUNTER7,
      CSR_HPMCOUNTER8,  CSR_HPMCOUNTER9,  CSR_HPMCOUNTER10, CSR_HPMCOUNTER11,
      CSR_HPMCOUNTER12, CSR_HPMCOUNTER13, CSR_HPMCOUNTER14, CSR_HPMCOUNTER15,
      CSR_HPMCOUNTER16, CSR_HPMCOUNTER17, CSR_HPMCOUNTER18, CSR_HPMCOUNTER19,
      CSR_HPMCOUNTER20, CSR_HPMCOUNTER21, CSR_HPMCOUNTER22, CSR_HPMCOUNTER23,
      CSR_HPMCOUNTER24, CSR_HPMCOUNTER25, CSR_HPMCOUNTER26, CSR_HPMCOUNTER27,
      CSR_HPMCOUNTER28, CSR_HPMCOUNTER29, CSR_HPMCOUNTER30, CSR_HPMCOUNTER31:
        csr_rdata_int = mhpmcounter_q[csr_addr_i[4:0]][31:0];

        CSR_MCYCLEH,
      CSR_MINSTRETH,
      CSR_MHPMCOUNTER3H,
      CSR_MHPMCOUNTER4H,  CSR_MHPMCOUNTER5H,  CSR_MHPMCOUNTER6H,  CSR_MHPMCOUNTER7H,
      CSR_MHPMCOUNTER8H,  CSR_MHPMCOUNTER9H,  CSR_MHPMCOUNTER10H, CSR_MHPMCOUNTER11H,
      CSR_MHPMCOUNTER12H, CSR_MHPMCOUNTER13H, CSR_MHPMCOUNTER14H, CSR_MHPMCOUNTER15H,
      CSR_MHPMCOUNTER16H, CSR_MHPMCOUNTER17H, CSR_MHPMCOUNTER18H, CSR_MHPMCOUNTER19H,
      CSR_MHPMCOUNTER20H, CSR_MHPMCOUNTER21H, CSR_MHPMCOUNTER22H, CSR_MHPMCOUNTER23H,
      CSR_MHPMCOUNTER24H, CSR_MHPMCOUNTER25H, CSR_MHPMCOUNTER26H, CSR_MHPMCOUNTER27H,
      CSR_MHPMCOUNTER28H, CSR_MHPMCOUNTER29H, CSR_MHPMCOUNTER30H, CSR_MHPMCOUNTER31H,
      CSR_CYCLEH,
      CSR_INSTRETH,
      CSR_HPMCOUNTER3H,
      CSR_HPMCOUNTER4H,  CSR_HPMCOUNTER5H,  CSR_HPMCOUNTER6H,  CSR_HPMCOUNTER7H,
      CSR_HPMCOUNTER8H,  CSR_HPMCOUNTER9H,  CSR_HPMCOUNTER10H, CSR_HPMCOUNTER11H,
      CSR_HPMCOUNTER12H, CSR_HPMCOUNTER13H, CSR_HPMCOUNTER14H, CSR_HPMCOUNTER15H,
      CSR_HPMCOUNTER16H, CSR_HPMCOUNTER17H, CSR_HPMCOUNTER18H, CSR_HPMCOUNTER19H,
      CSR_HPMCOUNTER20H, CSR_HPMCOUNTER21H, CSR_HPMCOUNTER22H, CSR_HPMCOUNTER23H,
      CSR_HPMCOUNTER24H, CSR_HPMCOUNTER25H, CSR_HPMCOUNTER26H, CSR_HPMCOUNTER27H,
      CSR_HPMCOUNTER28H, CSR_HPMCOUNTER29H, CSR_HPMCOUNTER30H, CSR_HPMCOUNTER31H:
        csr_rdata_int = mhpmcounter_q[csr_addr_i[4:0]][63:32];

        CSR_MCOUNTINHIBIT: csr_rdata_int = mcountinhibit_q;

        CSR_MHPMEVENT3,
      CSR_MHPMEVENT4,  CSR_MHPMEVENT5,  CSR_MHPMEVENT6,  CSR_MHPMEVENT7,
      CSR_MHPMEVENT8,  CSR_MHPMEVENT9,  CSR_MHPMEVENT10, CSR_MHPMEVENT11,
      CSR_MHPMEVENT12, CSR_MHPMEVENT13, CSR_MHPMEVENT14, CSR_MHPMEVENT15,
      CSR_MHPMEVENT16, CSR_MHPMEVENT17, CSR_MHPMEVENT18, CSR_MHPMEVENT19,
      CSR_MHPMEVENT20, CSR_MHPMEVENT21, CSR_MHPMEVENT22, CSR_MHPMEVENT23,
      CSR_MHPMEVENT24, CSR_MHPMEVENT25, CSR_MHPMEVENT26, CSR_MHPMEVENT27,
      CSR_MHPMEVENT28, CSR_MHPMEVENT29, CSR_MHPMEVENT30, CSR_MHPMEVENT31:
        csr_rdata_int = mhpmevent_q[csr_addr_i[4:0]];

        // hardware loops  (not official)
        CSR_LPSTART0: csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_start_i[0];
        CSR_LPEND0:   csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_end_i[0];
        CSR_LPCOUNT0: csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_cnt_i[0];
        CSR_LPSTART1: csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_start_i[1];
        CSR_LPEND1:   csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_end_i[1];
        CSR_LPCOUNT1: csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_cnt_i[1];

        // PMP config registers
        CSR_PMPCFG0: csr_rdata_int = USE_PMP ? pmp_reg_q.pmpcfg_packed[0] : '0;
        CSR_PMPCFG1: csr_rdata_int = USE_PMP ? pmp_reg_q.pmpcfg_packed[1] : '0;
        CSR_PMPCFG2: csr_rdata_int = USE_PMP ? pmp_reg_q.pmpcfg_packed[2] : '0;
        CSR_PMPCFG3: csr_rdata_int = USE_PMP ? pmp_reg_q.pmpcfg_packed[3] : '0;

        CSR_PMPADDR0, CSR_PMPADDR1, CSR_PMPADDR2, CSR_PMPADDR3,
      CSR_PMPADDR4, CSR_PMPADDR5, CSR_PMPADDR6, CSR_PMPADDR7,
      CSR_PMPADDR8, CSR_PMPADDR9, CSR_PMPADDR10, CSR_PMPADDR11,
      CSR_PMPADDR12, CSR_PMPADDR13, CSR_PMPADDR14, CSR_PMPADDR15 :
        csr_rdata_int = USE_PMP ? pmp_reg_q.pmpaddr[csr_addr_i[3:0]] : '0;

        /* USER CSR */
        // ustatus
        CSR_USTATUS: csr_rdata_int = {27'b0, mstatus_q.upie, 3'h0, mstatus_q.uie};
        // utvec: user trap-handler base address
        CSR_UTVEC: csr_rdata_int = {utvec_q, 6'h0, utvec_mode_q};
        // duplicated mhartid: unique hardware thread id (not official)
        CSR_UHARTID: csr_rdata_int = !COREV_PULP ? 'b0 : hart_id_i;
        // uepc: exception program counter
        CSR_UEPC: csr_rdata_int = uepc_q;
        // ucause: exception cause
        CSR_UCAUSE: csr_rdata_int = {ucause_q[5], 26'h0, ucause_q[4:0]};

        // current priv level (not official)
        CSR_PRIVLV: csr_rdata_int = !COREV_PULP ? 'b0 : {30'h0, priv_lvl_q};

        default: csr_rdata_int = '0;
      endcase
    end
  end else begin : gen_no_pulp_secure_read_logic  // PULP_SECURE == 0
    // read logic
    always_comb begin

      case (csr_addr_i)
        // fcsr: Floating-Point Control and Status Register (frm + fflags).
        CSR_FFLAGS: csr_rdata_int = (FPU == 1) ? {27'b0, fflags_q} : '0;
        CSR_FRM: csr_rdata_int = (FPU == 1) ? {29'b0, frm_q} : '0;
        CSR_FCSR: csr_rdata_int = (FPU == 1) ? {24'b0, frm_q, fflags_q} : '0;
        // mstatus: always M-mode, contains IE bit
        CSR_MSTATUS:
        csr_rdata_int = {
          (FPU == 1 && ZFINX == 0) ? (mstatus_fs_fwd == FS_DIRTY ? 1'b1 : 1'b0) : 1'b0,
          13'b0,
          mstatus_q.mprv,
          2'b0,
          (FPU == 1 && ZFINX == 0) ? mstatus_fs_fwd : FS_OFF,
          mstatus_q.mpp,
          3'b0,
          mstatus_q.mpie,
          2'h0,
          mstatus_q.upie,
          mstatus_q.mie,
          2'h0,
          mstatus_q.uie
        };
        // misa: machine isa register
        CSR_MISA: csr_rdata_int = MISA_VALUE;
        // mie: machine interrupt enable
        CSR_MIE: begin
          csr_rdata_int = mie_q;
        end

        // mtvec: machine trap-handler base address
        CSR_MTVEC: csr_rdata_int = {mtvec_q, 6'h0, mtvec_mode_q};
        // mscratch: machine scratch
        CSR_MSCRATCH: csr_rdata_int = mscratch_q;
        // mepc: exception program counter
        CSR_MEPC: csr_rdata_int = mepc_q;
        // mcause: exception cause
        CSR_MCAUSE: csr_rdata_int = {mcause_q[5], 26'b0, mcause_q[4:0]};
        // mip: interrupt pending
        CSR_MIP: begin
          csr_rdata_int = mip;
        end
        // mhartid: unique hardware thread id
        CSR_MHARTID: csr_rdata_int = hart_id_i;

        // mvendorid: Machine Vendor ID
        CSR_MVENDORID: csr_rdata_int = {MVENDORID_BANK, MVENDORID_OFFSET};

        // marchid: Machine Architecture ID
        CSR_MARCHID: csr_rdata_int = MARCHID;

        // mimpid, Machine Implementation ID
        CSR_MIMPID: begin
          csr_rdata_int = (FPU == 1 || COREV_PULP == 1 || COREV_CLUSTER == 1) ? 32'h1 : 'b0;
        end

        // unimplemented, read 0 CSRs
        CSR_MTVAL: csr_rdata_int = 'b0;

        CSR_TSELECT, CSR_TDATA3, CSR_MCONTEXT, CSR_SCONTEXT: csr_rdata_int = 'b0;  // Always read 0
        CSR_TDATA1: csr_rdata_int = tmatch_control_rdata;
        CSR_TDATA2: csr_rdata_int = tmatch_value_rdata;
        CSR_TINFO: csr_rdata_int = tinfo_types;

        CSR_DCSR: csr_rdata_int = dcsr_q;  //
        CSR_DPC: csr_rdata_int = depc_q;
        CSR_DSCRATCH0: csr_rdata_int = dscratch0_q;  //
        CSR_DSCRATCH1: csr_rdata_int = dscratch1_q;  //

        // Hardware Performance Monitor
        CSR_MCYCLE,
      CSR_MINSTRET,
      CSR_MHPMCOUNTER3,
      CSR_MHPMCOUNTER4,  CSR_MHPMCOUNTER5,  CSR_MHPMCOUNTER6,  CSR_MHPMCOUNTER7,
      CSR_MHPMCOUNTER8,  CSR_MHPMCOUNTER9,  CSR_MHPMCOUNTER10, CSR_MHPMCOUNTER11,
      CSR_MHPMCOUNTER12, CSR_MHPMCOUNTER13, CSR_MHPMCOUNTER14, CSR_MHPMCOUNTER15,
      CSR_MHPMCOUNTER16, CSR_MHPMCOUNTER17, CSR_MHPMCOUNTER18, CSR_MHPMCOUNTER19,
      CSR_MHPMCOUNTER20, CSR_MHPMCOUNTER21, CSR_MHPMCOUNTER22, CSR_MHPMCOUNTER23,
      CSR_MHPMCOUNTER24, CSR_MHPMCOUNTER25, CSR_MHPMCOUNTER26, CSR_MHPMCOUNTER27,
      CSR_MHPMCOUNTER28, CSR_MHPMCOUNTER29, CSR_MHPMCOUNTER30, CSR_MHPMCOUNTER31,
      CSR_CYCLE,
      CSR_INSTRET,
      CSR_HPMCOUNTER3,
      CSR_HPMCOUNTER4,  CSR_HPMCOUNTER5,  CSR_HPMCOUNTER6,  CSR_HPMCOUNTER7,
      CSR_HPMCOUNTER8,  CSR_HPMCOUNTER9,  CSR_HPMCOUNTER10, CSR_HPMCOUNTER11,
      CSR_HPMCOUNTER12, CSR_HPMCOUNTER13, CSR_HPMCOUNTER14, CSR_HPMCOUNTER15,
      CSR_HPMCOUNTER16, CSR_HPMCOUNTER17, CSR_HPMCOUNTER18, CSR_HPMCOUNTER19,
      CSR_HPMCOUNTER20, CSR_HPMCOUNTER21, CSR_HPMCOUNTER22, CSR_HPMCOUNTER23,
      CSR_HPMCOUNTER24, CSR_HPMCOUNTER25, CSR_HPMCOUNTER26, CSR_HPMCOUNTER27,
      CSR_HPMCOUNTER28, CSR_HPMCOUNTER29, CSR_HPMCOUNTER30, CSR_HPMCOUNTER31:
        csr_rdata_int = mhpmcounter_q[csr_addr_i[4:0]][31:0];

        CSR_MCYCLEH,
      CSR_MINSTRETH,
      CSR_MHPMCOUNTER3H,
      CSR_MHPMCOUNTER4H,  CSR_MHPMCOUNTER5H,  CSR_MHPMCOUNTER6H,  CSR_MHPMCOUNTER7H,
      CSR_MHPMCOUNTER8H,  CSR_MHPMCOUNTER9H,  CSR_MHPMCOUNTER10H, CSR_MHPMCOUNTER11H,
      CSR_MHPMCOUNTER12H, CSR_MHPMCOUNTER13H, CSR_MHPMCOUNTER14H, CSR_MHPMCOUNTER15H,
      CSR_MHPMCOUNTER16H, CSR_MHPMCOUNTER17H, CSR_MHPMCOUNTER18H, CSR_MHPMCOUNTER19H,
      CSR_MHPMCOUNTER20H, CSR_MHPMCOUNTER21H, CSR_MHPMCOUNTER22H, CSR_MHPMCOUNTER23H,
      CSR_MHPMCOUNTER24H, CSR_MHPMCOUNTER25H, CSR_MHPMCOUNTER26H, CSR_MHPMCOUNTER27H,
      CSR_MHPMCOUNTER28H, CSR_MHPMCOUNTER29H, CSR_MHPMCOUNTER30H, CSR_MHPMCOUNTER31H,
      CSR_CYCLEH,
      CSR_INSTRETH,
      CSR_HPMCOUNTER3H,
      CSR_HPMCOUNTER4H,  CSR_HPMCOUNTER5H,  CSR_HPMCOUNTER6H,  CSR_HPMCOUNTER7H,
      CSR_HPMCOUNTER8H,  CSR_HPMCOUNTER9H,  CSR_HPMCOUNTER10H, CSR_HPMCOUNTER11H,
      CSR_HPMCOUNTER12H, CSR_HPMCOUNTER13H, CSR_HPMCOUNTER14H, CSR_HPMCOUNTER15H,
      CSR_HPMCOUNTER16H, CSR_HPMCOUNTER17H, CSR_HPMCOUNTER18H, CSR_HPMCOUNTER19H,
      CSR_HPMCOUNTER20H, CSR_HPMCOUNTER21H, CSR_HPMCOUNTER22H, CSR_HPMCOUNTER23H,
      CSR_HPMCOUNTER24H, CSR_HPMCOUNTER25H, CSR_HPMCOUNTER26H, CSR_HPMCOUNTER27H,
      CSR_HPMCOUNTER28H, CSR_HPMCOUNTER29H, CSR_HPMCOUNTER30H, CSR_HPMCOUNTER31H:
        csr_rdata_int = (MHPMCOUNTER_WIDTH == 64) ? mhpmcounter_q[csr_addr_i[4:0]][63:32] : '0;

        CSR_MCOUNTINHIBIT: csr_rdata_int = mcountinhibit_q;

        CSR_MHPMEVENT3,
      CSR_MHPMEVENT4,  CSR_MHPMEVENT5,  CSR_MHPMEVENT6,  CSR_MHPMEVENT7,
      CSR_MHPMEVENT8,  CSR_MHPMEVENT9,  CSR_MHPMEVENT10, CSR_MHPMEVENT11,
      CSR_MHPMEVENT12, CSR_MHPMEVENT13, CSR_MHPMEVENT14, CSR_MHPMEVENT15,
      CSR_MHPMEVENT16, CSR_MHPMEVENT17, CSR_MHPMEVENT18, CSR_MHPMEVENT19,
      CSR_MHPMEVENT20, CSR_MHPMEVENT21, CSR_MHPMEVENT22, CSR_MHPMEVENT23,
      CSR_MHPMEVENT24, CSR_MHPMEVENT25, CSR_MHPMEVENT26, CSR_MHPMEVENT27,
      CSR_MHPMEVENT28, CSR_MHPMEVENT29, CSR_MHPMEVENT30, CSR_MHPMEVENT31:
        csr_rdata_int = mhpmevent_q[csr_addr_i[4:0]];

        // hardware loops  (not official)
        CSR_LPSTART0: csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_start_i[0];
        CSR_LPEND0:   csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_end_i[0];
        CSR_LPCOUNT0: csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_cnt_i[0];
        CSR_LPSTART1: csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_start_i[1];
        CSR_LPEND1:   csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_end_i[1];
        CSR_LPCOUNT1: csr_rdata_int = !COREV_PULP ? 'b0 : hwlp_cnt_i[1];

        /* USER CSR */
        // dublicated mhartid: unique hardware thread id (not official)
        CSR_UHARTID: csr_rdata_int = !COREV_PULP ? 'b0 : hart_id_i;
        // current priv level (not official)
        CSR_PRIVLV: csr_rdata_int = !COREV_PULP ? 'b0 : {30'h0, priv_lvl_q};
        // Zfinx (not official)
        CSR_ZFINX: csr_rdata_int = (FPU == 1 && ZFINX == 1) ? 32'h1 : 32'h0;
        default: csr_rdata_int = '0;
      endcase
    end
  end  //PULP_SECURE

  if (PULP_SECURE == 1) begin : gen_pulp_secure_write_logic
    // write logic
    always_comb begin
      fflags_n                = fflags_q;
      frm_n                   = frm_q;
      mscratch_n              = mscratch_q;
      mepc_n                  = mepc_q;
      uepc_n                  = uepc_q;
      depc_n                  = depc_q;
      dcsr_n                  = dcsr_q;
      dscratch0_n             = dscratch0_q;
      dscratch1_n             = dscratch1_q;

      mstatus_n               = mstatus_q;
      mcause_n                = mcause_q;
      ucause_n                = ucause_q;
      exception_pc            = pc_id_i;
      priv_lvl_n              = priv_lvl_q;
      mtvec_n                 = csr_mtvec_init_i ? mtvec_addr_i[31:8] : mtvec_q;
      utvec_n                 = utvec_q;
      mtvec_mode_n            = mtvec_mode_q;
      utvec_mode_n            = utvec_mode_q;
      pmp_reg_n.pmpaddr       = pmp_reg_q.pmpaddr;
      pmp_reg_n.pmpcfg_packed = pmp_reg_q.pmpcfg_packed;
      pmpaddr_we              = '0;
      pmpcfg_we               = '0;

      mie_n                   = mie_q;

      if (FPU == 1) if (fflags_we_i) fflags_n = fflags_i | fflags_q;

      case (csr_addr_i)
        // fcsr: Floating-Point Control and Status Register (frm, fflags, fprec).
        CSR_FFLAGS: if (csr_we_int) fflags_n = (FPU == 1) ? csr_wdata_int[C_FFLAG-1:0] : '0;
        CSR_FRM:    if (csr_we_int) frm_n = (FPU == 1) ? csr_wdata_int[C_RM-1:0] : '0;
        CSR_FCSR:
        if (csr_we_int) begin
          fflags_n = (FPU == 1) ? csr_wdata_int[C_FFLAG-1:0] : '0;
          frm_n    = (FPU == 1) ? csr_wdata_int[C_RM+C_FFLAG-1:C_FFLAG] : '0;
        end

        // mstatus: IE bit
        CSR_MSTATUS:
        if (csr_we_int) begin
          mstatus_n = '{
              uie: csr_wdata_int[MSTATUS_UIE_BIT],
              mie: csr_wdata_int[MSTATUS_MIE_BIT],
              upie: csr_wdata_int[MSTATUS_UPIE_BIT],
              mpie: csr_wdata_int[MSTATUS_MPIE_BIT],
              mpp: PrivLvl_t'(csr_wdata_int[MSTATUS_MPP_BIT_HIGH:MSTATUS_MPP_BIT_LOW]),
              mprv: csr_wdata_int[MSTATUS_MPRV_BIT]
          };
        end
        // mie: machine interrupt enable
        CSR_MIE:
        if (csr_we_int) begin
          mie_n = csr_wdata_int & IRQ_MASK;
        end
        // mtvec: machine trap-handler base address
        CSR_MTVEC:
        if (csr_we_int) begin
          mtvec_n      = csr_wdata_int[31:8];
          mtvec_mode_n = {1'b0, csr_wdata_int[0]};  // Only direct and vectored mode are supported
        end
        // mscratch: machine scratch
        CSR_MSCRATCH:
        if (csr_we_int) begin
          mscratch_n = csr_wdata_int;
        end
        // mepc: exception program counter
        CSR_MEPC:
        if (csr_we_int) begin
          mepc_n = csr_wdata_int & ~32'b1;  // force 16-bit alignment
        end
        // mcause
        CSR_MCAUSE: if (csr_we_int) mcause_n = {csr_wdata_int[31], csr_wdata_int[4:0]};

        // Debug
        CSR_DCSR:
        if (csr_we_int) begin
          // Following are read-only and never assigned here (dcsr_q value is used):
          //
          // - xdebugver
          // - cause
          // - nmip

          dcsr_n.ebreakm = csr_wdata_int[15];
          dcsr_n.ebreaks = 1'b0;  // ebreaks (implemented as WARL)
          dcsr_n.ebreaku = csr_wdata_int[12];
          dcsr_n.stepie = csr_wdata_int[11];  // stepie
          dcsr_n.stopcount = 1'b0;  // stopcount
          dcsr_n.stoptime = 1'b0;  // stoptime
          dcsr_n.mprven = 1'b0;  // mprven
          dcsr_n.step = csr_wdata_int[2];
          dcsr_n.prv       = (PrivLvl_t'(csr_wdata_int[1:0]) == PRIV_LVL_M) ? PRIV_LVL_M : PRIV_LVL_U; // prv (implemented as WARL)
        end

        CSR_DPC:
        if (csr_we_int) begin
          depc_n = csr_wdata_int & ~32'b1;  // force 16-bit alignment
        end

        CSR_DSCRATCH0:
        if (csr_we_int) begin
          dscratch0_n = csr_wdata_int;
        end

        CSR_DSCRATCH1:
        if (csr_we_int) begin
          dscratch1_n = csr_wdata_int;
        end

        // PMP config registers
        CSR_PMPCFG0:
        if (csr_we_int) begin
          pmp_reg_n.pmpcfg_packed[0] = csr_wdata_int;
          pmpcfg_we[3:0] = 4'b1111;
        end
        CSR_PMPCFG1:
        if (csr_we_int) begin
          pmp_reg_n.pmpcfg_packed[1] = csr_wdata_int;
          pmpcfg_we[7:4] = 4'b1111;
        end
        CSR_PMPCFG2:
        if (csr_we_int) begin
          pmp_reg_n.pmpcfg_packed[2] = csr_wdata_int;
          pmpcfg_we[11:8] = 4'b1111;
        end
        CSR_PMPCFG3:
        if (csr_we_int) begin
          pmp_reg_n.pmpcfg_packed[3] = csr_wdata_int;
          pmpcfg_we[15:12] = 4'b1111;
        end

        CSR_PMPADDR0, CSR_PMPADDR1, CSR_PMPADDR2, CSR_PMPADDR3,
      CSR_PMPADDR4, CSR_PMPADDR5, CSR_PMPADDR6, CSR_PMPADDR7,
      CSR_PMPADDR8, CSR_PMPADDR9, CSR_PMPADDR10, CSR_PMPADDR11,
      CSR_PMPADDR12, CSR_PMPADDR13, CSR_PMPADDR14, CSR_PMPADDR15 :
        if (csr_we_int) begin
          pmp_reg_n.pmpaddr[csr_addr_i[3:0]] = csr_wdata_int;
          pmpaddr_we[csr_addr_i[3:0]] = 1'b1;
        end


        /* USER CSR */
        // ucause: exception cause
        CSR_USTATUS:
        if (csr_we_int) begin
          mstatus_n = '{
              uie: csr_wdata_int[MSTATUS_UIE_BIT],
              mie: mstatus_q.mie,
              upie: csr_wdata_int[MSTATUS_UPIE_BIT],
              mpie: mstatus_q.mpie,
              mpp: mstatus_q.mpp,
              mprv: mstatus_q.mprv
          };
        end
        // utvec: user trap-handler base address
        CSR_UTVEC:
        if (csr_we_int) begin
          utvec_n      = csr_wdata_int[31:8];
          utvec_mode_n = {1'b0, csr_wdata_int[0]};  // Only direct and vectored mode are supported
        end
        // uepc: exception program counter
        CSR_UEPC:
        if (csr_we_int) begin
          uepc_n = csr_wdata_int;
        end
        // ucause: exception cause
        CSR_UCAUSE: if (csr_we_int) ucause_n = {csr_wdata_int[31], csr_wdata_int[4:0]};
      endcase

      // exception controller gets priority over other writes
      unique case (1'b1)

        csr_save_cause_i: begin

          unique case (1'b1)
            csr_save_if_i: exception_pc = pc_if_i;
            csr_save_id_i: exception_pc = pc_id_i;
            csr_save_ex_i: exception_pc = pc_ex_i;
            default: ;
          endcase

          unique case (priv_lvl_q)

            PRIV_LVL_U: begin
              if (~is_irq) begin
                //Exceptions, Ecall U --> M
                priv_lvl_n     = PRIV_LVL_M;
                mstatus_n.mpie = mstatus_q.uie;
                mstatus_n.mie  = 1'b0;
                mstatus_n.mpp  = PRIV_LVL_U;
                if (debug_csr_save_i) depc_n = exception_pc;
                else mepc_n = exception_pc;
                mcause_n = csr_cause_i;

              end else begin
                if (~csr_irq_sec_i) begin
                  //U --> U
                  priv_lvl_n     = PRIV_LVL_U;
                  mstatus_n.upie = mstatus_q.uie;
                  mstatus_n.uie  = 1'b0;
                  if (debug_csr_save_i) depc_n = exception_pc;
                  else uepc_n = exception_pc;
                  ucause_n = csr_cause_i;

                end else begin
                  //U --> M
                  priv_lvl_n     = PRIV_LVL_M;
                  mstatus_n.mpie = mstatus_q.uie;
                  mstatus_n.mie  = 1'b0;
                  mstatus_n.mpp  = PRIV_LVL_U;
                  if (debug_csr_save_i) depc_n = exception_pc;
                  else mepc_n = exception_pc;
                  mcause_n = csr_cause_i;
                end
              end
            end  //PRIV_LVL_U

            PRIV_LVL_M: begin
              if (debug_csr_save_i) begin
                // all interrupts are masked, don't update cause, epc, tval dpc
                // and mpstatus
                dcsr_n.prv   = PRIV_LVL_M;
                dcsr_n.cause = debug_cause_i;
                depc_n       = exception_pc;
              end else begin
                //Exceptions or Interrupts from PRIV_LVL_M always do M --> M
                priv_lvl_n     = PRIV_LVL_M;
                mstatus_n.mpie = mstatus_q.mie;
                mstatus_n.mie  = 1'b0;
                mstatus_n.mpp  = PRIV_LVL_M;
                mepc_n         = exception_pc;
                mcause_n       = csr_cause_i;
              end
            end  //PRIV_LVL_M
            default: ;

          endcase

        end  //csr_save_cause_i

        csr_restore_uret_i: begin  //URET
          //mstatus_q.upp is implicitly 0, i.e PRIV_LVL_U
          mstatus_n.uie  = mstatus_q.upie;
          priv_lvl_n     = PRIV_LVL_U;
          mstatus_n.upie = 1'b1;
        end  //csr_restore_uret_i

        csr_restore_mret_i: begin  //MRET
          unique case (mstatus_q.mpp)
            PRIV_LVL_U: begin
              mstatus_n.uie  = mstatus_q.mpie;
              priv_lvl_n     = PRIV_LVL_U;
              mstatus_n.mpie = 1'b1;
              mstatus_n.mpp  = PRIV_LVL_U;
            end
            PRIV_LVL_M: begin
              mstatus_n.mie  = mstatus_q.mpie;
              priv_lvl_n     = PRIV_LVL_M;
              mstatus_n.mpie = 1'b1;
              mstatus_n.mpp  = PRIV_LVL_U;
            end
            default: ;
          endcase
        end  //csr_restore_mret_i


        csr_restore_dret_i: begin  //DRET
          // Restore to the recorded privilege level
          priv_lvl_n = dcsr_q.prv;

        end  //csr_restore_dret_i

        default: ;
      endcase
    end
  end else begin : gen_no_pulp_secure_write_logic  //PULP_SECURE == 0
    // write logic
    always_comb begin
      if (FPU == 1) begin
        fflags_n = fflags_q;
        frm_n = frm_q;
        if (ZFINX == 0) begin
          mstatus_fs_n = mstatus_fs_q;
          fcsr_update  = 1'b0;
        end
      end
      mscratch_n = mscratch_q;
      mepc_n = mepc_q;
      uepc_n = 'b0;  // Not used if PULP_SECURE == 0
      depc_n = depc_q;
      dcsr_n = dcsr_q;
      dscratch0_n = dscratch0_q;
      dscratch1_n = dscratch1_q;

      mstatus_we_int = 1'b0;
      mstatus_n = mstatus_q;
      mcause_n = mcause_q;
      ucause_n = '0;  // Not used if PULP_SECURE == 0
      exception_pc = pc_id_i;
      priv_lvl_n = priv_lvl_q;
      mtvec_n = csr_mtvec_init_i ? mtvec_addr_i[31:8] : mtvec_q;
      utvec_n = '0;  // Not used if PULP_SECURE == 0
      pmp_reg_n.pmpaddr = '0;  // Not used if PULP_SECURE == 0
      pmp_reg_n.pmpcfg_packed = '0;  // Not used if PULP_SECURE == 0
      pmp_reg_n.pmpcfg = '0;  // Not used if PULP_SECURE == 0
      pmpaddr_we = '0;
      pmpcfg_we = '0;

      mie_n = mie_q;
      mtvec_mode_n = mtvec_mode_q;
      utvec_mode_n = '0;  // Not used if PULP_SECURE == 0

      case (csr_addr_i)
        // fcsr: Floating-Point Control and Status Register (frm, fflags, fprec).
        CSR_FFLAGS:
        if (FPU == 1) begin
          if (csr_we_int) begin
            fflags_n = csr_wdata_int[C_FFLAG-1:0];
            if (ZFINX == 0) begin
              fcsr_update = 1'b1;
            end
          end
        end
        CSR_FRM:
        if (FPU == 1) begin
          if (csr_we_int) begin
            frm_n = csr_wdata_int[C_RM-1:0];
            if (ZFINX == 0) begin
              fcsr_update = 1'b1;
            end
          end
        end
        CSR_FCSR:
        if (FPU == 1) begin
          if (csr_we_int) begin
            fflags_n = csr_wdata_int[C_FFLAG-1:0];
            frm_n    = csr_wdata_int[C_RM+C_FFLAG-1:C_FFLAG];
            if (ZFINX == 0) begin
              fcsr_update = 1'b1;
            end
          end
        end

        // mstatus
        CSR_MSTATUS:
        if (csr_we_int) begin
          mstatus_n = '{
              uie: csr_wdata_int[MSTATUS_UIE_BIT],
              mie: csr_wdata_int[MSTATUS_MIE_BIT],
              upie: csr_wdata_int[MSTATUS_UPIE_BIT],
              mpie: csr_wdata_int[MSTATUS_MPIE_BIT],
              mpp: PrivLvl_t'(csr_wdata_int[MSTATUS_MPP_BIT_HIGH:MSTATUS_MPP_BIT_LOW]),
              mprv: csr_wdata_int[MSTATUS_MPRV_BIT]
          };
          if (FPU == 1 && ZFINX == 0) begin
            mstatus_we_int = 1'b1;
            mstatus_fs_n   = FS_t'(csr_wdata_int[MSTATUS_FS_BIT_HIGH:MSTATUS_FS_BIT_LOW]);
          end
        end
        // mie: machine interrupt enable
        CSR_MIE:
        if (csr_we_int) begin
          mie_n = csr_wdata_int & IRQ_MASK;
        end
        // mtvec: machine trap-handler base address
        CSR_MTVEC:
        if (csr_we_int) begin
          mtvec_n      = csr_wdata_int[31:8];
          mtvec_mode_n = {1'b0, csr_wdata_int[0]};  // Only direct and vectored mode are supported
        end
        // mscratch: machine scratch
        CSR_MSCRATCH:
        if (csr_we_int) begin
          mscratch_n = csr_wdata_int;
        end
        // mepc: exception program counter
        CSR_MEPC:
        if (csr_we_int) begin
          mepc_n = csr_wdata_int & ~32'b1;  // force 16-bit alignment
        end
        // mcause
        CSR_MCAUSE: if (csr_we_int) mcause_n = {csr_wdata_int[31], csr_wdata_int[4:0]};

        CSR_DCSR:
        if (csr_we_int) begin
          // Following are read-only and never assigned here (dcsr_q value is used):
          //
          // - xdebugver
          // - cause
          // - nmip

          dcsr_n.ebreakm   = csr_wdata_int[15];
          dcsr_n.ebreaks   = 1'b0;  // ebreaks (implemented as WARL)
          dcsr_n.ebreaku   = 1'b0;  // ebreaku (implemented as WARL)
          dcsr_n.stepie    = csr_wdata_int[11];  // stepie
          dcsr_n.stopcount = 1'b0;  // stopcount
          dcsr_n.stoptime  = 1'b0;  // stoptime
          dcsr_n.mprven    = 1'b0;  // mprven
          dcsr_n.step      = csr_wdata_int[2];
          dcsr_n.prv       = PRIV_LVL_M;  // prv (implemendted as WARL)
        end

        CSR_DPC:
        if (csr_we_int) begin
          depc_n = csr_wdata_int & ~32'b1;  // force 16-bit alignment
        end

        CSR_DSCRATCH0:
        if (csr_we_int) begin
          dscratch0_n = csr_wdata_int;
        end

        CSR_DSCRATCH1:
        if (csr_we_int) begin
          dscratch1_n = csr_wdata_int;
        end

      endcase

      if (FPU == 1) begin
        if (fflags_we_i) begin
          fflags_n = fflags_i | fflags_q;
        end

        if (ZFINX == 0) begin
          // FPU Register File/Flags implicit update or modified by CSR instructions
          if ((fregs_we_i && !(mstatus_we_int && mstatus_fs_n != FS_DIRTY)) || fflags_we_i || fcsr_update) begin
            mstatus_fs_n = FS_DIRTY;
          end
        end
      end

      // exception controller gets priority over other writes
      unique case (1'b1)

        csr_save_cause_i: begin
          unique case (1'b1)
            csr_save_if_i: exception_pc = pc_if_i;
            csr_save_id_i: exception_pc = pc_id_i;
            csr_save_ex_i: exception_pc = pc_ex_i;
            default: ;
          endcase

          if (debug_csr_save_i) begin
            // all interrupts are masked, don't update cause, epc, tval dpc and
            // mpstatus
            dcsr_n.prv   = PRIV_LVL_M;
            dcsr_n.cause = debug_cause_i;
            depc_n       = exception_pc;
          end else begin
            priv_lvl_n     = PRIV_LVL_M;
            mstatus_n.mpie = mstatus_q.mie;
            mstatus_n.mie  = 1'b0;
            mstatus_n.mpp  = PRIV_LVL_M;
            mepc_n         = exception_pc;
            mcause_n       = csr_cause_i;
          end
        end  //csr_save_cause_i

        csr_restore_mret_i: begin  //MRET
          mstatus_n.mie  = mstatus_q.mpie;
          priv_lvl_n     = PRIV_LVL_M;
          mstatus_n.mpie = 1'b1;
          mstatus_n.mpp  = PRIV_LVL_M;
        end  //csr_restore_mret_i

        csr_restore_dret_i: begin  //DRET
          // Restore to the recorded privilege level
          priv_lvl_n = dcsr_q.prv;
        end  //csr_restore_dret_i

        default: ;
      endcase
    end
  end  //PULP_SECURE

  // CSR operation logic
  always_comb begin
    csr_wdata_int = csr_wdata_i;
    csr_we_int    = 1'b1;

    case (csr_op_i)
      CSR_OP_WRITE: csr_wdata_int = csr_wdata_i;
      CSR_OP_SET:   csr_wdata_int = csr_wdata_i | csr_rdata_o;
      CSR_OP_CLEAR: csr_wdata_int = (~csr_wdata_i) & csr_rdata_o;

      CSR_OP_READ: begin
        csr_wdata_int = csr_wdata_i;
        csr_we_int    = 1'b0;
      end
    endcase
  end

  assign csr_rdata_o = csr_rdata_int;

  // directly output some registers
  assign m_irq_enable_o = mstatus_q.mie && !(dcsr_q.step && !dcsr_q.stepie);
  assign u_irq_enable_o = mstatus_q.uie && !(dcsr_q.step && !dcsr_q.stepie);
  assign priv_lvl_o = priv_lvl_q;
  assign sec_lvl_o = priv_lvl_q[0];

  // mstatus_fs_q = FS_OFF, FPU not enabled
  assign fs_off_o = (FPU == 1 && ZFINX == 0) ? (mstatus_fs_q == FS_OFF ? 1'b1 : 1'b0) : 1'b0;
  assign frm_o = (FPU == 1) ? frm_q : '0;

  assign mtvec_o = mtvec_q;
  assign utvec_o = utvec_q;
  assign mtvec_mode_o = mtvec_mode_q;
  assign utvec_mode_o = utvec_mode_q;

  assign mepc_o = mepc_q;
  assign uepc_o = uepc_q;

  assign mcounteren_o = PULP_SECURE ? mcounteren_q : '0;

  assign depc_o = depc_q;

  assign pmp_addr_o = pmp_reg_q.pmpaddr;
  assign pmp_cfg_o = pmp_reg_q.pmpcfg;

  assign debug_single_step_o = dcsr_q.step;
  assign debug_ebreakm_o = dcsr_q.ebreakm;
  assign debug_ebreaku_o = dcsr_q.ebreaku;

  generate
    if (PULP_SECURE == 1) begin : gen_pmp_user

      for (j = 0; j < N_PMP_ENTRIES; j++) begin : CS_PMP_CFG
        assign pmp_reg_n.pmpcfg[j] = pmp_reg_n.pmpcfg_packed[j/4][8*((j%4)+1)-1:8*(j%4)];
        assign pmp_reg_q.pmpcfg_packed[j/4][8*((j%4)+1)-1:8*(j%4)] = pmp_reg_q.pmpcfg[j];
      end

      for (j = 0; j < N_PMP_ENTRIES; j++) begin : CS_PMP_REGS_FF
        always_ff @(posedge clk, negedge rst_n) begin
          if (rst_n == 1'b0) begin
            pmp_reg_q.pmpcfg[j]  <= '0;
            pmp_reg_q.pmpaddr[j] <= '0;
          end else begin
            if (pmpcfg_we[j]) pmp_reg_q.pmpcfg[j] <= USE_PMP ? pmp_reg_n.pmpcfg[j] : '0;
            if (pmpaddr_we[j]) pmp_reg_q.pmpaddr[j] <= USE_PMP ? pmp_reg_n.pmpaddr[j] : '0;
          end
        end
      end  //CS_PMP_REGS_FF

      always_ff @(posedge clk, negedge rst_n) begin
        if (rst_n == 1'b0) begin
          uepc_q       <= '0;
          ucause_q     <= '0;
          utvec_q      <= '0;
          utvec_mode_q <= MTVEC_MODE;
          priv_lvl_q   <= PRIV_LVL_M;
        end else begin
          uepc_q       <= uepc_n;
          ucause_q     <= ucause_n;
          utvec_q      <= utvec_n;
          utvec_mode_q <= utvec_mode_n;
          priv_lvl_q   <= priv_lvl_n;
        end
      end
    end else begin : gen_no_pmp_user
      assign pmp_reg_q    = '0;
      assign uepc_q       = '0;
      assign ucause_q     = '0;
      assign utvec_q      = '0;
      assign utvec_mode_q = '0;
      assign priv_lvl_q   = PRIV_LVL_M;
    end
  endgenerate

  // actual registers
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      if (FPU == 1) begin
        frm_q <= '0;
        fflags_q <= '0;
        if (ZFINX == 0) begin
          mstatus_fs_q <= FS_OFF;
        end
      end
      mstatus_q <= '{
          uie: 1'b0,
          mie: 1'b0,
          upie: 1'b0,
          mpie: 1'b0,
          mpp: PRIV_LVL_M,
          mprv: 1'b0
      };
      mepc_q <= '0;
      mcause_q <= '0;

      depc_q <= '0;
      dcsr_q <= '{
          xdebugver: XDEBUGVER_STD,
          cause: DBG_CAUSE_NONE,  // 3'h0
          prv: PRIV_LVL_M,
          default: '0
      };
      dscratch0_q <= '0;
      dscratch1_q <= '0;
      mscratch_q <= '0;
      mie_q <= '0;
      mtvec_q <= '0;
      mtvec_mode_q <= MTVEC_MODE;
    end else begin
      // update CSRs
      if (FPU == 1) begin
        frm_q    <= frm_n;
        fflags_q <= fflags_n;
        if (ZFINX == 0) begin
          mstatus_fs_q <= mstatus_fs_n;
        end
      end
      if (PULP_SECURE == 1) begin
        mstatus_q <= mstatus_n;
      end else begin
        mstatus_q <= '{
            uie: 1'b0,
            mie: mstatus_n.mie,
            upie: 1'b0,
            mpie: mstatus_n.mpie,
            mpp: PRIV_LVL_M,
            mprv: 1'b0
        };
      end
      mepc_q       <= mepc_n;
      mcause_q     <= mcause_n;
      depc_q       <= depc_n;
      dcsr_q       <= dcsr_n;
      dscratch0_q  <= dscratch0_n;
      dscratch1_q  <= dscratch1_n;
      mscratch_q   <= mscratch_n;
      mie_q        <= mie_n;
      mtvec_q      <= mtvec_n;
      mtvec_mode_q <= mtvec_mode_n;
    end
  end
  ////////////////////////////////////////////////////////////////////////
  //  ____       _                   _____     _                        //
  // |  _ \  ___| |__  _   _  __ _  |_   _| __(_) __ _  __ _  ___ _ __  //
  // | | | |/ _ \ '_ \| | | |/ _` |   | || '__| |/ _` |/ _` |/ _ \ '__| //
  // | |_| |  __/ |_) | |_| | (_| |   | || |  | | (_| | (_| |  __/ |    //
  // |____/ \___|_.__/ \__,_|\__, |   |_||_|  |_|\__, |\__, |\___|_|    //
  //                         |___/               |___/ |___/            //
  ////////////////////////////////////////////////////////////////////////

  if (DEBUG_TRIGGER_EN) begin : gen_trigger_regs
    // Register values
    logic        tmatch_control_exec_q;
    logic [31:0] tmatch_value_q;
    // Write enables
    logic        tmatch_control_we;
    logic        tmatch_value_we;

    // Write select
    assign tmatch_control_we = csr_we_int & debug_mode_i & (csr_addr_i == CSR_TDATA1);
    assign tmatch_value_we   = csr_we_int & debug_mode_i & (csr_addr_i == CSR_TDATA2);


    // Registers
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        tmatch_control_exec_q <= 'b0;
        tmatch_value_q        <= 'b0;
      end else begin
        if (tmatch_control_we) tmatch_control_exec_q <= csr_wdata_int[2];
        if (tmatch_value_we) tmatch_value_q <= csr_wdata_int[31:0];
      end
    end

    // All supported trigger types
    assign tinfo_types = 1 << TTYPE_MCONTROL;

    // Assign read data
    // TDATA0 - only support simple address matching
    assign tmatch_control_rdata = {
      TTYPE_MCONTROL,  // type    : address/data match
      1'b1,  // dmode   : access from D mode only
      6'h00,  // maskmax : exact match only
      1'b0,  // hit     : not supported
      1'b0,  // select  : address match only
      1'b0,  // timing  : match before execution
      2'b00,  // sizelo  : match any access
      4'h1,  // action  : enter debug mode
      1'b0,  // chain   : not supported
      4'h0,  // match   : simple match
      1'b1,  // m       : match in m-mode
      1'b0,  // 0       : zero
      1'b0,  // s       : not supported
      PULP_SECURE == 1,  // u       : match in u-mode
      tmatch_control_exec_q,  // execute : match instruction address
      1'b0,  // store   : not supported
      1'b0
    };  // load    : not supported

    // TDATA1 - address match value only
    assign tmatch_value_rdata = tmatch_value_q;

    // Breakpoint matching
    // We match against the next address, as the breakpoint must be taken before execution
    assign trigger_match_o = tmatch_control_exec_q & (pc_id_i[31:0] == tmatch_value_q[31:0]);

  end else begin : gen_no_trigger_regs
    assign tinfo_types          = 'b0;
    assign tmatch_control_rdata = 'b0;
    assign tmatch_value_rdata   = 'b0;
    assign trigger_match_o      = 'b0;
  end

  /////////////////////////////////////////////////////////////////
  //   ____            __     ____                  _            //
  // |  _ \ ___ _ __ / _|   / ___|___  _   _ _ __ | |_ ___ _ __  //
  // | |_) / _ \ '__| |_   | |   / _ \| | | | '_ \| __/ _ \ '__| //
  // |  __/  __/ |  |  _|  | |__| (_) | |_| | | | | ||  __/ |    //
  // |_|   \___|_|  |_|(_)  \____\___/ \__,_|_| |_|\__\___|_|    //
  //                                                             //
  /////////////////////////////////////////////////////////////////

  // ------------------------
  // Events to count
  assign hpm_events[0] = 1'b1;  // cycle counter
  assign hpm_events[1] = mhpmevent_minstret_i;  // instruction counter
  assign hpm_events[2] = mhpmevent_ld_stall_i;  // nr of load use hazards
  assign hpm_events[3] = mhpmevent_jr_stall_i;  // nr of jump register hazards
  assign hpm_events[4]  = mhpmevent_imiss_i;                             // cycles waiting for instruction fetches, excluding jumps and branches
  assign hpm_events[5] = mhpmevent_load_i;  // nr of loads
  assign hpm_events[6] = mhpmevent_store_i;  // nr of stores
  assign hpm_events[7] = mhpmevent_jump_i;  // nr of jumps (unconditional)
  assign hpm_events[8] = mhpmevent_branch_i;  // nr of branches (conditional)
  assign hpm_events[9] = mhpmevent_branch_taken_i;  // nr of taken branches (conditional)
  assign hpm_events[10] = mhpmevent_compressed_i;  // compressed instruction counter
  assign hpm_events[11] = COREV_CLUSTER ? mhpmevent_pipe_stall_i : 1'b0;  // extra cycles from ELW
  assign hpm_events[12] = !APU ? 1'b0 : apu_typeconflict_i && !apu_dep_i;
  assign hpm_events[13] = !APU ? 1'b0 : apu_contention_i;
  assign hpm_events[14] = !APU ? 1'b0 : apu_dep_i && !apu_contention_i;
  assign hpm_events[15] = !APU ? 1'b0 : apu_wb_i;

  // ------------------------
  // address decoder for performance counter registers
  logic mcounteren_we;
  logic mcountinhibit_we;
  logic mhpmevent_we;

  assign mcounteren_we = csr_we_int & (csr_addr_i == CSR_MCOUNTEREN);
  assign mcountinhibit_we = csr_we_int & (csr_addr_i == CSR_MCOUNTINHIBIT);
  assign mhpmevent_we     = csr_we_int & ( (csr_addr_i == CSR_MHPMEVENT3  )||
                                           (csr_addr_i == CSR_MHPMEVENT4  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT5  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT6  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT7  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT8  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT9  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT10 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT11 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT12 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT13 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT14 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT15 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT16 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT17 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT18 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT19 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT20 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT21 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT22 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT23 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT24 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT25 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT26 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT27 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT28 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT29 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT30 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT31 ) );

  // ------------------------
  // Increment value for performance counters
  genvar incr_gidx;
  generate
    for (incr_gidx = 0; incr_gidx < 32; incr_gidx++) begin : gen_mhpmcounter_increment
      assign mhpmcounter_increment[incr_gidx] = mhpmcounter_q[incr_gidx] + 1;
    end
  endgenerate

  // ------------------------
  // next value for performance counters and control registers
  always_comb begin
    mcounteren_n    = mcounteren_q;
    mcountinhibit_n = mcountinhibit_q;
    mhpmevent_n     = mhpmevent_q;

    // User Mode Enable
    if (PULP_SECURE && mcounteren_we) mcounteren_n = csr_wdata_int;

    // Inhibit Control
    if (mcountinhibit_we) mcountinhibit_n = csr_wdata_int;

    // Event Control
    if (mhpmevent_we) mhpmevent_n[csr_addr_i[4:0]] = csr_wdata_int;
  end

  genvar wcnt_gidx;
  generate
    for (wcnt_gidx = 0; wcnt_gidx < 32; wcnt_gidx++) begin : gen_mhpmcounter_write

      // Write lower counter bits
      assign mhpmcounter_write_lower[wcnt_gidx] = csr_we_int && (csr_addr_i == (CSR_MCYCLE + wcnt_gidx));

      // Write upper counter bits
      assign mhpmcounter_write_upper[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                  csr_we_int && (csr_addr_i == (CSR_MCYCLEH + wcnt_gidx)) && (MHPMCOUNTER_WIDTH == 64);

      // Increment counter
      if (!PULP_PERF_COUNTERS) begin : gen_no_pulp_perf_counters
        if (wcnt_gidx == 0) begin : gen_mhpmcounter_mcycle
          // mcycle = mhpmcounter[0] : count every cycle (if not inhibited)
          assign mhpmcounter_write_increment[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                          !mhpmcounter_write_upper[wcnt_gidx] &&
                                                          !mcountinhibit_q[wcnt_gidx];
        end else if (wcnt_gidx == 2) begin : gen_mhpmcounter_minstret
          // minstret = mhpmcounter[2]  : count every retired instruction (if not inhibited)
          assign mhpmcounter_write_increment[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                          !mhpmcounter_write_upper[wcnt_gidx] &&
                                                          !mcountinhibit_q[wcnt_gidx] &&
                                                          hpm_events[1];
        end else if( (wcnt_gidx>2) && (wcnt_gidx<(NUM_MHPMCOUNTERS+3))) begin : gen_mhpmcounter
          // add +1 if any event is enabled and active
          assign mhpmcounter_write_increment[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                          !mhpmcounter_write_upper[wcnt_gidx] &&
                                                          !mcountinhibit_q[wcnt_gidx] &&
                                                          |(hpm_events & mhpmevent_q[wcnt_gidx][NUM_HPM_EVENTS-1:0]);
        end else begin : gen_mhpmcounter_not_implemented
          assign mhpmcounter_write_increment[wcnt_gidx] = 1'b0;
        end
      end else begin : gen_pulp_perf_counters
        // PULP PERF COUNTERS share all events in one register (not compliant with RISC-V)
        assign mhpmcounter_write_increment[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                        !mhpmcounter_write_upper[wcnt_gidx] &&
                                                        !mcountinhibit_q[wcnt_gidx] &&
                                                        |(hpm_events & mhpmevent_q[wcnt_gidx][NUM_HPM_EVENTS-1:0]);
      end
    end
  endgenerate

  // ------------------------
  // HPM Registers
  //  Counter Registers: mhpcounter_q[]
  genvar cnt_gidx;
  generate
    for (cnt_gidx = 0; cnt_gidx < 32; cnt_gidx++) begin : gen_mhpmcounter
      // mcyclce  is located at index 0
      // there is no counter at index 1
      // minstret is located at index 2
      // Programable HPM counters start at index 3
      if ((cnt_gidx == 1) || (cnt_gidx >= (NUM_MHPMCOUNTERS + 3))) begin : gen_non_implemented
        assign mhpmcounter_q[cnt_gidx] = 'b0;
      end else begin : gen_implemented
        always_ff @(posedge clk, negedge rst_n)
          if (!rst_n) begin
            mhpmcounter_q[cnt_gidx] <= 'b0;
          end else begin
            if (PULP_PERF_COUNTERS && (cnt_gidx == 2 || cnt_gidx == 0)) begin
              mhpmcounter_q[cnt_gidx] <= 'b0;
            end else begin
              if (mhpmcounter_write_lower[cnt_gidx]) begin
                mhpmcounter_q[cnt_gidx][31:0] <= csr_wdata_int;
              end else if (mhpmcounter_write_upper[cnt_gidx]) begin
                mhpmcounter_q[cnt_gidx][63:32] <= csr_wdata_int;
              end else if (mhpmcounter_write_increment[cnt_gidx]) begin
                mhpmcounter_q[cnt_gidx] <= mhpmcounter_increment[cnt_gidx];
              end
            end
          end
      end
    end
  endgenerate

  //  Event Register: mhpevent_q[]
  genvar evt_gidx;
  generate
    for (evt_gidx = 0; evt_gidx < 32; evt_gidx++) begin : gen_mhpmevent
      // programable HPM events start at index3
      if ((evt_gidx < 3) || (evt_gidx >= (NUM_MHPMCOUNTERS + 3))) begin : gen_non_implemented
        assign mhpmevent_q[evt_gidx] = 'b0;
      end else begin : gen_implemented
        if (NUM_HPM_EVENTS < 32) begin : gen_tie_off
          assign mhpmevent_q[evt_gidx][31:NUM_HPM_EVENTS] = 'b0;
        end
        always_ff @(posedge clk, negedge rst_n)
          if (!rst_n) mhpmevent_q[evt_gidx][NUM_HPM_EVENTS-1:0] <= 'b0;
          else
            mhpmevent_q[evt_gidx][NUM_HPM_EVENTS-1:0] <= mhpmevent_n[evt_gidx][NUM_HPM_EVENTS-1:0];
      end
    end
  endgenerate

  //  Enable Regsiter: mcounteren_q
  genvar en_gidx;
  generate
    for (en_gidx = 0; en_gidx < 32; en_gidx++) begin : gen_mcounteren
      if( (PULP_SECURE == 0) ||
          (en_gidx == 1) ||
          (en_gidx >= (NUM_MHPMCOUNTERS+3) ) )
        begin : gen_non_implemented
        assign mcounteren_q[en_gidx] = 'b0;
      end else begin : gen_implemented
        always_ff @(posedge clk, negedge rst_n)
          if (!rst_n) mcounteren_q[en_gidx] <= 'b0;  // default disable
          else mcounteren_q[en_gidx] <= mcounteren_n[en_gidx];
      end
    end
  endgenerate

  //  Inhibit Regsiter: mcountinhibit_q
  //  Note: implemented counters are disabled out of reset to save power
  genvar inh_gidx;
  generate
    for (inh_gidx = 0; inh_gidx < 32; inh_gidx++) begin : gen_mcountinhibit
      if ((inh_gidx == 1) || (inh_gidx >= (NUM_MHPMCOUNTERS + 3))) begin : gen_non_implemented
        assign mcountinhibit_q[inh_gidx] = 'b0;
      end else begin : gen_implemented
        always_ff @(posedge clk, negedge rst_n)
          if (!rst_n) mcountinhibit_q[inh_gidx] <= 'b1;  // default disable
          else mcountinhibit_q[inh_gidx] <= mcountinhibit_n[inh_gidx];
      end
    end
  endgenerate

`ifdef CV32E40P_ASSERT_ON

  //----------------------------------------------------------------------------
  // Assertions
  //----------------------------------------------------------------------------

  // Check that mie_bypass_o equals mie_n
  a_mie_bypass :
  assert property (@(posedge clk) disable iff (!rst_n) (1'b1) |-> (mie_bypass_o == mie_n));

`endif

endmodule
