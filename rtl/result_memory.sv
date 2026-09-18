module result_memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,  // 2^8 = 256 locations
    parameter DEPTH = 256
)(
    input  wire                   clk,
    input  wire                   wen1,
    input  wire [ADDR_WIDTH-1:0]  addr,
    input  wire [DATA_WIDTH-1:0]  din,
    output reg  [DATA_WIDTH-1:0]  dout
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (wen1)
            mem[addr] <= din;
        dout <= mem[addr];
    end

endmodule