module lfsr_4 ( input wire clk_in, 
                input wire rst_in,
                input wire [3:0] seed_in,
                output logic [3:0] q_out);

    always_ff @(posedge clk_in) begin

        if (rst_in) begin
            q_out[0] <= seed_in[0];
            q_out[1] <= seed_in[1];
            q_out[2] <= seed_in[2];
            q_out[3] <= seed_in[3];  

        end else begin
            q_out[0] <= q_out[3];
            q_out[1] <= q_out[0] ^ q_out[3];
            q_out[2] <= q_out[1];
            q_out[3] <= q_out[2];
        end
    end

endmodule