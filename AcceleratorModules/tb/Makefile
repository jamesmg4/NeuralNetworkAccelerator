IVERILOG ?= iverilog
VVP      ?= vvp

RTL_DIR   := ../rtl
BUILD_DIR := ../build/tests

MAC_RTL    := $(RTL_DIR)/INT8_MAC/INT8_MAC.sv
DOTP_RTL   := $(MAC_RTL) $(RTL_DIR)/INT8_MAC/DotProductController.sv
MATVEC_RTL := $(DOTP_RTL) $(RTL_DIR)/MatrixVector/MatrixVectorController.sv

MAC_OUT    := $(BUILD_DIR)/INT8_MAC_tb.out
DOTP_OUT   := $(BUILD_DIR)/dotpcontroller_tb.out
MATVEC_OUT := $(BUILD_DIR)/MatrixVectorController_tb.out

.PHONY: all test mac dotp matvec waves clean

all: test

test: mac dotp matvec

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

matvec: | $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s MatrixVectorController_tb \
		-o $(MATVEC_OUT) $(MATVEC_RTL) MatrixVectorController_tb.sv
	$(VVP) $(MATVEC_OUT)

waves: | $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s MatrixVectorController_tb \
		-o $(MATVEC_OUT) $(MATVEC_RTL) MatrixVectorController_tb.sv
	$(VVP) $(MATVEC_OUT) +waves

clean:
	rm -f $(MAC_OUT) $(DOTP_OUT) $(MATVEC_OUT) \
		MatrixVectorController_tb.vcd
