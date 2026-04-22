module uart_top (
    input  wire clk,
    input  wire rst_button, 
    input  wire rx,
    output wire tx,
    output reg  [7:0] led
);

    // === CONFIGURATION ===
    localparam CLK_FREQ = 100_000_000;
    localparam BAUD     = 115200;       
    localparam integer DIV = CLK_FREQ / BAUD;

    // === INTERNAL RESET ===
    reg [3:0] rst_cnt = 0;
    reg sys_rst = 1;
    always @(posedge clk) begin
        if (rst_cnt < 4'hF) begin
            rst_cnt <= rst_cnt + 1;
            sys_rst <= 1;
        end else begin
            sys_rst <= 0; 
        end
    end

    // === SIGNALS ===
    wire baud_tick;
    wire [7:0] rx_byte_u;
    wire rx_valid;
    wire tx_busy;

    wire fft_out_valid;
    wire [2:0] fft_bin;
    wire signed [15:0] fft_y_re;
    wire signed [15:0] fft_y_im;

    // === STATE MACHINE STATES ===
    localparam S_RX_WAIT     = 3'd0; 
    localparam S_PROCESS     = 3'd1; 
    localparam S_TX_PREP     = 3'd2; // Decide what byte to send
    localparam S_TX_START    = 3'd3; // Pulse start
    localparam S_TX_WAIT_HI  = 3'd4; // Wait for Busy = 1
    localparam S_TX_WAIT_LO  = 3'd5; // Wait for Busy = 0
    localparam S_TX_NEXT     = 3'd6; // Increment/Finish

    reg [2:0] state = S_RX_WAIT;
    reg [3:0] sample_cnt; 
    reg [4:0] tx_cnt;     
    reg header_sent; // Flag: Have we sent the 0xAA yet?
    
    // === DATA STORAGE ===
    reg [7:0] out_rom [0:15]; 
    reg [7:0] tx_data_reg;
    reg tx_start_pulse;

    // === RX/FFT LOGIC ===
    wire signed [7:0]  x_q7  = rx_byte_u;
    wire signed [15:0] x_ext = { {8{x_q7[7]}}, x_q7 };
    wire signed [15:0] x_q14 = x_ext <<< 4;

   
    // INSTANTIATIONS
    
    baud_gen #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) bg (
        .clk(clk), .rst(sys_rst), .baud_tick(baud_tick)
    );

    uart_rx #(.CLKS_PER_BIT(DIV)) uut_rx (
        .clk(clk), .rst(sys_rst), .rx(rx), 
        .data_out(rx_byte_u), .data_valid(rx_valid)
    );

    
    fft8_q14 fft_inst (
        .clk(clk), .rst(sys_rst),
        .en(rx_valid && (state == S_RX_WAIT)), 
        .x_in(x_q14),
        .out_valid(fft_out_valid), .bin_index(fft_bin),
        .y_re(fft_y_re), .y_im(fft_y_im)
    );

    uart_tx uut_tx (
        .clk(clk), .rst(sys_rst), .baud_tick(baud_tick),
        .data_in(tx_data_reg), .tx_start(tx_start_pulse),
        .tx(tx), .busy(tx_busy)
    );


    always @(posedge clk) begin
        if (sys_rst) begin
            state <= S_RX_WAIT;
            sample_cnt <= 0;
            tx_cnt <= 0;
            header_sent <= 0;
            tx_start_pulse <= 0;
            led <= 0;
        end else begin
            tx_start_pulse <= 0; 

            case (state)
                // 1. RECEIVE
                S_RX_WAIT: begin
                    header_sent <= 0;
                    tx_cnt <= 0;
                    if (rx_valid) begin
                        if (sample_cnt == 7) begin
                            sample_cnt <= 0;
                            state <= S_PROCESS;
                        end else begin
                            sample_cnt <= sample_cnt + 1;
                        end
                    end
                end

                // 2. PROCESS FFT
                S_PROCESS: begin
                    if (fft_out_valid) begin
                        if (fft_bin == 0) led <= fft_y_re[14:7]; 
                        
                        out_rom[{fft_bin, 1'b0}] <= fft_y_re[14:7];
                        out_rom[{fft_bin, 1'b1}] <= fft_y_im[14:7];

                        if (fft_bin == 3'd7) begin
                            state <= S_TX_PREP; // Start Transmission Cycle
                        end
                    end
                end

                // 3. PREP (Load Data)
                S_TX_PREP: begin
                    if (header_sent == 0) begin
                        tx_data_reg <= 8'hAA; // Magic Header
                    end else begin
                        tx_data_reg <= out_rom[tx_cnt]; // Real Data
                    end
                    state <= S_TX_START;
                end

                // 4. PULSE START
                S_TX_START: begin
                    tx_start_pulse <= 1;
                    state <= S_TX_WAIT_HI;
                end

                // 5. WAIT FOR BUSY TO GO HIGH (Start Confirmed)
                S_TX_WAIT_HI: begin
                    if (tx_busy) state <= S_TX_WAIT_LO;
                end

                // 6. WAIT FOR BUSY TO GO LOW (Finish Confirmed)
                S_TX_WAIT_LO: begin
                    if (!tx_busy) state <= S_TX_NEXT;
                end
                
                // 7. NEXT STEP
                S_TX_NEXT: begin
                    if (header_sent == 0) begin
                        // We just finished the header
                        header_sent <= 1;
                        state <= S_TX_PREP; // Go back to send Byte 0
                    end else begin
                        // We just finished a data byte
                        if (tx_cnt == 15) begin
                            state <= S_RX_WAIT; // All done
                        end else begin
                            tx_cnt <= tx_cnt + 1;
                            state <= S_TX_PREP; // Send next byte
                        end
                    end
                end

            endcase
        end
    end

endmodule
