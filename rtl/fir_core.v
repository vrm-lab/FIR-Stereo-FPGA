`timescale 1ns/1ps

// ============================================================================
// fir_core
// -----------------------------------------------------------------------------
// Parameterized Transposed-Form FIR Core
//
// - Fixed-point arithmetic
// - Supports rounding and saturation
// - Coefficients provided as a flat vector
// - Designed to be synthesis-safe on Vivado
//
// This module implements a single-channel FIR filter using a transposed
// structure, which is well-suited for FPGA pipelining.
// ============================================================================

module fir_core #(
    parameter integer DATAW     = 16,  // Input / Output data width
    parameter integer COEFW     = 16,  // Coefficient width
    parameter integer NTAPS     = 129, // Number of FIR taps
    parameter integer ACCW      = 64,  // Internal accumulator width
    parameter integer OUT_SHIFT = 15,  // Output normalization shift
    parameter integer ROUND     = 1,   // Enable rounding (1 = ON)
    parameter integer SATURATE  = 1    // Enable saturation (1 = ON)
)(
    input  wire clk,
    input  wire rstn,           // Active-low synchronous reset
    input  wire en,             // Input enable
    input  wire clear_state,    // Clear internal FIR state (coefficients intact)

    input  wire signed [DATAW-1:0] din,
    input  wire [NTAPS*COEFW-1:0]  coef_flat, // Flattened coefficient vector

    output reg  signed [DATAW-1:0] dout
);

    // =========================================================================
    // INTERNAL REGISTERS & SIGNALS
    // =========================================================================

    // Z-chain registers for transposed FIR structure
    // Total registers: (NTAPS - 1), each ACCW bits wide
    reg signed [((NTAPS-1)*ACCW)-1 : 0] z_chain;

    // Combinational helper registers (used within clocked process)
    reg signed [ACCW-1:0]  acc_comb;   // Accumulator for tap 0
    reg signed [DATAW-1:0] y_next;     // Next output value after scaling

    // Loop helpers
    integer i;
    reg signed [COEFW-1:0] coef_curr;  // Current coefficient slice
    reg signed [ACCW-1:0]  prod_curr;  // Multiplication result
    reg signed [ACCW-1:0]  z_curr;     // Current Z register
    reg signed [ACCW-1:0]  z_next_val; // Next Z value

    // Saturation limits (output domain)
    localparam signed [ACCW-1:0] MAX_VAL =
        {{(ACCW-DATAW){1'b0}}, 1'b0, {(DATAW-1){1'b1}}}; // +Max

    localparam signed [ACCW-1:0] MIN_VAL =
        {{(ACCW-DATAW){1'b1}}, 1'b1, {(DATAW-1){1'b0}}}; // -Min

    // Rounding constant (adds 0.5 LSB before shifting)
    wire signed [ACCW-1:0] round_add =
        (OUT_SHIFT == 0) ? {ACCW{1'b0}} :
        {{(ACCW-OUT_SHIFT){1'b0}}, {(OUT_SHIFT-1){1'b0}}, 1'b1};

    // =========================================================================
    // MAIN SEQUENTIAL PROCESS
    // =========================================================================
    always @(posedge clk) begin
        if (!rstn) begin
            // Global reset
            z_chain <= {((NTAPS-1)*ACCW){1'b0}};
            dout    <= {DATAW{1'b0}};

        end else if (en) begin
            if (clear_state) begin
                // Clear FIR internal state only
                z_chain <= {((NTAPS-1)*ACCW){1'b0}};
                dout    <= {DATAW{1'b0}};

            end else begin
                // -------------------------------------------------------------
                // 1. TAP 0 COMPUTATION (MAC + OPTIONAL ROUNDING)
                // -------------------------------------------------------------
                coef_curr = coef_flat[0 +: COEFW];
                z_curr    = z_chain[0 +: ACCW];

                prod_curr = $signed(din) * coef_curr;

                if (ROUND)
                    acc_comb = prod_curr + z_curr + round_add;
                else
                    acc_comb = prod_curr + z_curr;

                // -------------------------------------------------------------
                // 2. OUTPUT SCALING & SATURATION
                // -------------------------------------------------------------
                if (SATURATE) begin
                    if ((acc_comb >>> OUT_SHIFT) > MAX_VAL)
                        y_next = MAX_VAL[DATAW-1:0];
                    else if ((acc_comb >>> OUT_SHIFT) < MIN_VAL)
                        y_next = MIN_VAL[DATAW-1:0];
                    else
                        y_next = acc_comb[OUT_SHIFT +: DATAW];
                end else begin
                    y_next = acc_comb[OUT_SHIFT +: DATAW];
                end

                // -------------------------------------------------------------
                // 3. REGISTER OUTPUT
                // -------------------------------------------------------------
                dout <= y_next;

                // -------------------------------------------------------------
                // 4. TRANSPOSED FIR PIPELINE UPDATE (Z-CHAIN)
                // -------------------------------------------------------------
                // z[i] <= z[i+1] + (din * h[i+1])
                for (i = 0; i < NTAPS-1; i = i + 1) begin
                    coef_curr = coef_flat[(i+1)*COEFW +: COEFW];
                    prod_curr = $signed(din) * coef_curr;

                    if (i == NTAPS-2)
                        z_next_val = {ACCW{1'b0}};
                    else
                        z_next_val = z_chain[(i+1)*ACCW +: ACCW];

                    z_chain[i*ACCW +: ACCW] <= z_next_val + prod_curr;
                end
            end
        end
    end

endmodule
