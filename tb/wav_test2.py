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
async def dd8_sample_processing_test(dut):
    """Test single sample ingestion with new_sample pulse"""
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Alapbeállítások
    dut.new_sample.value = 0
    dut.sample_in.value = 0
    dut.mode_sel.value = 0  # Standard mód
    dut.dtime.value = 1
    dut.feedback.value = 4 
    dut.elevel.value = 6
    dut.enable.value = 1  # Effekt bekapcsolva

    await Timer(100, units="ns")

    # Egyetlen minta beadása
    await RisingEdge(dut.clk)
    dut.sample_in.value = 500000
    dut.new_sample.value = 1
    
    await RisingEdge(dut.clk)
    dut.new_sample.value = 0

    # Várakozás néhány ciklust, hogy lássuk a kimenet változását
    for _ in range(5):
        await RisingEdge(dut.clk)

    cocotb.log.info(f"Sikeres futás! Kimenet értéke: {dut.sample_out.value}")
    
    
    
    # 3. WAV fájl paraméterek és impulzus generálás
    input_wav_name = os.path.join(tb_dir, "input_test.wav")
    output_wav_name = os.path.join(tb_dir, "output_processed.wav")

    cocotb.log.info("Impulzus / teszthang WAV generálása a bemenethez...")
    sample_rate = 44100
    total_duration_sec = 1.5   # 1.5 másodperc össz-idő, hogy halljuk a delay-t
    
    # 24-bit audio írása a bemeneti fájlba
    with wave.open(input_wav_name, 'w') as wf:
        wf.setnchannels(1)      # Mono
        wf.setsampwidth(3)      # 24-bit audio (3 bájt)
        wf.setframerate(sample_rate)
        
        for i in range(int(sample_rate * total_duration_sec)):
            # Csak az elején adjunk be egy rövid impulzust (pl. az első 500 mintán), 
            # utána tiszta csend (0), hogy halljuk a visszhangokat!
            if i < 500:
                # Enyhe bevezető tranziens vagy egy hangosabb impulzus
                sample_val = int(7000000 * math.sin(2 * math.pi * 440 * (i / sample_rate)))
            else:
                sample_val = 0
                
            wf.writeframes(sample_val.to_bytes(3, byteorder='little', signed=True))

   # 4. WAV olvasás és feldolgozás
    with wave.open(input_wav_name, 'r') as wf_in:
        n_channels = wf_in.getnchannels()
        sample_width = wf_in.getsampwidth()
        framerate = wf_in.getframerate()
        n_frames = wf_in.getnframes()
        
        cocotb.log.info(f"Feldolgozás indítása: {n_frames} minta...")

        with wave.open(output_wav_name, 'w') as wf_out:
            wf_out.setnchannels(n_channels)
            wf_out.setsampwidth(sample_width)
            wf_out.setframerate(framerate)

            for i in range(n_frames):
                raw_data = wf_in.readframes(1)
                if not raw_data:
                    break
                
                input_sample = int.from_bytes(raw_data, byteorder='little', signed=True)

                await RisingEdge(dut.clk)
                dut.sample_in.value = input_sample & 0xFFFFFF
                dut.new_sample.value = 1
                
                await RisingEdge(dut.clk)
                dut.new_sample.value = 0

                # Biztonságosabb kimenet olvasás
                val_str = str(dut.sample_out.value)
                if 'x' in val_str.lower() or 'z' in val_str.lower():
                    output_sample = 0
                else:
                    try:
                        output_sample = int(dut.sample_out.value)
                    except ValueError:
                        output_sample = 0
                
                

                if output_sample & (1 << 23):
                    output_sample -= (1 << 24)

                wf_out.writeframes(output_sample.to_bytes(3, byteorder='little', signed=True))

    cocotb.log.info(f"Feldolgozás kész! Eredmény mentve ide: {output_wav_name}")