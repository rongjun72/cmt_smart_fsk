# CMT Smart FSK 仿真代码归档文档

> 归档日期: 2025-07-10  
> 项目: cmt_smart_fsk  
> 作者: rongjun72  
> 状态: 原始代码，尚未修改

---

## 一、文件清单

### 1.1 主仿真文件

| 文件名 | 行数 | 说明 |
|--------|------|------|
| `smart_gmfsk_16x.m` | 315 | **主仿真脚本**，完整的BER曲线蒙特卡洛仿真 |

### 1.2 子函数目录 (`sub_function_sgmfsk/`)

| # | 文件名 | 行数 | 功能分类 | 说明 |
|---|--------|------|----------|------|
| 1 | `awn_channelizing.m` | 49 | 信道 | AWGN噪声添加，基于Eb/No计算噪声功率 |
| 2 | `bpf_pair_fir_design.m` | 49 | 滤波器设计 | 复数带通滤波器对设计（零极点旋转法） |
| 3 | `cordic_rotation.m` | 57 | 数字信号处理 | CORDIC旋转算法实现（16迭代，支持象限预处理） |
| 4 | `fftTransform.m` | 36 | 可视化 | FFT频谱分析与绘图工具 |
| 5 | `pll_demode.m` | 29 | 解调 | 标准2阶II型PLL频率解调器 |
| 6 | `pll_demode_typeIII.m` | 31 | 解调 | 3阶III型PLL频率解调器（增强型） |
| 7 | `pll_initialize.m` | 32 | 解调 | PLL参数初始化（自然角频率、阻尼系数、环路增益） |
| 8 | `plot_time_freq_response.m` | 91 | 可视化 | 时域波形+频域响应联合绘图 |
| 9 | `ref_metric_gen.m` | 55 | MLSE/Viterbi | 生成Viterbi译码所需的参考度量模板 |
| 10 | `rssi_snr_estimati.m` | 24 | 信道估计 | RSSI接收信号强度/SNR信噪比估计 |
| 11 | `rx_cmix.m` | 13 | 接收前端 | 残余频偏混频校正（支持CORDIC模式） |
| 12 | `rx_ddc_mixer.m` | 5 | 接收前端 | 数字下变频（DDC）混频器 |
| 13 | `sgmfsk_CoDemod.m` | 207 | 解调 | **核心解调器**，支持多种解调方式 |
| 14 | `sgmfsk_decimation.m` | 63 | 接收前端 | 多级CIC/HBF降采样（32MHz→16kHz） |
| 15 | `sgmfsk_filter_series.m` | 312 | 主脚本副本 | ⚠️ 内容与主文件相同，疑似误拷贝 |
| 16 | `sgmfsk_modulator.m` | 187 | 发射机 | **核心调制器**，4FSK GFSK信号生成 |
| 17 | `viterbi_decode_isi.m` | 77 | MLSE/Viterbi | ISI感知的4状态Viterbi软判决序列检测 |

---

## 二、系统参数总览

| 参数 | 符号 | 数值 | 说明 |
|------|------|------|------|
| 调制阶数 | Mfsk | **4** (4FSK) | 每符号携带 2 bits |
| 比特速率 | BR | 2 kbps | log₂(M)×1e3 |
| 符号速率 | Rs | 1 ksym/s | BR/log₂(M) |
| 符号周期 | Tsym | 1 ms | 1/Rs |
| ADC采样率 | fs | **32 MHz** | 射频前端采样率 |
| 发射每符号采样 | sps | 16 | fs_tx = 16 kHz |
| 接收采样率 | fs_rx | **16 kHz** | 16×BW |
| 中频频率 | Flo | 500 kHz | IF频率 |
| 射频载波 | f_rf | 433.92 MHz | ISM频段 |
| 带宽时间积 | BT | 0.5 | 高斯滤波器参数 |
| 调制指数 | h | 0.5 | F_dev×Tsym |
| 最大频偏 | F_dev | 500 Hz | h/Tsym |
| 发射符号数 | Nsym_total | 200,000 | 总仿真长度 |
| 分段长度 | Nsym_segment | 2,000 | 每帧处理符号数 |

---

## 三、信号处理链路

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           发射端 (TX)                                    │
│  ┌─────────┐   ┌────────────┐   ┌──────────┐   ┌──────────┐   ┌────────┐│
│  │ 比特生成 │ → │ 4FSK映射   │ → │ 高斯滤波 │ → │ 相位积分 │ → │ 上变频 ││
│  │(rand/syn)│   │(Gray编码)  │   │gausspuls │   │  CPM调制 │   │32MHz   ││
│  └─────────┘   └────────────┘   └──────────┘   └──────────┘   └────────┘│
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
                              射频信号 (433.92MHz + 500kHz IF)
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                           信道                                           │
│                    ┌──────────────────┐                                 │
│                    │ AWGN噪声添加     │  (awn_channelizing.m)           │
│                    │ Eb/No → 噪声功率 │                                 │
│                    └──────────────────┘                                 │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                           接收端 (RX)                                    │
│  ┌──────────┐   ┌────────────┐   ┌──────────┐   ┌──────────┐   ┌───────┐│
│  │ DDC混频  │ → │ 降采样     │ → │ 载波校正 │ → │ 信道滤波 │ → │ 解调  ││
│  │(rx_ddc)  │   │(CIC/HBF)   │   │(rx_cmix) │   │(chFilter)│   │       ││
│  │ -500kHz  │   │32M→16k     │   │CORDIC可选│   │          │   │       ││
│  └──────────┘   └────────────┘   └──────────┘   └──────────┘   └───────┘│
│                                                                    ↓    │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │ 解调方式 (sgmfsk_CoDemod.m):                                   │      │
│  │  1. MIX-LPF   : 多支路混频+LPF，硬判决/MLSE软判决              │      │
│  │  2. FREQ-DET  : 差分鉴频法                                    │      │
│  │  3. NCCH-REF  : 非相干参考解调                                 │      │
│  └──────────────────────────────────────────────────────────────┘      │
│                                                                    ↓    │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │ MLSE/Viterbi软判决 (viterbi_decode_isi.m):                    │      │
│  │  - 4状态 (M_v=4)                                              │      │
│  │  - 基于ISI感知的参考模板匹配                                   │      │
│  │  - 向量化前向递归，序列回溯                                    │      │
│  └──────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                           BER统计与结果输出                              │
│  - 错误比特统计 (error_stat)                                            │
│  - BER曲线绘制 (semilogy)                                               │
│  - 灵敏度计算 (sensitivity_calc)                                        │
│  - 结果保存到文件 (mfsk_ber_16x.txt)                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 四、4FSK 频率映射关系

| 比特对 | 十进制 | 频率偏移 | 备注 |
|--------|--------|----------|------|
| 00 | 0 | **-3F_dev** (-1500 Hz) | 最低频 |
| 01 | 1 | **-F_dev** (-500 Hz) | |
| 11 | 2 | **+F_dev** (+500 Hz) | |
| 10 | 3 | **+3F_dev** (+1500 Hz) | 最高频 |

---

## 五、关键子函数详解

### 5.1 调制器 `sgmfsk_modulator.m`

**输入参数：**
- `Nsym`: 符号数
- `seg_type`: 帧类型 ('rand'随机/'syn'同步/'ref'参考)
- `sps`, `fs`, `fs_tx`, `F_dev`, `fc`, `fig_num`

**处理流程：**
1. 生成高斯滤波系数 (`gausspulsdesign`, TBW=1, span=4)
2. 生成随机比特或特定比特模式
3. 4FSK符号映射（采用特定线性映射，非标准Gray）
4. 上采样 → 高斯滤波 → 相位积分 (CPM)
5. 重采样到 32MHz，叠加中频相位，输出复指数信号

**内部函数：**
- `code2bin()`: 将符号转换为二进制序列
- `FLT_gaussWin()`: 滑动窗高斯滤波实现
- `gausspulsdesign()`: 高斯脉冲设计

### 5.2 AWGN信道 `awn_channelizing.m`

**核心逻辑：**
```matlab
P_sig = (in_sig' * in_sig) / length(in_sig);  % 信号功率
Eb_dB = 10*log10(P_sig);                       % 比特能量(dB)
No_dB = Eb_dB - ENo_dB;                        % 噪声功率谱密度
out_sig = in_sig + wgn(length(in_sig), 1, No_power_dB);  % 添加白噪声
```

### 5.3 DDC混频 `rx_ddc_mixer.m`

简单的复数混频下变频：
```matlab
rx_baseband = rx_signal .* exp(-1i * 2*pi*(Flo + f_off) .* time_rx);
```

### 5.4 降采样 `sgmfsk_decimation.m`

**多级CIC降采样结构：**
- Stage1: Dec1 (R=2, N=5)
- Stage2: Dec2 (R=2, N=5)
- Stage3: Dec3 (R=2, N=5)
- Stage4: Dec4 (R=125, N=5) ← 主要降采样级
- Stage5: Dec5 + HBF

总降采样比: 32MHz / (2×2×2×125×4) ≈ 8kHz（根据实际配置）

也支持 `Direct_resample==0` 时直接用 `resample()` 函数。

### 5.5 载波混频校正 `rx_cmix.m`

- 生成时间轴，计算残余相位
- `CORDIC_EN=1`: 使用CORDIC算法进行复数旋转
- `CORDIC_EN=0`: 直接使用复指数乘法

### 5.6 相干解调 `sgmfsk_CoDemod.m`

**支持三种解调方式：**

#### A. MIX-LPF 方式（主方式）
- 将接收信号复制 Mfsk 份，分别与各频率 tone 混频
- 通过各自的 LPF 滤波器
- 在符号中间采样，取最大支路作为判决
- 支持硬判决 + **Viterbi MLSE软判决**

#### B. FREQ-DET 方式（差分鉴频）
- `diff_conj = rx_iq .* conj([last_iq; rx_iq(1:end-1)])`
- 提取相位差，LPF滤波
- 与阈值比较进行判决

#### C. NCCH-REF 方式（非相干参考）
- 调用 `fskDemod()` 进行非相干解调

**辅助函数：**
- `phase_diff_max_min()`: 估计频偏
- `sync_search()`: 同步头搜索
- `crossing_stats()/crossing_weight()`: 过零统计
- `peak_statistic()`: 峰值统计

### 5.7 PLL频率解调

#### `pll_initialize.m`
- 自然角频率: `wn = 2π×(f_dev + BW×0.35)`
- 阻尼系数: `ζ = 0.99/√√2`
- 环路增益、滤波器系数计算
- 绘制根轨迹图

#### `pll_demode.m` (2阶II型)
- 相位误差: `phi_err = angle(rx_iq) - pll_state.phivco`
- 环路滤波器 + NCO积分器
- 输出解调频率

#### `pll_demode_typeIII.m` (3阶III型)
- 增加额外积分器支路
- 更好的跟踪性能

### 5.8 Viterbi MLSE译码 `viterbi_decode_isi.m`

**算法特性：**
- **4状态** (M_v = 4)，对应4FSK的4个符号
- **ISI-aware**: 考虑码间干扰的参考模板匹配
- **Soft-decision**: 基于归一化L2距离的软度量

**前向递归（向量化）：**
```matlab
branch_all = reshape(obs_normed(:,t)' * ref_all, M_v, M_v);
val = pathMetric(:,t-1) + branch_all;
[pm_t, back_t] = max(val, [], 1);
```

**回溯：**
- 从最后时刻最大路径度量开始
- 根据 `back` 矩阵回溯最优路径

### 5.9 参考模板生成 `ref_metric_gen.m`

- 生成所有16种 (prev_g, curr_g) 状态转移对应的参考波形
- 通过4个LPF支路提取包络
- 在特定采样点提取度量值，构建 `ref_metric(M,M,M)` 三维矩阵

### 5.10 CORDIC旋转 `cordic_rotation.m`

- 16次迭代
- 角度预处理（分解为象限 + [0, π/2) 残留角）
- 增益补偿: `K = Π(1/√(1+2^(-2i)))`

### 5.11 BPF设计 `bpf_pair_fir_design.m`

- 先设计低通FIR原型
- 通过零极点旋转产生复数带通滤波器对（正/负频率偏移）

---

## 六、主仿真流程 (smart_gmfsk_16x.m)

### 6.1 初始化阶段
1. 清除全局变量，设置路径
2. 定义系统参数（Mfsk, BR, fs, fs_tx, fs_rx, F_dev, Flo等）
3. 定义Eb/No扫描范围
4. 初始化BER统计状态（支持断点续仿）
5. 计算理论BER参考曲线

### 6.2 外层循环
- **方法循环**: 遍历各种解调方法（MIX-LPF, FREQ-DET等）
- **Eb/No循环**: 遍历不同信噪比

### 6.3 内层符号循环
- **第0帧**: 发送同步帧，完成接收机初始化（滤波器状态、相位同步）
- **第1~N帧**: 发送随机数据帧
  - 调制 → 信道 → DDC → 降采样 → 载波校正 → 信道滤波
  - 拼接前后帧（处理滤波器延迟）
  - 解调（硬判决 + MLSE软判决）
  - 错误统计

### 6.4 结果输出
- BER曲线绘制（semilog）
- 灵敏度表格
- 结果保存到文本文件

### 6.5 内置辅助函数

| 函数名 | 功能 |
|--------|------|
| `reset_filter_objs()` | 重置全局滤波器对象状态 |
| `cma_eq()` | CMA盲均衡器 |
| `ber_state_init()` | BER状态初始化（支持新建/续跑） |
| `ber_result_save()` | BER结果保存 |
| `sensitivity_calc()` | 灵敏度计算（BER=0.001对应的Eb/No） |
| `zero_crossing_find()` | 过零点插值查找 |
| `error_stat()` | 错误统计（含错误位置分析） |

---

## 七、已知问题与注意事项

| # | 问题 | 位置 | 严重程度 |
|---|------|------|----------|
| 1 | `sgmfsk_filter_series.m` 内容与主文件完全相同，疑似误拷贝 | `sub_function_sgmfsk/` | 中 |
| 2 | `sgmfsk_filter_gen()` 函数不存在，但主文件第60行调用 | `smart_gmfsk_16x.m:60` | **高** |
| 3 | `refMetric(len)` 应为 `ref_metric_gen()`，函数名不匹配 | `smart_gmfsk_16x.m:62` | **高** |
| 4 | `EbNo_dB = 20*(1.2.^((0:1:-20)'))` 产生空向量（步进方向错误） | `smart_gmfsk_16x.m:40` | **高** |
| 5 | `filt_dly` 未定义就被使用 | `smart_gmfsk_16x.m:85` | 中 |
| 6 | `rx_bits_mlse` 未定义 | `smart_gmfsk_16x.m:108` | 中 |
| 7 | `sgmfsk_CoDemod.m` 中多处变量未定义（`Msk`, `rx_len_sps_rx`等） | `sgmfsk_CoDemod.m` | 中 |
| 8 | `sgmfsk_filter_series.m` 实际应该是滤波器生成函数 | - | 中 |

> ⚠️ 以上问题**在本次归档中不做修改**，仅做记录。待后续开发时逐一处理。

---

## 八、全局变量一览

| 变量名 | 作用域 | 说明 |
|--------|--------|------|
| `FILT` | 全局 | 滤波器对象数组（chFilter, LPFx等） |
| `Samp_IDET` | 全局 | 采样标识 |
| `Mfsk` | 全局 | 调制阶数 |
| `ref_metric` | 全局 | Viterbi参考度量模板 |
| `DEBUG` | 全局 | 调试开关 |
| `Demod_method_list` | 全局 | 解调方法列表 |
| `N_32M_start` | 全局 | 32MHz采样时间索引 |
| `N_4K_start` | 全局 | 4kHz采样时间索引 |
| `last_rx_phase` | 全局 | 接收端上一帧相位 |
| `last_tx_phase` | 全局 | 发射端上一帧相位 |
| `last_iq` | 全局 | 上一帧IQ采样 |
| `pll_state` | 全局 | PLL状态变量 |
| `pll_config` | 全局 | PLL配置参数 |
| `pll_integ` | 全局 | PLL积分器对象 |
| `FLT_DEC_stage1~5` | 全局 | CIC降采样滤波器 |
| `FLT_gaussWin` | 全局 | 高斯滤波器（含状态） |

---

## 九、依赖关系图

```
smart_gmfsk_16x.m (主脚本)
    ├── sgmfsk_modulator.m
    │   ├── gausspulsdesign() [内部]
    │   ├── FLT_gaussWin() [内部]
    │   └── code2bin() [内部]
    ├── awn_channelizing.m
    ├── rx_ddc_mixer.m
    ├── sgmfsk_decimation.m
    │   └── fftTransform.m [DEBUG时]
    ├── rx_cmix.m
    │   └── cordic_rotation.m [CORDIC_EN=1时]
    ├── sgmfsk_CoDemod.m
    │   ├── viterbi_decode_isi.m
    │   ├── plot_time_freq_response.m
    │   └── fftTransform.m
    ├── ref_metric_gen.m
    │   ├── sgmfsk_modulator.m
    │   ├── rx_ddc_mixer.m
    │   ├── sgmfsk_decimation.m
    │   └── rx_cmix.m
    ├── pll_demode.m / pll_demode_typeIII.m
    │   └── pll_initialize.m
    ├── rssi_snr_estimati.m
    └── bpf_pair_fir_design.m [滤波器设计时]
```

---

*本文档为代码理解归档，后续开发修改前请仔细核对。*
