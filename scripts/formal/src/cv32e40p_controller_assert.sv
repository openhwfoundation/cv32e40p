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
//                                                                                //
// Description:  Assertion for unreachable code in CV32E40P controller            //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

module cv32e40p_controller_assert import cv32e40p_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic data_load_event_i,
    input logic trigger_match_i,
    input logic ebrk_insn_i,
    input logic debug_mode_q,
    input logic debug_req_entry_q,
    input logic ebrk_force_debug_mode,
    input logic debug_force_wakeup_q,
    input logic debug_single_step_i,
    input logic data_err_i,
    input ctrl_state_e ctrl_fsm_cs
);

    property all_true_ctrl_1187_1189_and_1191;
        @(posedge clk_i) disable iff(!rst_ni)
            ((ctrl_fsm_cs == DBG_TAKEN_ID) && ~debug_mode_q) |-> (trigger_match_i | (ebrk_force_debug_mode & ebrk_insn_i) | debug_req_entry_q);
    endproperty

    property all_true_ctrl_1210_and_1212;
        @(posedge clk_i) disable iff(!rst_ni)
            (ctrl_fsm_cs == DBG_TAKEN_IF) |-> (debug_force_wakeup_q | debug_single_step_i);
    endproperty

    property unreachable_ctrl_1241_row_4;
        @(posedge clk_i) disable iff(!rst_ni)
            ((ctrl_fsm_cs == DBG_FLUSH) && !data_err_i) && (~debug_req_entry_q && ~data_load_event_i && ~(ebrk_force_debug_mode & ebrk_insn_i) && ~debug_mode_q) |-> ~trigger_match_i;
    endproperty

    property unreachable_ctrl_1241_row_5;
        @(posedge clk_i) disable iff(!rst_ni)
            ((ctrl_fsm_cs == DBG_FLUSH) && !data_err_i) && (~debug_req_entry_q && ~data_load_event_i && ~(debug_mode_q | trigger_match_i) && ebrk_insn_i) |-> ebrk_force_debug_mode;
    endproperty

    property unreachable_ctrl_1241_row_10;
        @(posedge clk_i) disable iff(!rst_ni)
            ((ctrl_fsm_cs == DBG_FLUSH) && !data_err_i) && (~debug_req_entry_q && ~((debug_mode_q | trigger_match_i) | (ebrk_force_debug_mode & ebrk_insn_i))) |-> !data_load_event_i;
    endproperty

    // Issue #1010: controller line 850 (and 852-887). dcsr.step can only change through dret, which
    // returns to DECODE, or through a CSR write, which flushes the pipeline back to DECODE. In DECODE
    // the single-step check halts before DECODE_HWLOOP can be entered.
    property unreachable_ctrl_850;
        @(posedge clk_i) disable iff(!rst_ni)
            (ctrl_fsm_cs == DECODE_HWLOOP) |-> ~(debug_single_step_i & ~debug_mode_q);
    endproperty

    assert_all_true_ctrl_1187_1189_and_1191: assert property(all_true_ctrl_1187_1189_and_1191);
    assert_all_true_ctrl_1210_and_1212 : assert property(all_true_ctrl_1210_and_1212);
    //This one is inconclusive with questa formal. To avoid long run keep it disabled
     assert_unreachable_ctrl_1241_row_4 : assert property(unreachable_ctrl_1241_row_4);
    assert_unreachable_ctrl_1241_row_5 : assert property(unreachable_ctrl_1241_row_5);
    assert_unreachable_ctrl_1241_row_10: assert property(unreachable_ctrl_1241_row_10);
    assert_unreachable_ctrl_850        : assert property(unreachable_ctrl_850);

endmodule
