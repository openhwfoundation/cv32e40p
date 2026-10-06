puts "Info: Running script [info script]"
###############################################################################
# Variable name setup
###############################################################################

# Milkyway library
set MW_LIBRARY_NAME                      ${DESIGN_NAME}_LIB

# Constraint files
set SDC_INPUT_FILE   ../constraints/${DESIGN_NAME}.sdc

# Check reports
set CHECK_LIBRARY_REPORT                 ${DESIGN_NAME}.check_library.rpt
set CHECK_DESIGN_REPORT                  ${DESIGN_NAME}.check_design.rpt

# Final reports
set FINAL_QOR_REPORT                     ${DESIGN_NAME}.mapped.qor.rpt
set FINAL_TIMING_REPORT                  ${DESIGN_NAME}.mapped.timing.rpt
set FINAL_AREA_REPORT                    ${DESIGN_NAME}.mapped.area.rpt
set FINAL_POWER_REPORT                   ${DESIGN_NAME}.mapped.power.rpt
set FINAL_DESIGNWARE_AREA_REPORT         ${DESIGN_NAME}.mapped.designware_area.rpt
set FINAL_RESOURCES_REPORT               ${DESIGN_NAME}.mapped.final_resources.rpt
set FINAL_CLOCK_GATING_REPORT            ${DESIGN_NAME}.mapped.clock_gating.rpt
set FINAL_SELF_GATING_REPORT             ${DESIGN_NAME}.mapped.self_gating.rpt
set THRESHOLD_VOLTAGE_GROUP_REPORT       ${DESIGN_NAME}.mapped.threshold.voltage.group.rpt

set FINAL_INTERFACE_TIMING_REPORT        ${DESIGN_NAME}.mapped.interface_timing.rpt

# DCT reports
set DCT_PHYSICAL_CONSTRAINTS_REPORT                ${DESIGN_NAME}.physical_constraints.rpt

set DCT_FINAL_CONGESTION_REPORT                    ${DESIGN_NAME}.mapped.congestion.rpt
set DCT_FINAL_CONGESTION_MAP_OUTPUT_FILE           ${DESIGN_NAME}.mapped.congestion_map.png
set DCT_FINAL_CONGESTION_MAP_WINDOW_OUTPUT_FILE    ${DESIGN_NAME}.mapped.congestion_map_window.png
set ANALYZE_RTL_CONGESTION_REPORT_FILE             ${DESIGN_NAME}.analyze_rtl_congetion.rpt

set DCT_FINAL_QOR_SNAPSHOT_FOLDER                  ${DESIGN_NAME}.qor_snapshot
set DCT_FINAL_QOR_SNAPSHOT_REPORT                  ${DESIGN_NAME}.qor_snapshot.rpt

# DCT Outputs
set DCT_FLOORPLAN_OUTPUT_FILE                      ${DESIGN_NAME}.initial.fp

set DCT_FINAL_FLOORPLAN_OUTPUT_FILE                ${DESIGN_NAME}.mapped.fp
set DCT_FINAL_SPEF_OUTPUT_FILE                     ${DESIGN_NAME}.mapped.spef
set DCT_FINAL_SDF_OUTPUT_FILE                      ${DESIGN_NAME}.mapped.sdf

# Design outputs
set ELABORATED_DESIGN_DDC_OUTPUT_FILE ${DESIGN_NAME}.elab.ddc
set FINAL_DDC_OUTPUT_FILE             ${DESIGN_NAME}.mapped.ddc
set FINAL_SDC_OUTPUT_FILE             ${DESIGN_NAME}.mapped.sdc

# Formality flow Files
set SVF_OUTPUT_FILE               ${DESIGN_NAME}.mapped.svf
set UNMATCHED_POINTS_REPORT       ${DESIGN_NAME}.fmv_unmatched_points.rpt

# Create the reports/results dir if not already created
set REPORTS_DIR "reports"
set RESULTS_DIR "results"
file mkdir ${REPORTS_DIR}
file mkdir ${RESULTS_DIR}

puts "Info: Completed script [info script]"
