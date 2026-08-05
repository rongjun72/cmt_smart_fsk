# Release Notes — CMT Smart FSK

---

## v1.2 — Soft-Metric Viterbi Fix (2026-08-05)

### Summary

Fixed the long-standing issue where Viterbi soft-decision decoding showed **no BER gain** (and sometimes negative gain) over hard-decision. Root cause traced to a **MATLAB R2024a bug** in `vitdec(..., 'unquant')`.

### Root Cause

- MATLAB R2024a's `vitdec(..., 'unquant')` mode is **broken** — even with perfect ±1 soft inputs, output BER ≈ 0.336
- Verified with standalone test scripts (`sim/debug_vitdec_unquant.m`, `sim/debug_vitdec_soft.m`)
- `'soft'` mode (3-bit, 4-bit, 8-bit) and `'hard'` mode work correctly
- **Same code runs fine on R2018b** — confirmed as R2024a regression

### Fix Details

| Component | Change |
|-----------|--------|
| `deinterleave_conv_dec.m` | Added `'soft'` mode: `tanh` + 8-bit quantization, erasure padding with `2^(nsdec-1)` |
| `smart_gmfsk_16x.m` | Viterbi calls switched from `'unquant'` / `'hard'` → `'soft'` (soft) / `'hard'` (MLSE) |
| `test_bench_diff_conv.m` | Same switch; non-interleaved path uses inline `tanh` + `vitdec(..., 'soft', nsdec)` |
| New files | `debug_vitdec_soft.m`, `debug_vitdec_unquant.m` — standalone reproduction scripts |

### Performance Results (BER = 1e-3)

| Convolutional Code | Hard-decision Eb/No | Soft-decision Eb/No | **Gain** |
|--------------------|---------------------|---------------------|----------|
| (7,5)  K=3, 4-state | ~9.24 dB | 7.78 dB | **~1.46 dB** |
| (15,13) K=4, 8-state | ~9.30 dB | 7.59 dB | **~1.71 dB** |

> The ~1.5–1.7 dB gain is consistent with theoretical soft-decision Viterbi expectations for these codes.

### Known Limitations

- `vitdec(..., 'unquant')` must be avoided on MATLAB R2024a; use `'soft'` with `nsdec=8` instead
- Interleaved path tested; non-interleaved path also updated but full sweep pending

---

## v1.1 — Convolutional Coding + Interleaving + Puncturing (2026-07-31)

### New Features

- **Convolutional encoding**: Configurable codes — (7,5), (15,13), (23,35), (171,133)
- **Block interleaving**: Row-write / column-read, with zero-padding for odd-length frames
- **Puncturing**: Support for rate-2/3 and rate-3/4 via puncture patterns
- **Test bench**: `test_bench_diff_conv.m` for comparing multiple codes in one run

### Architecture

```
TX:  Info Bits → convenc() → [puncture_bits()] → [conv_enc_interleave()] → modulator
RX:  demod → [deinterleave_conv_dec()] → vitdec() → BER (info-bit level)
```

### BER Results (Hard-decision, no puncturing)

| Code | Sensitivity @ BER=1e-3 |
|------|------------------------|
| (7,5) | ~9.22 dB |
| (15,13) | ~9.26 dB |
| (23,35) | ~8.90 dB |
| (171,133) | ~8.86 dB |

> (7,5) and (15,13) curves overlap closely; (23,35) and (171,133) provide ~0.3–0.4 dB improvement.

### New Files

- `sim/sub_function_sgmfsk/conv_enc_interleave.m`
- `sim/sub_function_sgmfsk/deinterleave_conv_dec.m`
- `sim/sub_function_sgmfsk/puncture_bits.m`
- `sim/test_bench_diff_conv.m`
- `sim/bpsk_test.m` — BPSK baseline for verifying convolutional code performance

---

## v1.0 — Initial Release (2026-07-10)

### Features

- Full RF-chain GFSK simulation: TX → AWGN → RX (DDC + CIC decimation + channel filter)
- Multiple demodulation modes: MIX-LPF, FREQ-DET, NCOH-REF
- Hard-decision + MLSE/Viterbi soft-decision (pre-R2024a `'unquant'` mode)
- 4FSK frequency mapping: ±500 Hz, ±1500 Hz
- CORDIC-based carrier mixing (optional)
- BER Monte-Carlo with sensitivity calculation
- Resume-from-checkpoint support via `ber_state_init()` / `ber_result_save()`

### File Structure

```
cmt_smart_fsk/
├── README.md
├── sim/
│   ├── smart_gmfsk_16x.m          # Main simulation
│   ├── smart_gmfsk_tb.m           # Test bench (legacy)
│   ├── sub_function_sgmfsk/       # ~20 sub-functions
│   │   ├── sgmfsk_modulator.m
│   │   ├── sgmfsk_CoDemod.m
│   │   ├── sgmfsk_decimation.m
│   │   ├── sgmfsk_filter_series.m
│   │   ├── rx_ddc_mixer.m
│   │   ├── rx_cmix.m
│   │   ├── awgn_channelizing.m
│   │   ├── viterbi_decode_isi.m
│   │   ├── ref_metric_gen.m
│   │   └── ...
│   └── mgfsk_viterbi/             # Baseband-only MLSE simulations
│       ├── gfsk_4ary_viterbi_isi.m
│       ├── gfsk_8ary_viterbi_isi.m
│       └── ...
└── docs/
    ├── code_archive.md
    ├── signal_flow_diagram.md
    └── mgfsk_viterbi_archive.md
```

### Known Issues at v1.0

- Several scanned-OCR code errors (function name mismatches, undefined variables) — fixed in subsequent commits
- `sgmfsk_filter_series.m` content duplication resolved
- `fvtool` figure window not closing on `close all` in R2024a — documented, not critical

---

*Release notes maintained manually. For detailed code-level changes, see `git log`.*
