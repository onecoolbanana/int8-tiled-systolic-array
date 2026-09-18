module result_writer (
    input wire clk, rst,
    input  wire start,                        // pulse
    input  wire [1:0] tile_i, tile_j,
    input  wire signed [31:0] acc_in [0:3][0:3],
    output reg  busy, done,
    output wire [7:0] addr,
    output wire  [31:0]  din,
    output reg  wen1
);

    wire [1:0] row, col;
    reg [3:0] counter;
    assign row = counter[3:2];
    assign col = counter[1:0];
    assign addr = (row + tile_i * 4)*16 + (col + tile_j * 4);
    assign din = acc_in[row][col];

    always @(posedge clk) begin
        if (rst) begin
            counter <= 0;
            busy <= 0;
            done <= 0;
            wen1 <= 0;
        end else begin
            if (start) begin
                busy <= 1;
                done <= 0;
                counter <= 0;
                wen1 <= 1;
            end else if (busy) begin
                if (counter == 15) begin
                    busy <= 0;
                    done <= 1;
                    wen1 <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end else begin
                wen1 <= 0;
                done <= 0;
            end
        end
    end

endmodule