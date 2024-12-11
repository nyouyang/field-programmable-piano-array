module lfsr_16 ( input wire clk_in, 
                input wire rst_in,
                input wire [15:0] seed_in,
                output logic [15:0] q_out);

    always_ff @(posedge clk_in) begin

        if (rst_in) begin
            for (int i=0; i<16; i=i+1) begin
                q_out[i] <= seed_in[i];
            end

        end else begin
            for (int i=0; i<16; i=i+1) begin
                if (i == 2 || i == 15) begin
                    q_out[i] <= q_out[i-1] ^ q_out[15];
                    q_out[i] <= q_out[i-1] ^ q_out[15];            
                end else if (i == 0) begin
                    q_out[i] <= q_out[15];
                end else begin
                    q_out[i] <= q_out[i-1];
                end

            end
            
        end
    end

endmodule