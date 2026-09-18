module ram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 11,  // 2^11 = 2048 locations
    parameter DEPTH = 2048,
    parameter LOAD_FILE = "mem_a.hex"
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

    // For simulation - initialise from file
    initial begin
        $readmemh(LOAD_FILE, mem);
    end
endmodule