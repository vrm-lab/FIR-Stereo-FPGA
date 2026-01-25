/*
 * fir_stereo.c
 * -----------------------------------------------------------------------------
 * Bare-Metal Driver Implementation for FIR Stereo AXI Wrapper
 *
 * This file provides low-level control functions for:
 * - Enabling / disabling the FIR core
 * - Soft-resetting internal FIR state
 * - Reading and writing FIR coefficients at runtime
 *
 * The driver is intended for bare-metal or lightweight RTOS environments
 * (e.g., standalone BSP, FreeRTOS).
 * -----------------------------------------------------------------------------
 */

#include "fir_stereo.h"

// =============================================================================
// LOW-LEVEL REGISTER ACCESS MACROS
// =============================================================================
#define FIR_WriteReg(BaseAddr, Offset, Data) \
    Xil_Out32((BaseAddr) + (Offset), (u32)(Data))

#define FIR_ReadReg(BaseAddr, Offset) \
    Xil_In32((BaseAddr) + (Offset))

// =============================================================================
// DRIVER API IMPLEMENTATION
// =============================================================================

/**
 * FIR_Init
 *
 * Initializes the FIR driver instance.
 * Sets base address, tap count, and places the hardware into a known state.
 */
int FIR_Init(FirStereo_Config *InstancePtr, UINTPTR BaseAddress, u32 NumTaps)
{
    if (InstancePtr == NULL)
        return XST_FAILURE;

    InstancePtr->BaseAddress = BaseAddress;
    InstancePtr->NumTaps     = NumTaps;
    InstancePtr->IsReady     = XIL_COMPONENT_IS_READY;

    // Default state: disabled and reset
    FIR_Enable(InstancePtr, 0);
    FIR_SoftReset(InstancePtr);

    return XST_SUCCESS;
}

/**
 * FIR_Enable
 *
 * Enables or disables the FIR core.
 */
void FIR_Enable(FirStereo_Config *InstancePtr, u8 Enable)
{
    u32 RegVal = FIR_ReadReg(InstancePtr->BaseAddress,
                             FIR_REG_CTRL_OFFSET);

    if (Enable)
        RegVal |= FIR_CTRL_ENABLE_BIT;
    else
        RegVal &= ~FIR_CTRL_ENABLE_BIT;

    FIR_WriteReg(InstancePtr->BaseAddress,
                 FIR_REG_CTRL_OFFSET,
                 RegVal);
}

/**
 * FIR_SoftReset
 *
 * Clears internal FIR state (delay line / accumulators)
 * without modifying coefficient memory.
 */
void FIR_SoftReset(FirStereo_Config *InstancePtr)
{
    UINTPTR Base = InstancePtr->BaseAddress;
    u32 RegVal   = FIR_ReadReg(Base, FIR_REG_CTRL_OFFSET);

    // Pulse CLEAR bit: 0 -> 1 -> 0
    FIR_WriteReg(Base, FIR_REG_CTRL_OFFSET,
                 RegVal | FIR_CTRL_CLEAR_BIT);
    FIR_WriteReg(Base, FIR_REG_CTRL_OFFSET,
                 RegVal & ~FIR_CTRL_CLEAR_BIT);
}

/**
 * FIR_SetCoeff
 *
 * Writes a single FIR coefficient.
 *
 * Coefficient format: signed Q1.15
 */
void FIR_SetCoeff(FirStereo_Config *InstancePtr,
                  u32 TapIndex,
                  s16 Value)
{
    if (TapIndex >= InstancePtr->NumTaps)
        return;

    // Address = Base + coefficient base + (index * 4 bytes)
    UINTPTR Addr = InstancePtr->BaseAddress
                 + FIR_MEM_COEFF_OFFSET
                 + (TapIndex * 4);

    // Hardware consumes lower 16 bits
    FIR_WriteReg(Addr, 0, (u32)Value);
}

/**
 * FIR_GetCoeff
 *
 * Reads back a FIR coefficient.
 */
s16 FIR_GetCoeff(FirStereo_Config *InstancePtr, u32 TapIndex)
{
    if (TapIndex >= InstancePtr->NumTaps)
        return 0;

    UINTPTR Addr = InstancePtr->BaseAddress
                 + FIR_MEM_COEFF_OFFSET
                 + (TapIndex * 4);

    return (s16)FIR_ReadReg(Addr, 0);
}

/**
 * FIR_LoadConfig
 *
 * Loads an entire FIR coefficient set safely.
 *
 * Steps:
 * 1. Disable FIR core
 * 2. Clear unused taps
 * 3. Write new coefficients
 * 4. Restore enable state (if previously enabled)
 */
void FIR_LoadConfig(FirStereo_Config *InstancePtr,
                    const s16 *CoeffArray,
                    u32 Length)
{
    // Preserve current enable state
    u32 CtrlReg = FIR_ReadReg(InstancePtr->BaseAddress,
                              FIR_REG_CTRL_OFFSET);
    u8 WasEnabled = (CtrlReg & FIR_CTRL_ENABLE_BIT) ? 1 : 0;

    // Disable FIR during update
    FIR_Enable(InstancePtr, 0);

    u32 Limit = (Length < InstancePtr->NumTaps)
              ? Length
              : InstancePtr->NumTaps;

    // Clear unused taps
    for (u32 i = Limit; i < InstancePtr->NumTaps; i++)
        FIR_SetCoeff(InstancePtr, i, 0);

    // Load new coefficients
    for (u32 i = 0; i < Limit; i++)
        FIR_SetCoeff(InstancePtr, i, CoeffArray[i]);

    // Restore enable state
    if (WasEnabled)
        FIR_Enable(InstancePtr, 1);
}
