puts "Info: Running script [info script]"
source "scripts/common/saed32.tcl"
source "scripts/common/design.tcl"
source "scripts/dc/dc_setup_filenames.tcl"

if {![shell_is_in_topographical_mode]} {
  puts "Error: dc_shell must be run in topographical mode."
  exit 1
}

###############################################################################
# Milkyway library setup
###############################################################################
# Milkyway variable settings
set mw_reference_library ${MW_REFERENCE_LIB_DIRS}
set mw_design_library    ${MW_LIBRARY_NAME}
set mw_site_name_mapping { {CORE unit} {Core unit} {core unit} }

# Only create new Milkyway design library if it doesn't already exist
if {![file isdirectory $mw_design_library ]} {
  create_mw_lib \
    -technology $TECH_FILE \
    -mw_reference_library $mw_reference_library \
    $mw_design_library
} else {
  # If Milkyway design library already exists, ensure that it is consistent with specified Milkyway reference libraries
  set_mw_lib_reference \
    $mw_design_library \
    -mw_reference_library $mw_reference_library
}

open_mw_lib $mw_design_library

check_library > ${REPORTS_DIR}/${CHECK_LIBRARY_REPORT}

set_tlu_plus_files \
  -max_tluplus $TLUPLUS_MAX_FILE \
  -min_tluplus $TLUPLUS_MIN_FILE \
  -tech2itf_map $MAP_FILE

check_tlu_plus_files

###############################################################################
# Library setup
###############################################################################
set_app_var search_path ". ${ADDITIONAL_SEARCH_PATH} $search_path"
set_app_var target_library ${TARGET_LIBRARY_FILES}
set_app_var synthetic_library {dw_minpower.sldb dw_foundation.sldb}
set_app_var link_library "* $target_library $ADDITIONAL_LINK_LIB_FILES $synthetic_library"
foreach {max_library min_library} $MIN_LIBRARY_FILES {
  set_min_library $max_library -min_version $min_library
}

###############################################################################
# Don't use file
###############################################################################
if {[file exists [which ${LIBRARY_DONT_USE_FILE}]]} {
  puts "Info: Sourcing script file [which ${LIBRARY_DONT_USE_FILE}]\n"
  source -echo -verbose ${LIBRARY_DONT_USE_FILE}
}

puts "Info: Completed script [info script]"
