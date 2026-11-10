COBC      ?= cobc
PG_CONFIG ?= pg_config
COBFLAGS  ?= -free -Wall -O2
DB_NAME   ?= cobol_notes
PORT      ?= 8080

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/cobol-notes
TEST_BIN  := $(BUILD_DIR)/test-util

PG_LIBDIR := $(shell $(PG_CONFIG) --libdir 2>/dev/null)
LDFLAGS   := $(if $(PG_LIBDIR),-L$(PG_LIBDIR)) -lpq

# -fstatic-call links CALL "x" directly to C symbols (libc, libpq) and
# to the other COBOL programs, instead of resolving them at runtime.
# -Wno-repository-checks: helpers take generic max-size buffers and an
# explicit length, so passing a smaller field is intentional.
ALL_FLAGS := $(COBFLAGS) -fstatic-call -Wno-repository-checks -I copy

# server.cbl must come first: it is the main program.
SOURCES := src/server.cbl src/http.cbl src/router.cbl src/handlers.cbl \
           src/views.cbl src/notes-db.cbl src/util.cbl
COPYBOOKS := $(wildcard copy/*.cpy)

.PHONY: all run db test test-unit test-smoke clean

all: $(TARGET)

$(TARGET): $(SOURCES) $(COPYBOOKS) | $(BUILD_DIR)
	$(COBC) -x $(ALL_FLAGS) -o $@ $(SOURCES) $(LDFLAGS)

$(TEST_BIN): tests/test-util.cbl src/util.cbl $(COPYBOOKS) | $(BUILD_DIR)
	$(COBC) -x $(ALL_FLAGS) -o $@ tests/test-util.cbl src/util.cbl

$(BUILD_DIR):
	mkdir -p $@

# Create the database if it does not exist yet (the table is created
# by the server on startup).
db:
	@psql -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname = '$(DB_NAME)'" | grep -q 1 \
	  || createdb $(DB_NAME)
	@echo "database $(DB_NAME) ready"

run: $(TARGET)
	PORT=$(PORT) ./$(TARGET)

test: test-unit test-smoke

test-unit: $(TEST_BIN)
	./$(TEST_BIN)

test-smoke: $(TARGET)
	./tests/smoke.sh $(TARGET)

clean:
	rm -rf $(BUILD_DIR)
