# mgfsk_viterbi Archive

## 项目概述

`mgfsk_viterbi` 是一个 **4FSK / 8FSK 基带 GFSK 相干解调仿真平台**，与主项目 `cmt_smart_fsk`（射频全链路仿真）形成**互补关系**：

| 项目 | 范围 | 重点 |
|------|------|------|
| `cmt_smart_fsk` | 射频全链路 (32MHz → 基带) | 射频信号产生、DDC、CIC/HBF 抽取、MIX-LPF 解调 |
| `mgfsk_viterbi` | 纯基带 (16kHz 采样) | ISI-aware Viterbi MLSE 序列检测、软信息分支度量、BER 增益评估 |

**核心目标**：评估基于 branch metric 软信息的 Viterbi 译码相对于传统硬判决的 BER 增益。

---

## 系统参数

| 参数 | 4FSK | 8FSK |
|------|------|------|
| 符号率 Rs | 1 kHz | 1 kHz |
| 采样率 Fs | 16 kHz | 16 kHz |
| 每符号采样 nsps | 16 | 16 |
| 调制指数 h | 1.0 (默认) | 1.0 (默认) |
| 高斯 BT | 0.5 | 0.5 |
| 高斯 span | 4 符号 | 4 符号 |
| Tone 间隔 | 1000 Hz | 1000 Hz |
| Tone LPF 阶数 | 36 (Chebwin) | 24 (Chebwin) |
| Tone LPF fc | 0.75 × tone_spacing | 0.75 × tone_spacing |
| 信道滤波器 Fp | 2.0 kHz | 4.5~5.0 kHz |
| 信道滤波器 Fstop | 2.8 kHz | 5.5~6.0 kHz |
| 信道滤波器抑制 | 80 dB | 80 dB |

---

## 文件目录结构

```
sim/mgfsk_viterbi/
├── README.md                              # 项目概述（英文）
├── gfsk_4ary_simulation_report.md         # 详细仿真报告（中文）
├── MLSE_Tutorial_temp.md                  # MLSE 教程（中文）
├── Trellis_temp.md                        # Trellis 状态转移详解（中文）
│
├── gfsk_4ary_coherent_final.m             # 4FSK 硬判决基准 + 理论 BER + 误差地板分析
├── gfsk_4ary_coherent_parfor.m            # 4FSK 并行硬判决（parfor 加速）
├── gfsk_4ary_viterbi.m                    # 4FSK 基础 Viterbi（无 ISI 感知，历史版）
├── gfsk_4ary_viterbi_isi.m                # ⭐ 4FSK ISI-aware Viterbi（核心成果，向量化优化）
├── gfsk_4ary_viterbi_64state.m            # 4FSK 64-state Viterbi（3-symbol 记忆，实验版）
│
├── gfsk_8ary_coherent_final.m             # 8FSK 硬判决基准 + 理论 BER
├── gfsk_8ary_viterbi_isi.m                # ⭐ 8FSK ISI-aware Viterbi（核心成果）
│
├── optimize_8gfsk_h_lpf.m                 # 8FSK 参数联合优化（h, LPF order, fc）
├── plot_viterbi_trellis.m                 # Viterbi Trellis 图可视化（3 图）
│
├── analyze_symbol_internal_metrics.m      # 4FSK 符号内分支度量分析
├── analyze_8gfsk_tone_metrics_intrasync.m # 8FSK 符号内 tone-mixer 度量分析
├── analyze_per_branch_optimal_phase.m     # 8FSK 逐分支最优采样相位分析
├── analyze_per_branch_optimal_phase_4ary.m # 4FSK 逐分支最优采样相位分析
├── scan_sample_phase_8gfsk.m             # 8FSK 采样相位偏移扫描（-3~+3）
├── test_tone_lpf_order.m                  # Tone LPF 阶数扫描（10-50）与 BER 对比
│
└── MLSE_Viterbi_Tutorial/                 # Python MLSE 教程与演示
    ├── MLSE教程.md
    ├── Trellis状态转移详解.md
    ├── mlse_viterbi_demo.py               # BPSK MLSE vs MMSE BER 对比
    ├── sliding_window_viterbi.py          # 实时滑动窗口 Viterbi
    └── viterbi_forward_trace.py           # 逐步 Viterbi 前向递推演示
```

> **注**：二进制图片文件（.png）未通过 GitHub API 推送，需手动上传至 `sim/mgfsk_viterbi/` 目录：
> - `fig1_ber_comparison.png`, `fig2_viterbi_gain.png`, `fig3_waveform_constellation.png`
> - `fig4_trellis_full.png`, `fig5_trellis_traceback.png`, `fig6_trellis_forward.png`
> - `mlse_vs_mmse_ber.png`, `trellis_convergence.png`, `viterbi_trellis_path.png`

---

## 核心架构

### 信号链路

```
随机符号生成 → GFSK 调制器 → AWGN 信道 + 信道滤波器 → Tone-Mixer 相干检测 → 硬判决 / Viterbi MLSE
```

### 关键模块

1. **GFSK 信号生成**：`gaussdesign(BT, span, nsps)` 高斯脉冲整形 + 相位积分 → 连续相位 CPFSK
2. **AWGN 信道**：复高斯噪声，Eb/N0 可控
3. **信道滤波器**：80dB 带外抑制 FIR 低通，优化通带宽度减少噪声通过
4. **Tone-Mixer 相干检测**：M 个分支分别混频到基带 + Chebyshev 窗 LPF + 采样取模值
5. **硬判决**：逐符号最大模值判决
6. **ISI-aware Viterbi**：
   - 预计算 `(prev_gray, curr_gray)` 组合的参考模板（16/64 个）
   - 分支度量 = 归一化观测向量与参考模板的 **余弦相似度**
   - 全帧回溯，路径度量归一化防溢出

---

## 关键设计要点

### 1. 总延迟补偿

```matlab
total_delay = round(delay_gauss + delay_ch + delay_tone)
```

- **发射高斯滤波器**：~16 采样（1 符号）
- **信道滤波器**：~40 采样（2.5 符号）
- **Tone LPF**：~18 采样（1.1 符号，4FSK 36阶）或 ~12 采样（8FSK 24阶）
- **总延迟**：约 75 采样（4.7 符号）

> ⚠️ 遗漏 `delay_gauss` 会导致 BER≈0.5（系统采样偏移 1 符号）

### 2. ISI 参考模板

- 必须包含 **信道滤波器**（`ch_filter`），否则频率响应/幅度失真导致模板失配
- 防护带 `N_guard = 12`，确保滤波器完全稳态
- 所有模板使用 **相同防护带**（symbol 0），保证可比性
- 采样点公式与主仿真完全一致：`idx = (N_guard + 1) * nsps + nsps/2 + total_delay`

### 3. 分支度量：余弦相似度

```matlab
branch = (obs_normed' * ref_normed)  % cos θ ∈ [0, 1]
```

- **幅度无关性**：不受 AGC 增益波动影响
- **ISI 特征捕捉**：比较 4-branch/8-branch 的"分布模式"而非绝对值
- **与欧氏距离等价**：对于单位向量，`cos θ = 1 - ½||obs - ref||²`

### 4. Viterbi 向量化优化（4FSK 核心版）

原始三重循环 → 矩阵乘法 + `max(..., [], 1)`：
- `obs_normed(:, t)' (1×M) * ref_all (M×M²) → branch_all (1×M²)`
- `reshape` 为 `M×M`（rows=prev, cols=curr）
- `pm(:, t-1)` (M×1) 自动广播到 M×M 各列
- `max(val, [], 1)` 向量化选择幸存者

**实测加速**：Nsym=100000 时，132.27s → 10.36s，**~12.8×**

### 5. 关键调试历程

| Bug | 症状 | 原因 | 修复 |
|-----|------|------|------|
| 采样索引越界 | BER≈0.5 | 遗漏 `delay_gauss` | `total_delay = delay_gauss + delay_ch + delay_tone` |
| 数组维度不匹配 | 比较失败 | `det_sym` 行向量 vs `sym_tx_valid` 列向量 | 强制 `det_gray(:)` 转为列向量 |
| 参考模板索引错位 | Viterbi 退化 50% 错误 | `generate_gfsk` 接收自然二进制，但状态用 Gray 编码 | `ref_metric` 索引用 Gray，传入前用 `gry2nat` 转换 |
| 参考模板遗漏信道滤波 | 无噪声自检失败 | 模板未经过 `ch_filter` | 参考模板也经过 `filter(ch_coeffs, 1, s)` |
| 采样相位偏移 | 不同 delta 性能差异 | 不同频率 tone 经过滤波器后群延迟不同 | 负 delta（-1~-3）Viterbi 工作正常，正 delta（+1~+3）失败 |

### 6. Tone LPF 阶数约束

- **必须为偶数**：奇数阶数产生半整数 `grpdelay`，`round(total_delay)` 导致 0.5 采样偏移
- 10-44 阶偶数通过无噪声检查

### 7. 前导码约束

- 前导码必须固定为 `0`（对应 Gray=0，tone=最低频率）
- 随机前导码导致 Viterbi 50% 错误（参考模板假设 prev=0）

---

## 仿真结果摘要

### 4FSK (h=1.0, BT=0.5)

| Eb/N0 (dB) | 硬判决 BER | Viterbi BER | Viterbi 增益 (dB) | 主导因素 |
|------------|-----------|-------------|-------------------|---------|
| 0 | 2.7×10⁻¹ | 2.8×10⁻¹ | -0.15 | 噪声 |
| 5 | 8.5×10⁻² | 9.0×10⁻² | -0.5 | 噪声 |
| 10 | 7.0×10⁻³ | 7.8×10⁻³ | -0.4 | 噪声/ISI 过渡 |
| 12 | 3.2×10⁻³ | 2.5×10⁻³ | **+1.2** | **ISI 主导** |
| 15 | 6.0×10⁻⁴ | 1.5×10⁻⁴ | **+3~5** | **ISI 主导** |

- **误差地板**：硬判决 ~3×10⁻³，Viterbi ~1×10⁻⁴（降低约一个数量级）
- **Viterbi 增益**：高 SNR 区域 **3-5 dB**

### 8FSK (h=1.0, order=24, fc=0.75)

- 硬判决无噪声 SER：~16.25%（tone 拥挤 + 高斯 ISI）
- Viterbi 无噪声 SER：~1.08%（显著 ISI 缓解）

### 8FSK 优化后 (h=1.2, order=20, fc=1.0)

- 最佳 SER：~3.5%（vs h=1.0, order=20, fc=1.0 的 6.1%）
- **关键洞察**：低延迟优于选择性；宽 fc + 低阶数 = 更好的采样位置

---

## 使用说明

```matlab
% 运行 4FSK 核心仿真（ISI-aware Viterbi）
gfsk_4ary_viterbi_isi

% 运行 8FSK 核心仿真
gfsk_8ary_viterbi_isi

% 运行参数优化
optimize_8gfsk_h_lpf

% 可视化 Trellis
plot_viterbi_trellis

% 分析采样相位
scan_sample_phase_8gfsk

% 分析 LPF 阶数影响
test_tone_lpf_order
```

### 可调参数（文件顶部修改）

```matlab
h       = 1.0;          % 调制指数（1.0 = 1000 Hz 间隔）
BT      = 0.5;          % 高斯滤波 BT（越小 ISI 越强）
Nsym    = 10000;        % 有效符号数
EbN0_dB = 12*log10(1:1.9:20)/log10(20);  % 非线性 EbN0 分布
```

---

## 与 cmt_smart_fsk 的关系

`mgfsk_viterbi` 为 `cmt_smart_fsk` 的 Viterbi 译码模块提供了**算法原型和参数验证**：

1. **ISI-aware Viterbi 架构**：`(prev, curr)` 组合参考模板 + 余弦相似度分支度量
2. **向量化优化方案**：矩阵广播替代三重循环，用于 `sgmfsk_viterbi_mlse.m` 性能优化
3. **参数设计参考**：`N_guard=12`、前导码固定为 0、采样相位偏移方向（负 delta）
4. **调试经验**：总延迟必须包含 `delay_gauss`、tone LPF 阶数需为偶数、参考模板必须包含信道滤波器

---

## 参考文献

- G. D. Forney Jr., "The Viterbi Algorithm" (1973)
- Proakis & Salehi, *Digital Communications*
- MATLAB Signal Processing Toolbox documentation

---

*归档日期：2026-07-14*
*归档版本：与 cmt_smart_fsk v1.0-viterbi-stable 同步*
