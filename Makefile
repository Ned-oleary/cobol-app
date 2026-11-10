COBC      ?= cobc
COBFLAGS  ?= -x -free -Wall -O2
SRC_DIR   := src
BUILD_DIR := build
TARGET    := $(BUILD_DIR)/cobol-app

SOURCES := $(wildcard $(SRC_DIR)/*.cbl)

.PHONY: all run test clean

all: $(TARGET)

$(TARGET): $(SOURCES) | $(BUILD_DIR)
	$(COBC) $(COBFLAGS) -o $@ $(SRC_DIR)/main.cbl

$(BUILD_DIR):
	mkdir -p $@

run: $(TARGET)
	./$(TARGET)

test: $(TARGET)
	./tests/run.sh $(TARGET)

clean:
	rm -rf $(BUILD_DIR)
