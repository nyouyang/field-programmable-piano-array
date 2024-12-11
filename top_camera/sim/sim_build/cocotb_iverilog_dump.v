module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/lucycai/6.205/final project/sim/sim_build/key_association.fst");
    $dumpvars(0, key_association);
end
endmodule
