TOPLEVEL_LANG ?= verilog

# A Verilog források útvonala az rtl/ mappából
VERILOG_SOURCES += $(PWD)/rtl/dd8_core.v
# Ha van még más rtl fájl is (pl. almodulok), add hozzájuk soronként:
# VERILOG_SOURCES += $(PWD)/rtl/masik_modul.v

# Top modul neve
COCOTB_TOPLEVEL = dd8_core

# A tb/ mappában lévő Python tesztfájl neve (kiterjesztés nélkül, pl. wav_test.py -> wav_test)
COCOTB_TEST_MODULES = wav_test
MODULE = wav_test

# Hozzáadjuk a tb/ mappát a Python keresési útvonalához, hogy megtalálja a wav_test.py-t
export PYTHONPATH := $(PWD)/tb:$(PYTHONPATH)

# Alapértelmezett szimulátor az Icarus Verilog
SIM ?= icarus

# Cocotb alap Makefile betöltése
include $(shell cocotb-config --makefiles)/Makefile.sim