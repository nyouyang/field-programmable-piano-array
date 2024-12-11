module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/emilyzhang/Desktop/6.205/fpga/sim_build/spi_receive.fst");
    $dumpvars(0, spi_receive);
end
endmodule
