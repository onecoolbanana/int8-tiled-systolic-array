module systolic_array(

    input clk,
    input rst,
    input clr,

    input wire signed [7:0] a_in_row [0:3],
    input wire signed [7:0] b_in_row [0:3],

    output wire signed [31:0] acc_out [0:3][0:3]

);

    wire signed [7:0] a_wire [0:3][0:4];
    wire signed [7:0] b_wire [0:4][0:3];

    genvar r, c;
    generate
        for (r = 0; r < 4; r = r+1) begin : gen_row
            for (c = 0; c < 4; c = c+1) begin : gen_col
                pe pe_inst (
                    .clk(clk),
                    .rst(rst),
                    .a_in( (c == 0) ? a_in_row[r] : a_wire[c-1][r] ),
                    .b_in( (r == 0) ? b_in_row[c] : b_wire[c][r-1] ),
                    .acc_out(acc_out[r][c]),
                    .a_out(a_wire[c][r]),
                    .b_out(b_wire[c][r]),
                    .acc_clr(clr)
                );
            end
        end
    endgenerate
endmodule
