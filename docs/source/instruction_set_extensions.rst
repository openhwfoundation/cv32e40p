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

.. _custom-isa-extensions:

CORE-V Instruction Set Custom Extensions
========================================

CV32E40P supports the following CORE-V ISA X Custom Extensions, which can be enabled by setting ``COREV_PULP`` == 1.

 * Post-Increment load and stores, see :ref:`corev_load_store`, invoked in the tool chain with ``-march=rv32i*_xcvmem``.
 * Hardware Loop extension, see :ref:`corev_hardware_loop`, invoked in the tool chain with ``-march=rv32i*_xcvhwlp``.
 * ALU extensions, see :ref:`corev_alu`, which are divided into three sub-extensions:

   * bit manipulation instructions, invoked in the tool chain with ``-march=rv32i*_xcvbitmanip``;
   * miscellaneous ALU instructions, invoked in the tool chain with ``-march=rv32i*_xcvalu``; and
   * immediate branch instructions, invoked in the tool chain with ``-march=rv32i*_xcvbi``.

 * Multiply-Accumulate extensions, see :ref:`corev_multiply_accumulate`, invoked in the tool chain with ``-march=rv32i*_xcvmac``.
 * Single Instruction Multiple Data (aka SIMD) extensions, see :ref:`corev_simd`, invoked in the tool chain with ``-march=rv32i*_xcvsimd``.

Additionally the event load instruction (**cv.elw**) is supported by setting ``COREV_CLUSTER`` == 1, see :ref:`corev_event_load`.
This is a separate ISA extension, invoked in the tool chain with ``-march=rv32i*_xcvelw``.

If not specified, all the operands are signed and immediate values are sign-extended.

To use such instructions, you need to compile your SW with the CORE-V GCC or Clang/LLVM compiler.

.. note::

  Clang/LLVM assembler will be supported by 30 June 2023, with builtin function support by 31 December 2023.

.. _pseudo_instructions:

Pseudo-instructions
-------------------

This specification also includes documentation of some CORE-V pseudo-instructions. Pseudo-instructions are implemented in the assembler
that are similar to a base instruction but provides control information to the assembler as opposed to generating its base instruction.
This makes it easier to program as we gain clarity on the intention of the programmer.

  * 16-Bit x 16-Bit Multiplication pseudo-instructions, see :ref:`corev_16_bit_multiply_pseudo_instructions`.

.. _corev_load_store:

Post-Increment Load & Store Instructions and Register-Register Load & Store Instructions
----------------------------------------------------------------------------------------

Post-Increment load and store instructions perform a load, or a
store, respectively, while at the same time incrementing the address
that was used for the memory access. Since it is a post-incrementing
scheme, the base address is used for the access and the modified address
is written back to the register-file. There are versions of those
instructions that use immediates and those that use registers as
offsets. The base address always comes from a register.

The custom post-increment load & store instructions and register-register
load & store instructions are only supported if ``COREV_PULP`` == 1.

Load operations
^^^^^^^^^^^^^^^

.. note::

  When same register is used as address and destination (rD == rs1) for post-incremented loads,
  loaded data has highest priority over incremented address when writing to this same register.

.. table:: Load operations
  :name: Load operations
  :widths: 30 70
  :class: no-scrollbar-table

  +----------------------------------------------------+-------------------------------+
  | **Mnemonic**                                       | **Description**               |
  +====================================================+===============================+
  | **Register-Immediate Loads with Post-Increment**                                   |
  +----------------------------------------------------+-------------------------------+
  | **cv.lb rD, (rs1), Imm**                           | rD = Sext(Mem8(rs1))          |
  |                                                    |                               |
  |                                                    | rs1 += Sext(Imm[11:0])        |
  +----------------------------------------------------+-------------------------------+
  | **cv.lbu rD, (rs1), Imm**                          | rD = Zext(Mem8(rs1))          |
  |                                                    |                               |
  |                                                    | rs1 += Sext(Imm[11:0])        |
  +----------------------------------------------------+-------------------------------+
  | **cv.lh rD, (rs1), Imm**                           | rD = Sext(Mem16(rs1))         |
  |                                                    |                               |
  |                                                    | rs1 += Sext(Imm[11:0])        |
  +----------------------------------------------------+-------------------------------+
  | **cv.lhu rD, (rs1), Imm**                          | rD = Zext(Mem16(rs1))         |
  |                                                    |                               |
  |                                                    | rs1 += Sext(Imm[11:0])        |
  +----------------------------------------------------+-------------------------------+
  | **cv.lw rD, (rs1), Imm**                           | rD = Mem32(rs1)               |
  |                                                    |                               |
  |                                                    | rs1 += Sext(Imm[11:0])        |
  +----------------------------------------------------+-------------------------------+
  | **Register-Register Loads with Post-Increment**                                    |
  +----------------------------------------------------+-------------------------------+
  | **cv.lb rD, (rs1), rs2**                           | rD = Sext(Mem8(rs1))          |
  |                                                    |                               |
  |                                                    | rs1 += rs2                    |
  +----------------------------------------------------+-------------------------------+
  | **cv.lbu rD, (rs1), rs2**                          | rD = Zext(Mem8(rs1))          |
  |                                                    |                               |
  |                                                    | rs1 += rs2                    |
  +----------------------------------------------------+-------------------------------+
  | **cv.lh rD, (rs1), rs2**                           | rD = Sext(Mem16(rs1))         |
  |                                                    |                               |
  |                                                    | rs1 += rs2                    |
  +----------------------------------------------------+-------------------------------+
  | **cv.lhu rD, (rs1), rs2**                          | rD = Zext(Mem16(rs1))         |
  |                                                    |                               |
  |                                                    | rs1 += rs2                    |
  +----------------------------------------------------+-------------------------------+
  | **cv.lw rD, (rs1), rs2**                           | rD = Mem32(rs1)               |
  |                                                    |                               |
  |                                                    | rs1 += rs2                    |
  +----------------------------------------------------+-------------------------------+
  | **Register-Register Loads**                                                        |
  +----------------------------------------------------+-------------------------------+
  | **cv.lb rD, rs2(rs1)**                             | rD = Sext(Mem8(rs1 + rs2))    |
  +----------------------------------------------------+-------------------------------+
  | **cv.lbu rD, rs2(rs1)**                            | rD = Zext(Mem8(rs1 + rs2))    |
  +----------------------------------------------------+-------------------------------+
  | **cv.lh rD, rs2(rs1)**                             | rD = Sext(Mem16(rs1 + rs2))   |
  +----------------------------------------------------+-------------------------------+
  | **cv.lhu rD, rs2(rs1)**                            | rD = Zext(Mem16(rs1 + rs2))   |
  +----------------------------------------------------+-------------------------------+
  | **cv.lw rD, rs2(rs1)**                             | rD = Mem32(rs1 + rs2)         |
  +----------------------------------------------------+-------------------------------+

Store operations
^^^^^^^^^^^^^^^^

.. table:: Store operations
  :name: Store operations
  :widths: 30 70
  :class: no-scrollbar-table

  +-----------------------------------------------------+--------------------------+
  | **Mnemonic**                                        | **Description**          |
  +=====================================================+==========================+
  | **Register-Immediate Stores with Post-Increment**                              |
  +-----------------------------------------------------+--------------------------+
  | **cv.sb rs2, (rs1), Imm**                           | Mem8(rs1) = rs2          |
  |                                                     |                          |
  |                                                     | rs1 += Sext(Imm[11:0])   |
  +-----------------------------------------------------+--------------------------+
  | **cv.sh rs2, (rs1), Imm**                           | Mem16(rs1) = rs2         |
  |                                                     |                          |
  |                                                     | rs1 += Sext(Imm[11:0])   |
  +-----------------------------------------------------+--------------------------+
  | **cv.sw rs2, (rs1), Imm**                           | Mem32(rs1) = rs2         |
  |                                                     |                          |
  |                                                     | rs1 += Sext(Imm[11:0])   |
  +-----------------------------------------------------+--------------------------+
  | **Register-Register Stores with Post-Increment**                               |
  +-----------------------------------------------------+--------------------------+
  | **cv.sb rs2, (rs1), rs3**                           | Mem8(rs1) = rs2          |
  |                                                     |                          |
  |                                                     | rs1 += rs3               |
  +-----------------------------------------------------+--------------------------+
  | **cv.sh rs2, (rs1), rs3**                           | Mem16(rs1) = rs2         |
  |                                                     |                          |
  |                                                     | rs1 += rs3               |
  +-----------------------------------------------------+--------------------------+
  | **cv.sw rs2, (rs1), rs3**                           | Mem32(rs1) = rs2         |
  |                                                     |                          |
  |                                                     | rs1 += rs3               |
  +-----------------------------------------------------+--------------------------+
  | **Register-Register Stores**                                                   |
  +-----------------------------------------------------+--------------------------+
  | **cv.sb rs2, rs3(rs1)**                             | Mem8(rs1 + rs3) = rs2    |
  +-----------------------------------------------------+--------------------------+
  | **cv.sh rs2 rs3(rs1)**                              | Mem16(rs1 + rs3) = rs2   |
  +-----------------------------------------------------+--------------------------+
  | **cv.sw rs2, rs3(rs1)**                             | Mem32(rs1 + rs3) = rs2   |
  +-----------------------------------------------------+--------------------------+

Encoding
^^^^^^^^

.. table:: Post-Increment Register-Immediate Load operations encoding
  :name: Post-Increment Register-Immediate Load operations encoding
  :widths: 25 10 10 15 15 25
  :class: no-scrollbar-table

  +---------------+---------+------------+--------+------------+---------------------------+
  | 31    :    20 | 19 : 15 | 14   :  12 | 11 : 7 | 6    :   0 |                           |
  +---------------+---------+------------+--------+------------+---------------------------+
  | **imm[11:0]** | **rs1** | **funct3** | **rD** | **opcode** | **Mnemonic**              |
  +===============+=========+============+========+============+===========================+
  | offset        | base    | 000        | dest   | 000 1011   | **cv.lb rD, (rs1), Imm**  |
  +---------------+---------+------------+--------+------------+---------------------------+
  | offset        | base    | 100        | dest   | 000 1011   | **cv.lbu rD, (rs1), Imm** |
  +---------------+---------+------------+--------+------------+---------------------------+
  | offset        | base    | 001        | dest   | 000 1011   | **cv.lh rD, (rs1), Imm**  |
  +---------------+---------+------------+--------+------------+---------------------------+
  | offset        | base    | 101        | dest   | 000 1011   | **cv.lhu rD, (rs1), Imm** |
  +---------------+---------+------------+--------+------------+---------------------------+
  | offset        | base    | 010        | dest   | 000 1011   | **cv.lw rD, (rs1), Imm**  |
  +---------------+---------+------------+--------+------------+---------------------------+

.. table:: Post-Increment Register-Register Load operations encoding
  :name: Post-Increment Register-Register Load operations encoding
  :widths: 15 10 10 10 15 15 25
  :class: no-scrollbar-table

  +------------+----------+---------+------------+--------+------------+---------------------------+
  | 31  :   25 | 24  : 20 | 19 : 15 | 14   :  12 | 11 : 7 | 6   :    0 |                           |
  +------------+----------+---------+------------+--------+------------+---------------------------+
  | **funct7** | **rs2**  | **rs1** | **funct3** | **rD** | **opcode** | **Mnemonic**              |
  +============+==========+=========+============+========+============+===========================+
  | 000 0000   | offset   | base    | 011        | dest   | 010 1011   | **cv.lb rD, (rs1), rs2**  |
  +------------+----------+---------+------------+--------+------------+---------------------------+
  | 000 1000   | offset   | base    | 011        | dest   | 010 1011   | **cv.lbu rD, (rs1), rs2** |
  +------------+----------+---------+------------+--------+------------+---------------------------+
  | 000 0001   | offset   | base    | 011        | dest   | 010 1011   | **cv.lh rD, (rs1), rs2**  |
  +------------+----------+---------+------------+--------+------------+---------------------------+
  | 000 1001   | offset   | base    | 011        | dest   | 010 1011   | **cv.lhu rD, (rs1), rs2** |
  +------------+----------+---------+------------+--------+------------+---------------------------+
  | 000 0010   | offset   | base    | 011        | dest   | 010 1011   | **cv.lw rD, (rs1), rs2**  |
  +------------+----------+---------+------------+--------+------------+---------------------------+

.. table:: Register-Register Load operations encoding
  :name: Register-Register Load operations encoding
  :widths: 15 10 10 10 15 15 25
  :class: no-scrollbar-table

  +------------+----------+---------+------------+--------+------------+---------------------------+
  | 31  :   25 | 24  : 20 | 19 : 15 | 14   :  12 | 11 : 7 | 6   :    0 |                           |
  +------------+----------+---------+------------+--------+------------+---------------------------+
  | **funct7** | **rs2**  | **rs1** | **funct3** | **rD** | **opcode** | **Mnemonic**              |
  +============+==========+=========+============+========+============+===========================+
  | 000 0100   | offset   | base    | 011        | dest   | 010 1011   | **cv.lb rD, rs2(rs1)**    |
  +------------+----------+---------+------------+--------+------------+---------------------------+
  | 000 1100   | offset   | base    | 011        | dest   | 010 1011   | **cv.lbu rD, rs2(rs1)**   |
  +------------+----------+---------+------------+--------+------------+---------------------------+
  | 000 0101   | offset   | base    | 011        | dest   | 010 1011   | **cv.lh rD, rs2(rs1)**    |
  +------------+----------+---------+------------+--------+------------+---------------------------+
  | 000 1101   | offset   | base    | 011        | dest   | 010 1011   | **cv.lhu rD, rs2(rs1)**   |
  +------------+----------+---------+------------+--------+------------+---------------------------+
  | 000 0110   | offset   | base    | 011        | dest   | 010 1011   | **cv.lw rD, rs2(rs1)**    |
  +------------+----------+---------+------------+--------+------------+---------------------------+

.. table:: Post-Increment Register-Immediate Store operations encoding
  :name: Post-Increment Register-Immediate Store operations encoding
  :widths: 15 10 10 10 15 15 25
  :class: no-scrollbar-table

  +----------------+---------+---------+------------+---------------+------------+---------------------------+
  | 31    :     25 | 24 : 20 | 19 : 15 | 14   :  12 | 11     :    7 | 6    :   0 |                           |
  +----------------+---------+---------+------------+---------------+------------+---------------------------+
  | **imm[11:5]**  | **rs2** | **rs1** | **funct3** | **imm[4:0]**  | **opcode** | **Mnemonic**              |
  +================+=========+=========+============+===============+============+===========================+
  | offset[11:5]   | src     | base    | 000        | offset[4:0]   | 010 1011   | **cv.sb rs2, (rs1), Imm** |
  +----------------+---------+---------+------------+---------------+------------+---------------------------+
  | offset[11:5]   | src     | base    | 001        | offset[4:0]   | 010 1011   | **cv.sh rs2, (rs1), Imm** |
  +----------------+---------+---------+------------+---------------+------------+---------------------------+
  | offset[11:5]   | src     | base    | 010        | offset[4:0]   | 010 1011   | **cv.sw rs2, (rs1), Imm** |
  +----------------+---------+---------+------------+---------------+------------+---------------------------+

.. table:: Post-Increment Register-Register Store operations encoding
  :name: Post-Increment Register-Register Store operations encoding
  :widths: 15 10 10 10 15 15 25
  :class: no-scrollbar-table

  +------------+----------+---------+------------+---------+------------+---------------------------+
  | 31  :   25 | 24  : 20 | 19 : 15 | 14   :  12 | 11 : 7  | 6    :   0 |                           |
  +------------+----------+---------+------------+---------+------------+---------------------------+
  | **funct7** | **rs2**  | **rs1** | **funct3** | **rs3** | **opcode** | **Mnemonic**              |
  +============+==========+=========+============+=========+============+===========================+
  | 001 0000   | src      | base    | 011        | offset  | 010 1011   | **cv.sb rs2, (rs1), rs3** |
  +------------+----------+---------+------------+---------+------------+---------------------------+
  | 001 0001   | src      | base    | 011        | offset  | 010 1011   | **cv.sh rs2, (rs1), rs3** |
  +------------+----------+---------+------------+---------+------------+---------------------------+
  | 001 0010   | src      | base    | 011        | offse t | 010 1011   | **cv.sw rs2, (rs1), rs3** |
  +------------+----------+---------+------------+---------+------------+---------------------------+
  
.. table:: Register-Register Store operations encoding
  :name: Register-Register Store operations encoding
  :widths: 15 10 10 10 15 15 25
  :class: no-scrollbar-table

  +------------+----------+---------+------------+---------+------------+---------------------------+
  | 31  :   25 | 24 :  20 | 19 : 15 | 14   :  12 | 11  : 7 | 6    :   0 |                           |
  +------------+----------+---------+------------+---------+------------+---------------------------+
  | **funct7** | **rs2**  | **rs1** | **funct3** | **rs3** | **opcode** | **Mnemonic**              |
  +============+==========+=========+============+=========+============+===========================+
  | 001 0100   | src      | base    | 011        | offset  | 010 1011   | **cv.sb rs2, rs3(rs1)**   |
  +------------+----------+---------+------------+---------+------------+---------------------------+
  | 001 0101   | src      | base    | 011        | offset  | 010 1011   | **cv.sh rs2, rs3(rs1)**   |
  +------------+----------+---------+------------+---------+------------+---------------------------+
  | 001 0110   | src      | base    | 011        | offset  | 010 1011   | **cv.sw rs2, rs3(rs1)**   |
  +------------+----------+---------+------------+---------+------------+---------------------------+

.. _corev_event_load:

Event Load Instruction
----------------------

The event load instruction **cv.elw** is only supported if the ``COREV_CLUSTER`` parameter is set to 1.
The event load performs a load word and can cause the CV32E40P to enter a sleep state as explained
in :ref:`pulp_cluster`.

Event Load operation
^^^^^^^^^^^^^^^^^^^^

.. table:: Event Load operation
  :name: Event Load operation
  :widths: 30 70
  :class: no-scrollbar-table

  +----------------------------------------------------+-------------------------------+
  | **Mnemonic**                                       | **Description**               |
  +====================================================+===============================+
  | **Event Load**                                                                     |
  +----------------------------------------------------+-------------------------------+
  | **cv.elw rD, Imm(rs1)**                            | rD = Mem32(Sext(Imm) + rs1)   |
  +----------------------------------------------------+-------------------------------+

Encoding
^^^^^^^^

.. table:: Event Load operation encoding
  :name: Event Load operation encoding
  :widths: 25 10 10 15 15 25
  :class: no-scrollbar-table

  +---------------+---------+------------+--------+------------+---------------------------+
  | 31     :   20 | 19 : 15 | 14   :  12 | 11 : 7 | 6   :    0 |                           |
  +---------------+---------+------------+--------+------------+---------------------------+
  | **imm[11:0]** | **rs1** | **funct3** | **rD** | **opcode** | **Mnemonic**              |
  +===============+=========+============+========+============+===========================+
  | offset        | base    | 011        | dest   | 000 1011   | **cv.elw rD, Imm(rs1)**   |
  +---------------+---------+------------+--------+------------+---------------------------+

.. _corev_hardware_loop:

Hardware Loops
--------------

The loop has to be setup before entering the loop body. For this purpose, there are two
methods, either the long commands that separately set start- and
end-addresses of the loop and the number of iterations, or the short
command that does all of this in a single instruction. The short command
has a limited range for the number of instructions contained in the loop
and the loop must start in the next instruction after the setup
instruction.

Due to start/end addresses constraint, the 2 LSBs are hardwired to 0.
When using cv.start and cv.end instructions, the 2 LSBs of rs1 are ignored.

Hardware loop instructions and related CSRs are only supported if ``COREV_PULP`` == 1.

Details about the hardware loop constraints are provided in :ref:`hwloop-specs`.

In the following tables, the hardware loop instructions are reported.
In assembly, **L** is referred by 0 or 1.

Hardware Loops operations
^^^^^^^^^^^^^^^^^^^^^^^^^

.. table:: Long Hardware Loop Setup operations
  :name: Long Hardware Loop Setup operations
  :widths: 30 70
  :class: no-scrollbar-table

  +----------------------------------------------+----------------------------------------------------------+
  | **Mnemonic**                                 | **Description**                                          |
  +==============================================+==========================================================+
  | **cv.starti L, uimmL**                       | lpstart[L] = PC + (uimmL << 2)                           |
  +----------------------------------------------+----------------------------------------------------------+
  | **cv.start L, rs1**                          | lpstart[L] = rs1                                         |
  +----------------------------------------------+----------------------------------------------------------+
  | **cv.endi L, uimmL**                         | lpend[L] = PC + (uimmL << 2)                             |
  +----------------------------------------------+----------------------------------------------------------+
  | **cv.end L, rs1**                            | lpend[L] = rs1                                           |
  +----------------------------------------------+----------------------------------------------------------+
  | **cv.counti L, uimmL**                       | lpcount[L] = uimmL                                       |
  +----------------------------------------------+----------------------------------------------------------+
  | **cv.count L, rs1**                          | lpcount[L] = rs1                                         |
  +----------------------------------------------+----------------------------------------------------------+

.. table:: Short Hardware Loop Setup operations
  :name: Short Hardware Loop Setup operations
  :widths: 30 70
  :class: no-scrollbar-table

  +----------------------------------------------+----------------------------------------------------------+
  | **Mnemonic**                                 | **Description**                                          |
  +==============================================+==========================================================+
  | **cv.setupi L, uimmL, uimmS**                | lpstart[L] = PC + 4                                      |
  |                                              |                                                          |
  |                                              | lpend[L] = PC + (uimmS << 2)                             |
  |                                              |                                                          |
  |                                              | lpcount[L] = uimmL                                       |
  +----------------------------------------------+----------------------------------------------------------+
  | **cv.setup L, rs1, uimmL**                   | lpstart[L] = PC + 4                                      |
  |                                              |                                                          |
  |                                              | lpend[L] = PC + (uimmL << 2)                             |
  |                                              |                                                          |
  |                                              | lpcount[L] = rs1                                         |
  +----------------------------------------------+----------------------------------------------------------+

Encoding
^^^^^^^^

.. table:: Hardware Loops operations encoding
  :name: Hardware Loops operations encoding
  :widths: 17 15 10 10 5 15 28
  :class: no-scrollbar-table

  +-----------------+------------+------------+------------+-------+------------+-------------------------------+
  | 31   :   20     | 19 : 15    | 14   :  12 | 11   :   8 |     7 | 6   :    0 |                               |
  +-----------------+------------+------------+------------+-------+------------+-------------------------------+
  | **uimmL[11:0]** | **rs1**    | **funct3** | **funct4** | **L** | **opcode** | **Mnemonic**                  |
  +=================+============+============+============+=======+============+===============================+
  | uimmL[11:0]     | 00000      | 100        | 0000       | L     | 010 1011   | **cv.starti L, uimmL**        |
  +-----------------+------------+------------+------------+-------+------------+-------------------------------+
  | 0000 0000 0000  | src1       | 100        | 0001       | L     | 010 1011   | **cv.start L, rs1**           |
  +-----------------+------------+------------+------------+-------+------------+-------------------------------+
  | uimmL[11:0]     | 00000      | 100        | 0010       | L     | 010 1011   | **cv.endi L, uimmL**          |
  +-----------------+------------+------------+------------+-------+------------+-------------------------------+
  | 0000 0000 0000  | src1       | 100        | 0011       | L     | 010 1011   | **cv.end L, rs1**             |
  +-----------------+------------+------------+------------+-------+------------+-------------------------------+
  | uimmL[11:0]     | 00000      | 100        | 0100       | L     | 010 1011   | **cv.counti L, uimmL**        |
  +-----------------+------------+------------+------------+-------+------------+-------------------------------+
  | 0000 0000 0000  | src1       | 100        | 0101       | L     | 010 1011   | **cv.count L, rs1**           |
  +-----------------+------------+------------+------------+-------+------------+-------------------------------+
  | uimmL[11:0]     | uimmS[4:0] | 100        | 0110       | L     | 010 1011   | **cv.setupi L, uimmL, uimmS** |
  +-----------------+------------+------------+------------+-------+------------+-------------------------------+
  | uimmL[11:0]     | src1       | 100        | 0111       | L     | 010 1011   | **cv.setup L, rs1, uimmL**    |
  +-----------------+------------+------------+------------+-------+------------+-------------------------------+

.. _corev_alu:

ALU
---

CV32E40P supports advanced ALU operations that allow to perform multiple
instructions that are specified in the base instruction set in one
single instruction and thus increases efficiency of the core. For
example, those instructions include zero-/sign-extension instructions
for 8-bit and 16-bit operands, simple bit manipulation/counting
instructions and min/max/avg instructions. The ALU does also support
saturating, clipping and normalizing instructions which make fixed-point
arithmetic more efficient.

The custom ALU extensions are only supported if ``COREV_PULP`` == 1.

The custom extensions to the ALU are split into several subgroups that belong
together.

- Bit manipulation instructions are useful to work on single bits or
  groups of bits within a word, see :ref:`corev_bit_manipulation`.

- General ALU instructions try to fuse common used sequences into a
  single instruction and thus increase the performance of small kernels
  that use those sequence, see :ref:`corev_general_alu`.

- Immediate branching instructions are useful to compare a register
  with an immediate value before taking or not a branch, see see :ref:`corev_immediate_branching`.

Extract, Insert, Clear and Set instructions have the following meaning:

- Extract Is3+1 or rs2[9:5]+1 bits from position Is2 or rs2[4:0] [and sign extend it]

- Insert Is3+1 or rs2[9:5]+1 bits at position Is2 or rs2[4:0]

- Clear Is3+1 or rs2[9:5]+1 bits at position Is2 or rs2[4:0]

- Set Is3+1 or rs2[9:5]+1 bits at position Is2 or rs2[4:0]


Bit Reverse Instruction
^^^^^^^^^^^^^^^^^^^^^^^

This section will describe the `cv.bitrev` instruction from a bit manipulation
perspective without describing it's application as part of an FFT. The bit
reverse instruction will reverse bits in groupings of 1, 2 or 3 bits. The
number of grouped bits is described by *Is3* as follows:

* **0** - reverse single bits
* **1** - reverse groups of 2 bits
* **2** - reverse groups of 3 bits

The number of bits that are reversed can be controlled by *Is2*. This will
specify the number of bits that will be removed by a left shift prior to
the reverse operation resulting in the *32-Is2* least significant bits of
the input value being reversed and the *Is2* most significant bits of the
input value being thrown out.

What follows is a few examples.

.. highlight:: none

::

   cv.bitrev x18, x20, 0, 4 (groups of 1 bit; radix-2)

   in:    0xC64A5933 11000110010010100101100100110011
   shift: 0x64A59330 01100100101001011001001100110000
   out:   0x0CC9A526 00001100110010011010010100100110

   Swap pattern:
   A B C D E F G H . . . . . . . . . . . . . . . . . . . . . . . .
   0 1 1 0 0 1 0 0 1 0 1 0 0 1 0 1 1 0 0 1 0 0 1 1 0 0 1 1 0 0 0 0
   . . . . . . . . . . . . . . . . . . . . . . . . H G F E D C B A
   0 0 0 0 1 1 0 0 1 1 0 0 1 0 0 1 1 0 1 0 0 1 0 1 0 0 1 0 0 1 1 0

In this example the input value is first shifted by 4 (*Is2*). Each individual
bit is reversed. For example, bits 31 and 0 are swapped, 30 and 1, etc.

::

   cv.bitrev x18, x20, 1, 4 (groups of 2 bits; radix-4)

   in:    0xC64A5933 11000110010010100101100100110011
   shift: 0x64A59330 01100100101001011001001100110000
   out:   0x0CC65A19 00001100110001100101101000011001

   Swap pattern:
   A  B  C  D  E  F  G  H  I  J  K  L  M  N  O  P
   01 10 01 00 10 10 01 01 10 01 00 11 00 11 00 00
   P  O  N  M  L  K  J  I  H  G  F  E  D  C  B  A
   00 00 11 00 11 00 01 10 01 01 10 10 00 01 10 01

In this example the input value is first shifted by 4 (*Is2*). Each group of
two bits are reversed. For example, bits 31 and 30 are swapped with 1 and 0
(retaining their position relative to each other), bits 29 and 28 are swapped
with 3 and 2, etc.

::

   cv.bitrev x18, x20, 2, 4 (groups of 3 bits; radix-8)

   in:    0xC64A5933 11000110010010100101100100110011
   shift: 0x64A59330 01100100101001011001001100110000
   out:   0x216B244B 00100001011010110010010001001011

   Swap pattern:
   A   B   C   D   E   F   G   H   I   J
   011 001 001 010 010 110 010 011 001 100 00
      J   I   H   G   F   E   D   C   B   A
   00 100 001 011 010 110 010 010 001 001 011

In this last example the input value is first shifted by 4 (*Is2*). Each group
of three bits are reversed. For example, bits 31, 30 and 29 are swapped with
4, 3 and 2 (retaining their position relative to each other), bits 28, 27 and
26 are swapped with 7, 6 and 5, etc. Notice in this example that bits 0 and 1
are lost and the result is shifted right by two with bits 31 and 30 being tied
to zero. Also notice that when J (100) is swapped with A (011), the four most
significant bits are no longer zero as in the other cases. This may not be
desirable if the intention is to pack a specific number of grouped bits
aligned to the least significant bit and zero extended into the result. In
this case care should be taken to set *Is2* appropriately.


.. _corev_bit_manipulation:

Bit Manipulation operations
^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. table:: Bit Manipulation operations
  :name: Bit Manipulation operations
  :widths: 30 70
  :class: no-scrollbar-table

  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **Mnemonic**                                | **Description**                                                                                                                          |
  +=============================================+==========================================================================================================================================+
  | **cv.extract rD, rs1, Is3, Is2**            | rD = Sext(rs1[min(Is3+Is2,31):Is2])                                                                                                      |
  |                                             |                                                                                                                                          |
  |                                             | Note: Sign extension is done over the MSB of the extracted part.                                                                         |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.extractu rD, rs1, Is3, Is2**           | rD = Zext(rs1[min(Is3+Is2,31):Is2])                                                                                                      |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.extractr rD, rs1, rs2**                | rD = Sext(rs1[min(rs2[9:5]+rs2[4:0],31):rs2[4:0]])                                                                                       |
  |                                             |                                                                                                                                          |
  |                                             | Note: Sign extension is done over the MSB of the extracted part.                                                                         |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.extractur rD, rs1, rs2**               | rD = Zext(rs1[min(rs2[9:5]+rs2[4:0],31):rs2[4:0]])                                                                                       |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.insert rD, rs1, Is3, Is2**             | rD[min(Is3+Is2,31):Is2] = rs1[Is3-(max(Is3+Is2,31)-31):0]                                                                                |
  |                                             |                                                                                                                                          |
  |                                             | The rest of the bits of rD are untouched and keep their previous value.                                                                  |
  |                                             |                                                                                                                                          |
  |                                             | Is3 + Is2 must be < 32.                                                                                                                  |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.insertr rD, rs1, rs2**                 | rD[min(rs2[9:5]+rs2[4:0],31):rs2[4:0]] =                                                                                                 |
  |                                             |                                                                                                                                          |
  |                                             | rs1[rs2[9:5]-(max(rs2[9:5]+rs2[4:0],31)-31):0]                                                                                           |
  |                                             |                                                                                                                                          |
  |                                             | The rest of the bits of rD are untouched and keep their previous value.                                                                  |
  |                                             |                                                                                                                                          |
  |                                             | rs2[9:5] + rs2[4:0] must be < 32.                                                                                                        |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.bclr rD, rs1, Is3, Is2**               | rD[min(Is3+Is2,31):Is2] bits set to 0                                                                                                    |
  |                                             |                                                                                                                                          |
  |                                             | The rest of the bits of rD are passed through from rs1 and are not modified.                                                             |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.bclrr rD, rs1, rs2**                   | rD[min(rs2[9:5]+rs2[4:0],31):rs2[4:0]] bits set to 0                                                                                     |
  |                                             |                                                                                                                                          |
  |                                             | The rest of the bits of rD are passed through from rs1 and are not modified.                                                             |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.bset rD, rs1, Is3, Is2**               | rD[min(Is3+Is2,31):Is2] bits set to 1                                                                                                    |
  |                                             |                                                                                                                                          |
  |                                             | The rest of the bits of rD are passed through from rs1 and are not modified.                                                             |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.bsetr rD, rs1, rs2**                   | rD[min(rs2[9:5]+rs2[4:0],31):rs2[4:0]] bits set to 1                                                                                     |
  |                                             |                                                                                                                                          |
  |                                             | The rest of the bits of rD are passed through from rs1 and are not modified.                                                             |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.ff1 rD, rs1**                          | rD = bit position of the first bit set in rs1, starting from LSB.                                                                        |
  |                                             |                                                                                                                                          |
  |                                             | If bit 0 is set, rD will be 0. If only bit 31 is set, rD will be 31.                                                                     |
  |                                             |                                                                                                                                          |
  |                                             | If rs1 is 0, rD will be 32.                                                                                                              |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.fl1 rD, rs1**                          | rD = bit position of the last bit set in rs1, starting from MSB.                                                                         |
  |                                             |                                                                                                                                          |
  |                                             | If bit 31 is set, rD will be 31. If only bit 0 is set, rD will be 0.                                                                     |
  |                                             |                                                                                                                                          |
  |                                             | If rs1 is 0, rD will be 32.                                                                                                              |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.clb rD, rs1**                          | rD = count leading bits of rs1                                                                                                           |
  |                                             |                                                                                                                                          |
  |                                             | Number of consecutive 1's or 0's starting from MSB.                                                                                      |
  |                                             |                                                                                                                                          |
  |                                             | If rs1 is 0, rD will be 0. If rs1 is different than 0, returns (number - 1).                                                             |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.cnt rD, rs1**                          | rD = Population count of rs1                                                                                                             |
  |                                             |                                                                                                                                          |
  |                                             | Number of bits set in rs1.                                                                                                               |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.ror rD, rs1, rs2**                     | rD = RotateRight(rs1, rs2)                                                                                                               |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+
  | **cv.bitrev rD, rs1, Is3, Is2**             | Given an input rs1 it returns a bit reversed representation assuming                                                                     |
  |                                             |                                                                                                                                          |
  |                                             | FFT on 2^Is2 points in Radix 2^(Is3+1).                                                                                                  |
  |                                             |                                                                                                                                          |
  |                                             | Is3 can be either 0 (radix-2), 1 (radix-4) or 2 (radix-8).                                                                               |
  |                                             |                                                                                                                                          |
  |                                             | Note:  When Is3 = 3, instruction has the same bahavior as if it was 0 (radix-2).                                                         |
  +---------------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------+


Bit Manipulation Encoding
^^^^^^^^^^^^^^^^^^^^^^^^^

.. table:: Immediate Bit Manipulation operations encoding
  :name: Immediate Bit Manipulation operations encoding
  :widths: 5 14 13 5 8 6 16 33
  :class: no-scrollbar-table

  +--------+----------------------+---------------+---------+------------+--------+------------+------------------------------------+
  | 31: 30 | 29       :        25 | 24    :    20 | 19 : 15 | 14   :  12 | 11 : 7 | 6    :   0 |                                    |
  +--------+----------------------+---------------+---------+------------+--------+------------+------------------------------------+
  | **f2** | **Is3[4:0]**         | **Is2[4:0]**  | **rs1** | **funct3** | **rD** | **opcode** | **Mnemonic**                       |
  +========+======================+===============+=========+============+========+============+====================================+
  | 00     | Luimm5[4:0]          | Luimm5[4:0]   | src     | 000        | dest   | 101 1011   | **cv.extract rD, rs1, Is3, Is2**   |
  +--------+----------------------+---------------+---------+------------+--------+------------+------------------------------------+
  | 01     | Luimm5[4:0]          | Luimm5[4:0]   | src     | 000        | dest   | 101 1011   | **cv.extractu rD, rs1, Is3, Is2**  |
  +--------+----------------------+---------------+---------+------------+--------+------------+------------------------------------+
  | 10     | Luimm5[4:0]          | Luimm5[4:0]   | src     | 000        | dest   | 101 1011   | **cv.insert rD, rs1, Is3, Is2**    |
  +--------+----------------------+---------------+---------+------------+--------+------------+------------------------------------+
  | 00     | Luimm5[4:0]          | Luimm5[4:0]   | src     | 001        | dest   | 101 1011   | **cv.bclr rD, rs1, Is3, Is2**      |
  +--------+----------------------+---------------+---------+------------+--------+------------+------------------------------------+
  | 01     | Luimm5[4:0]          | Luimm5[4:0]   | src     | 001        | dest   | 101 1011   | **cv.bset rD, rs1, Is3, Is2**      |
  +--------+----------------------+---------------+---------+------------+--------+------------+------------------------------------+
  | 11     | 000, Luimm2[1:0]     | Luimm5[4:0]   | src     | 001        | dest   | 101 1011   | **cv.bitrev rD, rs1, Is3, Is2**    |
  +--------+----------------------+---------------+---------+------------+--------+------------+------------------------------------+

.. table:: Register Bit Manipulation operations encoding
  :name: Register Bit Manipulation operations encoding
  :widths: 19 13 5 8 6 16 33
  :class: no-scrollbar-table

  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | 31   :  25 | 24 : 20 | 19 : 15 | 14   :  12 | 11 : 7 | 6   :    0 |                                |
  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | **funct7** | **rs2** | **rs1** | **funct3** | **rD** | **opcode** |                                |
  +============+=========+=========+============+========+============+================================+
  | 001 1000   | src2    | src1    | 011        | dest   | 010 1011   | **cv.extractr rD, rs1, rs2**   |
  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | 001 1001   | src2    | src1    | 011        | dest   | 010 1011   | **cv.extractur rD, rs1, rs2**  |
  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | 001 1010   | src2    | src1    | 011        | dest   | 010 1011   | **cv.insertr rD, rs1, rs2**    |
  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | 001 1100   | src2    | src1    | 011        | dest   | 010 1011   | **cv.bclrr rD, rs1, rs2**      |
  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | 001 1101   | src2    | scr1    | 011        | dest   | 010 1011   | **cv.bsetr rD, rs1, rs2**      |
  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | 010 0000   | src2    | src1    | 011        | dest   | 010 1011   | **cv.ror rD, rs1, rs2**        |
  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | 010 0001   | 00000   | src1    | 011        | dest   | 010 1011   | **cv.ff1 rD, rs1**             |
  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | 010 0010   | 00000   | src1    | 011        | dest   | 010 1011   | **cv.fl1 rD, rs1**             |
  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | 010 0011   | 00000   | src1    | 011        | dest   | 010 1011   | **cv.clb rD, rs1**             |
  +------------+---------+---------+------------+--------+------------+--------------------------------+
  | 010 0100   | 00000   | src1    | 011        | dest   | 010 1011   | **cv.cnt rD, rs1**             |
  +------------+---------+---------+------------+--------+------------+--------------------------------+

.. _corev_general_alu:

General ALU operations
^^^^^^^^^^^^^^^^^^^^^^

.. table:: General ALU operations
  :name: General ALU operations
  :widths: 30 70
  :class: no-scrollbar-table

  +-------------------------------------------+------------------------------------------------------------------------+
  | **Mnemonic**                              | **Description**                                                        |
  +===========================================+========================================================================+
  | **cv.abs rD, rs1**                        | rD = rs1 < 0 ? -rs1 : rs1                                              |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.sle rD, rs1, rs2**                   | rD = rs1 <= rs2 ? 1 : 0                                                |
  |                                           |                                                                        |
  |                                           | Note: Comparison is signed.                                            |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.sleu rD, rs1, rs2**                  | rD = rs1 <= rs2 ? 1 : 0                                                |
  |                                           |                                                                        |
  |                                           | Note: Comparison is unsigned.                                          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.min rD, rs1, rs2**                   | rD = rs1 < rs2 ? rs1 : rs2                                             |
  |                                           |                                                                        |
  |                                           | Note: Comparison is signed.                                            |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.minu rD, rs1, rs2**                  | rD = rs1 < rs2 ? rs1 : rs2                                             |
  |                                           |                                                                        |
  |                                           | Note: Comparison is unsigned.                                          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.max rD, rs1, rs2**                   | rD = rs1 < rs2 ? rs2 : rs1                                             |
  |                                           |                                                                        |
  |                                           | Note: Comparison is signed.                                            |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.maxu rD, rs1, rs2**                  | rD = rs1 < rs2 ? rs2 : rs1                                             |
  |                                           |                                                                        |
  |                                           | Note: Comparison is unsigned.                                          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.exths rD, rs1**                      | rD = Sext(rs1[15:0])                                                   |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.exthz rD, rs1**                      | rD = Zext(rs1[15:0])                                                   |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.extbs rD, rs1**                      | rD = Sext(rs1[7:0])                                                    |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.extbz rD, rs1**                      | rD = Zext(rs1[7:0])                                                    |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.clip rD, rs1, Is2**                  | if rs1 <= -2^(Is2-1), rD = -2^(Is2-1),                                 |
  |                                           |                                                                        |
  |                                           | else if rs1 >= 2^(Is2-1)-1, rD = 2^(Is2-1)-1,                          |
  |                                           |                                                                        |
  |                                           | else rD = rs1                                                          |
  |                                           |                                                                        |
  |                                           | Note: If Is2 is equal to 0,                                            |
  |                                           |                                                                        |
  |                                           | -2^(Is2-1) is equivalent to -1 while (2^(Is2-1)-1) is equivalent to 0. |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.clipu rD, rs1, Is2**                 | if rs1 <= 0, rD = 0,                                                   |
  |                                           |                                                                        |
  |                                           | else if rs1 >= 2^(Is2-1)-1, rD = 2^(Is2-1)-1,                          |
  |                                           |                                                                        |
  |                                           | else rD = rs1                                                          |
  |                                           |                                                                        |
  |                                           | Note: If Is2 is equal to 0, (2^(Is2-1)-1) is equivalent to 0.          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.clipr rD, rs1, rs2**                 | rs2' = rs2 & 0x7FFFFFFF                                                |
  |                                           |                                                                        |
  |                                           | if rs1 <= -(rs2'+1), rD = -(rs2'+1),                                   |
  |                                           |                                                                        |
  |                                           | else if rs1 >=rs2', rD = rs2',                                         |
  |                                           |                                                                        |
  |                                           | else rD = rs1                                                          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.clipur rD, rs1, rs2**                | rs2' = rs2 & 0x7FFFFFFF                                                |
  |                                           |                                                                        |
  |                                           | if rs1 <= 0, rD = 0,                                                   |
  |                                           |                                                                        |
  |                                           | else if rs1 >= rs2', rD = rs2',                                        |
  |                                           |                                                                        |
  |                                           | else rD = rs1                                                          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.addN rD, rs1, rs2, Is3**             | rD = (rs1 + rs2) >>> Is3                                               |
  |                                           |                                                                        |
  |                                           | Note: Arithmetic shift right.                                          |
  |                                           |                                                                        |
  |                                           | Setting Is3 to 1 replaces former cv.avg.                               |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.adduN rD, rs1, rs2, Is3**            | rD = (rs1 + rs2) >> Is3                                                |
  |                                           |                                                                        |
  |                                           | Note: Logical shift right.                                             |
  |                                           |                                                                        |
  |                                           | Setting Is3 to 1 replaces former cv.avgu.                              |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.addRN rD, rs1, rs2, Is3**            | rD = (rs1 + rs2 + 2^(Is3-1)) >>> Is3                                   |
  |                                           |                                                                        |
  |                                           | Note: Arithmetic shift right.                                          |
  |                                           |                                                                        |
  |                                           | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                    |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.adduRN rD, rs1, rs2, Is3**           | rD = (rs1 + rs2 + 2^(Is3-1))) >> Is3                                   |
  |                                           |                                                                        |
  |                                           | Note: Logical shift right.                                             |
  |                                           |                                                                        |
  |                                           | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                    |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.subN rD, rs1, rs2, Is3**             | rD = (rs1 - rs2) >>> Is3                                               |
  |                                           |                                                                        |
  |                                           | Note: Arithmetic shift right.                                          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.subuN rD, rs1, rs2, Is3**            | rD = (rs1 - rs2) >> Is3                                                |
  |                                           |                                                                        |
  |                                           | Note: Logical shift right.                                             |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.subRN rD, rs1, rs2, Is3**            | rD = (rs1 - rs2 + 2^(Is3-1)) >>> Is3                                   |
  |                                           |                                                                        |
  |                                           | Note: Arithmetic shift right.                                          |
  |                                           |                                                                        |
  |                                           | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                    |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.subuRN rD, rs1, rs2, Is3**           | rD = (rs1 - rs2 + 2^(Is3-1))) >> Is3                                   |
  |                                           |                                                                        |
  |                                           | Note: Logical shift right.                                             |
  |                                           |                                                                        |
  |                                           | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                    |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.addNr rD, rs1, rs2**                 | rD = (rD + rs1) >>> rs2[4:0]                                           |
  |                                           |                                                                        |
  |                                           | Note: Arithmetic shift right.                                          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.adduNr rD, rs1, rs2**                | rD = (rD + rs1) >> rs2[4:0]                                            |
  |                                           |                                                                        |
  |                                           | Note: Logical shift right.                                             |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.addRNr rD, rs1, rs2**                | rD = (rD + rs1 + 2^(rs2[4:0]-1)) >>> rs2[4:0]                          |
  |                                           |                                                                        |
  |                                           | Note: Arithmetic shift right.                                          |
  |                                           |                                                                        |
  |                                           | If rs2[4:0] is equal to 0, 2^(rs2[4:0]-1) is equivalent to 0.          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.adduRNr rD, rs1, rs2**               | rD = (rD + rs1 + 2^(rs2[4:0]-1))) >> rs2[4:0]                          |
  |                                           |                                                                        |
  |                                           | Note: Logical shift right.                                             |
  |                                           |                                                                        |
  |                                           | If rs2[4:0] is equal to 0, 2^(rs2[4:0]-1) is equivalent to 0.          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.subNr rD, rs1, rs2**                 | rD = (rD - rs1) >>> rs2[4:0]                                           |
  |                                           |                                                                        |
  |                                           | Note: Arithmetic shift right.                                          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.subuNr rD, rs1, rs2**                | rD = (rD - rs1) >> rs2[4:0]                                            |
  |                                           |                                                                        |
  |                                           | Note: Logical shift right.                                             |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.subRNr rD, rs1, rs2**                | rD = (rD - rs1+ 2^(rs2[4:0]-1)) >>> rs2[4:0]                           |
  |                                           |                                                                        |
  |                                           | Note: Arithmetic shift right.                                          |
  |                                           |                                                                        |
  |                                           | If rs2[4:0] is equal to 0, 2^(rs2[4:0]-1) is equivalent to 0.          |
  +-------------------------------------------+------------------------------------------------------------------------+
  | **cv.subuRNr rD, rs1, rs2**               | rD = (rD - rs1+ 2^(rs2[4:0]-1))) >> rs2[4:0]                           |
  |                                           |                                                                        |
  |                                           | Note: Logical shift right.                                             |
  |                                           |                                                                        |
  |                                           | If rs2[4:0] is equal to 0, 2^(rs2[4:0]-1) is equivalent to 0.          |
  +-------------------------------------------+------------------------------------------------------------------------+

General ALU Encoding
^^^^^^^^^^^^^^^^^^^^

.. table:: General ALU operations encoding
  :name: General ALU operations encoding
  :widths: 21 13 9 9 9 11 28
  :class: no-scrollbar-table

  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 31   :  25 | 24 : 20 | 19 : 15 | 14   :  12 | 11 : 7 | 6  :     0 |                           |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | **funct7** | **rs2** | **rs1** | **funct3** | **rD** | **opcode** |                           |
  +============+=========+=========+============+========+============+===========================+
  | 010 1000   | 00000   | src1    | 011        | dest   | 010 1011   | **cv.abs rD, rs1**        |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 010 1001   | src2    | src1    | 011        | dest   | 010 1011   | **cv.sle rD, rs1, rs2**   |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 010 1010   | src2    | src1    | 011        | dest   | 010 1011   | **cv.sleu rD, rs1, rs2**  |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 010 1011   | src2    | src1    | 011        | dest   | 010 1011   | **cv.min rD, rs1, rs2**   |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 010 1100   | src2    | src1    | 011        | dest   | 010 1011   | **cv.minu rD, rs1, rs2**  |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 010 1101   | src2    | src1    | 011        | dest   | 010 1011   | **cv.max rD, rs1, rs2**   |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 010 1110   | src2    | src1    | 011        | dest   | 010 1011   | **cv.maxu rD, rs1, rs2**  |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 011 0000   | 00000   | src1    | 011        | dest   | 010 1011   | **cv.exths rD, rs1**      |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 011 0001   | 00000   | src1    | 011        | dest   | 010 1011   | **cv.exthz rD, rs1**      |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 011 0010   | 00000   | src1    | 011        | dest   | 010 1011   | **cv.extbs rD, rs1**      |
  +------------+---------+---------+------------+--------+------------+---------------------------+
  | 011 0011   | 00000   | src1    | 011        | dest   | 010 1011   | **cv.extbz rD, rs1**      |
  +------------+---------+---------+------------+--------+------------+---------------------------+

.. table:: General ALU operations encoding
  :name: General ALU operations encoding
  :widths: 21 13 9 9 9 11 28
  :class: no-scrollbar-table

  +------------+---------------+---------+------------+--------+------------+-----------------------------+
  | 31  :   25 | 24   :     20 | 19 : 15 | 14   :  12 | 11 : 7 | 6   :    0 |                             |
  +------------+---------------+---------+------------+--------+------------+-----------------------------+
  | **funct7** | **Is2[4:0]**  | **rs1** | **funct3** | **rD** | **opcode** |                             |
  +============+===============+=========+============+========+============+=============================+
  | 011 1000   | Luimm5[4:0]   | src1    | 011        | dest   | 010 1011   | **cv.clip rD, rs1, Is2**    |
  +------------+---------------+---------+------------+--------+------------+-----------------------------+
  | 011 1001   | Luimm5[4:0]   | src1    | 011        | dest   | 010 1011   | **cv.clipu rD, rs1, Is2**   |
  +------------+---------------+---------+------------+--------+------------+-----------------------------+
  | 011 1010   | src2          | src1    | 011        | dest   | 010 1011   | **cv.clipr rD, rs1, rs2**   |
  +------------+---------------+---------+------------+--------+------------+-----------------------------+
  | 011 1011   | src2          | src1    | 011        | dest   | 010 1011   | **cv.clipur rD, rs1, rs2**  |
  +------------+---------------+---------+------------+--------+------------+-----------------------------+

.. table:: General ALU operations encoding
  :name: General ALU operations encoding
  :widths: 5 16 13 9 9 9 11 28
  :class: no-scrollbar-table

  +--------+---------------+---------+---------+------------+--------+------------+----------------------------------+
  | 31: 30 | 29    :    25 | 24 : 20 | 19 : 15 | 14   :  12 | 11 : 7 | 6   :    0 |                                  |
  +--------+---------------+---------+---------+------------+--------+------------+----------------------------------+
  | **f2** | **Is3[4:0]**  | **rs2** | **rs1** | **funct3** | **rD** | **opcode** |                                  |
  +========+===============+=========+=========+============+========+============+==================================+
  | 00     | Luimm5[4:0]   | src2    | src1    | 010        | dest   | 101 1011   | **cv.addN rD, rs1, rs2, Is3**    |
  +--------+---------------+---------+---------+------------+--------+------------+----------------------------------+
  | 01     | Luimm5[4:0]   | src2    | src1    | 010        | dest   | 101 1011   | **cv.adduN rD, rs1, rs2, Is3**   |
  +--------+---------------+---------+---------+------------+--------+------------+----------------------------------+
  | 10     | Luimm5[4:0]   | src2    | src1    | 010        | dest   | 101 1011   | **cv.addRN rD, rs1, rs2, Is3**   |
  +--------+---------------+---------+---------+------------+--------+------------+----------------------------------+
  | 11     | Luimm5[4:0]   | src2    | src1    | 010        | dest   | 101 1011   | **cv.adduRN rD, rs1, rs2, Is3**  |
  +--------+---------------+---------+---------+------------+--------+------------+----------------------------------+
  | 00     | Luimm5[4:0]   | src2    | src1    | 011        | dest   | 101 1011   | **cv.subN rD, rs1, rs2, Is3**    |
  +--------+---------------+---------+---------+------------+--------+------------+----------------------------------+
  | 01     | Luimm5[4:0]   | src2    | src1    | 011        | dest   | 101 1011   | **cv.subuN rD, rs1, rs2, Is3**   |
  +--------+---------------+---------+---------+------------+--------+------------+----------------------------------+
  | 10     | Luimm5[4:0]   | src2    | src1    | 011        | dest   | 101 1011   | **cv.subRN rD, rs1, rs2, Is3**   |
  +--------+---------------+---------+---------+------------+--------+------------+----------------------------------+
  | 11     | Luimm5[4:0]   | src2    | src1    | 011        | dest   | 101 1011   | **cv.subuRN rD, rs1, rs2, Is3**  |
  +--------+---------------+---------+---------+------------+--------+------------+----------------------------------+

.. table:: General ALU operations encoding
  :name: General ALU operations encoding
  :widths: 21 13 9 9 9 11 28
  :class: no-scrollbar-table

  +------------+--------------+---------+------------+--------+------------+-----------------------------+
  | 31  :   25 | 24    :   20 | 19 : 15 | 14   :  12 | 11 : 7 | 6   :    0 |                             |
  +------------+--------------+---------+------------+--------+------------+-----------------------------+
  | **funct7** | **Is3[4:0]** | **rs1** | **funct3** | **rD** | **opcode** |                             |
  +============+==============+=========+============+========+============+=============================+
  | 100 0000   | src2         | src1    | 011        | dest   | 010 1011   | **cv.addNr rD, rs1, rs2**   |
  +------------+--------------+---------+------------+--------+------------+-----------------------------+
  | 100 0001   | src2         | src1    | 011        | dest   | 010 1011   | **cv.adduNr rD, rs1, rs**   |
  +------------+--------------+---------+------------+--------+------------+-----------------------------+
  | 100 0010   | src2         | src1    | 011        | dest   | 010 1011   | **cv.addRNr rD, rs1, rs**   |
  +------------+--------------+---------+------------+--------+------------+-----------------------------+
  | 100 0011   | src2         | src1    | 011        | dest   | 010 1011   | **cv.adduRNr rD, rs1, rs2** |
  +------------+--------------+---------+------------+--------+------------+-----------------------------+
  | 100 0100   | src2         | src1    | 011        | dest   | 010 1011   | **cv.subNr rD, rs1, rs2**   |
  +------------+--------------+---------+------------+--------+------------+-----------------------------+
  | 100 0101   | src2         | src1    | 011        | dest   | 010 1011   | **cv.subuNr rD, rs1, rs2**  |
  +------------+--------------+---------+------------+--------+------------+-----------------------------+
  | 100 0110   | src2         | src1    | 011        | dest   | 010 1011   | **cv.subRNr rD, rs1, rs2**  |
  +------------+--------------+---------+------------+--------+------------+-----------------------------+
  | 100 0111   | src2         | src1    | 011        | dest   | 010 1011   | **cv.subuRNr rD, rs1, rs2** |
  +------------+--------------+---------+------------+--------+------------+-----------------------------+

.. _corev_immediate_branching:

Immediate Branching operations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. table:: Immediate Branching operations
  :name: Immediate Branching operations
  :widths: 30 70
  :class: no-scrollbar-table

  +---------------------------------+------------------------------------------------------------------------+
  | **Mnemonic**                    | **Description**                                                        |
  +=================================+========================================================================+
  | **cv.beqimm rs1, Imm5, Imm12**  | Branch to PC + (Imm12 << 1) if rs1 is equal to Imm5.                   |
  |                                 |                                                                        |
  |                                 | Note: Imm5 is signed.                                                  |
  +---------------------------------+------------------------------------------------------------------------+
  | **cv.bneimm rs1, Imm5, Imm12**  | Branch to PC + (Imm12 << 1) if rs1 is not equal to Imm5.               |
  |                                 |                                                                        |
  |                                 | Note: Imm5 is signed.                                                  |
  +---------------------------------+------------------------------------------------------------------------+

Immediate Branching Encoding
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. table:: Immediate Branching encoding
  :name: Immediate Branching encoding
  :widths: 13 14 8 6 8 12 12 11 16
  :class: no-scrollbar-table

  +---------------+-----------------+----------+----------+------------+-------------+------------+------------+---------------------------------+
  | 31            | 30     :     25 | 24  : 20 | 19  : 15 | 14   :  12 | 11   :    8 | 7          | 6   :    0 |                                 |
  +---------------+-----------------+----------+----------+------------+-------------+------------+------------+---------------------------------+
  | **Imm12[12]** | **Imm12[10:5]** | **Imm5** | **rs1**  | **funct3** | **Imm12**   | **Imm12**  | **opcode** |                                 |
  +===============+=================+==========+==========+============+=============+============+============+=================================+
  | Imm12[12]     | Imm12[10:5]     | Imm5     | src1     | 110        | Imm12[4:1]  | Imm12[11]  | 000 1011   | **cv.beqimm rs1, Imm5, Imm12**  |
  +---------------+-----------------+----------+----------+------------+-------------+------------+------------+---------------------------------+
  | Imm12[12]     | Imm12[10:5]     | Imm5     | src1     | 111        | Imm12[4:1]  | Imm12[11]  | 000 1011   | **cv.bneimm rs1, Imm5, Imm12**  |
  +---------------+-----------------+----------+----------+------------+-------------+------------+------------+---------------------------------+

.. _corev_multiply_accumulate:

Multiply-Accumulate
-------------------

CV32E40P supports custom extensions for multiply-accumulate and half-word multiplications with
an optional post-multiplication shift.

The custom multiply-accumulate extensions are only supported if ``COREV_PULP`` == 1.

16-Bit x 16-Bit Multiplication operations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. table:: 16-Bit x 16-Bit Multiplication operations
  :name: 16-Bit x 16-Bit Multiplication operations
  :widths: 30 70
  :class: no-scrollbar-table

  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **Mnemonic**                                  | **Description**                                                              |
  +===============================================+==============================================================================+
  | **cv.muluN rD, rs1, rs2, Is3**                | rD[31:0] = (Zext(rs1[15:0]) \* Zext(rs2[15:0])) >> Is3                       |
  |                                               |                                                                              |
  |                                               | Note: Logical shift right.                                                   |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.mulhhuN rD, rs1, rs2, Is3**              | rD[31:0] = (Zext(rs1[31:16]) \* Zext(rs2[31:16])) >> Is3                     |
  |                                               |                                                                              |
  |                                               | Note: Logical shift right.                                                   |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.mulsN rD, rs1, rs2, Is3**                | rD[31:0] = (Sext(rs1[15:0]) \* Sext(rs2[15:0])) >>> Is3                      |
  |                                               |                                                                              |
  |                                               | Note: Arithmetic shift right.                                                |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.mulhhsN rD, rs1, rs2, Is3**              | rD[31:0] = (Sext(rs1[31:16]) \* Sext(rs2[31:16])) >>> Is3                    |
  |                                               |                                                                              |
  |                                               | Note: Arithmetic shift right.                                                |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.muluRN rD, rs1, rs2, Is3**               | rD[31:0] = (Zext(rs1[15:0]) \* Zext(rs2[15:0]) + 2^(Is3-1)) >> Is3           |
  |                                               |                                                                              |
  |                                               | Note: Logical shift right.                                                   |
  |                                               |                                                                              |
  |                                               | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                          |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.mulhhuRN rD, rs1, rs2, Is3**             | rD[31:0] = (Zext(rs1[31:16]) \* Zext(rs2[31:16]) + 2^(Is3-1)) >> Is3         |
  |                                               |                                                                              |
  |                                               | Note: Logical shift right.                                                   |
  |                                               |                                                                              |
  |                                               | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                          |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.mulsRN rD, rs1, rs2, Is3**               | rD[31:0] = (Sext(rs1[15:0]) \* Sext(rs2[15:0]) + 2^(Is3-1)) >>> Is3          |
  |                                               |                                                                              |
  |                                               | Note: Arithmetic shift right.                                                |
  |                                               |                                                                              |
  |                                               | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                          |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.mulhhsRN rD, rs1, rs2, Is3**             | rD[31:0] = (Sext(rs1[31:16]) \* Sext(rs2[31:16]) + 2^(Is3-1)) >>> Is3        |
  |                                               |                                                                              |
  |                                               | Note: Arithmetic shift right.                                                |
  |                                               |                                                                              |
  |                                               | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                          |
  +-----------------------------------------------+------------------------------------------------------------------------------+

.. _corev_16_bit_multiply_pseudo_instructions:

16-Bit x 16-Bit Multiplication pseudo-instructions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
.. table:: 16-Bit x 16-Bit Multiplication pseudo-instructions
  :name: 16-Bit x 16-Bit Multiplication pseudo-instructions
  :widths: 23 27 50
  :class: no-scrollbar-table

  +-----------------------------------------+--------------------------------------------+--------------------------------------------------------------+
  | **Mnemonic**                            | **Base Instruction**                       | **Description**                                              |
  +=========================================+============================================+==============================================================+
  | **cv.mulu rD, rs1, rs2**                |  **cv.muluN rD, rs1, rs2, 0**              | rD[31:0] = (Zext(rs1[15:0]) \* Zext(rs2[15:0])) >> 0         |
  |                                         |                                            |                                                              |
  |                                         |                                            | Note: Logical shift right.                                   |
  +-----------------------------------------+--------------------------------------------+--------------------------------------------------------------+
  | **cv.mulhhu rD, rs1, rs2**              | **cv.mulhhuN rD, rs1, rs2, 0**             | rD[31:0] = (Zext(rs1[31:16]) \* Zext(rs2[31:16])) >> 0       |
  |                                         |                                            |                                                              |
  |                                         |                                            | Note: Logical shift right.                                   |
  +-----------------------------------------+--------------------------------------------+--------------------------------------------------------------+
  | **cv.muls rD, rs1, rs2**                | **cv.mulsN rD, rs1, rs2, 0**               | rD[31:0] = (Sext(rs1[15:0]) \* Sext(rs2[15:0])) >> 0         |
  |                                         |                                            |                                                              |
  |                                         |                                            | Note: Arithmetic shift right.                                |
  +-----------------------------------------+--------------------------------------------+--------------------------------------------------------------+
  | **cv.mulhhs rD, rs1, rs2**              | **cv.mulhhsN rD, rs1, rs2, 0**             | rD[31:0] = (Sext(rs1[31:16]) \* Sext(rs2[31:16])) >> 0       |
  |                                         |                                            |                                                              |
  |                                         |                                            | Note: Arithmetic shift right.                                |
  +-----------------------------------------+--------------------------------------------+--------------------------------------------------------------+

16-Bit x 16-Bit Multiply-Accumulate operations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. table:: 16-Bit x 16-Bit Multiply-Accumulate operations
  :name: 16-Bit x 16-Bit Multiply-Accumulate operations
  :widths: 30 70
  :class: no-scrollbar-table

  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **Mnemonic**                                  | **Description**                                                              |
  +===============================================+==============================================================================+
  | **cv.macuN rD, rs1, rs2, Is3**                | rD[31:0] = (Zext(rs1[15:0]) \* Zext(rs2[15:0]) + rD) >> Is3                  |
  |                                               |                                                                              |
  |                                               | Note: Logical shift right.                                                   |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.machhuN rD, rs1, rs2, Is3**              | rD[31:0] = (Zext(rs1[31:16]) \* Zext(rs2[31:16]) + rD) >> Is3                |
  |                                               |                                                                              |
  |                                               | Note: Logical shift right.                                                   |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.macsN rD, rs1, rs2, Is3**                | rD[31:0] = (Sext(rs1[15:0]) \* Sext(rs2[15:0]) + rD) >>> Is3                 |
  |                                               |                                                                              |
  |                                               | Note: Arithmetic shift right.                                                |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.machhsN rD, rs1, rs2, Is3**              | rD[31:0] = (Sext(rs1[31:16]) \* Sext(rs2[31:16]) + rD) >>> Is3               |
  |                                               |                                                                              |
  |                                               | Note: Arithmetic shift right.                                                |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.macuRN rD, rs1, rs2, Is3**               | rD[31:0] = (Zext(rs1[15:0]) \* Zext(rs2[15:0]) + rD + 2^(Is3-1)) >> Is3      |
  |                                               |                                                                              |
  |                                               | Note: Logical shift right.                                                   |
  |                                               |                                                                              |
  |                                               | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                          |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.machhuRN rD, rs1, rs2, Is3**             | rD[31:0] = (Zext(rs1[31:16]) \* Zext(rs2[31:16]) + rD + 2^(Is3-1)) >> Is3    |
  |                                               |                                                                              |
  |                                               | Note: Logical shift right.                                                   |
  |                                               |                                                                              |
  |                                               | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                          |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.macsRN rD, rs1, rs2, Is3**               | rD[31:0] = (Sext(rs1[15:0]) \* Sext(rs2[15:0]) + rD + 2^(Is3-1)) >>> Is3     |
  |                                               |                                                                              |
  |                                               | Note: Arithmetic shift right.                                                |
  |                                               |                                                                              |
  |                                               | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                          |
  +-----------------------------------------------+------------------------------------------------------------------------------+
  | **cv.machhsRN rD, rs1, rs2, Is3**             | rD[31:0] = (Sext(rs1[31:16]) \* Sext(rs2[31:16]) + rD + 2^(Is3-1)) >>> Is3   |
  |                                               |                                                                              |
  |                                               | Note: Arithmetic shift right.                                                |
  |                                               |                                                                              |
  |                                               | If Is3 is equal to 0, 2^(Is3-1) is equivalent to 0.                          |
  +-----------------------------------------------+------------------------------------------------------------------------------+

32-Bit x 32-Bit Multiply-Accumulate operations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. table:: 32-Bit x 32-Bit Multiply-Accumulate operations
  :name: 32-Bit x 32-Bit Multiply-Accumulate operations
  :widths: 30 70
  :class: no-scrollbar-table

  +--------------------------------+-------------------------------------------------------------------------------------------+
  | **Mnemonic**                   | **Description**                                                                           |
  +================================+===========================================================================================+
  | **cv.mac rD, rs1, rs2**        | rD = rD + rs1 \* rs2                                                                      |
  +--------------------------------+-------------------------------------------------------------------------------------------+
  | **cv.msu rD, rs1, rs2**        | rD = rD - rs1 \* rs2                                                                      |
  +--------------------------------+-------------------------------------------------------------------------------------------+

Encoding
^^^^^^^^

.. table:: 16-Bit x 16-Bit Multiplication encoding
  :name: 16-Bit x 16-Bit Multiplication encoding
  :widths: 5 16 6 6 9 6 11 39
  :class: no-scrollbar-table

  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 31: 30 | 29    :    25 | 24 : 20 | 19 : 15 | 14   :  12 | 11 : 7 | 6   :    0 |                                    |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | **f2** | **Is3[4:0]**  | **rs2** | **rs1** | **funct3** | **rD** | **opcode** |                                    |
  +========+===============+=========+=========+============+========+============+====================================+
  | 00     | Luimm5[4:0]   | src2    | src1    | 101        | dest   | 101 1011   | **cv.muluN rD, rs1, rs2, Is3**     |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 01     | Luimm5[4:0]   | src2    | src1    | 101        | dest   | 101 1011   | **cv.mulhhuN rD, rs1, rs2, Is3**   |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 00     | Luimm5[4:0]   | src2    | src1    | 100        | dest   | 101 1011   | **cv.mulsN rD, rs1, rs2, Is3**     |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 01     | Luimm5[4:0]   | src2    | src1    | 100        | dest   | 101 1011   | **cv.mulhhsN rD, rs1, rs2, Is3**   |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 10     | Luimm5[4:0]   | src2    | src1    | 101        | dest   | 101 1011   | **cv.muluRN rD, rs1, rs2, Is3**    |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 11     | Luimm5[4:0]   | src2    | src1    | 101        | dest   | 101 1011   | **cv.mulhhuRN rD, rs1, rs2, Is3**  |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 10     | Luimm5[4:0]   | src2    | src1    | 100        | dest   | 101 1011   | **cv.mulsRN rD, rs1, rs2, Is3**    |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 11     | Luimm5[4:0]   | src2    | src1    | 100        | dest   | 101 1011   | **cv.mulhhsRN rD, rs1, rs2, Is3**  |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+

.. table:: 16-Bit x 16-Bit Multiply-Accumulate encoding
  :name: 16-Bit x 16-Bit Multiply-Accumulate encoding
  :widths: 5 16 6 6 9 6 11 39
  :class: no-scrollbar-table

  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 31: 30 | 29    :    25 | 24 : 20 | 19 : 15 | 14   :  12 | 11 : 7 | 6   :    0 |                                    |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | **f2** | **Is3[4:0]**  | **rs2** | **rs1** | **funct3** | **rD** | **opcode** |                                    |
  +========+===============+=========+=========+============+========+============+====================================+
  | 00     | Luimm5[4:0]   | src2    | src1    | 111        | dest   | 101 1011   | **cv.macuN rD, rs1, rs2, Is3**     |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 01     | Luimm5[4:0]   | src2    | src1    | 111        | dest   | 101 1011   | **cv.machhuN rD, rs1, rs2, Is3**   |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 00     | Luimm5[4:0]   | src2    | src1    | 110        | dest   | 101 1011   | **cv.macsN rD, rs1, rs2, Is3**     |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 01     | Luimm5[4:0]   | src2    | src1    | 110        | dest   | 101 1011   | **cv.machhsN rD, rs1, rs2, Is3**   |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 10     | Luimm5[4:0]   | src2    | src1    | 111        | dest   | 101 1011   | **cv.macuRN rD, rs1, rs2, Is3**    |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 11     | Luimm5[4:0]   | src2    | src1    | 111        | dest   | 101 1011   | **cv.machhuRN rD, rs1, rs2, Is3**  |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 10     | Luimm5[4:0]   | src2    | src1    | 110        | dest   | 101 1011   | **cv.macsRN rD, rs1, rs2, Is3**    |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+
  | 11     | Luimm5[4:0]   | src2    | src1    | 110        | dest   | 101 1011   | **cv.machhsRN rD, rs1, rs2, Is3**  |
  +--------+---------------+---------+---------+------------+--------+------------+------------------------------------+

.. table:: 32-Bit x 32-Bit Multiply-Accumulate encoding
  :name: 32-Bit x 32-Bit Multiply-Accumulate encoding
  :widths: 21 6 6 9 6 11 39
  :class: no-scrollbar-table

  +------------+---------+---------+------------+--------+------------+--------------------------+
  | 31   :  25 | 24 : 20 | 19 : 15 | 14   :  12 | 11 : 7 | 6   :    0 |                          |
  +------------+---------+---------+------------+--------+------------+--------------------------+
  | **funct7** | **rs2** | **rs1** | **funct3** | **rD** | **opcode** |                          |
  +============+=========+=========+============+========+============+==========================+
  | 100 1000   | src2    | src1    | 011        | dest   | 010 1011   | **cv.mac rD, rs1, rs2**  |
  +------------+---------+---------+------------+--------+------------+--------------------------+
  | 100 1001   | src2    | src1    | 011        | dest   | 010 1011   | **cv.msu rD, rs1, rs2**  |
  +------------+---------+---------+------------+--------+------------+--------------------------+

.. _corev_simd:

SIMD
----

The SIMD instructions perform operations on multiple sub-word elements at the same time. This is done by segmenting
the data path into smaller parts when 8- or 16-bit operations should be performed.

The custom SIMD extensions are only supported if ``COREV_PULP`` == 1.

.. note::

  See the comments at the start of :ref:`custom-isa-extensions` on availability of the compiler tool chains.
  Support for SIMD will be primarily through assembly code and builtin functions, with no auto-vectorization and limited other optimization.
  Simple auto-vectorization (add, sub...) and optimization will be evaluated once a stable GCC toolchain is available.

SIMD instructions are available in two flavors:

-  8-Bit, to perform four operations on the 4 bytes inside a 32-bit word
   at the same time (.b)

-  16-Bit, to perform two operations on the 2 half-words inside a 32-bit
   word at the same time (.h)

All the operations are rounded to the specified bidwidth as for the original
RISC-V arithmetic operations. This is described by the "and" operation with a
MASK. No overflow or carry-out flags are generated as for the 32-bit operations.

Additionally, there are three modes that influence the second operand:

1. Normal mode, vector-vector operation. Both operands, from rs1 and
   rs2, are treated as vectors of bytes or half-words.

   e.g. cv.add.h x3,x2,x1 performs:

    x3[31:16] = x2[31:16] + x1[31:16]

    x3[15: 0] = x2[15: 0] + x1[15: 0]

2. Scalar replication mode (.sc), vector-scalar operation. Operand 1 is
   treated as a vector, while operand 2 is treated as a scalar and
   replicated two or four times to form a complete vector. The LSP is
   used for this purpose.

   e.g. cv.add.sc.h x3,x2,x1 performs:

    x3[31:16] = x2[31:16] + x1[15: 0]

    x3[15: 0] = x2[15: 0] + x1[15: 0]

3. Immediate scalar replication mode (.sci), vector-scalar operation.
   Operand 1 is treated as vector, while operand 2 is treated as a
   scalar and comes from a 6-bit immediate.

   The immediate is either sign- or zero-extended depending on the operation.
   If not specified, the immediate is sign-extended with the exception
   of all cv.shuffle* where it is always unsigned.

   e.g. cv.add.sci.h x3,x2,-22 performs:

    x3[31:16] = x2[31:16] + 0xFFEA

    x3[15: 0] = x2[15: 0] + 0xFFEA

And finally for all the SIMD Bit Manipulation instructions, Imm6 is zero-extended.

In the following tables, the index i ranges from 0 to 1 for 16-Bit operations and from 0 to 3 for 8-Bit operations:

- The index 0 is 15:0  for 16-Bit operations or 7:0 for 8-Bit operations.

- The index 1 is 31:16 for 16-Bit operations or 15:8 for 8-Bit operations.

- The index 2 is 23:16 for 8-Bit operations.

- The index 3 is 31:24 for 8-Bit operations.

And I5, I4, I3, I2, I1 and I0 respectively represent bits 5, 4, 3, 2, 1 and 0 of the immediate value.

SIMD ALU operations
^^^^^^^^^^^^^^^^^^^

.. table:: SIMD ALU operations
  :name: SIMD ALU operations
  :widths: 50 50
  :class: no-scrollbar-table

  +------------------------------------------------------------+------------------------------------------------------------------+
  | **Mnemonic**                                               | **Description**                                                  |
  +============================================================+==================================================================+
  | **cv.add[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = (rs1[i] + op2[i]) & {0xFFFF, 0xFF}                       |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.sub[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = (rs1[i] - op2[i]) & {0xFFFF, 0xFF}                       |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.avg[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = ((rs1[i] + op2[i]) & {0xFFFF, 0xFF}) >> 1                |
  |                                                            |                                                                  |
  |                                                            | Note: Arithmetic right shift.                                    |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.avgu[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**          | rD[i] = ((rs1[i] + op2[i]) & {0xFFFF, 0xFF}) >> 1                |
  |                                                            |                                                                  |
  |                                                            | Note: Immediate is zero-extended, shift is logical.              |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.min[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] < op2[i] ? rs1[i] : op2[i]                        |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.minu[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**          | rD[i] = rs1[i] < op2[i] ? rs1[i] : op2[i]                        |
  |                                                            |                                                                  |
  |                                                            | Note: Immediate is zero-extended, comparison is unsigned.        |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.max[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] > op2[i] ? rs1[i] : op2[i]                        |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.maxu[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**          | rD[i] = rs1[i] > op2[i] ? rs1[i] : op2[i]                        |
  |                                                            |                                                                  |
  |                                                            | Note: Immediate is zero-extended, comparison is unsigned.        |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.srl[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] >> op2[i]                                         |
  |                                                            |                                                                  |
  |                                                            | Note: Immediate is zero-extended, shift is logical.              |
  |                                                            |                                                                  |
  |                                                            | Only Imm6[3:0] and rs2[3:0] are used for .h instruction and      |
  |                                                            | Imm6[2:0] and rs2[2:0] for .b instruction.                       |
  |                                                            |                                                                  |
  |                                                            | In .sci case, unused Imm6 bits must be set to 0.                 |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.sra[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] >>> op2[i]                                        |
  |                                                            |                                                                  |
  |                                                            | Note: Immediate is zero-extended, shift is arithmetic.           |
  |                                                            |                                                                  |
  |                                                            | Only Imm6[3:0] and rs2[3:0] are used for .h instruction and      |
  |                                                            | Imm6[2:0] and rs2[2:0] for .b instruction.                       |
  |                                                            |                                                                  |
  |                                                            | In .sci case, unused Imm6 bits must be set to 0.                 |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.sll[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] << op2[i]                                         |
  |                                                            |                                                                  |
  |                                                            | Note: Immediate is zero-extended, shift is logical.              |
  |                                                            |                                                                  |
  |                                                            | Only Imm6[3:0] and rs2[3:0] are used for .h instruction and      |
  |                                                            | Imm6[2:0] and rs2[2:0] for .b instruction.                       |
  |                                                            |                                                                  |
  |                                                            | In .sci case, unused Imm6 bits must be set to 0.                 |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.or[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**            | rD[i] = rs1[i] \| op2[i]                                         |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.xor[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] ^ op2[i]                                          |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.and[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] & op2[i]                                          |
  +------------------------------------------------------------+------------------------------------------------------------------+
  | **cv.abs{.h,.b} rD, rs1**                                  | rD[i] = rs1[i] < 0 ? -rs1[i] : rs1[i]                            |
  +------------------------------------------------------------+------------------------------------------------------------------+

SIMD Bit Manipulation operations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. table:: SIMD Bit Manipulation operations
  :name: SIMD Bit Manipulation operations
  :widths: 50 50
  :class: no-scrollbar-table

  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **Mnemonic**                          | **Description**                                                                       |
  +=======================================+=======================================================================================+
  | **cv.extract.h rD, rs1, Imm6**        | rD = Sext(rs1[I0\*16+15:I0\*16])                                                      |
  |                                       |                                                                                       |
  |                                       | Note: Only Imm6[0] bit is used and other Imm6 bits must be set to 0.                  |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.extract.b rD, rs1, Imm6**        | rD = Sext(rs1[(I1:I0)\*8+7:(I1:I0)\*8])                                               |
  |                                       |                                                                                       |
  |                                       | Note: Only Imm6[1:0] bits are used and other Imm6 bits must be set to 0.              |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.extractu.h rD, rs1, Imm6**       | rD = Zext(rs1[I0\*16+15:I0\*16])                                                      |
  |                                       |                                                                                       |
  |                                       | Note: Only Imm6[0] bit is used and other Imm6 bits must be set to 0.                  |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.extractu.b rD, rs1, Imm6**       | rD = Zext(rs1[(I1:I0)\*8+7:(I1:I0)\*8])                                               |
  |                                       |                                                                                       |
  |                                       | Note: Only Imm6[1:0] bits are used and other Imm6 bits must be set to 0.              |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.insert.h rD, rs1, Imm6**         | rD[I0\*16+15:I0\*16] = rs1[15:0]                                                      |
  |                                       |                                                                                       |
  |                                       | Note: The rest of the bits of rD are untouched and keep their previous value.         |
  |                                       |                                                                                       |
  |                                       | Only Imm6[0] bit is used and other Imm6 bits must be set to 0.                        |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.insert.b rD, rs1, Imm6**         | rD[(I1:I0)\*8+7:(I1:I0)\*8] = rs1[7:0]                                                |
  |                                       |                                                                                       |
  |                                       | Note: The rest of the bits of rD are untouched and keep their previous value.         |
  |                                       |                                                                                       |
  |                                       | Only Imm6[1:0] bits are used and other Imm6 bits must be set to 0.                    |
  +---------------------------------------+---------------------------------------------------------------------------------------+

SIMD Dot Product operations
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. table:: SIMD Dot Product operations
  :name: SIMD Dot Product operations
  :widths: 50 50
  :class: no-scrollbar-table

  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **Mnemonic**                                               | **Description**                                                                       |
  +============================================================+=======================================================================================+
  | **cv.dotup[.sc,.sci].h rD, rs1, [rs2, Imm6]**              | rD = rs1[0] \* op2[0] + rs1[1] \* op2[1]                                              |
  |                                                            |                                                                                       |
  |                                                            | Note: All operands are unsigned.                                                      |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.dotup[.sc,.sci].b rD, rs1, [rs2, Imm6]**              | rD = rs1[0] \* op2[0] + rs1[1] \* op2[1] +                                            |
  |                                                            |                                                                                       |
  |                                                            | rs1[2] \* op2[2] + rs1[3] \* op2[3]                                                   |
  |                                                            |                                                                                       |
  |                                                            | Note: All operands are unsigned.                                                      |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.dotusp[.sc,.sci].h rD, rs1, [rs2, Imm6]**             | rD = rs1[0] \* op2[0] + rs1[1] \* op2[1]                                              |
  |                                                            |                                                                                       |
  |                                                            | Note: rs1 is treated as unsigned, while op2 is treated as signed.                     |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.dotusp[.sc,.sci].b rD, rs1, [rs2, Imm6]**             | rD = rs1[0] \* op2[0] + rs1[1] \* op2[1] +                                            |
  |                                                            |                                                                                       |
  |                                                            | rs1[2] \* op2[2] + rs1[3] \* op2[3]                                                   |
  |                                                            |                                                                                       |
  |                                                            | Note: rs1 is treated as unsigned, while op2 is treated as signed.                     |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.dotsp[.sc,.sci].h rD, rs1, [rs2, Imm6]**              | rD = rs1[0] \* op2[0] + rs1[1] \* op2[1]                                              |
  |                                                            |                                                                                       |
  |                                                            | Note: All operands are signed.                                                        |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.dotsp[.sc,.sci].b rD, rs1, [rs2, Imm6]**              | rD = rs1[0] \* op2[0] + rs1[1] \* op2[1] +                                            |
  |                                                            |                                                                                       |
  |                                                            | rs1[2] \* op2[2] + rs1[3] \* op2[3]                                                   |
  |                                                            |                                                                                       |
  |                                                            | Note: All operands are signed.                                                        |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.sdotup[.sc,.sci].h rD, rs1, [rs2, Imm6]**             | rD = rD + rs1[0] \* op2[0] + rs1[1] \* op2[1]                                         |
  |                                                            |                                                                                       |
  |                                                            | Note: All operands are unsigned.                                                      |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.sdotup[.sc,.sci].b rD, rs1, [rs2, Imm6]**             | rD = rD + rs1[0] \* op2[0] + rs1[1] \* op2[1] +                                       |
  |                                                            |                                                                                       |
  |                                                            | rs1[2] \* op2[2] + rs1[3] \* op2[3]                                                   |
  |                                                            |                                                                                       |
  |                                                            | Note: All operands are unsigned.                                                      |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.sdotusp[.sc,.sci].h rD, rs1, [rs2, Imm6]**            | rD = rD + rs1[0] \* op2[0] + rs1[1] \* op2[1]                                         |
  |                                                            |                                                                                       |
  |                                                            | Note: rs1 is treated as unsigned while op2 is treated as signed.                      |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.sdotusp[.sc,.sci].b rD, rs1, [rs2, Imm6]**            | rD = rD + rs1[0] \* op2[0] + rs1[1] \* op2[1] +                                       |
  |                                                            |                                                                                       |
  |                                                            | rs1[2] \* op2[2] + rs1[3] \* op2[3]                                                   |
  |                                                            |                                                                                       |
  |                                                            | Note: rs1 is treated as unsigned while op2 is treated as signed.                      |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.sdotsp[.sc,.sci].h rD, rs1, [rs2, Imm6]**             | rD = rD + rs1[0] \* op2[0] + rs1[1] \* op2[1]                                         |
  |                                                            |                                                                                       |
  |                                                            | Note: All operands are signed.                                                        |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.sdotsp[.sc,.sci].b rD, rs1, [rs2, Imm6]**             | rD = rD + rs1[0] \* op2[0] + rs1[1] \* op2[1] +                                       |
  |                                                            |                                                                                       |
  |                                                            | rs1[2] \* op2[2] + rs1[3] \* op2[3]                                                   |
  |                                                            |                                                                                       |
  |                                                            | Note: All operands are signed.                                                        |
  +------------------------------------------------------------+---------------------------------------------------------------------------------------+

SIMD Shuffle and Pack operations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. table:: SIMD Shuffle and Pack operations
  :name: SIMD Shuffle and Pack operations
  :widths: 35 65
  :class: no-scrollbar-table

  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **Mnemonic**                          | **Description**                                                                       |
  +=======================================+=======================================================================================+
  | **cv.shuffle.h rD, rs1, rs2**         | rD[31:16] = rs1[rs2[16]\*16+15:rs2[16]\*16]                                           |
  |                                       |                                                                                       |
  |                                       | rD[15:0] = rs1[rs2[0]\*16+15:rs2[0]\*16]                                              |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.shuffle.sci.h rD, rs1, Imm6**    | rD[31:16] = rs1[I1\*16+15:I1\*16]                                                     |
  |                                       |                                                                                       |
  |                                       | rD[15:0] = rs1[I0\*16+15:I0\*16]                                                      |
  |                                       |                                                                                       |
  |                                       | Note: Only Imm6[1:0] bits are used and other Imm6 bits must be set to 0.              |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.shuffle.b rD, rs1, rs2**         | rD[31:24] = rs1[rs2[25:24]\*8+7:rs2[25:24]\*8]                                        |
  |                                       |                                                                                       |
  |                                       | rD[23:16] = rs1[rs2[17:16]\*8+7:rs2[17:16]\*8]                                        |
  |                                       |                                                                                       |
  |                                       | rD[15:8] = rs1[rs2[9:8]\*8+7:rs2[9:8]\*8]                                             |
  |                                       |                                                                                       |
  |                                       | rD[7:0] = rs1[rs2[1:0]\*8+7:rs2[1:0]\*8]                                              |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.shuffleI0.sci.b rD, rs1, Imm6**  | rD[31:24] = rs1[7:0]                                                                  |
  |                                       |                                                                                       |
  |                                       | rD[23:16] = rs1[(I5:I4)\*8+7: (I5:I4)\*8]                                             |
  |                                       |                                                                                       |
  |                                       | rD[15:8] = rs1[(I3:I2)\*8+7: (I3:I2)\*8]                                              |
  |                                       |                                                                                       |
  |                                       | rD[7:0] = rs1[(I1:I0)\*8+7:(I1:I0)\*8]                                                |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.shuffleI1.sci.b rD, rs1, Imm6**  | rD[31:24] = rs1[15:8]                                                                 |
  |                                       |                                                                                       |
  |                                       | rD[23:16] = rs1[(I5:I4)\*8+7: (I5:I4)\*8]                                             |
  |                                       |                                                                                       |
  |                                       | rD[15:8] = rs1[(I3:I2)\*8+7: (I3:I2)\*8]                                              |
  |                                       |                                                                                       |
  |                                       | rD[7:0] = rs1[(I1:I0)\*8+7:(I1:I0)\*8]                                                |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.shuffleI2.sci.b rD, rs1, Imm6**  | rD[31:24] = rs1[23:16]                                                                |
  |                                       |                                                                                       |
  |                                       | rD[23:16] = rs1[(I5:I4)\*8+7: (I5:I4)\*8]                                             |
  |                                       |                                                                                       |
  |                                       | rD[15:8] = rs1[(I3:I2)\*8+7: (I3:I2)\*8]                                              |
  |                                       |                                                                                       |
  |                                       | rD[7:0] = rs1[(I1:I0)\*8+7:(I1:I0)\*8]                                                |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.shuffleI3.sci.b rD, rs1, Imm6**  | rD[31:24] = rs1[31:24]                                                                |
  |                                       |                                                                                       |
  |                                       | rD[23:16] = rs1[(I5:I4)\*8+7: (I5:I4)\*8]                                             |
  |                                       |                                                                                       |
  |                                       | rD[15:8] = rs1[(I3:I2)\*8+7: (I3:I2)\*8]                                              |
  |                                       |                                                                                       |
  |                                       | rD[7:0] = rs1[(I1:I0)\*8+7:(I1:I0)\*8]                                                |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.shuffle2.h rD, rs1, rs2**        | rD[31:16] = ((rs2[17] == 1) ? rs1 : rD)[rs2[16]\*16+15:rs2[16]\*16]                   |
  |                                       |                                                                                       |
  |                                       | rD[15:0] = ((rs2[1] == 1) ? rs1 : rD)[rs2[0]\*16+15:rs2[0]\*16]                       |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.shuffle2.b rD, rs1, rs2**        | rD[31:24] = ((rs2[26] == 1) ? rs1 : rD)[rs2[25:24]\*8+7:rs2[25:24]\*8]                |
  |                                       |                                                                                       |
  |                                       | rD[23:16] = ((rs2[18] == 1) ? rs1 : rD)[rs2[17:16]\*8+7:rs2[17:16]\*8]                |
  |                                       |                                                                                       |
  |                                       | rD[15:8] = ((rs2[10] == 1) ? rs1 : rD)[rs2[9:8]\*8+7:rs2[9:8]\*8]                     |
  |                                       |                                                                                       |
  |                                       | rD[7:0] = ((rs2[2] == 1) ? rs1 : rD)[rs2[1:0]\*8+7:rs2[1:0]\*8]                       |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.pack rD, rs1, rs2**              | rD[31:16] = rs1[15:0]                                                                 |
  |                                       |                                                                                       |
  |                                       | rD[15:0] = rs2[15:0]                                                                  |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.pack.h rD, rs1, rs2**            | rD[31:16] = rs1[31:16]                                                                |
  |                                       |                                                                                       |
  |                                       | rD[15:0] = rs2[31:16]                                                                 |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.packhi.b rD, rs1, rs2**          | rD[31:24] = rs1[7:0]                                                                  |
  |                                       |                                                                                       |
  |                                       | rD[23:16] = rs2[7:0]                                                                  |
  |                                       |                                                                                       |
  |                                       | Note: The rest of the bits of rD are untouched and keep their previous value.         |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.packlo.b rD, rs1, rs2**          | rD[15:8] = rs1[7:0]                                                                   |
  |                                       |                                                                                       |
  |                                       | rD[7:0] = rs2[7:0]                                                                    |
  |                                       |                                                                                       |
  |                                       | Note: The rest of the bits of rD are untouched and keep their previous value.         |
  +---------------------------------------+---------------------------------------------------------------------------------------+

SIMD ALU Encoding
~~~~~~~~~~~~~~~~~

.. table:: SIMD ALU encoding
  :name: SIMD ALU encoding
  :widths: 11 4 4 13 7 8 8 13 32
  :class: no-scrollbar-table

  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 31  : 27   | 26    | 25 | 24 : 20          | 19 : 15 | 14  :   12 | 11  :  7 | 6    :   0 |                                      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | **funct5** | **F** |    | **rs2**          | **rs1** | **funct3** | **rD**   | **opcode** |                                      |
  +============+=======+====+==================+=========+============+==========+============+======================================+
  | 0 0000     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.add.h rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0000     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.add.sc.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0000     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.add.sci.h rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0000     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.add.b rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0000     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.add.sc.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0000     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.add.sci.b rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0001     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.sub.h rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0001     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.sub.sc.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0001     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.sub.sci.h rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0001     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.sub.b rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0001     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.sub.sc.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0001     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.sub.sci.b rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0010     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.avg.h rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0010     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.avg.sc.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0010     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.avg.sci.h rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0010     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.avg.b rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0010     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.avg.sc.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0010     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.avg.sci.b rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0011     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.avgu.h rD, rs1, rs2**           |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0011     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.avgu.sc.h rD, rs1, rs2**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0011     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.avgu.sci.h rD, rs1, Imm6**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0011     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.avgu.b rD, rs1, rs2**           |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0011     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.avgu.sc.b rD, rs1, rs2**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0011     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.avgu.sci.b rD, rs1, Imm6**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0100     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.min.h rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0100     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.min.sc.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0100     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.min.sci.h rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0100     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.min.b rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0100     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.min.sc.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0100     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.min.sci.b rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0101     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.minu.h rD, rs1, rs2**           |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0101     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.minu.sc.h rD, rs1, rs2**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0101     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.minu.sci.h rD, rs1, Imm6**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0101     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.minu.b rD, rs1, rs2**           |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0101     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.minu.sc.b rD, rs1, rs2**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0101     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.minu.sci.b rD, rs1, Imm6**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0110     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.max.h rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0110     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.max.sc.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0110     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.max.sci.h rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0110     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.max.b rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0110     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.max.sc.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0110     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.max.sci.b rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0111     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.maxu.h rD, rs1, rs2**           |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0111     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.maxu.sc.h rD, rs1, rs2**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0111     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.maxu.sci.h rD, rs1, Imm6**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0111     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.maxu.b rD, rs1, rs2**           |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0111     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.maxu.sc.b rD, rs1, rs2**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 0111     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.maxu.sci.b rD, rs1, Imm6**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1000     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.srl.h rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1000     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.srl.sc.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1000     | 0     | Imm6[0] 00 Imm6[3:1]  | src1    | 110        | dest     | 111 1011   | **cv.srl.sci.h rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1000     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.srl.b rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1000     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.srl.sc.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1000     | 0     | Imm6[0] 000 Imm6[2:1] | src1    | 111        | dest     | 111 1011   | **cv.srl.sci.b rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1001     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.sra.h rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1001     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.sra.sc.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1001     | 0     | Imm6[0] 00 Imm6[3:1]  | src1    | 110        | dest     | 111 1011   | **cv.sra.sci.h rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1001     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.sra.b rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1001     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.sra.sc.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1001     | 0     | Imm6[0] 000 Imm6[2:1] | src1    | 111        | dest     | 111 1011   | **cv.sra.sci.b rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1010     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.sll.h rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1010     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.sll.sc.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1010     | 0     | Imm6[0] 00 Imm6[3:1]  | src1    | 110        | dest     | 111 1011   | **cv.sll.sci.h rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1010     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.sll.b rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1010     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.sll.sc.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1010     | 0     | Imm6[0] 000 Imm6[2:1] | src1    | 111        | dest     | 111 1011   | **cv.sll.sci.b rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1011     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.or.h rD, rs1, rs2**             |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1011     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.or.sc.h rD, rs1, rs2**          |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1011     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.or.sci.h rD, rs1, Imm6**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1011     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.or.b rD, rs1, rs2**             |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1011     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.or.sc.b rD, rs1, rs2**          |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1011     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.or.sci.b rD, rs1, Imm6**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1100     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.xor.h rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1100     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.xor.sc.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1100     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.xor.sci.h rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1100     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.xor.b rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1100     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.xor.sc.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1100     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.xor.sci.b rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1101     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.and.h rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1101     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.and.sc.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1101     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.and.sci.h rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1101     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.and.b rD, rs1, rs2**            |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1101     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.and.sc.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1101     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.and.sci.b rD, rs1, Imm6**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1110     | 0     | 0  | 0                | src1    | 000        | dest     | 111 1011   | **cv.abs.h rD, rs1**                 |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 0 1110     | 0     | 0  | 0                | src1    | 001        | dest     | 111 1011   | **cv.abs.b rD, rs1**                 |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0111     | 0     | Imm6[0] 00000         | src1    | 000        | dest     | 111 1011   | **cv.extract.h rD, rs1, Imm6**       |
  +------------+-------+-----------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0111     | 0     | Imm6[0] 0000 Imm6[1]  | src1    | 001        | dest     | 111 1011   | **cv.extract.b rD, rs1, Imm6**       |
  +------------+-------+-----------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0111     | 0     | Imm6[0] 00000         | src1    | 010        | dest     | 111 1011   | **cv.extractu.h rD, rs1, Imm6**      |
  +------------+-------+-----------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0111     | 0     | Imm6[0] 0000 Imm6[1]  | src1    | 011        | dest     | 111 1011   | **cv.extractu.b rD, rs1, Imm6**      |
  +------------+-------+-----------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0111     | 0     | Imm6[0] 00000         | src1    | 100        | dest     | 111 1011   | **cv.insert.h rD, rs1, Imm6**        |
  +------------+-------+-----------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0111     | 0     | Imm6[0] 0000 Imm6[1]  | src1    | 101        | dest     | 111 1011   | **cv.insert.b rD, rs1, Imm6**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0000     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.dotup.h rD, rs1, rs2**          |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0000     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.dotup.sc.h rD, rs1, rs2**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0000     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.dotup.sci.h rD, rs1, Imm6**     |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0000     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.dotup.b rD, rs1, rs2**          |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0000     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.dotup.sc.b rD, rs1, rs2**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0000     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.dotup.sci.b rD, rs1, Imm6**     |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0001     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.dotusp.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0001     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.dotusp.sc.h rD, rs1, rs2**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0001     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.dotusp.sci.h rD, rs1, Imm6**    |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0001     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.dotusp.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0001     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.dotusp.sc.b rD, rs1, rs2**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0001     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.dotusp.sci.b rD, rs1, Imm6**    |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0010     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.dotsp.h rD, rs1, rs2**          |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0010     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.dotsp.sc.h rD, rs1, rs2**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0010     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.dotsp.sci.h rD, rs1, Imm6**     |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0010     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.dotsp.b rD, rs1, rs2**          |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0010     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.dotsp.sc.b rD, rs1, rs2**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0010     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.dotsp.sci.b rD, rs1, Imm6**     |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0011     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.sdotup.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0011     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.sdotup.sc.h rD, rs1, rs2**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0011     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.sdotup.sci.h rD, rs1, Imm6**    |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0011     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.sdotup.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0011     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.sdotup.sc.b rD, rs1, rs2**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0011     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.sdotup.sci.b rD, rs1, Imm6**    |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0100     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.sdotusp.h rD, rs1, rs2**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0100     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.sdotusp.sc.h rD, rs1, rs2**     |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0100     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.sdotusp.sci.h rD, rs1, Imm6**   |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0100     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.sdotusp.b rD, rs1, rs2**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0100     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.sdotusp.sc.b rD, rs1, rs2**     |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0100     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.sdotusp.sci.b rD, rs1, Imm6**   |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0101     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.sdotsp.h rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0101     | 0     | 0  | src2             | src1    | 100        | dest     | 111 1011   | **cv.sdotsp.sc.h rD, rs1, rs2**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0101     | 0     | Imm6[0\|5:1]          | src1    | 110        | dest     | 111 1011   | **cv.sdotsp.sci.h rD, rs1, Imm6**    |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0101     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.sdotsp.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0101     | 0     | 0  | src2             | src1    | 101        | dest     | 111 1011   | **cv.sdotsp.sc.b rD, rs1, rs2**      |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 0101     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.sdotsp.sci.b rD, rs1, Imm6**    |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1000     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.shuffle.h rD, rs1, rs2**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1000     | 0     | Imm6[0] 0000 Imm6[1]  | src1    | 110        | dest     | 111 1011   | **cv.shuffle.sci.h rD, rs1, Imm6**   |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1000     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.shuffle.b rD, rs1, rs2**        |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1000     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.shuffleI0.sci.b rD, rs1, Imm6** |
  +------------+-------+-----------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1001     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.shuffleI1.sci.b rD, rs1, Imm6** |
  +------------+-------+-----------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1010     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.shuffleI2.sci.b rD, rs1, Imm6** |
  +------------+-------+-----------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1011     | 0     | Imm6[0\|5:1]          | src1    | 111        | dest     | 111 1011   | **cv.shuffleI3.sci.b rD, rs1, Imm6** |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1100     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.shuffle2.h rD, rs1, rs2**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1100     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.shuffle2.b rD, rs1, rs2**       |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1110     | 0     | 0  | src2             | src1    | 000        | dest     | 111 1011   | **cv.pack rD, rs1, rs2**             |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1110     | 0     | 1  | src2             | src1    | 000        | dest     | 111 1011   | **cv.pack.h rD, rs1, rs2**           |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1111     | 0     | 1  | src2             | src1    | 001        | dest     | 111 1011   | **cv.packhi.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+
  | 1 1111     | 0     | 0  | src2             | src1    | 001        | dest     | 111 1011   | **cv.packlo.b rD, rs1, rs2**         |
  +------------+-------+----+------------------+---------+------------+----------+------------+--------------------------------------+


SIMD Comparison operations
^^^^^^^^^^^^^^^^^^^^^^^^^^

SIMD comparisons are done on individual bytes (.b) or half-words
(.h), depending on the chosen mode. If the comparison result is true,
all bits in the corresponding byte/half-word are set to 1. If the
comparison result is false, all bits are set to 0.

The default mode (no .sc, .sci) compares the lowest byte/half-word of
the first operand with the lowest byte/half-word of the second operand,
and so on. If the mode is set to scalar replication (.sc), always the
lowest byte/half-word of the second operand is used for comparisons,
thus instead of a vector comparison a scalar comparison is performed. In
the immediate scalar replication mode (.sci), the immediate given to the
instruction is used for the comparison.

.. table:: SIMD Comparison operations
  :name: SIMD Comparison operations
  :widths: 50 50
  :class: no-scrollbar-table

  +---------------------------------------------------------------+-----------------------------------+
  | **Mnemonic**                                                  | **Description**                   |
  +===============================================================+===================================+
  | **cv.cmpeq[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**            | rD[i] = rs1[i] == op2 ? '1 : '0   |
  +---------------------------------------------------------------+-----------------------------------+
  | **cv.cmpne[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**            | rD[i] = rs1[i] != op2 ? '1 : '0   |
  +---------------------------------------------------------------+-----------------------------------+
  | **cv.cmpgt[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**            | rD[i] = rs1[i] > op2 ? '1 : '0    |
  +---------------------------------------------------------------+-----------------------------------+
  | **cv.cmpge[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**            | rD[i] = rs1[i] >=op2 ? '1 : '0    |
  +---------------------------------------------------------------+-----------------------------------+
  | **cv.cmplt[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**            | rD[i] = rs1[i] < op2 ? '1 : '0    |
  +---------------------------------------------------------------+-----------------------------------+
  | **cv.cmple[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**            | rD[i] = rs1[i] <= op2 ? '1 : '0   |
  +---------------------------------------------------------------+-----------------------------------+
  | **cv.cmpgtu[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] > op2 ? '1 : '0    |
  |                                                               |                                   |
  |                                                               | Note: Unsigned comparison.        |
  +---------------------------------------------------------------+-----------------------------------+
  | **cv.cmpgeu[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] >= op2 ? '1 : '0   |
  |                                                               |                                   |
  |                                                               | Note: Unsigned comparison.        |
  +---------------------------------------------------------------+-----------------------------------+
  | **cv.cmpltu[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] < op2 ? '1 : '0    |
  |                                                               |                                   |
  |                                                               | Note: Unsigned comparison.        |
  +---------------------------------------------------------------+-----------------------------------+
  | **cv.cmpleu[.sc,.sci]{.h,.b} rD, rs1, [rs2, Imm6]**           | rD[i] = rs1[i] <= op2 ? '1 : '0   |
  |                                                               |                                   |
  |                                                               | Note: Unsigned comparison.        |
  +---------------------------------------------------------------+-----------------------------------+

SIMD Comparison Encoding
^^^^^^^^^^^^^^^^^^^^^^^^

.. table:: SIMD Comparison encoding
  :name: SIMD Comparison encoding
  :widths: 11 4 4 9 7 8 8 13 36
  :class: no-scrollbar-table

  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 31  : 27   | 26    | 25 | 24 : 20 | 19 : 15 | 14  :   12 | 11  :  7 | 6    :   0 |                                   |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | **funct5** | **F** |    | **rs2** | **rs1** | **funct3** | **rD**   | **opcode** |                                   |
  +============+=======+====+=========+=========+============+==========+============+===================================+
  | 0 0000     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cmpeq.h rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0000     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cmpeq.sc.h rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0000     | 1     | Imm6[0\|5:1] | src1    | 110        | dest     | 111 1011   | **cv.cmpeq.sci.h rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0000     | 1     | 0  | src2    | src1    | 001        | dest     | 111 1011   | **cv.cmpeq.b rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0000     | 1     | 0  | src2    | src1    | 101        | dest     | 111 1011   | **cv.cmpeq.sc.b rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0000     | 1     | Imm6[0\|5:1] | src1    | 111        | dest     | 111 1011   | **cv.cmpeq.sci.b rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0001     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cmpne.h rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0001     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cmpne.sc.h rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0001     | 1     | Imm6[0\|5:1] | src1    | 110        | dest     | 111 1011   | **cv.cmpne.sci.h rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0001     | 1     | 0  | src2    | src1    | 001        | dest     | 111 1011   | **cv.cmpne.b rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0001     | 1     | 0  | src2    | src1    | 101        | dest     | 111 1011   | **cv.cmpne.sc.b rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0001     | 1     | Imm6[0\|5:1] | src1    | 111        | dest     | 111 1011   | **cv.cmpne.sci.b rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0010     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cmpgt.h rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0010     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cmpgt.sc.h rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0010     | 1     | Imm6[0\|5:1] | src1    | 110        | dest     | 111 1011   | **cv.cmpgt.sci.h rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0010     | 1     | 0  | src2    | src1    | 001        | dest     | 111 1011   | **cv.cmpgt.b rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0010     | 1     | 0  | src2    | src1    | 101        | dest     | 111 1011   | **cv.cmpgt.sc.b rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0010     | 1     | Imm6[0\|5:1] | src1    | 111        | dest     | 111 1011   | **cv.cmpgt.sci.b rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0011     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cmpge.h rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0011     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cmpge.sc.h rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0011     | 1     | Imm6[0\|5:1] | src1    | 110        | dest     | 111 1011   | **cv.cmpge.sci.h rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0011     | 1     | 0  | src2    | src1    | 001        | dest     | 111 1011   | **cv.cmpge.b rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0011     | 1     | 0  | src2    | src1    | 101        | dest     | 111 1011   | **cv.cmpge.sc.b rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0011     | 1     | Imm6[0\|5:1] | src1    | 111        | dest     | 111 1011   | **cv.cmpge.sci.b rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0100     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cmplt.h rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0100     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cmplt.sc.h rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0100     | 1     | Imm6[0\|5:1] | src1    | 110        | dest     | 111 1011   | **cv.cmplt.sci.h rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0100     | 1     | 0  | src2    | src1    | 001        | dest     | 111 1011   | **cv.cmplt.b rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0100     | 1     | 0  | src2    | src1    | 101        | dest     | 111 1011   | **cv.cmplt.sc.b rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0100     | 1     | Imm6[0\|5:1] | src1    | 111        | dest     | 111 1011   | **cv.cmplt.sci.b rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0101     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cmple.h rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0101     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cmple.sc.h rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0101     | 1     | Imm6[0\|5:1] | src1    | 110        | dest     | 111 1011   | **cv.cmple.sci.h rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0101     | 1     | 0  | src2    | src1    | 001        | dest     | 111 1011   | **cv.cmple.b rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0101     | 1     | 0  | src2    | src1    | 101        | dest     | 111 1011   | **cv.cmple.sc.b rD, rs1, rs2**    |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0101     | 1     | Imm6[0\|5:1] | src1    | 111        | dest     | 111 1011   | **cv.cmple.sci.b rD, rs1, Imm6**  |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0110     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cmpgtu.h rD, rs1, rs2**      |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0110     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cmpgtu.sc.h rD, rs1, rs2**   |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0110     | 1     | Imm6[0\|5:1] | src1    | 110        | dest     | 111 1011   | **cv.cmpgtu.sci.h rD, rs1, Imm6** |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0110     | 1     | 0  | src2    | src1    | 001        | dest     | 111 1011   | **cv.cmpgtu.b rD, rs1, rs2**      |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0110     | 1     | 0  | src2    | src1    | 101        | dest     | 111 1011   | **cv.cmpgtu.sc.b rD, rs1, rs2**   |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0110     | 1     | Imm6[0\|5:1] | src1    | 111        | dest     | 111 1011   | **cv.cmpgtu.sci.b rD, rs1, Imm6** |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0111     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cmpgeu.h rD, rs1, rs2**      |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0111     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cmpgeu.sc.h rD, rs1, rs2**   |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0111     | 1     | Imm6[0\|5:1] | src1    | 110        | dest     | 111 1011   | **cv.cmpgeu.sci.h rD, rs1, Imm6** |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0111     | 1     | 0  | src2    | src1    | 001        | dest     | 111 1011   | **cv.cmpgeu.b rD, rs1, rs2**      |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0111     | 1     | 0  | src2    | src1    | 101        | dest     | 111 1011   | **cv.cmpgeu.sc.b rD, rs1, rs2**   |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 0111     | 1     | Imm6[0\|5:1] | src1    | 111        | dest     | 111 1011   | **cv.cmpgeu.sci.b rD, rs1, Imm6** |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1000     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cmpltu.h rD, rs1, rs2**      |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1000     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cmpltu.sc.h rD, rs1, rs2**   |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1000     | 1     | Imm6[0\|5:1] | src1    | 110        | dest     | 111 1011   | **cv.cmpltu.sci.h rD, rs1, Imm6** |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1000     | 1     | 0  | src2    | src1    | 001        | dest     | 111 1011   | **cv.cmpltu.b rD, rs1, rs2**      |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1000     | 1     | 0  | src2    | src1    | 101        | dest     | 111 1011   | **cv.cmpltu.sc.b rD, rs1, rs2**   |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1000     | 1     | Imm6[0\|5:1] | src1    | 111        | dest     | 111 1011   | **cv.cmpltu.sci.b rD, rs1, Imm6** |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1001     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cmpleu.h rD, rs1, rs2**      |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1001     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cmpleu.sc.h rD, rs1, rs2**   |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1001     | 1     | Imm6[0\|5:1] | src1    | 110        | dest     | 111 1011   | **cv.cmpleu.sci.h rD, rs1, Imm6** |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1001     | 1     | 0  | src2    | src1    | 001        | dest     | 111 1011   | **cv.cmpleu.b rD, rs1, rs2**      |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1001     | 1     | 0  | src2    | src1    | 101        | dest     | 111 1011   | **cv.cmpleu.sc.b rD, rs1, rs2**   |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+
  | 0 1001     | 1     | Imm6[0\|5:1] | src1    | 111        | dest     | 111 1011   | **cv.cmpleu.sci.b rD, rs1, Imm6** |
  +------------+-------+----+---------+---------+------------+----------+------------+-----------------------------------+

SIMD Complex-number operations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

SIMD Complex-number operations are extra instructions
that uses the packed-SIMD extentions to represent Complex-numbers.
These extentions use only the half-words mode and only operand in registers.
A number C = {Re, Im} is represented as a vector of two 16-Bits signed numbers.
C[0] is the real part [15:0], C[1] is the
imaginary part [31:16].
Such operations are subtraction of 2 complexes with post rotation by -j, the complex and conjugate,
complex multiplications and complex additions/substractions.
The complex multiplications are performed in two separate instructions, one to compute the real part,
and one to compute the imaginary part.


As for all the other SIMD instructions, no flags are raised and CSR register are unmodified.
No carry, overflow is generated. Instructions are rounded up as the mask & 0xFFFF explicits.

.. table:: SIMD Complex-number operations
  :name: SIMD Complex-number operations
  :widths: 35 65
  :class: no-scrollbar-table

  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **Mnemonic**                          | **Description**                                                                       |
  +=======================================+=======================================================================================+
  | **cv.cplxmul.r{/,.div2,.div4,.div8}** | rD[1] = rD[1]                                                                         |
  |                                       |                                                                                       |
  |                                       | rD[0] = (rs1[0]\*rs2[0] - rs1[1]\*rs2[1]) >> {15,16,17,18}                            |
  |                                       |                                                                                       |
  |                                       | Note: Arithmetic shift right.                                                         |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.cplxmul.i{/,.div2,.div4,.div8}** | rD[1] = (rs1[0]\*rs2[1] + rs1[1]\*rs2[0]) >> {15,16,17,18}                            |
  |                                       |                                                                                       |
  |                                       | rD[0] = rD[0]                                                                         |
  |                                       |                                                                                       |
  |                                       | Note: Arithmetic shift right.                                                         |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.cplxconj**                       | rD[1] = -rs1[1]                                                                       |
  |                                       |                                                                                       |
  |                                       | rD[0] = rs1[0]                                                                        |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.subrotmj{/,.div2,.div4,.div8}**  | rD[1] = ((rs2[0] - rs1[0]) & 0xFFFF) >> {0,1,2,3}                                     |
  |                                       |                                                                                       |
  |                                       | rD[0] = ((rs1[1] - rs2[1]) & 0xFFFF) >> {0,1,2,3}                                     |
  |                                       |                                                                                       |
  |                                       | Note: Arithmetic shift right.                                                         |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.add{.div2,.div4,.div8}**         | rD[1] = ((rs1[1] + rs2[1]) & 0xFFFF) >> {1,2,3}                                       |
  |                                       |                                                                                       |
  |                                       | rD[0] = ((rs1[0] + rs2[0]) & 0xFFFF) >> {1,2,3}                                       |
  |                                       |                                                                                       |
  |                                       | Note: Arithmetic shift right.                                                         |
  +---------------------------------------+---------------------------------------------------------------------------------------+
  | **cv.sub{.div2,.div4,.div8}**         | rD[1] = ((rs1[1] - rs2[1]) & 0xFFFF) >> {1,2,3}                                       |
  |                                       |                                                                                       |
  |                                       | rD[0] = ((rs1[0] - rs2[0]) & 0xFFFF) >> {1,2,3}                                       |
  |                                       |                                                                                       |
  |                                       | Note: Arithmetic shift right.                                                         |
  +---------------------------------------+---------------------------------------------------------------------------------------+

SIMD Complex-number Encoding
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. table:: SIMD Complex-number encoding
  :name: SIMD Complex-number encoding
  :widths: 11 4 4 9 7 8 8 13 36
  :class: no-scrollbar-table

  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 31  : 27   | 26    | 25 | 24 : 20 | 19 : 15 | 14   :  12 | 11  :  7 | 6    :   0 |                                    |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | **funct5** | **F** |    | **rs2** | **rs1** | **funct3** | **rD**   | **opcode** |                                    |
  +============+=======+====+=========+=========+============+==========+============+====================================+
  | 0 1010     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cplxmul.r rD, rs1, rs2**      |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1010     | 1     | 0  | src2    | src1    | 010        | dest     | 111 1011   | **cv.cplxmul.r.div2 rD, rs1, rs2** |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1010     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cplxmul.r.div4 rD, rs1, rs2** |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1010     | 1     | 0  | src2    | src1    | 110        | dest     | 111 1011   | **cv.cplxmul.r.div8 rD, rs1, rs2** |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1010     | 1     | 1  | src2    | src1    | 000        | dest     | 111 1011   | **cv.cplxmul.i rD, rs1, rs2**      |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1010     | 1     | 1  | src2    | src1    | 010        | dest     | 111 1011   | **cv.cplxmul.i.div2 rD, rs1, rs2** |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1010     | 1     | 1  | src2    | src1    | 100        | dest     | 111 1011   | **cv.cplxmul.i.div4 rD, rs1, rs2** |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1010     | 1     | 1  | src2    | src1    | 110        | dest     | 111 1011   | **cv.cplxmul.i.div8 rD, rs1, rs2** |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1011     | 1     | 0  | 00000   | src1    | 000        | dest     | 111 1011   | **cv.cplxconj rD, rs1**            |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1100     | 1     | 0  | src2    | src1    | 000        | dest     | 111 1011   | **cv.subrotmj rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1100     | 1     | 0  | src2    | src1    | 010        | dest     | 111 1011   | **cv.subrotmj.div2 rD, rs1, rs2**  |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1100     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.subrotmj.div4 rD, rs1, rs2**  |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1100     | 1     | 0  | src2    | src1    | 110        | dest     | 111 1011   | **cv.subrotmj.div8 rD, rs1, rs2**  |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1101     | 1     | 0  | src2    | src1    | 010        | dest     | 111 1011   | **cv.add.div2 rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1101     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.add.div4 rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1101     | 1     | 0  | src2    | src1    | 110        | dest     | 111 1011   | **cv.add.div8 rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1110     | 1     | 0  | src2    | src1    | 010        | dest     | 111 1011   | **cv.sub.div2 rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1110     | 1     | 0  | src2    | src1    | 100        | dest     | 111 1011   | **cv.sub.div4 rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
  | 0 1110     | 1     | 0  | src2    | src1    | 110        | dest     | 111 1011   | **cv.sub.div8 rD, rs1, rs2**       |
  +------------+-------+----+---------+---------+------------+----------+------------+------------------------------------+
