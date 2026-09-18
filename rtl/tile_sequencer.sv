module tile_sequencer (
    input  wire clk, rst,
    input  wire start,
    output reg  done,
    output reg  [1:0] tile_i, tile_j, tile_k,
    
    output reg  load_start,
    input  wire load_ready,
    
    output wire [2:0] stream_counter_out,
    output reg store_buffer,
    output reg  acc_clr,
    output reg  stream_en,
    
    output reg  store_start,
    input  wire store_done
);
    
    reg [2:0] state;
    reg [2:0] stream_counter;
    reg [1:0] drain_counter;

    assign stream_counter_out = stream_counter;

    reg load_start_pulsed, store_start_pulsed;

    always @(posedge clk) begin
        if (rst) begin
            state <= 0;
            done <= 0;
            tile_i <= 0;
            tile_j <= 0;
            tile_k <= 0;
            load_start <= 0;
            acc_clr <= 0;
            stream_en <= 0;
            store_start <= 0;
            store_buffer <= 0;
        end else begin
            case (state)
                0: begin // Idle
                    if (start) begin
                        state <= 1;
                        done <= 0;
                        tile_i <= 0;
                        tile_j <= 0;
                        tile_k <= 0;
                        load_start <= 0;
                        load_start_pulsed <= 0;
                        store_start <= 0;
                        store_start_pulsed <= 0;
                    end
                end
                1: begin // Clear
                    acc_clr <= 1;
                    state <= 2;
                end
                2: begin // Load
                    if (!load_start_pulsed) begin
                        load_start <= 1;
                        load_start_pulsed <= 1;
                    end else begin
                        load_start <= 0;
                    end

                    acc_clr <= 0;
                    stream_counter <= 0;
                    drain_counter <= 0;
                    if (load_ready) begin
                        load_start <= 0;
                        stream_en <= 1;
                        state <= 3;
                        load_start_pulsed <= 0;
                    end

                end
                3: begin // Stream
                    if (stream_counter == 6) begin
                        stream_en <= 0;
                        stream_counter <= 0;
                        
                        if (tile_k < 3) begin
                            tile_k <= tile_k + 1;
                            state <= 2;
                        end else begin
                            state <= 4;
                        end

                    end else begin
                        stream_counter <= stream_counter + 1;
                    end
                end
                4: begin // Drain (wait for last element to reach corner PE)                    
                    if (drain_counter == 3) begin
                        state <= 5;
                        store_buffer <= 1;
                    end else begin
                        drain_counter <= drain_counter + 1;
                    end
                end
                5: begin
                    store_buffer <= 0;
                    if (!store_start_pulsed) begin
                        store_start <= 1;
                        store_start_pulsed <= 1;
                    end else begin
                        store_start <= 0;
                        store_start <= 0;
                        store_start_pulsed <= 0;
                        if (tile_j == 3) begin
                            if (tile_i == 3) begin        
                                state <= 6;
                            end else begin
                                tile_i <= tile_i + 1;
                                tile_j <= 0;
                                tile_k <= 0;
                                state <= 1;
                            end                        
                        end else begin
                            tile_j <= tile_j + 1;
                            tile_k <= 0;
                            state <= 1;
                        end
                    end
                end
                6: begin
                    if (store_done) begin
                        done <= 1;
                        state <= 0;
                    end
                end
            default: begin
                    state <= 0;
                end
            endcase
        end
    end

endmodule
