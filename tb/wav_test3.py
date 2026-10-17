import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

import wave
import os
import math

tb_dir = os.path.dirname(os.path.abspath(__file__))


@cocotb.test()
async def dd8_basic_passthrough_test(dut):
    """Test bypass mode (enable = 0) passes input straight to output"""
    # 100 MHz órajel indítása (10 ns periodus)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Kezdeti értékek
    dut.new_sample.value = 0
    dut.sample_in.value = 12345
    dut.mode_sel.value = 0
    dut.dtime.value = 0
    dut.feedback.value = 0
    dut.elevel.value = 4
    dut.enable.value = 0  # Bypass aktív

    await Timer(50, units="ns")
    await RisingEdge(dut.clk)

    # Bypassed állapotban a kimenetnek egyeznie kell a bemenettel
    assert dut.sample_out.value == 12345, \
        f"Bypass failed: got {dut.sample_out.value}, expected 12345"


@cocotb.test()
async def dd8_custom_wav_file_test(dut):
    """Test processing an existing WAV file from the tb/ directory (e.g. clean_sample.wav)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Fájlnevek megadása a tb/ mappán belül
    # Használhatod a clean_guitar.wav-t vagy bármilyen más saját fájlt is!
    input_filename = os.path.join(tb_dir, "clean_sample.wav")
    output_filename = os.path.join(tb_dir, "output_custom_processed.wav")

    # Ellenőrzés, hogy létezik-e a bemeneti fájl
    if not os.path.exists(input_filename):
        cocotb.log.error(f"A bemeneti WAV fájl nem található itt: {input_filename}")
        return

    # Hardver alapbeállítások (kipróbálhatsz más módot is, pl. Tape = 2)
    dut.new_sample.value = 0
    dut.sample_in.value = 0
    dut.mode_sel.value = 2     # 2 = Tape mód (vagy 0 = Standard)
    dut.dtime.value = 4        # Delay idő (0-6)
    dut.feedback.value = 4     # Visszacsatolás (ismétlések)
    dut.elevel.value = 5       # Wet/Effect szint
    dut.enable.value = 1       # Effekt bekapcsolva

    await Timer(100, units="ns")

    cocotb.log.info(f"Feldolgozás indítása ezzel a fájllal: {os.path.basename(input_filename)}")

    with wave.open(input_filename, 'r') as wf_in:
        n_channels = wf_in.getnchannels()
        sample_width = wf_in.getsampwidth()
        framerate = wf_in.getframerate()
        n_frames = wf_in.getnframes()
        
        cocotb.log.info(f"WAVinfó -> Csatornák: {n_channels}, Bitszélesség: {sample_width} bájt, Mintavételi freki: {framerate} Hz, Minták száma: {n_frames}")

        with wave.open(output_filename, 'w') as wf_out:
            wf_out.setnchannels(n_channels)
            wf_out.setsampwidth(sample_width)
            wf_out.setframerate(framerate)

            for i in range(n_frames):
                raw_data = wf_in.readframes(1)
                if not raw_data:
                    break
                
                # Bemeneti minta konverzió bitszélesség alapján (24-bit vagy 16-bit)
                if sample_width == 3:
                    input_sample = int.from_bytes(raw_data, byteorder='little', signed=True)
                    signal_in = input_sample & 0xFFFFFF
                elif sample_width == 2:
                    input_sample = int.from_bytes(raw_data, byteorder='little', signed=True)
                    signal_in = (input_sample << 8) & 0xFFFFFF  # 16-bit felskálázása 24-bitre
                else:
                    input_sample = int.from_bytes(raw_data, byteorder='little', signed=True)
                    signal_in = input_sample

                # Beadás a hardverbe órajelre ütemezve
                await RisingEdge(dut.clk)
                dut.sample_in.value = signal_in
                dut.new_sample.value = 1
                
                await RisingEdge(dut.clk)
                dut.new_sample.value = 0

                # Kimenet biztonságos kiolvasása
                val_str = str(dut.sample_out.value)
                if 'x' in val_str.lower() or 'z' in val_str.lower():
                    output_sample = 0
                else:
                    try:
                        output_sample = int(dut.sample_out.value)
                    except ValueError:
                        output_sample = 0
                
                # Eljeles 24-bit kezelés visszaléptetéshez
                if output_sample & (1 << 23):
                    output_sample -= (1 << 24)

                # Mentés a kimeneti WAV-ba
                if sample_width == 3:
                    wf_out.writeframes(output_sample.to_bytes(3, byteorder='little', signed=True))
                elif sample_width == 2:
                    out_16 = max(-32768, min(32767, output_sample >> 8))
                    wf_out.writeframes(out_16.to_bytes(2, byteorder='little', signed=True))
                else:
                    wf_out.writeframes(output_sample.to_bytes(sample_width, byteorder='little', signed=True))

    cocotb.log.info(f"Egyedi WAV feldolgozás sikeresen véget ért! Eredmény mentve ide: {output_filename}")