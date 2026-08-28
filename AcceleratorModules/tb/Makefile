IVERILOG ?= iverilog
VVP      ?= vvp
VERILATOR ?= verilator

RTL_DIR   := ../rtl
BUILD_DIR := ../build/tests

MAC_RTL    := $(RTL_DIR)/INT8_MAC/INT8_MAC.sv
DOTP_RTL   := $(MAC_RTL) $(RTL_DIR)/INT8_MAC/DotProductController.sv
MATVEC_RTL := $(DOTP_RTL) $(RTL_DIR)/MatrixVector/MatrixVectorController.sv

MAC_OUT    := $(BUILD_DIR)/INT8_MAC_tb.out
DOTP_OUT   := $(BUILD_DIR)/dotpcontroller_tb.out
MATVEC_OUT := $(BUILD_DIR)/MatrixVectorController_tb.out

MATVEC_CONFIGS := matvec-1x1 matvec-1x4 matvec-4x1 \
	matvec-2x3 matvec-4x4 matvec-8x8

.PHONY: all test mac dotp matvec $(MATVEC_CONFIGS) lint lint-rtl lint-tb \
	lint-mac-tb lint-dotp-tb lint-matvec-tb waves clean

all: test

test: mac dotp matvec

lint: lint-rtl lint-tb

lint-rtl:
	$(VERILATOR) --lint-only --sv -Wall \
		--top-module MatrixVectorController $(MATVEC_RTL)

lint-tb: lint-mac-tb lint-dotp-tb lint-matvec-tb

lint-mac-tb:
	$(VERILATOR) --lint-only --sv --timing -Wall \
		--top-module INT8_MAC_tb $(MAC_RTL) INT8_MAC_tb.sv

lint-dotp-tb:
	$(VERILATOR) --lint-only --sv --timing -Wall \
		--top-module dotpcontroller_tb $(DOTP_RTL) dotpcontroller_tb.sv

lint-matvec-tb:
	$(VERILATOR) --lint-only --sv --timing -Wall \
		--top-module MatrixVectorController_tb \
		$(MATVEC_RTL) MatrixVectorController_tb.sv

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

mac: | $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s INT8_MAC_tb \
		-o $(MAC_OUT) $(MAC_RTL) INT8_MAC_tb.sv
	$(VVP) $(MAC_OUT)

dotp: | $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s dotpcontroller_tb \
		-o $(DOTP_OUT) $(DOTP_RTL) dotpcontroller_tb.sv
	$(VVP) $(DOTP_OUT)

define run_matvec
	$(IVERILOG) -g2012 -Wall -s MatrixVectorController_tb \
		-PMatrixVectorController_tb.ROWS=$(1) \
		-PMatrixVectorController_tb.COLS=$(2) \
		-o $(BUILD_DIR)/MatrixVectorController_tb_$(1)x$(2).out \
		$(MATVEC_RTL) MatrixVectorController_tb.sv
	$(VVP) $(BUILD_DIR)/MatrixVectorController_tb_$(1)x$(2).out
endef

matvec: $(MATVEC_CONFIGS)

matvec-1x1: | $(BUILD_DIR)
	$(call run_matvec,1,1)

matvec-1x4: | $(BUILD_DIR)
	$(call run_matvec,1,4)

matvec-4x1: | $(BUILD_DIR)
	$(call run_matvec,4,1)

matvec-2x3: | $(BUILD_DIR)
	$(call run_matvec,2,3)

matvec-4x4: | $(BUILD_DIR)
	$(call run_matvec,4,4)

matvec-8x8: | $(BUILD_DIR)
	$(call run_matvec,8,8)

waves: | $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s MatrixVectorController_tb \
		-o $(MATVEC_OUT) $(MATVEC_RTL) MatrixVectorController_tb.sv
	$(VVP) $(MATVEC_OUT) +waves

clean:
	rm -f $(MAC_OUT) $(DOTP_OUT) $(MATVEC_OUT) \
		$(BUILD_DIR)/MatrixVectorController_tb_1x1.out \
		$(BUILD_DIR)/MatrixVectorController_tb_1x4.out \
		$(BUILD_DIR)/MatrixVectorController_tb_4x1.out \
		$(BUILD_DIR)/MatrixVectorController_tb_2x3.out \
		$(BUILD_DIR)/MatrixVectorController_tb_4x4.out \
		$(BUILD_DIR)/MatrixVectorController_tb_8x8.out \
		MatrixVectorController_tb.vcd
