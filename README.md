# CMT Smart FSK

> Multi-level GFSK (4FSK/8FSK) RF signal generation, air-channel AWGN, RF receiver, LO mixing, CIC/HBF decimation, and coherent demodulation (hard + MLSE/Viterbi soft-decision) simulation in MATLAB.

---

## Project Overview

This repository contains a full-chain MATLAB simulation of a **4FSK/8FSK (M-ary GFSK)** communication system, covering:

- **TX**: GFSK modulation, Gaussian filtering, CPM phase integration, RF up-conversion
- **Channel**: AWGN noise based on configurable Eb/No
- **RX**: DDC mixing, multi-stage CIC/HBF decimation (32 MHz → 16 kHz), carrier mixing correction, channel filtering
- **Demodulation**: Coherent multi-branch mix+LPF, hard-decision and MLSE/Viterbi soft-decision
- **Channel Coding** (optional): Convolutional encoding + block interleaving + puncturing + Viterbi decoding with soft metrics

### Two Simulation Sets

| Directory | Description |
|-----------|-------------|
| `sim/` | **Full RF chain simulation** (`smart_gmfsk_16x.m`, `test_bench_diff_conv.m`) — from 32 MHz RF down to baseband |
| `sim/mgfsk_viterbi/` | **Baseband-only simulation** — GFSK modulation, AWGN, and demodulation for evaluating MLSE/Viterbi BER gain over hard-decision |

---

## Quick Start

```matlab
cd sim/
addpath('sub_function_sgmfsk/');
smart_gmfsk_16x.m       % Main RF-chain BER Monte-Carlo
```

---

## Key Files

| File | Lines | Description |
|------|-------|-------------|
| `sim/smart_gmfsk_16x.m` | ~400 | Main simulation — BER sweep with configurable CONV / INTERLEAVE / PUNCTURE |
| `sim/test_bench_diff_conv.m` | ~378 | Test bench — compares (7,5), (15,13), (23,35), (171,133) convolutional codes |
| `sim/sub_function_sgmfsk/sgmfsk_CoDemod.m` | ~230 | Core demodulator — hard decision + LLR soft metrics + MLSE Viterbi |
| `sim/sub_function_sgmfsk/sgmfsk_modulator.m` | ~190 | Core modulator — GFSK/CPM signal generation |
| `sim/sub_function_sgmfsk/deinterleave_conv_dec.m` | ~70 | De-interleave + depuncture + Viterbi (`hard` / `soft` / `unquant`) |
| `sim/sub_function_sgmfsk/conv_enc_interleave.m` | ~60 | Convolutional encode + block interleave + puncture |
| `sim/mgfsk_viterbi/gfsk_4ary_viterbi_isi.m` | — | Baseband 4FSK MLSE Viterbi ISI simulation |
| `sim/mgfsk_viterbi/gfsk_8ary_viterbi_isi.m` | — | Baseband 8FSK MLSE Viterbi ISI simulation |

Full function inventory in [`docs/code_archive.md`](docs/code_archive.md).

---

## System Parameters (Default)

| Parameter | Symbol | Value | Notes |
|-----------|--------|-------|-------|
| Modulation | Mfsk | 4 (4FSK) | 2 bits per symbol |
| Bit rate | BR | 2 kbps | log₂(M) × 1 kbps |
| Symbol rate | Rs | 1 ksym/s | |
| TX samples / sym | sps | 16 | fs_tx = 16 kHz |
| RF sample rate | fs | 32 MHz | ADC/DAC rate |
| RX sample rate | fs_rx | 16 kHz | After CIC/HBF decimation |
| IF frequency | Flo | 500 kHz | Intermediate frequency |
| Carrier | f_rf | 433.92 MHz | ISM band |
| BT product | BT | 0.5 | Gaussian filter |
| Modulation index | h | 0.5 | F_dev × Tsym |
| Max deviation | F_dev | 500 Hz | h / Tsym |

---

## Signal Processing Flow

```
TX:  Info Bits → [Conv Enc] → [Interleave] → GFSK Mod → RF Up-conversion (32 MHz)
                                          ↓
Channel:                              AWGN (Eb/No configurable)
                                          ↓
RX:  DDC Mix (IF→BB) → CIC Decimation (32M→16k) → Ch. Filter → Coherent Demod
                                          ↓
                          ┌─────────────────────────┐
                          │  Hard Decision (MIX-LPF)│
                          │  Soft LLR (for Viterbi) │
                          │  MLSE Viterbi (branch metrics)│
                          └─────────────────────────┘
                                          ↓
                          [De-interleave] → [Viterbi Decode] → BER Stats
```

Detailed block diagram in [`docs/signal_flow_diagram.md`](docs/signal_flow_diagram.md).

---

## Recent Release: Soft-Metric Viterbi Fix (v1.2)

> **Root cause identified**: MATLAB R2024a `vitdec(..., 'unquant')` contains a critical bug — perfect ±1 soft inputs produce BER ≈ 0.336. `'soft'` mode with proper quantization works correctly.

### Fix Applied

- Switched all Viterbi decoding from `'unquant'` to `'soft'` (8-bit quantization via `tanh` + scaling)
- `deinterleave_conv_dec.m` now supports `'soft'` mode with erasure padding (`pad_val = 2^(nsdec-1)`)
- Both `smart_gmfsk_16x.m` and `test_bench_diff_conv.m` updated to use `vitdec(..., 'soft', nsdec)`

### Measured Performance

| Code | Hard-decision Sensitivity (BER=1e-3) | Soft-decision Sensitivity | **Gain** |
|------|--------------------------------------|---------------------------|----------|
| (7,5) | ~9.24 dB | 7.78 dB | **~1.46 dB** |
| (15,13) | ~9.30 dB | 7.59 dB | **~1.71 dB** |

Full release notes in [`RELEASENOTES.md`](RELEASENOTES.md).

---

## Documentation

| File | Content |
|------|---------|
| `docs/code_archive.md` | Complete code inventory, function descriptions, dependency graph |
| `docs/signal_flow_diagram.md` | System block diagram with data rates and signal formats |
| `docs/mgfsk_viterbi_archive.md` | Baseband MLSE/Viterbi simulation archive |

---

## Requirements

- **MATLAB R2020a or later** (R2024a tested; note `vitdec 'unquant'` bug on R2024a)
- Communications Toolbox (`vitdec`, `convenc`, `poly2trellis`)
- Signal Processing Toolbox (`gausspulsdesign`, `designfilt`)
- DSP System Toolbox (CIC/HBF decimator objects)

---

*Last updated: 2026-08-05*
