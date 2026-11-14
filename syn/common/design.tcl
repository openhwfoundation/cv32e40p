puts "Info: Running script [info script]"

set DESIGN_NAME "cv32e40p_core"
set RTL_SOURCE_FILES {cv32e40p_core.sv \
          cv32e40p_aligner.sv \
          cv32e40p_alu.sv\
          cv32e40p_alu_div.sv\
          cv32e40p_apu_disp.sv\
          cv32e40p_compressed_decoder.sv\
          cv32e40p_controller.sv\
          cv32e40p_core.sv\
          cv32e40p_cs_registers.sv\
          cv32e40p_decoder.sv\
          cv32e40p_ex_stage.sv\
          cv32e40p_ff_one.sv\
          cv32e40p_fifo.sv\
          cv32e40p_fp_wrapper.sv\
          cv32e40p_hwloop_regs.sv\
          cv32e40p_id_stage.sv\
          cv32e40p_if_stage.sv\
          cv32e40p_int_controller.sv\
          cv32e40p_load_store_unit.sv\
          cv32e40p_mult.sv\
          cv32e40p_obi_interface.sv\
          cv32e40p_popcnt.sv\
          cv32e40p_prefetch_buffer.sv\
          cv32e40p_prefetch_controller.sv\
          cv32e40p_register_file_ff.sv\
          cv32e40p_register_file_latch.sv\
          cv32e40p_sleep_unit.sv\
          cv32e40p_wrapper.sv }
set PKG_SOURCE_FILES { cv32e40p_pkg.sv \
          cv32e40p_fpu_pkg.sv\
          cv32e40p_apu_core_pkg.sv}



puts "Info: Completed script [info script]"
