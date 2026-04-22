`timescale 1ns / 1ps

// 8-POINT FFT


module fft8_q14 (
    input  wire clk,
    input  wire rst,
    input  wire en,
    input  wire signed [15:0] x_in,
    output reg  out_valid,
    output reg  [2:0] bin_index,
    output reg signed [15:0] y_re,
    output reg signed [15:0] y_im
);

    // Distributed RAM for simultaneous access
    (* ram_style = "distributed" *) reg signed [15:0] mem_re [0:7];
    (* ram_style = "distributed" *) reg signed [15:0] mem_im [0:7];

    reg [2:0] wr_ptr;
    reg [2:0] rd_ptr; // NEW: Separate Read Pointer
    reg full;

    reg [2:0] state;
    reg [2:0] idx;

    localparam S_IDLE   = 3'd0;
    localparam S_STAGE0 = 3'd1;
    localparam S_STAGE1 = 3'd2;
    localparam S_STAGE2 = 3'd3;
    localparam S_OUTPUT = 3'd4;

    // Twiddle constants
    localparam signed [15:0] TW_RE_0 = 16384; localparam signed [15:0] TW_IM_0 = 0;
    localparam signed [15:0] TW_RE_1 = 11585; localparam signed [15:0] TW_IM_1 = -11585;
    localparam signed [15:0] TW_RE_2 = 0;     localparam signed [15:0] TW_IM_2 = -16384;
    localparam signed [15:0] TW_RE_3 = -11585; localparam signed [15:0] TW_IM_3 = -11585;

    // Temp variables
    integer i;
    integer a_idx, b_idx;
    reg signed [15:0] a_re16, a_im16, b_re16, b_im16;
    reg signed [15:0] tw_re, tw_im;
    reg signed [31:0] m1, m2, m3, m4;
    reg signed [31:0] t_re32, t_im32;

    always @(*) begin
        case(idx)
            3'd0: begin tw_re = TW_RE_0; tw_im = TW_IM_0; end
            3'd1: begin tw_re = TW_RE_1; tw_im = TW_IM_1; end
            3'd2: begin tw_re = TW_RE_2; tw_im = TW_IM_2; end
            3'd3: begin tw_re = TW_RE_3; tw_im = TW_IM_3; end
            default: begin tw_re = 0; tw_im = 0; end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0; rd_ptr <= 0;
            full <= 0; state <= S_IDLE; idx <= 0;
            out_valid <= 0; bin_index <= 0; y_re <= 0; y_im <= 0;
            for (i = 0; i < 8; i = i+1) begin
                mem_re[i] <= 0; mem_im[i] <= 0;
            end
        end else begin
            out_valid <= 0;

            // INPUT
            if (en && !full) begin
                mem_re[wr_ptr] <= x_in;
                mem_im[wr_ptr] <= 0;
                wr_ptr <= wr_ptr + 1;
                if (wr_ptr == 3'd7) full <= 1;
            end

            case (state)
                S_IDLE: begin
                    if (full) begin
                        idx <= 0; state <= S_STAGE0;
                    end
                end

                S_STAGE0: begin 
                    if (idx < 4) begin
                        a_idx = (idx<<1); b_idx = a_idx + 1;
                        a_re16 = mem_re[a_idx]; a_im16 = mem_im[a_idx];
                        b_re16 = mem_re[b_idx]; b_im16 = mem_im[b_idx];
                        mem_re[a_idx] <= a_re16 + b_re16;
                        mem_im[a_idx] <= a_im16 + b_im16;
                        mem_re[b_idx] <= a_re16 - b_re16;
                        mem_im[b_idx] <= a_im16 - b_im16;
                        idx <= idx + 1;
                    end else begin
                        idx <= 0; state <= S_STAGE1;
                    end
                end

                S_STAGE1: begin
                    if (idx < 4) begin
                        case(idx)
                            0: begin a_idx=0; b_idx=2; end
                            1: begin a_idx=1; b_idx=3; end
                            2: begin a_idx=4; b_idx=6; end
                            3: begin a_idx=5; b_idx=7; end
                        endcase
                        a_re16 = mem_re[a_idx]; a_im16 = mem_im[a_idx];
                        b_re16 = mem_re[b_idx]; b_im16 = mem_im[b_idx];
                        mem_re[a_idx] <= a_re16 + b_re16;
                        mem_im[a_idx] <= a_im16 + b_im16;
                        mem_re[b_idx] <= a_re16 - b_re16;
                        mem_im[b_idx] <= a_im16 - b_im16;
                        idx <= idx + 1;
                    end else begin
                        idx <= 0; state <= S_STAGE2;
                    end
                end

                S_STAGE2: begin
                    if (idx < 4) begin
                        case(idx)
                            0: begin a_idx=0; b_idx=4; end
                            1: begin a_idx=1; b_idx=5; end
                            2: begin a_idx=2; b_idx=6; end
                            3: begin a_idx=3; b_idx=7; end
                        endcase
                        a_re16 = mem_re[a_idx]; a_im16 = mem_im[a_idx];
                        b_re16 = mem_re[b_idx]; b_im16 = mem_im[b_idx];
                        m1 = b_re16 * tw_re; m2 = b_im16 * tw_im;
                        m3 = b_re16 * tw_im; m4 = b_im16 * tw_re;
                        t_re32 = (m1 - m2) >>> 14;
                        t_im32 = (m3 + m4) >>> 14;
                        mem_re[a_idx] <= a_re16 + t_re32[15:0];
                        mem_im[a_idx] <= a_im16 + t_im32[15:0];
                        mem_re[b_idx] <= a_re16 - t_re32[15:0];
                        mem_im[b_idx] <= a_im16 - t_im32[15:0];
                        idx <= idx + 1;
                    end else begin
                        idx <= 0; 
                        rd_ptr <= 0; // Reset Read Pointer
                        state <= S_OUTPUT;
                    end
                end

              
                S_OUTPUT: begin
                    y_re <= mem_re[rd_ptr];
                    y_im <= mem_im[rd_ptr];
                    
                  
                    bin_index <= rd_ptr; 
                    out_valid <= 1;

                    if (rd_ptr == 3'd7) begin
                        wr_ptr <= 0; full <= 0; state <= S_IDLE;
                    end else begin
                        rd_ptr <= rd_ptr + 1;
                    end
                end
            endcase
        end
    end
endmodule
