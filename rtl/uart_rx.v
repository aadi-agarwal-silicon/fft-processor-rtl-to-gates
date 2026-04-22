`timescale 1ns / 1ps

module uart_rx #(
    parameter CLKS_PER_BIT = 868  // 100MHz / 115200 = 868
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] data_out,
    output reg        data_valid
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [15:0] clk_cnt; // Internal Timer (Jiritsu)
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            clk_cnt    <= 0;
            bit_idx    <= 0;
            data_out   <= 0;
            data_valid <= 0;
            shift_reg  <= 0;
        end else begin
            data_valid <= 0;

            case (state)
                IDLE: begin
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if (rx == 0) begin // Start Bit Detected
                        state <= START;
                    end
                end

                // Wait for Middle of Start Bit
                START: begin
                    if (clk_cnt == (CLKS_PER_BIT / 2)) begin
                        if (rx == 0) begin
                            clk_cnt <= 0;
                            state   <= DATA;
                        end else begin
                            state <= IDLE; // Noise! Go back.
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                // Sample 8 Data Bits
                DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        shift_reg[bit_idx] <= rx;
                        
                        if (bit_idx == 7) begin
                            bit_idx <= 0;
                            state   <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                // Stop Bit (End of Frame)
                STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        data_valid <= 1; // Good Byte!
                        data_out   <= shift_reg;
                        state      <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
