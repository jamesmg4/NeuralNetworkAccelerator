# OpenROAD Flow Scripts configuration for the baseline matrix-vector engine.
#
# Docker usage assumes the accelerator repository is mounted at /work, which
# flow/util/docker_shell does when it is launched from the repository root.
# Override NN_ACCEL_ROOT when running OpenROAD directly on the host.
NN_ACCEL_ROOT ?= /work

export DESIGN_NICKNAME = matrix_vector_controller
export DESIGN_NAME     = MatrixVectorController
export PLATFORM        = sky130hd

export VERILOG_FILES = \
  $(NN_ACCEL_ROOT)/AcceleratorModules/rtl/INT8_MAC/INT8_MAC.sv \
  $(NN_ACCEL_ROOT)/AcceleratorModules/rtl/INT8_MAC/DotProductController.sv \
  $(NN_ACCEL_ROOT)/AcceleratorModules/rtl/MatrixVector/MatrixVectorController.sv

export SDC_FILE = $(NN_ACCEL_ROOT)/AcceleratorModules/openroad/sky130hd/constraint.sdc

# Baseline elaboration parameters: a 3-row by 4-column weight matrix. Keep
# these fixed while collecting a baseline; later runs can override them with:
#   make ... VERILOG_TOP_PARAMS="WEIGHT_COLUMN_WIDTH 8 WEIGHT_ROW_WIDTH 8"
export VERILOG_TOP_PARAMS ?= WEIGHT_COLUMN_WIDTH 4 WEIGHT_ROW_WIDTH 3

# Leave routing room in this first physical implementation. Density can be
# increased later as a controlled area/timing experiment.
export CORE_UTILIZATION = 35
export PLACE_DENSITY_LB_ADDON = 0.15

# Report every timing path group when calculating total negative slack.
export TNS_END_PERCENT = 100
