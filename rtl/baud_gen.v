`timescale 1ns / 1ps
module baud_gen #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD     = 115200
)(
    input  wire clk,
    input  wire rst,
    output reg  baud_tick
);
    localparam integer DIV = CLK_FREQ / BAUD;
    reg [31:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 0;
            baud_tick <= 0;
        end else begin
            if (cnt == DIV-1) begin
                cnt <= 0;
                baud_tick <= 1;
            end else begin
                cnt <= cnt + 1;
                baud_tick <= 0;
            end
        end
    end
endmodule
