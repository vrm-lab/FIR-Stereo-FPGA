from pynq import Overlay, allocate
import numpy as np

BITSTREAM = "fir.bit"
DMA_NAME  = "axi_dma_0"

CHUNK = 1024

def main():
    print("[INFO] Loading bitstream...")
    ol = Overlay(BITSTREAM)

    dma = getattr(ol, DMA_NAME)

    print("[INFO] Allocating buffers...")
    buf_in  = allocate(shape=(CHUNK,), dtype=np.uint32)
    buf_out = allocate(shape=(CHUNK,), dtype=np.uint32)

    print("[INFO] Generating test signal...")
    # Simple stereo ramp (L and R identical)
    test = (np.arange(CHUNK) % 32768).astype(np.int16)
    packed = (test.astype(np.uint32) << 16) | (test.astype(np.uint32) & 0xFFFF)

    buf_in[:] = packed

    print("[INFO] Starting DMA transfer...")
    dma.sendchannel.transfer(buf_in)
    dma.recvchannel.transfer(buf_out)

    dma.sendchannel.wait()
    dma.recvchannel.wait()

    print("[INFO] Transfer complete.")

    # Basic sanity check
    diff = np.abs(buf_out.astype(np.int64) - buf_in.astype(np.int64))
    max_err = diff.max()

    print(f"[INFO] Max difference: {max_err}")

    if max_err == 0:
        print("[PASS] Output matches input (pass-through / identity response)")
    else:
        print("[WARN] Output differs from input (expected if FIR is active)")

    buf_in.freebuffer()
    buf_out.freebuffer()

    print("[INFO] Done.")

if __name__ == "__main__":
    main()
