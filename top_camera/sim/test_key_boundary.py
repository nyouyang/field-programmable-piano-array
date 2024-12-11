import cocotb
from cocotb.triggers import Timer
import os
from pathlib import Path
import sys

from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,ReadWrite,with_timeout, First, Join
from cocotb.runner import get_runner

from PIL import Image
import numpy as np


async def send_frame(dut):
    await FallingEdge(dut.clk_in)
    for v in range(180):
        for h in range(320):
            # dut.addr_into_fb.value = h+320*v
            if h % 24 == 6:
                dut.pixel_from_fb.value = 1
            elif h % 48 == 7:
                dut.pixel_from_fb.value = 1
            else:
                dut.pixel_from_fb.value = 0
            await RisingEdge(dut.clk_in)
            await FallingEdge(dut.clk_in)


@cocotb.test()
async def test_key_boundary(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 2)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 2)
    await send_frame(dut)


def key_boundary_runner():
    """key_boundary Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "key_boundary.sv"]
    # sources += [proj_path / "hdl" / "kernels.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="key_boundary",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="key_boundary",
        test_module="test_key_boundary",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    key_boundary_runner()