remove_design -all

#****** identification ******
set designer {Pasquale Davide Schiavone}
set company  {OpenHW Group}


#****** report inferred latches after elaborate ******
set hdlin_check_no_latch true
set hdlin_latch_always_async_set_reset true

#****** variable for saif export (power estimation) ******
set power_preserve_rtl_hier_names true


set verilogout_no_tri true

set CV32E40P_PATH   "../../"
set search_path [ join "$CV32E40P_PATH
                        $CV32E40P_PATH/rtl/include
                        $search_path"
                ]

analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/fpnew/src/fpnew_pkg.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/include/apu_core_package.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/include/riscv_defines.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/include/riscv_config.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_alu.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_alu_div.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_compressed_decoder.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_controller.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_cs_registers.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_decoder.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_int_controller.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_ex_stage.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_hwloop_controller.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_hwloop_regs.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_id_stage.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_if_stage.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_load_store_unit.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_mult.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_prefetch_buffer.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_fetch_fifo.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_core.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_apu_disp.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/register_file_test_wrap.sv
analyze -format sverilog  -work work ${CV32E40P_PATH}/rtl/riscv_register_file.sv

elaborate riscv_core

rename_design [current_design_name] cv32e40p


## Create the clocks
echo "Creating the clock clk_i"

set CLOCK_SPEED 2000
create_clock      [get_ports clk_i] -period $CLOCK_SPEED -name CORE_CLK
set_ideal_network [get_ports clk_i]


## Set IO delays
echo "Setting input and output delays"

set core_outputs [all_outputs]
set core_inputs  [remove_from_collection [all_inputs] [get_ports clk_i]]
set core_inputs  [remove_from_collection $core_inputs [get_ports rst_ni]]

set INPUT_DELAY  [expr 0.7*$CLOCK_SPEED]
set OUTPUT_DELAY [expr 0.7*$CLOCK_SPEED]

set_input_delay  $INPUT_DELAY  $core_inputs  -clock [get_clock]
set_output_delay $OUTPUT_DELAY [all_outputs] -clock [get_clock]

## Exceptions (false paths, multicycle etc.)
echo "Setting the exceptions"

set_ideal_network       -no_propagate    [all_connected  [get_ports rst_ni]]
set_ideal_network       -no_propagate    [get_nets  rst_ni]
set_dont_touch_network  -no_propagate    [get_ports rst_ni]
set_multicycle_path 2   -from            [get_ports rst_ni]
set_case_analysis   0                    [get_ports test_en_i]
set_case_analysis   1                    [get_ports clock_en_i]

##constant values relax
set_multicycle_path 2   -from [get_ports boot_addr_i         ]
set_multicycle_path 2   -from [get_ports core_id_i           ]
set_multicycle_path 2   -from [get_ports cluster_id_i        ]
set_multicycle_path 2   -from [get_ports apu_master_gnt_i    ]
set_multicycle_path 2   -from [get_ports apu_master_valid_i  ]
set_multicycle_path 2   -from [get_ports apu_master_result_i ]
set_multicycle_path 2   -from [get_ports apu_master_flags_i  ]
set_multicycle_path 2   -from [get_ports fetch_enable_i      ]

## Relax constraints for debug_req as it arrives from external flip-flop not memories, thus 70% is not fair
set_input_delay  [expr 0.1*$CLOCK_SPEED]  [get_ports   debug_req_i]  -clock [get_clock]


compile_ultra -gate_clock -no_autoungroup
