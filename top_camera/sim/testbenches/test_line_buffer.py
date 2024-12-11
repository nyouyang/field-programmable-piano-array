import cocotb
from cocotb.triggers import Timer
import os
from pathlib import Path
import sys

from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,ReadWrite,with_timeout, First, Join
from cocotb.runner import get_runner


H_TOTAL = 6
V_TOTAL = 6
H_ACTIVE = 4
V_ACTIVE = 4

async def send_frame(dut, frame):
    await FallingEdge(dut.clk_in)
    for v in range(V_TOTAL):
        for h in range(H_TOTAL):
            dut.hcount_in.value = h
            dut.vcount_in.value = v
            valid = (h < H_ACTIVE) and (v < V_ACTIVE)
            dut.data_valid_in.value = valid
            if valid:
                dut.pixel_data_in.value = frame[v][h]
            await RisingEdge(dut.clk_in)
            await FallingEdge(dut.clk_in)


@cocotb.test()
async def test_line_buffer(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.hcount_in.value = 0
    dut.vcount_in.value = 0
    dut.data_valid_in.value = False
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 2)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 2)

    frame = [[1,2,3,4],[1,2,3,4],[1,2,3,4],[1,2,3,4]]
    await send_frame(dut, frame)


def line_buffer_runner():
    """line_buffer Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "line_buffer.sv"]
    sources += [proj_path / "hdl" / "xilinx_true_dual_port_read_first_1_clock_ram.v"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="line_buffer",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="line_buffer",
        test_module="test_line_buffer",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    line_buffer_runner()