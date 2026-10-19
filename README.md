Known Issues

- Reverse: Audible clicks at long delay times (D4 and above).
- +RV: Insufficient reverb effect. Replace the current gain-based approximation with a proper reverb algorithm
- Shimmer: Distorted repeats caused by the simplistic absolute-value-based octave effect
- Tape/Mod: Distorted repeats




# FPGA Multi-Mode Audio Delay Effect (BOSS DD-8 Inspired)

![Vivado](https://img.shields.io/badge/Vivado-2017.4%2B-blue.svg)
![Board](https://img.shields.io/badge/Board-Digilent%20Arty%20S7--100-orange.svg)
![Language](https://img.shields.io/badge/Language-Verilog%20%2F%20SystemVerilog-brightgreen.svg)
![Interface](https://img.shields.io/badge/Pmod-I2S2%20Audio-red.svg)

Hardware implementation of a multi-mode digital audio delay pedal effect, designed for Xilinx Spartan-7 FPGAs. Inspired by the BOSS DD-8.

---

## Key Features

- **8 Distinct Delay Modes:**
  - `Standard`: Clean digital delay repeats.
  - `Analog`: Darkened repeats with low-pass roll-off.
  - `Tape`: Wow/Flutter style modulation based on a hardware LFO.
  - `Warm`: Soft digital tone with gentle high-frequency damping.
  - `Reverse`: Block-wise backwards audio playback.
  - `+RV`: Delay with built-in ambient decay.
  - `Shimmer`: Pitch-shifted octave-up feedback blend.
  - `Mod`: Classic modulated delay effect.
- **Synchronous BRAM Architecture:** Single-port read/write circular buffer ($65,536 \times 24\text{-bit}$) inferred in dedicated Xilinx Block RAMs (`RAMB36E1`).
- **DSP Slice Acceleration:** Hard-wired DSP48E1 multipliers (`(* use_dsp = "yes" *)`) for saturation-safe fixed-point gain scaling and feedback attenuation.
- **Interactive Front Panel Control:** Integrated hardware debouncing module (`btn_ctrl.v`) supporting mode selection, parameter navigation, and state indication via board LEDs.
- **PMOD 7-Segment Display:** Parameter setting feedback


---

## Hardware Architecture

The audio signal flow follows an AXI4-Stream master-slave architecture operating on a 100 MHz system clock, interfacing with a Digilent Pmod I2S2 24-bit stereo audio codec.

 
### RTL Module Breakdown

| Module | Description |
| :--- | :--- |
| `top.v` | Top-level hardware wrapper integrating clocks, I2S transceiver, and control routing. |
| `axis_dd8_wrapper.v` | AXI4-Stream handshake logic (`s_axis_valid/ready`, `m_axis_valid/ready`) and strobe generation. |
| `dd8_core.v` | DSP processing core containing BRAM pointers, LFO generator, reverse logic, and saturation arithmetic. |
| `btn_ctrl.v` | Hardware debouncer, edge-detector, parameter register bank, and status LED controller. |
| `axis_i2s2.v` | Digilent Pmod I2S2 audio codec transceiver (I2S $\leftrightarrow$ AXI-Stream). |
| `pmod_ssd_ctrl.v` | Digilent Pmod 7-Segment Dsiplay control. |

---

## Repository Structure

This repository follows standard FPGA industry practices, isolating clean RTL sources from vendor-generated build artifacts.

```text
arty-s7-dsp-audio/
├── .gitignore          # Excludes Vivado temporary files (.runs, .cache, etc.)
├── README.md           # Project documentation
├── create_project.tcl  # 1-click Vivado project recreation script
├──	Makefile			# Makefile for verification
├── constraints/
│   └── arty_s7.xdc     # Pin layout and timing constraints for Arty S7
├── ip/
│   └── clk_wiz_0/      # Clocking Wizard IP source (.xci)
│       └── clk_wiz_0.xci
├── rtl/                # Synthesizable Verilog RTL source files
│   ├── top.v
│   ├── axis_dd8_wrapper.v
│   ├── dd8_core.v
│   ├── btn_ctrl.v
│   ├── axis_i2s2.v
|	└── pmod_ssd_ctrl.v
└── tb/                 # Python cocotb testbenches for simulation
    └── tb_dd8_core.py
```
	
## Getting Started & Build Instructions

Prerequisites
Vivado Design Suite: 2017.3 or newer (Standard/Enterprise edition).
Hardware: Digilent Arty S7-100 (XC7S100) or S7-50 FPGA development board.
Peripheral: 
	Digilent Pmod I2S2 connected to Port JA
	Digilent Pmod SSD connected to Port JB and JC
	
1-Click Project Reconstruction (Tcl Workflow)
	Clone this repository:Bashgit clone [https://github.com/your-username/arty-s7-dsp-audio.git](https://github.com/your-username/arty-s7-dsp-audio.git)
	cd arty-s7-dsp-audio
	Open Xilinx Vivado.
	In the Tcl Console at the bottom of the window, navigate to the repository directory and execute:Tclcd ./arty-s7-dsp-audio
	source create_project.tcl
	Vivado will automatically generate the clean .xpr project structure, link all external RTL sources, and configure the clock IP.Click Generate Bitstream in the Flow Navigator.

## Hardware Controls & UI Map
SW0: Master Effect Bypass (0 = Bypass / Dry, 1 = Effect Enabled / Wet)
BTN0: Select Active Parameter Page 
BTN1: Decrement Value (-1)
BTN2: Increment Value (+1)

