# cmt_smart_fsk

## 项目简介

本项目致力于 **CMT（载波调制技术）智能 FSK（频移键控）** 通信系统的研究与仿真。

## 目录结构

```
cmt_smart_fsk/
├── docs/               # 说明文档
│   └── code_archive.md # 代码归档与理解文档
├── sim/                # 仿真代码与结果
│   ├── smart_gmfsk_16x.m          # 主仿真脚本
│   └── sub_function_sgmfsk/       # 子函数目录
│       ├── awn_channelizing.m     # AWGN信道噪声添加
│       ├── bpf_pair_fir_design.m  # 复数带通滤波器对设计
│       ├── cordic_rotation.m      # CORDIC旋转算法
│       ├── fftTransform.m         # FFT频谱绘图
│       ├── pll_demode.m           # 2阶II型PLL解调
│       ├── pll_demode_typeIII.m   # 3阶III型PLL解调
│       ├── pll_initialize.m       # PLL参数初始化
│       ├── plot_time_freq_response.m # 时频响应绘图
│       ├── ref_metric_gen.m       # Viterbi参考模板生成
│       ├── rssi_snr_estimati.m    # RSSI/SNR估计
│       ├── rx_cmix.m              # 残余频偏混频校正
│       ├── rx_ddc_mixer.m         # DDC混频下变频
│       ├── sgmfsk_CoDemod.m       # 核心相干解调器
│       ├── sgmfsk_decimation.m    # 多级CIC/HBF降采样
│       ├── sgmfsk_filter_series.m # 滤波器级联（待完善）
│       ├── sgmfsk_modulator.m     # 4FSK GFSK调制器
│       └── viterbi_decode_isi.m   # ISI感知Viterbi软判决
├── data/               # 数据文件
└── README.md           # 本文件
```

## 系统参数

| 参数 | 数值 | 说明 |
|------|------|------|
| 调制阶数 | 4FSK | 每符号2比特 |
| 比特速率 | 2 kbps | |
| ADC采样率 | 32 MHz | 射频前端 |
| 接收采样率 | 16 kHz | 降采样后 |
| 中频频率 | 500 kHz | |
| 射频载波 | 433.92 MHz | ISM频段 |
| 调制指数 | h = 0.5 | |
| 最大频偏 | 500 Hz | |
| 带宽时间积 | BT = 0.5 | 高斯滤波 |

## 信号处理链路

```
发射: 比特生成 → 4FSK映射 → 高斯滤波 → 相位积分(CPM) → 上变频(32MHz)
                              ↓
信道: AWGN噪声添加 (Eb/No可控)
                              ↓
接收: DDC混频 → 多级降采样(32M→16k) → 载波校正 → 信道滤波 → 解调
                                                                   ↓
解调: MIX-LPF(硬/软判决) / FREQ-DET(差分鉴频) / NCCH-REF(非相干)
                                                                   ↓
译码: Viterbi MLSE软判决 (4状态, ISI感知)
```

## 开发环境

- MATLAB R20xx 或更高版本
- 需要 DSP System Toolbox (dsp.IIRFilter等)
- 需要 Signal Processing Toolbox

## 快速开始

1. 打开 MATLAB，切换到 `sim/` 目录
2. 运行 `smart_gmfsk_16x.m`
3. 查看输出的BER曲线和灵敏度表格

## 许可证

（待补充）
