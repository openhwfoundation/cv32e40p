..
   Copyright 2024 OpenHW Group and Dolphin Design
   SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
  
   Licensed under the Solderpad Hardware License v 2.1 (the "License");
   you may not use this file except in compliance with the License, or,
   at your option, the Apache License version 2.0.
   You may obtain a copy of the License at
  
   https://solderpad.org/licenses/SHL-2.1/
  
   Unless required by applicable law or agreed to in writing, any work
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

.. _pipeline-details:

Pipeline Details
================

.. figure:: ../images/CV32E40P_Pipeline.png
   :name: cv32e40p-pipeline
   :align: center

   CV32E40P Pipeline

CV32E40P has a 4-stage in-order completion pipeline, the 4 stages are:

Instruction Fetch (IF)
  Fetches instructions from memory via an aligning prefetch buffer, capable of fetching 1 instruction per cycle if the instruction side memory system allows. This prefetch buffer is able to store 2 32-b data.
  The IF stage also pre-decodes RVC instructions into RV32I base instructions. See :ref:`instruction-fetch` for details.

Instruction Decode (ID)
  Decodes fetched instruction and performs required register file reads. Jumps are taken from the ID stage.

Execute (EX)
  Executes the instructions. The EX stage contains the ALU, Multiplier and Divider. Branches (with their condition met) are taken from the EX stage. Multi-cycle instructions will stall this stage until they are complete.
  The ALU, Multiplier and Divider instructions write back their result to the register file from the EX stage. The address generation part of the load-store-unit (LSU) is contained in EX as well.
  
  The FPU writes back its result at EX stage as well through this ALU/Mult/Div register file write port when FPU_*_LAT is either 0 cycle or greater than 1 cycle.
  When FPU_*_LAT > 1, FPU write-back has the highest priority so it will stall EX stage if there is a conflict. There are few exceptions to this FPU priority over ALU/Mult/Div.
  
  They are:

  * There is a multi-cycle MULH in EX.
  * There is a Misaligned LOAD/STORE in EX.
  * There is a Post-Increment LOAD/STORE in EX.

  In those 3 exceptions, EX will not be stalled, FPU result (and flags) are memorized and will be written back in the register file (and FPU CSR) as soon as there is no conflict anymore.

Writeback (WB)
  Writes the result of Load instructions back to the register file.
  
  The FPU writes back its result from WB stage as well when FPU_*_LAT is 1 cycle. It is reusing register file LSU write port but LSU has the highest priority over FPU if there is a conflict.

Hazards
-------

There is a forwarding path betwen ALU, Multiplier and Divider result in EX stage and ID stage flip-flops to avoid the need of a write-through register file.
This allows to have 0-cycle penalty between those instructions and immediately following one when using result.
This is the same with 0-cycle latency FPU instructions.

But the CV32E40P experiences a 1-cycle penalty on the following hazards:

 * Load data hazard in case the instruction immediately following a load uses the result of that load
 * Jump register (jalr) data hazard in case that a jalr depends on the result of an immediately preceding instruction
 * FPU data hazard when FPU_*_LAT = 1 in case the instruction immediately following a FPU one (except FDIV/FSQRT) uses the result of the FPU

More than 1-cycle penalty will happen when:

 * FPU data hazard of FPU_*_LAT cycles (FPU_*_LAT > 1) in case the instruction immediately following a FPU one (except FDIV/FSQRT) uses the result of the FPU
 * FPU data hazard in case the instruction immediately following FDIV/FSQRT uses the result of those instructions


Those cycles penalty can be hidden if the compiler is able to add instructions between the instructions causing this data hazard.

Single- and Multi-Cycle Instructions
------------------------------------

:numref:`Cycle counts per instruction type` shows the cycle count per instruction type. Some instructions have a variable time, this is indicated as a range e.g. 1..32 means that the instruction takes a minimum of 1 cycle and a maximum of 32 cycles.
The cycle counts assume zero stall on the instruction-side interface and zero stall on the data-side memory interface.

.. _instructions_latency_table:
.. table:: Cycle counts per instruction type
  :name: Cycle counts per instruction type
  :widths: 20 30 50
  :class: no-scrollbar-table

  +------------------------+--------------------------------------+-------------------------------------------------------------+
  |  **Instruction Type**  |               **Cycles**             |                       **Description**                       |
  +========================+======================================+=============================================================+
  | Integer                | 1                                    | Integer Computational Instructions are defined in the       |
  |                        |                                      | RISCV-V RV32I Base Integer Instruction Set.                 |
  | Computational          |                                      |                                                             |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | Multiplication         | 1 (mul)                              | CV32E40P uses a single-cycle 32-bit x 32-bit multiplier     |
  |                        |                                      | with a 32-bit result. The multiplications with upper-word   |
  |                        | 5 (mulh, mulhsu, mulhu)              | result take 5 cycles to compute.                            |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | Division               | 3..35                                | The number of cycles depends on the divider operand value   |
  |                        |                                      | (operand b), i.e. in the number of leading bits at 0.       |
  | Remainder              | 3..35                                | The minimum number of cycles is 3 when the divider has zero |
  |                        |                                      | leading bits at 0 (e.g., 0x8000000).                        |
  |                        |                                      | The maximum number of cycles is 35 when the divider is 0.   |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | Load/Store             | 1                                    | Load/Store is handled in 1 bus transaction using both EX    |
  |                        |                                      | and WB stages for 1 cycle each. For misaligned word         |
  |                        | 2 (non-word aligned word             | transfers and for halfword transfers that cross a word      |
  |                        | transfer)                            | boundary 2 bus transactions are performed using EX and WB   |
  |                        |                                      | stages for 2 cycles each.                                   |
  |                        | 2 (halfword transfer crossing        | A **cv.elw** takes 4 cycles.                                |
  |                        | word boundary)                       |                                                             |
  |                        |                                      |                                                             |
  |                        | 4 (cv.elw)                           |                                                             |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | Jump                   | 2                                    | Jumps are performed in the ID stage. Upon a jump the IF     |
  |                        |                                      | stage (including prefetch buffer) is flushed. The new PC    |
  |                        | 3 (target is a non-word-aligned      | request will appear on the instruction-side memory          |
  |                        | non-RVC instruction)                 | interface the same cycle the jump instruction is in the ID  |
  |                        |                                      | stage.                                                      |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | Branch                 | 1                                    | Any branch where the condition is not met will              |
  |                        |                                      | not stall.                                                  |
  | (Not-Taken)            |                                      |                                                             |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | Branch                 | 3                                    | The EX stage is used to compute the branch decision. Any    |
  |                        |                                      | branch where the condition is met will be taken from  the   |
  | (Taken)                | 4 (target is a non-word-aligned      | EX stage and will cause a flush of the IF stage (including  |
  |                        | non-RVC instruction)                 | prefetch buffer) and ID stage.                              |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | CSR Access             | 4 (mstatus, mepc, mtvec, mcause,     | CSR Access Instruction are defined in 'Zicsr' of the        |
  |                        | mcycle, minstret, mhpmcounter*,      | RISC-V specification.                                       |
  |                        | mcycleh, minstreth, mhpmcounter*h,   |                                                             |
  |                        | mcountinhibit, mhpmevent*, dscr,     |                                                             |
  |                        | dpc, dscratch0, dscratch1)           |                                                             |
  |                        |                                      |                                                             |
  |                        | 1 (all the other CSRs)               |                                                             |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | Instruction Fence      | 2                                    | The FENCE.I instruction as defined in 'Zifencei' of the     |
  |                        |                                      | RISC-V specification. Internally it is implemented as a     |
  |                        | 3 (target is a non-word-aligned      | jump to the instruction following the fence. The jump       |
  |                        | non-RVC instruction)                 | performs the required flushing as described above.          |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | Floating-Point         | 1..FPU_ADDMUL_LAT + 1                | Independent instructions with the same latency can start    |
  | Addition or            |                                      | each cycle when FPU_ADDMUL_LAT is 0 or 1. With              |
  | Multiplication         |                                      | FPU_ADDMUL_LAT >= 2, subsequent FPU instructions wait for   |
  |                        |                                      | completion.                                                 |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | Floating-Point         | 1..FPU_OTHERS_LAT + 1                | Independent instructions with the same latency can start    |
  | Comparison, Conversion |                                      | each cycle when FPU_OTHERS_LAT is 0 or 1. With              |
  | or Classify            |                                      | FPU_OTHERS_LAT >= 2, subsequent FPU instructions wait for   |
  |                        |                                      | completion.                                                 |
  +------------------------+--------------------------------------+-------------------------------------------------------------+
  | Single Precision       | 1..19                                | FDIV.S and FSQRT.S are not pipelined. Subsequent FPU        |
  | Floating-Point         |                                      | instructions wait for completion. Their cycle counts depend |
  | Division and           |                                      | on the operand values.                                      |
  | Square-Root            |                                      |                                                             |
  +------------------------+--------------------------------------+-------------------------------------------------------------+

These FPU issue limits apply even when consecutive instructions use different registers.
Independent integer instructions can execute while an FPU result is pending.
Instructions that use the result must wait for it. Switching between FPU instruction
latencies can also introduce additional stalls.
