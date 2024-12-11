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



@cocotb.test()
async def test_key_association(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 2)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 2)

    for i in range(13):
        # 10, 35, 60, 85, 110, 135, 160, 185, 210, 235, 260, 285, 310
        dut.x_coords_keys_top[i].value = 320-(10+25*i)

    dut.x_coords_keys_bottom[7].value = 12
    dut.x_coords_keys_bottom[6].value = 45
    dut.x_coords_keys_bottom[5].value = 100
    dut.x_coords_keys_bottom[4].value = 133
    dut.x_coords_keys_bottom[3].value = 172
    dut.x_coords_keys_bottom[2].value = 220
    dut.x_coords_keys_bottom[1].value = 275
    dut.x_coords_keys_bottom[0].value = 312

    dut.y_coords_keys_white[1].value = 60
    dut.y_coords_keys_white[0].value = 120
    
    dut.y_coords_keys_black[2].value = 60
    dut.y_coords_keys_black[1].value = 90
    dut.y_coords_keys_black[0].value = 120

    dut.x_com.value = 1
    dut.y_com.value = 100

    await ClockCycles(dut.clk_in, 200)


def key_association_runner():
    """key_association Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "key_association.sv"]
    # sources += [proj_path / "hdl" / "kernels.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="key_association",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="key_association",
        test_module="test_key_association",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    key_association_runner()