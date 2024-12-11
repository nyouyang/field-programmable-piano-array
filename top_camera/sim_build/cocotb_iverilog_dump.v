module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/emilyzhang/Desktop/6.205/final project/sim_build/spi_transmit.fst");
    $dumpvars(0, spi_transmit);
end
endmodule
