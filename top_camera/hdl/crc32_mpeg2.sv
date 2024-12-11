module crc32_mpeg2(
            input wire clk_in,
            input wire rst_in,
            input wire data_valid_in,
            input wire data_in,
            output logic [31:0] data_out);
 
    always_ff @(posedge clk_in) begin

        if (rst_in) begin
            data_out <= 32'hFFFF_FFFF;

        end else begin

            if (data_valid_in) begin
                for (int i=0; i<32; i=i+1) begin
                    if (i == 1 || i == 2 || i == 4 || i == 5 || i == 7 || i == 8 || i == 10 || i == 11 || i == 12 || i == 16 || i == 22 || i == 23 || i == 26) begin
                        data_out[i] <= data_out[i-1] ^ (data_in ^ data_out[31]);
                    end else if (i == 0) begin
                        data_out[i] <= data_in ^ data_out[31];
                    end else begin
                        data_out[i] <= data_out[i-1];
                    end

                end            
            end 
        end
    end

endmodule