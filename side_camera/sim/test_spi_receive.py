import cocotb
import os
import random
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

# utility function to reverse bits:
def reverse_bits(n,size):
    reversed_n = 0
    for i in range(size):
        reversed_n = (reversed_n << 1) | (n & 1)
        n >>= 1
    return reversed_n

# message_sent = 0b0001_0101_1000

bits_sent = [1,0,0,1,0,1,0,1,1,0,0,0]

@cocotb.test()
async def test_a(dut):
    """cocotb test for seven segment controller"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut._log.info("Holding reset...")
    dut.rst_in.value = 1
    dut.chip_sel_in.value = 1
    await ClockCycles(dut.clk_in, 3) #wait three clock cycles
    await  FallingEdge(dut.clk_in)
    dut.rst_in.value = 0 #un reset device
    await ClockCycles(dut.clk_in, 3) #wait a few clock cycles
    await RisingEdge(dut.clk_in)
    dut._log.info("Trigger from Controller")
    dut.chip_sel_in.value = 0
    # first duty cycle starts with low
    dut.chip_clk_in.value = 0
    dut.chip_data_in.value = bits_sent[0]
    for i in bits_sent[1:]:
        await ClockCycles(dut.clk_in, 4) #wait a few clock cycles
        await RisingEdge(dut.clk_in)
        dut.chip_clk_in.value = 1
        await ClockCycles(dut.clk_in, 4) #wait a few clock cycles
        await RisingEdge(dut.clk_in)
        dut.chip_data_in.value = i
        dut.chip_clk_in.value = 0
    await ClockCycles(dut.clk_in, 4) #wait a few clock cycles
    dut.chip_clk_in.value = 1
    await ClockCycles(dut.clk_in, 4) #wait a few clock cycles
    dut.chip_sel_in.value = 1
    dut.chip_clk_in.value = 1
    

    await ClockCycles(dut.clk_in, 300)

def spi_con_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent#.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "spi_receive.sv"]
    build_test_args = ["-Wall"]
    parameters = {'DATA_WIDTH': 12, 'DATA_CLK_PERIOD':10} #!!!change these to do different versions
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="spi_receive",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="spi_receive",
        test_module="test_spi_receive",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    spi_con_runner()