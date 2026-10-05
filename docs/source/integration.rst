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

.. _core-integration:

Core Integration
================

The main module is named ``cv32e40p_top`` and can be found in ``cv32e40p_top.sv``.
Below, the instantiation template is given and the parameters and interfaces are described.

.. note::

  ``cv32e40p_top`` instantiates former ``cv32e40p_core`` and a wrapped ``fpnew_top``.
  It is highly suggested to use ``cv32e40p_top`` in place of ``cv32e40p_core`` as
  it allows to easily enable/disable FPU parameter with no interface change.
  As mentioned in :ref:`backward_compatibility`, v2.0.0 ``cv32e40p_core`` has **slight**
  modifications that makes it not backward compatible with v1.0.0 one in some cases.
  It is worth mentioning that if the core in its v1 version was/is instantiated without parameters setting,
  there is still backward compatibility as all parameters default value are set to v1 values.

Instantiation Template
----------------------

.. code-block:: verilog

  cv32e40p_top #(
      .FPU                      ( 0 ),
      .FPU_ADDMUL_LAT           ( 0 ),
      .FPU_OTHERS_LAT           ( 0 ),
      .ZFINX                    ( 0 ),
      .COREV_PULP               ( 0 ),
      .COREV_CLUSTER            ( 0 ),
      .NUM_MHPMCOUNTERS         ( 1 )
  ) u_core (
      // Clock and reset
      .rst_ni                   (),
      .clk_i                    (),
      .scan_cg_en_i             (),

      // Special control signals
      .fetch_enable_i           (),
      .pulp_clock_en_i          (),
      .core_sleep_o             (),

      // Configuration
      .boot_addr_i              (),
      .mtvec_addr_i             (),
      .dm_halt_addr_i           (),
      .dm_exception_addr_i      (),
      .hart_id_i                (),

      // Instruction memory interface
      .instr_addr_o             (),
      .instr_req_o              (),
      .instr_gnt_i              (),
      .instr_rvalid_i           (),
      .instr_rdata_i            (),

      // Data memory interface
      .data_addr_o              (),
      .data_req_o               (),
      .data_gnt_i               (),
      .data_we_o                (),
      .data_be_o                (),
      .data_wdata_o             (),
      .data_rvalid_i            (),
      .data_rdata_i             (),

       // Interrupt interface
      .irq_i                    (),
      .irq_ack_o                (),
      .irq_id_o                 (),

      // Debug interface
      .debug_req_i              (),
      .debug_havereset_o        (),
      .debug_running_o          (),
      .debug_halted_o           ()
  );

Parameters
----------

.. table:: Parameters
  :name: Parameters
  :widths: 25 15 11 49
  :class: no-scrollbar-table

  +------------------------------+----------------+-------------+------------------------------------------------------------------+
  | **Name**                     | **Type/Range** | **Default** | **Description**                                                  |
  +==============================+================+=============+==================================================================+
  | ``FPU``                      | bit            | 0           | Enable Floating Point Unit (FPU) support, see :ref:`fpu`         |
  +------------------------------+----------------+-------------+------------------------------------------------------------------+
  | ``FPU_ADDMUL_LAT``           | int            | 0           | Number of pipeline registers for Floating-Point                  |
  |                              |                |             | addition and multiplication instructions, see :ref:`fpu`         |
  +------------------------------+----------------+-------------+------------------------------------------------------------------+
  | ``FPU_OTHERS_LAT``           | int            | 0           | Number of pipeline registers for Floating-Point                  |
  |                              |                |             | comparison, conversion and classify instructions, see :ref:`fpu` |
  +------------------------------+----------------+-------------+------------------------------------------------------------------+
  | ``ZFINX``                    | bit            | 0           | Enable Floating Point instructions to use the General Purpose    |
  |                              |                |             | register file instead of requiring a dedicated Floating Point    |
  |                              |                |             | register file, see :ref:`fpu`. Only allowed to be set to 1       |
  |                              |                |             | if ``FPU`` = 1                                                   |
  +------------------------------+----------------+-------------+------------------------------------------------------------------+
  | ``COREV_PULP``               | bit            | 0           | Enable all of the custom PULP ISA extensions (except **cv.elw**) |
  |                              |                |             | (see :ref:`custom-isa-extensions`) and all custom CSRs           |
  |                              |                |             | (see :ref:`cs-registers`).                                       |
  |                              |                |             |                                                                  |
  |                              |                |             | Examples of PULP ISA                                             |
  |                              |                |             | extensions are post-incrementing load and stores                 |
  |                              |                |             | (see :ref:`corev_load_store`) and hardware loops                 |
  |                              |                |             | (see :ref:`corev_hardware_loop`).                                |
  |                              |                |             |                                                                  |
  +------------------------------+----------------+-------------+------------------------------------------------------------------+
  | ``COREV_CLUSTER``            | bit            | 0           | Enable PULP Cluster support (**cv.elw**), see :ref:`pulp_cluster`|
  +------------------------------+----------------+-------------+------------------------------------------------------------------+
  | ``NUM_MHPMCOUNTERS``         | int (0..29)    | 1           | Number of MHPMCOUNTER performance counters, see                  |
  |                              |                |             | :ref:`performance-counters`                                      |
  +------------------------------+----------------+-------------+------------------------------------------------------------------+

Interfaces
----------

.. table:: Interfaces
  :name: Interfaces
  :widths: 25 10 7 58
  :class: no-scrollbar-table

  +-------------------------+-------------------------+---------+--------------------------------------------+
  | **Signal**              | **Width**               | **Dir** | **Description**                            |
  +=========================+=========================+=========+============================================+
  | ``rst_ni``              | 1                       | in      | Active-low asynchronous reset              |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``clk_i``               | 1                       | in      | Clock signal                               |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``scan_cg_en_i``        | 1                       | in      | Scan clock gate enable. Design for test    |
  |                         |                         |         | (DfT) related signal. Can be used during   |
  |                         |                         |         | scan testing operation to force            |
  |                         |                         |         | instantiated clock gate(s) to be enabled.  |
  |                         |                         |         | This signal should be 0 during normal /    |
  |                         |                         |         | functional operation.                      |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``fetch_enable_i``      | 1                       | in      | Enable the instruction fetch of CV32E40P.  |
  |                         |                         |         | The first instruction fetch after reset    |
  |                         |                         |         | de-assertion will not happen as long as    |
  |                         |                         |         | this signal is 0. ``fetch_enable_i`` needs |
  |                         |                         |         | to be set to 1 for at least one cycle      |
  |                         |                         |         | while not in reset to enable fetching.     |
  |                         |                         |         | Once fetching has been enabled the value   |
  |                         |                         |         | ``fetch_enable_i`` is ignored.             |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``core_sleep_o``        | 1                       | out     | Core is sleeping, see :ref:`sleep_unit`.   |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``pulp_clock_en_i``     | 1                       | in      | PULP clock enable (only used when          |
  |                         |                         |         | ``COREV_CLUSTER`` = 1, tie to 0 otherwise),|
  |                         |                         |         | see :ref:`sleep_unit`                      |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``boot_addr_i``         | 32                      | in      | Boot address. First program counter after  |
  |                         |                         |         | reset = ``boot_addr_i``. Must be half-word |
  |                         |                         |         | aligned. Do not change after enabling core |
  |                         |                         |         | via ``fetch_enable_i``                     |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``mtvec_addr_i``        | 32                      | in      | ``mtvec`` address. Initial value for the   |
  |                         |                         |         | address part of :ref:`csr-mtvec`.          |
  |                         |                         |         | Do not change after enabling core          |
  |                         |                         |         | via ``fetch_enable_i``                     |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``dm_halt_addr_i``      | 32                      | in      | Address to jump to when entering Debug     |
  |                         |                         |         | Mode, see :ref:`debug-support`. Must be    |
  |                         |                         |         | word-aligned. Do not change after enabling |
  |                         |                         |         | core via ``fetch_enable_i``                |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``dm_exception_addr_i`` | 32                      | in      | Address to jump to when an exception       |
  |                         |                         |         | occurs when executing code during Debug    |
  |                         |                         |         | Mode, see :ref:`debug-support`. Must be    |
  |                         |                         |         | word-aligned. Do not change after enabling |
  |                         |                         |         | core via ``fetch_enable_i``                |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``hart_id_i``           | 32                      | in      | Hart ID, usually static, can be read from  |
  |                         |                         |         | :ref:`csr-mhartid` and :ref:`csr-uhartid`  |
  |                         |                         |         | CSRs                                       |
  +-------------------------+-------------------------+---------+--------------------------------------------+
  | ``instr_*``             | Instruction fetch interface, see :ref:`instruction-fetch`                      |
  +-------------------------+--------------------------------------------------------------------------------+
  | ``data_*``              | Load-store unit interface, see :ref:`load-store-unit`                          |
  +-------------------------+--------------------------------------------------------------------------------+
  | ``irq_*``               | Interrupt inputs, see :ref:`exceptions-interrupts`                             |
  +-------------------------+--------------------------------------------------------------------------------+
  | ``debug_*``             | Debug interface, see :ref:`debug-support`                                      |
  +-------------------------+-------------------------+---------+--------------------------------------------+

.. _clock-gating-cell:

Clock Gating Cell
-----------------

CV32E40P requires clock gating cells.
These cells are usually specific to the selected target technology and thus not provided as part of the RTL design.
A simulation-only version of the clock gating cell is provided in ``cv32e40p_sim_clock_gate.sv``. This file contains
a module called ``cv32e40p_clock_gate`` that has the following ports:

* ``clk_i``: Clock Input
* ``en_i``: Clock Enable Input
* ``scan_cg_en_i``: Scan Clock Gate Enable Input (activates the clock even though ``en_i`` is not set)
* ``clk_o``: Gated Clock Output

Inside CV32E40P, clock gating cells are used in both ``cv32e40p_sleep_unit.sv`` and ``cv32e40p_top.sv``.

The ``cv32e40p_sim_clock_gate.sv`` file is not intended for synthesis. For ASIC synthesis and FPGA synthesis the manifest
should be adapted to use a customer specific file that implements the ``cv32e40p_clock_gate`` module using design primitives
that are appropriate for the intended synthesis target technology.

.. _synthesis_guidelines:

Synthesis guidelines
--------------------

The CV32E40P core is fully synthesizable.
It has been designed mainly for ASIC designs, but FPGA synthesis is supported as well.

The top level module is called cv32e40p_top and includes both the core and the FPU.
All the core files are in ``rtl`` folder (all synthesizable)
while all the FPU files are in ``rtl/vendor/pulp_platform_common_cells``, ``rtl/vendor/pulp_platform_fpnew`` and ``rtl/vendor/opene906``.
cv32e40p_fpu_manifest.flist is listing all the required files.

The user must provide a clock-gating module that instantiates the functionally equivalent clock-gating cell of the target technology.
This file must have the same interface and module name as the one provided for simulation-only purposes at ``bhv/cv32e40p_sim_clock_gate.sv`` (see :ref:`clock-gating-cell`).

The ``constraints/cv32e40p_core.sdc`` file provides an example of synthesis constraints.


ASIC Synthesis
^^^^^^^^^^^^^^

ASIC synthesis is supported for CV32E40P. The whole design is completely synchronous and uses positive-edge triggered flip-flops.

To give some size numbers, it has been synthetized at 100 MHz with a 32 KB memory connected on each of its OBI interface, DFT scan chains have been implemented and it went down to full back-end implementation with Clock Tree synthesis.
But no memory bist are inserted and there are no scan compression for DFT.

And a technology specific implementation of a clock gating cell as described in :ref:`clock-gating-cell` has been provided.

Following table gives CV32E40P size in Kilo-Gates numbers using a 2-input NAND gate with X1 drive for different top parameters settings (COREV_CLUSTER = 0 for all cases).

.. table:: CV32E40P size
  :name: CV32E40P size
  :widths: 45 45 10
  :class: no-scrollbar-table

  +-----------------------+--------------------+--------+
  | **Configuration**     | **Top Parameters** | **KG** |
  +=======================+====================+========+
  | V1                    | COREV_PULP = 0     | 40     |
  |                       |                    |        |
  |                       | FPU = 0            |        |
  |                       |                    |        |
  |                       | ZFINX = 0          |        |
  +-----------------------+--------------------+--------+
  | V2 PULP               | COREV_PULP = 1     | 57     |
  |                       |                    |        |
  |                       | FPU = 0            |        |
  |                       |                    |        |
  |                       | ZFINX = 0          |        |
  +-----------------------+--------------------+--------+
  | V2 PULP & FPU         | COREV_PULP = 1     | 93     |
  |                       |                    |        |
  |                       | FPU = 1            |        |
  |                       |                    |        |
  |                       | ZFINX = 0          |        |
  |                       |                    |        |
  |                       | FPU_ADDMUL_LAT = 0 |        |
  |                       |                    |        |
  |                       | FPU_OTHERS_LAT = 0 |        |
  +-----------------------+--------------------+--------+
  | V2 PULP & FPU & ZFINX | COREV_PULP = 1     | 77     |
  |                       |                    |        |
  |                       | FPU = 1            |        |
  |                       |                    |        |
  |                       | ZFINX = 1          |        |
  |                       |                    |        |
  |                       | FPU_ADDMUL_LAT = 0 |        |
  |                       |                    |        |
  |                       | FPU_OTHERS_LAT = 0 |        |
  +-----------------------+--------------------+--------+

FPGA Synthesis
^^^^^^^^^^^^^^^

FPGA synthesis is supported for CV32E40P and it has been successfully implemented using both AMD® Vivado® and Intel® Quartus® Prime Pro Edition tools.

Due to some advanced System Verilog features used by CV32E40P RTL design, Intel® Quartus® Prime Standard Edition isn't able to parse some CV32E40P System Verilog files.

The user needs to provide a technology specific implementation of a clock gating cell as described in :ref:`clock-gating-cell`.

.. _synthesis_with_fpu:

Synthesizing with the FPU
^^^^^^^^^^^^^^^^^^^^^^^^^

By default the pipeline of the FPU is purely combinatorial (FPU_*_LAT = 0). In this case FPU instructions latency is the same than simple ALU operations (except multicycle FDIV/FSQRT ones).
But as FPU operations are much more complex than ALU ones, maximum achievable frequency is much lower than ALU one when FPU is enabled.

If this can be fine for low frequency systems, it is possible to indicate how many pipeline registers are instantiated in the FPU to reach higher target frequency.
This is done by adjusting FPU_*_LAT CV32E40P parameters setting to perfectly fit target frequency.

It should be noted that any additional pipeline register is impacting FPU instructions latency and could cause performances degradation depending of applications using Floating-Point operations.

Those pipeline registers are all added at the end of the FPU pipeline with all operators before them. Optimal frequency is only achievable using automatic retiming commands in implementation tools.
As an exemple, this can be done for Synopsys® Design Compiler with the following command:

“set_optimize_registers true -designs [get_object_name [get_designs "\*cv32e40p_fp_wrapper\*"]]”.

