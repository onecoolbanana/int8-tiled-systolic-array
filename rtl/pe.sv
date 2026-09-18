module pe (
    input wire clk,
    input wire rst,
    input wire acc_clr,
    input wire signed [7:0] a_in,
    input wire signed [7:0] b_in,
    output reg signed [31:0] acc_out,
    output reg signed [7:0] a_out,
    output reg signed [7:0] b_out
);
  
    always @(posedge clk) begin
        if (rst) begin
            a_out <= 0;
            b_out <= 0;
            acc_out <= 0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            if (acc_clr) begin
                acc_out <= 0;
            end else begin
                acc_out <= acc_out + (a_in * b_in);
            end
        end
    end

endmodule
