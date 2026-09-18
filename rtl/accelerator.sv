module accelerator (
    input  wire clk, rst, start,
    output wire done
);

    wire [1:0] tile_i, tile_j, tile_k;
    wire tile_seq_load_start, tile_loader_tile_ready, tile_seq_acc_clr, 
        tile_seq_stream_en, tile_seq_store_start, tile_seq_store_buffer, result_writer_done;
    wire [2:0] stream_counter;

    tile_sequencer tile_seq (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .done(done),
        .tile_i(tile_i), 
        .tile_j(tile_j), 
        .tile_k(tile_k),
        .load_start(tile_seq_load_start), 
        .load_ready(tile_loader_tile_ready),
        .stream_counter_out(stream_counter),
        .store_buffer(tile_seq_store_buffer),
        .acc_clr(tile_seq_acc_clr), 
        .stream_en(tile_seq_stream_en),
        .store_start(tile_seq_store_start), 
        .store_done(result_writer_done)
    );

    wire tile_loader_busy;
    wire [5:0] tile_loader_addr_a, tile_loader_addr_b;
    wire [31:0] tile_loader_dout_a, tile_loader_dout_b;
    wire signed [7:0] tile_loader_a_buf [0:3][0:6];
    wire signed [7:0] tile_loader_b_buf [0:3][0:6];

    tile_loader loader (
        .clk(clk),
        .rst(rst),
        .start(tile_seq_load_start),                       
        .tile_i(tile_i), 
        .tile_j(tile_j), 
        .tile_k(tile_k),
        .busy(tile_loader_busy),
        .tile_ready(tile_loader_tile_ready),                  
        .addr_a(tile_loader_addr_a),
        .addr_b(tile_loader_addr_b),
        .dout_a(tile_loader_dout_a),
        .dout_b(tile_loader_dout_b),
        .a_buf(tile_loader_a_buf),
        .b_buf(tile_loader_b_buf)
    );

    wire signed [31:0] array_acc_out [0:3][0:3];
    reg signed [31:0] array_acc_out_buffer [0:3][0:3];
    reg signed [7:0] array_a_in_row [0:3];
    reg signed [7:0] array_b_in_row [0:3];

    always @(*) begin
        for (int r = 0; r < 4; r++) begin
            array_a_in_row[r] = tile_seq_stream_en ? tile_loader_a_buf[r][6 - stream_counter] : 8'sd0;
            array_b_in_row[r] = tile_seq_stream_en ? tile_loader_b_buf[r][6 - stream_counter] : 8'sd0;
        end
    end

    systolic_array array (
        .clk(clk),
        .rst(rst),
        .clr(tile_seq_acc_clr),
        .a_in_row(array_a_in_row),
        .b_in_row(array_b_in_row),
        .acc_out(array_acc_out)
    );

    wire result_writer_busy, result_writer_wen1;
    wire [7:0] result_writer_addr;
    wire signed [31:0] result_writer_din;

    result_writer writer (
        .clk(clk),
        .rst(rst),
        .start(tile_seq_store_start),                       
        .tile_i(store_i), 
        .tile_j(store_j), 
        .acc_in(array_acc_out_buffer),
        .busy(result_writer_busy),
        .done(result_writer_done),                  
        .addr(result_writer_addr),
        .din(result_writer_din),
        .wen1(result_writer_wen1)
    );

    reg [1:0] store_i, store_j;
    always @(posedge clk) begin
        if (tile_seq_store_buffer) begin
            store_i <= tile_i;
            store_j <= tile_j;
            for (int r = 0; r < 4; r++) begin
                for (int c = 0; c < 4; c++) begin
                    array_acc_out_buffer[r][c] <= array_acc_out[r][c];
                end
            end
        end
    end

    ram #(.DATA_WIDTH(32), .ADDR_WIDTH(6), .DEPTH(64), .LOAD_FILE("mem_a.hex")) mem_a(
        .clk(clk),
        .addr(tile_loader_addr_a),
        .dout(tile_loader_dout_a),
        .wen1(1'b0),
        .din(32'b0)
    );

    ram #(.DATA_WIDTH(32), .ADDR_WIDTH(6), .DEPTH(64), .LOAD_FILE("mem_b.hex")) mem_b(
        .clk(clk),
        .addr(tile_loader_addr_b),
        .dout(tile_loader_dout_b),
        .wen1(1'b0),
        .din(32'b0)
    );

    result_memory result_mem (
        .clk(clk),
        .dout(),
        .addr(result_writer_addr),
        .din(result_writer_din),
        .wen1(result_writer_wen1)
    );

endmodule

module accel_tb;

    reg clk;
    reg rst;
    reg start;
    wire done;
    
    accelerator uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    reg [31:0] ticks;

    initial ticks = 0;

    always @(posedge clk) begin
        ticks <= ticks + 1;
    end

    reg [31:0] exp [0:255];
    integer errors = 0;
    initial $readmemh("expected.hex", exp);

    initial begin
        rst = 1;
        start = 0;
        #10;
        rst = 0;
        #10;
        start = 1;
        #10;
        start = 0;

        wait(done);
        $display("Matrix multiplication completed. Ticks: %0d", ticks);
        // for (int i = 0; i < 4; i++) begin
        //     $display("%5d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d", 
        //              uut.result_mem.mem[i*16], uut.result_mem.mem[i*16+1], uut.result_mem.mem[i*16+2], uut.result_mem.mem[i*16+3], 
        //              uut.result_mem.mem[i*16+4], uut.result_mem.mem[i*16+5], uut.result_mem.mem[i*16+6], uut.result_mem.mem[i*16+7],
        //              uut.result_mem.mem[i*16+8], uut.result_mem.mem[i*16+9], uut.result_mem.mem[i*16+10], uut.result_mem.mem[i*16+11],
        //              uut.result_mem.mem[i*16+12], uut.result_mem.mem[i*16+13], uut.result_mem.mem[i*16+14], uut.result_mem.mem[i*16+15]);
        // end

        for (int i = 0; i < 256; i++)
            if (uut.result_mem.mem[i] !== exp[i]) begin
                if (errors < 10)
                    $display("MISMATCH C[%0d][%0d]: got %0d expected %0d",
                            i/16, i%16, $signed(uut.result_mem.mem[i]), $signed(exp[i]));
                errors = errors + 1;
            end
        $display("ERRORS: %0d", errors);

        $finish;
    end
endmodule