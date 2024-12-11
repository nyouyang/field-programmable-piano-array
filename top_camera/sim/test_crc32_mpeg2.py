import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
import libscrc
import struct

@cocotb.test()
async def test_a(dut):
    """cocotb test for crc32_mpeg2"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,2)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 0
    dut.data_valid_in.value = 1
    dut.data_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.data_valid_in.value = 1
    dut.data_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.data_valid_in.value = 1
    dut.data_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.data_valid_in.value = 1
    dut.data_in.value = 1
    await ClockCycles(dut.clk_in,1) 
    dut.data_valid_in.value = 0
    await ClockCycles(dut.clk_in,5) 
    randint = 0x9
    randcrc32 = libscrc.mpeg2(struct.pack('>L',randint))
    print(randcrc32)
    assert dut.data_out.value == randcrc32

def crc32_mpeg2_runner():
    """crc32_mpeg2 Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "crc32_mpeg2.sv"]
    # sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="crc32_mpeg2",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="crc32_mpeg2",
        test_module="test_crc32_mpeg2",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    crc32_mpeg2_runner()
