/*
 * fir_stereo.h
 * -----------------------------------------------------------------------------
 * Bare-Metal Driver Header for FIR Stereo AXI Wrapper
 *
 * This driver provides low-level access to the FIR stereo AXI IP core,
 * including control, soft reset, and runtime coefficient updates.
 *
 * AXI-Lite Memory Map:
 *   0x00 : Control Register
 *          [0] Enable
 *          [1] Clear FIR internal state
 *
 *   0x10 : Coefficient Memory Base Address
 *          h[0] @ 0x10
 *          h[1] @ 0x14
 *          ...
 *
 * Coefficient Format:
 *   Signed fixed-point Q1.15
 *   Range: -32768 to +32767
 * -----------------------------------------------------------------------------
 */

#ifndef FIR_STEREO_H
#define FIR_STEREO_H

#include "xil_types.h"
#include "xil_io.h"
#include "xstatus.h"

// =============================================================================
// HARDWARE REGISTER OFFSETS
// =============================================================================
#define FIR_REG_CTRL_OFFSET     0x00
#define FIR_MEM_COEFF_OFFSET    0x10

// =============================================================================
// CONTROL REGISTER BIT DEFINITIONS
// =============================================================================
#define FIR_CTRL_ENABLE_BIT     (1U << 0)
#define FIR_CTRL_CLEAR_BIT      (1U << 1)

// =============================================================================
// DRIVER INSTANCE STRUCTURE
// =============================================================================
typedef struct {
    UINTPTR BaseAddress;  // Physical base address of FIR AXI IP
    u32     NumTaps;      // Number of FIR taps (hardware-defined)
    u32     IsReady;      // Initialization status flag
} FirStereo_Config;

// =============================================================================
// FUNCTION PROTOTYPES
// =============================================================================

// -----------------------------------------------------------------------------
// Initialization
// -----------------------------------------------------------------------------
int FIR_Init(FirStereo_Config *InstancePtr,
             UINTPTR BaseAddress,
             u32 NumTaps);

// -----------------------------------------------------------------------------
// Hardware Control
// -----------------------------------------------------------------------------
void FIR_Enable(FirStereo_Config *InstancePtr, u8 Enable);
void FIR_SoftReset(FirStereo_Config *InstancePtr);

// -----------------------------------------------------------------------------
// Coefficient Management
// -----------------------------------------------------------------------------
// Coefficients are signed Q1.15 fixed-point values
void FIR_SetCoeff(FirStereo_Config *InstancePtr,
                  u32 TapIndex,
                  s16 Value);

s16  FIR_GetCoeff(FirStereo_Config *InstancePtr,
                  u32 TapIndex);

void FIR_LoadConfig(FirStereo_Config *InstancePtr,
                    const s16 *CoeffArray,
                    u32 Length);

#endif // FIR_STEREO_H
