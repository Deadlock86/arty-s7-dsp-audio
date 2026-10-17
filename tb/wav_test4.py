import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

import wave
import os
import math

tb_dir = os.path.dirname(os.path.abspath(__file__))



@cocotb.test()
async def dd8_custom_wav_file_test(dut):
    """Test processing an existing WAV file directly on dd8_core (using new_sample pulse per sample)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    input_filename = os.path.join(tb_dir, "clean guitar sample mono.wav")
    output_filename = os.path.join(tb_dir, "output_custom_processed.wav")

    if not os.path.exists(input_filename):
        cocotb.log.error(f"A bemeneti WAV fájl nem található itt: {input_filename}")
        return

    # Hardver alapbeállítások a dd8_core portjaihoz igazítva
    dut.new_sample.value = 0
    dut.sample_in.value = 0
    dut.mode_sel.value = 2     # 2 = Tape mód (vagy 0 = Standard)
    dut.dtime.value = 4        # Delay idő (0-6)
    dut.feedback.value = 4     # Visszacsatolás
    dut.elevel.value = 5       # Wet/Effect szint
    dut.enable.value = 1       # Effekt bekapcsolva

    await Timer(100, units="ns")

    cocotb.log.info(f"Feldolgozás indítása ezzel a fájllal: {os.path.basename(input_filename)}")

    with wave.open(input_filename, 'r') as wf_in:
        n_channels = wf_in.getnchannels()
        sample_width = wf_in.getsampwidth()
        framerate = wf_in.getframerate()
        n_frames = wf_in.getnframes()
        
        # Hozzáadunk egy kis lecsengési időt (tail) a fájl végéhez, hogy a delay is kifusson
        tail_duration_sec = 1.0
        total_frames = n_frames + int(framerate * tail_duration_sec)

        cocotb.log.info(f"WAVinfó -> Minták: {n_frames}, Teljes feldolgozandó (beletartozva a lecsengést is): {total_frames}")

        with wave.open(output_filename, 'w') as wf_out:
            wf_out.setnchannels(n_channels)
            wf_out.setsampwidth(sample_width)
            wf_out.setframerate(framerate)

            for i in range(total_frames):
                if i < n_frames:
                    raw_data = wf_in.readframes(1)
                    if not raw_data:
                        signal_in = 0
                    else:
                        if sample_width == 3:
                            input_sample = int.from_bytes(raw_data, byteorder='little', signed=True)
                            signal_in = input_sample & 0xFFFFFF
                        elif sample_width == 2:
                            input_sample = int.from_bytes(raw_data, byteorder='little', signed=True)
                            signal_in = (input_sample << 8) & 0xFFFFFF
                        else:
                            input_sample = int.from_bytes(raw_data, byteorder='little', signed=True)
                            signal_in = input_sample
                else:
                    # A fájl vége után tiszta csendet adunk be a delay lecsengéséhez
                    signal_in = 0

                # --- PONTOS MINTAÜTEMEZÉS A DD8_CORE-HOZ ---
                # 1. Órajel él: beállítjuk az adatot és a new_sample impulzust 1-re
                await RisingEdge(dut.clk)
                dut.sample_in.value = signal_in
                dut.new_sample.value = 1
                
                # 2. Következő órajel él: visszahúzzuk a new_sample-t 0-ra, 
                # és ekkor olvassuk ki a stabil kimenetet!
                await RisingEdge(dut.clk)
                dut.new_sample.value = 0

                # Kimenet kiolvasása
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

                # Mentés a kimeneti WAV-ba
                if sample_width == 3:
                    wf_out.writeframes(output_sample.to_bytes(3, byteorder='little', signed=True))
                elif sample_width == 2:
                    out_16 = max(-32768, min(32767, output_sample >> 8))
                    wf_out.writeframes(out_16.to_bytes(2, byteorder='little', signed=True))
                else:
                    wf_out.writeframes(output_sample.to_bytes(sample_width, byteorder='little', signed=True))
                #cocotb.log.info(f"ciklus adtai -> Be: {hex(signal_in)}, NewSample: {dut.new_sample.value}, Ki: {hex(output_sample)}")    

    cocotb.log.info(f"Feldolgozás kész! Eredmény mentve ide: {output_filename}")