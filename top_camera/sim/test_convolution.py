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

H_TOTAL = 5
V_TOTAL = 5
H_ACTIVE = 3
V_ACTIVE = 3

# # create a blank image with dimensions (w,h)
# im_output = Image.new('RGB',(H_ACTIVE,V_ACTIVE))
# # # write RGB values (r,g,b) [range 0-255] to coordinate (x,y)
# im_output.putpixel((0,0),(0,0,0))
# im_output.putpixel((0,1),(0,0,0))
# im_output.putpixel((0,2),(0,0,0))
# im_output.putpixel((1,0),(0,0,0))
# im_output.putpixel((1,1),(0,0,0))
# im_output.putpixel((1,2),(0,0,0))
# im_output.putpixel((2,0),(0,0,0))
# im_output.putpixel((2,1),(0,0,0))
# im_output.putpixel((2,2),(0,0,0))
# # save image to a file
# im_output.save('test.png','PNG')

# from PIL import Image, ImageFilter

# def convolve(image, kernel):
#     # Create a new image with the same size as the original
#     output = Image.new("RGB", image.size)

#     # Iterate over each pixel in the image
#     for x in range(image.width):
#         for y in range(image.height):
#             # Calculate the new pixel value using the kernel
#             new_pixel = [0, 0, 0]
#             for i in range(-1, 2):
#                 for j in range(-1, 2):
#                     pixel = image.getpixel((x + i, y + j))
#                     new_pixel[0] += pixel[0] * kernel[i + 1][j + 1]
#                     new_pixel[1] += pixel[1] * kernel[i + 1][j + 1]
#                     new_pixel[2] += pixel[2] * kernel[i + 1][j + 1]

#             # Clamp values to 0-255
#             new_pixel = [max(0, min(int(val), 255)) for val in new_pixel]

#             # Set the new pixel value in the output image
#             output.putpixel((x, y), tuple(new_pixel))

#     return output

# # Example usage
# image = Image.open("test.png")

# # Example 3x3 kernel for blurring
# kernel = [
#     [1/9, 1/9, 1/9],
#     [1/9, 1/9, 1/9],
#     [1/9, 1/9, 1/9]
# ]

# output = convolve(image, kernel)





async def send_frame(dut):
    await FallingEdge(dut.clk_in)
    for v in range(V_TOTAL):
        for h in range(H_TOTAL):
            dut.hcount_in.value = h
            dut.vcount_in.value = v
            valid = (h < H_ACTIVE) and (v < V_ACTIVE)
            dut.data_valid_in.value = valid
            if valid:
                dut.data_in.value = 0xF800F800F800
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

    await send_frame(dut)


def convolution_runner():
    """convolution Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "convolution.sv"]
    sources += [proj_path / "hdl" / "kernels.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="convolution",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="convolution",
        test_module="test_convolution",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    convolution_runner()