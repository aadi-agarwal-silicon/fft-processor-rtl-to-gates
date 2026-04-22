function fft_project_controller()

    % ======================
    % CONFIG
    % ======================
    port = "COM4";
    baud = 115200;        % or 1e6 if updated on FPGA

    s = serialport(port, baud);
    s.Timeout = 2;
    flush(s);

    fprintf("CONNECTED -> %s @ %d baud\n", port, baud);

    % ======================
    % 1. Generate 8 inputs
    % ======================
    x_float = 2*rand(1,8) - 1;
    x_q7    = int8(round(x_float * 127));
    x_bytes = typecast(x_q7, "uint8");

    fprintf("\n========== INPUT SAMPLES ==========\n");
    for i = 1:8
        fprintf("x[%d] = %+0.5f   (q7=%4d)\n", i-1, x_float(i), x_q7(i));
    end

    % ======================
    % 2. Send inputs to FPGA
    % ======================
    write(s, x_bytes, "uint8");
    pause(0.05);

    % ======================
    % 3. Read 17 bytes reliably
    % ======================
    needed = 17;
    buf = uint8([]);

    t0 = tic;
    while numel(buf) < needed
        if s.NumBytesAvailable > 0
            new = read(s, s.NumBytesAvailable, "uint8");
            buf = [buf ; new(:)];
        end
        if toc(t0) > s.Timeout
            error("Timeout: FPGA did not send full FFT packet.");
        end
    end

    buf = double(buf(:)');

    % ======================
    % 4. Check header (170)
    % ======================
    if buf(1) ~= 170
        error("Header mismatch! Got %d, expected 170.", buf(1));
    end

    payload = buf(2:17);

    % ======================
    % 5. Parse FPGA FFT
    % ======================
    FPGA_Re = zeros(1,8);
    FPGA_Im = zeros(1,8);

    for k = 1:8
        re_i8 = typecast(uint8(payload(2*k-1)), 'int8');
        im_i8 = typecast(uint8(payload(2*k)),   'int8');

        % Convert q7 → float and scale
        FPGA_Re(k) = double(re_i8) / 127 * 8;
        FPGA_Im(k) = double(im_i8) / 127 * 8;
    end

    % ======================
    % 6. Print FPGA FFT output
    % ======================
    fprintf("\n========== FPGA FFT OUTPUT ==========\n");
    for k = 1:8
        fprintf("bin %d :  Re = %+0.4f   Im = %+0.4f\n", ...
            k-1, FPGA_Re(k), FPGA_Im(k));
    end

    % ======================
    % 7. Plot ONLY FPGA FFT
    % ======================
    figure;

    subplot(2,1,1);
    stem(0:7, FPGA_Re, 'r', 'LineWidth', 1.5);
    grid on;
    title("FPGA FFT — Real Part");
    ylabel("Real Value");

    subplot(2,1,2);
    stem(0:7, FPGA_Im, 'b', 'LineWidth', 1.5);
    grid on;
    title("FPGA FFT — Imaginary Part");
    ylabel("Imag Value");
    xlabel("Bin Index");

    fprintf("\nPlot generated successfully.\n");

    clear s;

end
