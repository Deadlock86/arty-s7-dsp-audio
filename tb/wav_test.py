import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_bypass_mode(dut):
    """1. Teszt: Bypass mód ellenőrzése (enable = 0)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.new_sample.value = 0
    dut.sample_in.value = 0x123456
    dut.enable.value = 0  # Bypass

    await Timer(40, units="ns")
    await RisingEdge(dut.clk)

    # Bypass módban a kimenetnek azonnal kötnie kell a bemenetet
    assert dut.sample_out.value == 0x123456, \
        f"Hiba: Bypass kimenet {dut.sample_out.value:#x}, várt: 0x123456"
    cocotb.log.info("Sikeres Bypass teszt!")


@cocotb.test()
async def test_single_pulse_processing(dut):
    """2. Teszt: Egyetlen minta beadása new_sample plusszal"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.new_sample.value = 0
    dut.sample_in.value = 0
    dut.enable.value = 1       # Effekt aktív
    dut.mode_sel.value = 0     # Alap mód
    dut.dtime.value = 0       # Delay idő
    dut.feedback.value = 0
    dut.elevel.value = 4

    await Timer(50, units="ns")

    # Minta beadása 1 órajel ciklusra
    await RisingEdge(dut.clk)
    dut.sample_in.value = 0x00AABB
    dut.new_sample.value = 1
    
    await RisingEdge(dut.clk)
    dut.new_sample.value = 0



    # Várunk néhány ciklust, hogy a pipeline feldolgozza
    for i in range(200):
        await RisingEdge(dut.clk)
        cocotb.log.info(f"Ciklus {i}: kimenet = {dut.sample_out.value}")

    cocotb.log.info("Pulzus teszt lefutott.")