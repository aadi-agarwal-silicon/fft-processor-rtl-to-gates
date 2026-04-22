`timescale 1ns / 1ps

module uart_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire       baud_tick,
    input  wire [7:0] data_in,
    input  wire       tx_start,
    output reg        tx,
    output reg        busy
);
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [2:0] bit_idx;
    reg [7:0] data_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            tx       <= 1;
            busy     <= 0;
            bit_idx  <= 0;
            data_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1;
                    if (tx_start) begin
                        state    <= START;
                        busy     <= 1;
                        data_reg <= data_in;
                    end else begin
                        busy <= 0;
                    end
                end
                START: begin
                    busy <= 1;
                    if (baud_tick) begin
                        tx      <= 0;
                        state   <= DATA;
                        bit_idx <= 0;
                    end
                end
                DATA: begin
                    busy <= 1;
                    if (baud_tick) begin
                        tx       <= data_reg[0];
                        data_reg <= data_reg >> 1;
                        if (bit_idx == 7) state <= STOP;
                        else bit_idx <= bit_idx + 1;
                    end
                end
                STOP: begin
                    busy <= 1;
                    if (baud_tick) begin
                        tx    <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
