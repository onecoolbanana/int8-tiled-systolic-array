module tile_loader (
    input  wire clk,
    input  wire rst,
    input  wire start,                          // single-cycle pulse
    input  wire [1:0] tile_i, tile_j, tile_k,
    output reg  busy,
    output reg  tile_ready,                     // single-cycle pulse
    output wire [5:0] addr_a,
    output wire [5:0] addr_b,
    input  wire [31:0]  dout_a,
    input  wire [31:0]  dout_b,
    output reg signed [7:0] a_buf [0:3][0:6],
    output reg signed [7:0] b_buf [0:3][0:6]
);

    reg [1:0] counter;
    reg [1:0] counter_d;

    wire [1:0] e = counter[1:0];
    reg [1:0] e_d;

    assign addr_a = (tile_k*4 + e)*4 + tile_i;
    assign addr_b = (tile_k*4 + e)*4 + tile_j;

    always @(posedge clk) begin
        if (rst) begin
            busy <= 0;
            tile_ready <= 0;
            counter <= 0;
            for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 7; j++) begin
                        a_buf[i][j] <= 0;
                        b_buf[i][j] <= 0;
                    end
            end
        end else begin
            if (start) begin
                busy <= 1;
                tile_ready <= 0;
                counter <= 0;
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 7; j++) begin
                        a_buf[i][j] <= 0;
                        b_buf[i][j] <= 0;
                    end
                end
            end else if (busy) begin
                e_d <= e;
                counter_d <= counter;
                if (counter_d == 2'd3) begin
                    busy <= 0;
                    tile_ready <= 1;
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
                
                for (int r = 0; r < 4; r++) begin
                    a_buf[r][e_d + 3 - r] <= dout_a[r*8+:8];
                    b_buf[r][e_d + 3 - r] <= dout_b[r*8+:8];
                end
            end else begin
                tile_ready <= 0;
            end
        end
    end
endmodule

// module tile_loader_tb;
//     reg clk;
//     reg rst;
//     reg start;
//     reg [1:0] tile_i, tile_j, tile_k;
//     wire busy;
//     wire tile_ready;
//     wire [10:0] addr;
//     reg [7:0] dout;

//     tile_loader uut (
//         .clk(clk),
//         .rst(rst),
//         .start(start),
//         .tile_i(tile_i),
//         .tile_j(tile_j),
//         .tile_k(tile_k),
//         .busy(busy),
//         .tile_ready(tile_ready),
//         .addr(addr),
//         .dout(dout)
//     );

//     ram mem_inst (
//         .clk(clk),
//         .wen1(1'b0), // No write operations in this test
//         .addr(addr),
//         .din(8'd0), // Not used
//         .dout(dout)
//     );

//     initial begin
//         clk = 0;
//         forever #5 clk = ~clk; // 100MHz clock
        
//     end

//     initial begin
//         rst = 1;
//         start = 0;
//         tile_i = 1;
//         tile_j = 0;
//         tile_k = 2;

//         #20 rst = 0; // Release reset after 20ns

//         // Start loading a tile
//         #10 start = 1; // Pulse start signal
//         $display("Starting tile load at time %t", $time);
//         #10 start = 0;
//         wait (busy == 0); // Wait until loading is complete
//         $display("Tile load complete at time %t", $time);
//         for (int i = 0; i < 4; i++) begin
//             $display("a_buf[%0d]: %d, %d, %d, %d, %d, %d, %d", i, uut.a_buf[i][0], uut.a_buf[i][1], uut.a_buf[i][2], uut.a_buf[i][3], uut.a_buf[i][4], uut.a_buf[i][5], uut.a_buf[i][6]);
//         end
//         for (int i = 0; i < 4; i++) begin
//             $display("b_buf[%0d]: %d, %d, %d, %d, %d, %d, %d", i, uut.b_buf[i][0], uut.b_buf[i][1], uut.b_buf[i][2], uut.b_buf[i][3], uut.b_buf[i][4], uut.b_buf[i][5], uut.b_buf[i][6]);
//         end
//         $finish;
//     end
// endmodule