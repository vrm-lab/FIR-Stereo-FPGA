`timescale 1ns/1ps

// ============================================================================
// tb_fir_core_hpf
// -----------------------------------------------------------------------------
// Testbench for FIR Core configured as a simple High-Pass Filter (HPF)
//
// TEST OBJECTIVES:
// 1. Verify low-frequency attenuation (e.g., 500 Hz)
// 2. Verify high-frequency pass-through (e.g., 12 kHz)
// 3. Quantitatively compare output amplitudes (High vs Low frequency)
//
// The testbench measures peak output amplitude for each frequency and
// validates that high-frequency output is significantly larger than
// low-frequency output.
//
// Output samples are written to text files for offline plotting.
// ============================================================================

module tb_fir_core_hpf;

    // =========================================================================
    // 1. PARAMETERS
    // =========================================================================
    // Clock period corresponding to ~48 kHz sample rate
    localparam CLK_PERIOD = 20833; // ns

    // FIR configuration
    localparam integer DATAW     = 16;
    localparam integer COEFW     = 16;
    localparam integer NTAPS     = 16;
    localparam integer ACCW      = 40;
    localparam integer OUT_SHIFT = 14;
    localparam integer ROUND     = 1;
    localparam integer SATURATE  = 1;

    // =========================================================================
    // 2. SIGNAL DECLARATIONS
    // =========================================================================
    reg  clk;
    reg  rstn;
    reg  en;
    reg  clear_state;

    reg  signed [DATAW-1:0] din;
    wire signed [DATAW-1:0] dout;

    // Coefficient interface
    reg signed [COEFW-1:0] coef_array [0:NTAPS-1];
    logic [NTAPS*COEFW-1:0] coef_flat;

    // Helper variables
    real phase;
    real sine_val;
    integer i;

    // Peak amplitude tracking
    integer max_out_low_freq;
    integer max_out_high_freq;
    integer current_abs;

    // File handles
    integer fd_low;
    integer fd_high;

    // =========================================================================
    // 3. COEFFICIENT PACKING (ARRAY -> FLAT VECTOR)
    // =========================================================================
    always_comb begin
        for (int k = 0; k < NTAPS; k++) begin
            coef_flat[k*COEFW +: COEFW] = coef_array[k];
        end
    end

    // =========================================================================
    // 4. DUT INSTANTIATION
    // =========================================================================
    fir_core #(
        .DATAW    (DATAW),
        .COEFW    (COEFW),
        .NTAPS    (NTAPS),
        .ACCW     (ACCW),
        .OUT_SHIFT(OUT_SHIFT),
        .ROUND    (ROUND),
        .SATURATE (SATURATE)
    ) dut (
        .clk        (clk),
        .rstn       (rstn),
        .en         (en),
        .clear_state(clear_state),
        .din        (din),
        .coef_flat  (coef_flat),
        .dout       (dout)
    );

    // =========================================================================
    // 5. CLOCK GENERATION
    // =========================================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // 6. MAIN TEST SEQUENCE
    // =========================================================================
    initial begin
        $display("=== FIR CORE HPF TESTBENCH START ===");

        // Initialize files
        fd_low  = $fopen("hpf_response_500Hz.txt",  "w");
        fd_high = $fopen("hpf_response_12kHz.txt", "w");

        // Initialize signals
        rstn = 1'b0;
        en   = 1'b0;
        clear_state = 1'b0;
        din  = '0;

        max_out_low_freq  = 0;
        max_out_high_freq = 0;
        current_abs       = 0;

        // =========================================================================
        // TEST SETUP: HIGH-PASS FILTER COEFFICIENTS
        // =========================================================================
        // Symmetric HPF-like pattern
        // DC sum ≈ 0 -> DC rejection
        for (i = 0; i < NTAPS; i = i + 1)
            coef_array[i] = '0;

        coef_array[0] = -16'sd1000;
        coef_array[1] = -16'sd2000;
        coef_array[2] = -16'sd4000;
        coef_array[3] =  16'sd14000; // Center peak
        coef_array[4] = -16'sd4000;
        coef_array[5] = -16'sd2000;
        coef_array[6] = -16'sd1000;

        $display("HPF coefficients loaded (DC-blocking pattern)");

        #(10 * CLK_PERIOD);
        rstn = 1'b1;
        en   = 1'b1;

        // =========================================================================
        // TEST 1: LOW-FREQUENCY INPUT (500 Hz)
        // =========================================================================
        $display("--- TEST 1: 500 Hz Input (Expected: Attenuated) ---");
        phase = 0.0;

        for (i = 0; i < 200; i = i + 1) begin
            sine_val = $sin(phase);
            din      = $rtoi(sine_val * 16000);
            phase    = phase + (2.0 * 3.14159 * 500.0 / 48000.0);

            @(posedge clk);

            // Absolute value calculation
            current_abs = (dout < 0) ? -dout : dout;

            if (current_abs > max_out_low_freq)
                max_out_low_freq = current_abs;

            $fwrite(fd_low, "%0d %0d\n", din, dout);
        end

        $display("Max output amplitude @500 Hz : %0d", max_out_low_freq);

        // Clear FIR state
        clear_state = 1'b1;
        @(posedge clk);
        clear_state = 1'b0;

        // =========================================================================
        // TEST 2: HIGH-FREQUENCY INPUT (12 kHz)
        // =========================================================================
        $display("--- TEST 2: 12 kHz Input (Expected: Passed) ---");
        phase = 0.0;

        for (i = 0; i < 200; i = i + 1) begin
            sine_val = $sin(phase);
            din      = $rtoi(sine_val * 16000);
            phase    = phase + (2.0 * 3.14159 * 12000.0 / 48000.0);

            @(posedge clk);

            current_abs = (dout < 0) ? -dout : dout;

            if (current_abs > max_out_high_freq)
                max_out_high_freq = current_abs;

            $fwrite(fd_high, "%0d %0d\n", din, dout);
        end

        $display("Max output amplitude @12 kHz: %0d", max_out_high_freq);

        // =========================================================================
        // FINAL VERIFICATION
        // =========================================================================
        $display("=== FINAL VERIFICATION ===");

        if (max_out_low_freq == 0)
            max_out_low_freq = 1; // Prevent divide-by-zero

        if (max_out_high_freq > (max_out_low_freq * 5)) begin
            $display("SUCCESS: High-pass behavior verified");
            $display("High/Low amplitude ratio = %0d",
                     max_out_high_freq / max_out_low_freq);
        end else begin
            $display("FAIL: Frequency discrimination insufficient");
            $display("High/Low amplitude ratio = %0d",
                     max_out_high_freq / max_out_low_freq);
        end

        $fclose(fd_low);
        $fclose(fd_high);

        $display("=== FIR CORE HPF TESTBENCH COMPLETE ===");
        $finish;
    end

endmodule
