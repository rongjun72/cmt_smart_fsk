import os
import re

ws_dir = r"C:\Users\Administrator\Documents\Kimi\Workspaces\mgfsk_viterbi"

# Comprehensive mapping of Chinese comment patterns to English
# Order matters: longer/more specific patterns first
replacements = [
    # ===== Section headers / Architecture descriptions =====
    (r'%\s*接收前端：', r'% Receiver frontend: '),
    (r'%\s*接收后端：', r'% Receiver backend: '),
    (r'%\s*架构：', r'% Architecture: '),
    (r'%\s*发射：', r'% Tx: '),
    (r'%\s*信道：', r'% Channel: '),
    (r'%\s*ISI 感知设计：', r'% ISI-aware design: '),
    (r'%\s*ISI 感知', r'% ISI-aware'),
    (r'%\s*核心成果', r'% Core result'),
    (r'%\s*历史实验', r'% Historical experiment'),
    (r'%\s*最终归档', r'% Final archived version'),
    
    # ===== Parameter descriptions =====
    (r'%\s*符号率\s*\(Hz\)', r'% Symbol rate (Hz)'),
    (r'%\s*采样率\s*\(Hz\)', r'% Sampling rate (Hz)'),
    (r'%\s*每符号采样数\s*=', r'% Samples per symbol ='),
    (r'%\s*4进制', r'% 4-ary'),
    (r'%\s*8进制', r'% 8-ary'),
    (r'%\s*2 bits/symbol', r'% 2 bits/symbol'),
    (r'%\s*3 bits/symbol', r'% 3 bits/symbol'),
    (r'%\s*调制指数：', r'% Modulation index: '),
    (r'%\s*高斯滤波BT', r'% Gaussian filter BT'),
    (r'%\s*高斯滤波span', r'% Gaussian filter span'),
    (r'%\s*有效符号数', r'% Valid symbol count'),
    (r'%\s*非线性EbN0分布：', r'% Nonlinear EbN0 distribution: '),
    (r'%\s*每点仿真次数', r'% Simulations per point'),
    (r'%\s*参数配置', r'% Parameter configuration'),
    (r'%\s*可配置参数', r'% Configurable parameters'),
    (r'%\s*信道参数', r'% Channel parameters'),
    (r'%\s*判决深度', r'% Decision depth'),
    
    # ===== Filter design =====
    (r'%\s*高斯频率脉冲（发射端）', r'% Gaussian frequency pulse (transmitter)'),
    (r'%\s*高斯脉冲整形', r'% Gaussian pulse shaping'),
    (r'%\s*高斯滤波', r'% Gaussian filter'),
    (r'%\s*高斯脉冲群延迟', r'% Gaussian pulse group delay'),
    (r'%\s*信道滤波器：', r'% Channel filter: '),
    (r'%\s*信道滤波器', r'% Channel filter'),
    (r'%\s*Tone混频低通滤波器：', r'% Tone mixer lowpass filter: '),
    (r'%\s*Tone混频低通滤波器', r'% Tone mixer lowpass filter'),
    (r'%\s*Tone LPF 设计', r'% Tone LPF design'),
    (r'%\s*滤波器设计', r'% Filter design'),
    (r'%\s*滤波器设计与延迟计算', r'% Filter design and delay calculation'),
    (r'%\s*低通FIR', r'% Lowpass FIR'),
    (r'%\s*优化：', r'% Optimization: '),
    (r'%\s*优化理由', r'% Optimization rationale'),
    (r'%\s*窗函数：', r'% Window function: '),
    (r'%\s*截止频率：', r'% Cutoff frequency: '),
    (r'%\s*延迟：', r'% Delay: '),
    (r'%\s*阶数：', r'% Order: '),
    (r'%\s*总延迟', r'% Total delay'),
    (r'%\s*采样时刻：', r'% Sampling instant: '),
    (r'%\s*采样索引：', r'% Sampling index: '),
    (r'%\s*采样点：', r'% Sampling point: '),
    (r'%\s*采样索引越界', r'% Sampling index out of bounds'),
    
    # ===== Gray encoding =====
    (r'%\s*Gray 编解码映射', r'% Gray encoding/decoding mapping'),
    (r'%\s*Gray 编码', r'% Gray encoding'),
    (r'%\s*Gray 映射', r'% Gray mapping'),
    (r'%\s*频率编号', r'% Frequency index'),
    
    # ===== Helper functions =====
    (r'%\s*辅助函数：', r'% Helper function: '),
    (r'%\s*辅助函数', r'% Helper function'),
    (r'%\s*生成GFSK信号', r'% Generate GFSK signal'),
    (r'%\s*预计算：', r'% Precompute: '),
    (r'%\s*验证参考模板', r'% Verify reference templates'),
    (r'%\s*参考模板', r'% Reference template'),
    (r'%\s*测量', r'% Measure'),
    
    # ===== Viterbi / detection =====
    (r'%\s*Viterbi 解码器', r'% Viterbi decoder'),
    (r'%\s*Viterbi 序列检测', r'% Viterbi sequence detection'),
    (r'%\s*ISI 感知 Viterbi', r'% ISI-aware Viterbi'),
    (r'%\s*硬判决（逐符号最大模）', r'% Hard decision (per-symbol max magnitude)'),
    (r'%\s*硬判决', r'% Hard decision'),
    (r'%\s*软判决', r'% Soft decision'),
    (r'%\s*分支度量', r'% Branch metric'),
    (r'%\s*前向递推', r'% Forward recursion'),
    (r'%\s*回溯', r'% Traceback'),
    (r'%\s*全帧回溯', r'% Full-frame traceback'),
    (r'%\s*归一化防溢出', r'% Normalization prevents overflow'),
    (r'%\s*无噪声 Viterbi 自检', r'% Noiseless Viterbi self-check'),
    (r'%\s*无噪声', r'% Noiseless'),
    (r'%\s*自检', r'% Self-check'),
    (r'%\s*状态定义', r'% State definition'),
    (r'%\s*状态数', r'% Number of states'),
    (r'%\s*状态转移', r'% State transition'),
    (r'%\s*路径度量', r'% Path metric'),
    (r'%\s*累计路径度量', r'% Cumulative path metric'),
    (r'%\s*幸存路径', r'% Survivor path'),
    (r'%\s*最优路径', r'% Optimal path'),
    
    # ===== Simulation =====
    (r'%\s*主仿真：', r'% Main simulation: '),
    (r'%\s*主仿真', r'% Main simulation'),
    (r'%\s*Eb/N0 扫描', r'% Eb/N0 sweep'),
    (r'%\s*AWGN 噪声', r'% AWGN noise'),
    (r'%\s*AWGN + 信道滤波', r'% AWGN + channel filter'),
    (r'%\s*噪声方差计算', r'% Noise variance calculation'),
    (r'%\s*功率校验', r'% Power check'),
    (r'%\s*蒙特卡洛', r'% Monte Carlo'),
    (r'%\s*仿真结果', r'% Simulation results'),
    (r'%\s*仿真时间', r'% Simulation time'),
    (r'%\s*运行仿真', r'% Run simulation'),
    (r'%\s*可调参数', r'% Adjustable parameters'),
    (r'%\s*使用说明', r'% Usage instructions'),
    
    # ===== Visualization =====
    (r'%\s*可视化', r'% Visualization'),
    (r'%\s*信号频谱', r'% Signal spectrum'),
    (r'%\s*星座图', r'% Constellation diagram'),
    (r'%\s*误码率曲线', r'% BER curve'),
    (r'%\s*错误位置', r'% Error locations'),
    (r'%\s*对比', r'% Comparison'),
    (r'%\s*增益', r'% Gain'),
    (r'%\s*图', r'% Figure'),
    
    # ===== Analysis / Metrics =====
    (r'%\s*分析', r'% Analysis'),
    (r'%\s*统计', r'% Statistics'),
    (r'%\s*扫描', r'% Scan'),
    (r'%\s*优化', r'% Optimize'),
    (r'%\s*测试', r'% Test'),
    (r'%\s*评估', r'% Evaluate'),
    (r'%\s*性能', r'% Performance'),
    (r'%\s*指标', r'% Metrics'),
    (r'%\s*结果', r'% Results'),
    (r'%\s*结果汇总', r'% Result summary'),
    (r'%\s*结论', r'% Conclusion'),
    (r'%\s*验证', r'% Verification'),
    (r'%\s*确认', r'% Confirm'),
    (r'%\s*检查', r'% Check'),
    
    # ===== Specific analysis scripts =====
    (r'%\s*符号内部分支度量', r'% Intra-symbol branch metrics'),
    (r'%\s*Tone LPF 阶数测试', r'% Tone LPF order test'),
    (r'%\s*8-GFSK 符号内 tone 度量分析', r'% 8-GFSK intra-symbol tone metrics analysis'),
    (r'%\s*每分支最优相位', r'% Per-branch optimal phase'),
    (r'%\s*采样相位扫描', r'% Sampling phase scan'),
    (r'%\s*h 和 LPF 联合优化', r'% Joint h and LPF optimization'),
    
    # ===== 8-ary specific =====
    (r'%\s*8-ary GFSK', r'% 8-ary GFSK'),
    (r'%\s*8-branch', r'% 8-branch'),
    (r'%\s*8 状态', r'% 8 states'),
    (r'%\s*64 状态', r'% 64 states'),
    (r'%\s*4 状态', r'% 4 states'),
    (r'%\s*1符号记忆', r'% 1-symbol memory'),
    (r'%\s*2符号记忆', r'% 2-symbol memory'),
    (r'%\s*3符号记忆', r'% 3-symbol memory'),
    
    # ===== General terms =====
    (r'%\s*连续相位', r'% Continuous-phase'),
    (r'%\s*码间干扰', r'% Inter-symbol interference (ISI)'),
    (r'%\s*相干检测', r'% Coherent detection'),
    (r'%\s*相干解调', r'% Coherent demodulation'),
    (r'%\s*频率跳变', r'% Frequency jump'),
    (r'%\s*相位积分', r'% Phase integration'),
    (r'%\s*上采样', r'% Upsampling'),
    (r'%\s*混频', r'% Mixing'),
    (r'%\s*滤波', r'% Filtering'),
    (r'%\s*取模', r'% Magnitude'),
    (r'%\s*归一化', r'% Normalization'),
    (r'%\s*延迟补偿', r'% Delay compensation'),
    (r'%\s*群延迟', r'% Group delay'),
    (r'%\s*带外抑制', r'% Out-of-band rejection'),
    (r'%\s*通带截止', r'% Passband cutoff'),
    (r'%\s*阻带截止', r'% Stopband cutoff'),
    (r'%\s*通带带宽', r'% Passband bandwidth'),
    (r'%\s*过渡带', r'% Transition band'),
    (r'%\s*旁瓣抑制', r'% Sidelobe suppression'),
    (r'%\s*脉冲响应', r'% Impulse response'),
    (r'%\s*频率响应', r'% Frequency response'),
    (r'%\s*幅度响应', r'% Magnitude response'),
    (r'%\s*相位响应', r'% Phase response'),
    (r'%\s*稳态', r'% Steady state'),
    (r'%\s*边界效应', r'% Boundary effects'),
    (r'%\s*防护带', r'% Guard band'),
    (r'%\s*前导', r'% Preamble'),
    (r'%\s*后导', r'% Postamble'),
    (r'%\s*有效', r'% Valid'),
    (r'%\s*随机', r'% Random'),
    (r'%\s*固定', r'% Fixed'),
    (r'%\s*相同', r'% Identical'),
    (r'%\s*不同', r'% Different'),
    (r'%\s*完全', r'% Fully'),
    (r'%\s*部分', r'% Partially'),
    (r'%\s*主要', r'% Main'),
    (r'%\s*次要', r'% Secondary'),
    (r'%\s*所有', r'% All'),
    (r'%\s*每个', r'% Each'),
    (r'%\s*任意', r'% Any'),
    (r'%\s*其他', r'% Other'),
    (r'%\s*例如', r'% For example'),
    (r'%\s*比如', r'% For example'),
    (r'%\s*注意', r'% Note'),
    (r'%\s*警告', r'% Warning'),
    (r'%\s*错误', r'% Error'),
    (r'%\s*原因', r'% Reason'),
    (r'%\s*修复', r'% Fix'),
    (r'%\s*症状', r'% Symptom'),
    (r'%\s*因此', r'% Therefore'),
    (r'%\s*因为', r'% Because'),
    (r'%\s*所以', r'% So'),
    (r'%\s*但是', r'% But'),
    (r'%\s*然而', r'% However'),
    (r'%\s*如果', r'% If'),
    (r'%\s*否则', r'% Otherwise'),
    (r'%\s*当', r'% When'),
    (r'%\s*对于', r'% For'),
    (r'%\s*其中', r'% Where'),
    (r'%\s*通过', r'% Through'),
    (r'%\s*使用', r'% Using'),
    (r'%\s*基于', r'% Based on'),
    (r'%\s*由于', r'% Due to'),
    (r'%\s*导致', r'% Causes'),
    (r'%\s*产生', r'% Generates'),
    (r'%\s*计算', r'% Calculate'),
    (r'%\s*得到', r'% Obtain'),
    (r'%\s*获得', r'% Get'),
    (r'%\s*输出', r'% Output'),
    (r'%\s*输入', r'% Input'),
    (r'%\s*返回', r'% Return'),
    (r'%\s*设置', r'% Set'),
    (r'%\s*配置', r'% Configure'),
    (r'%\s*选择', r'% Select'),
    (r'%\s*确定', r'% Determine'),
    (r'%\s*获取', r'% Acquire'),
    (r'%\s*提取', r'% Extract'),
    (r'%\s*查找', r'% Find'),
    (r'%\s*搜索', r'% Search'),
    (r'%\s*比较', r'% Compare'),
    (r'%\s*匹配', r'% Match'),
    (r'%\s*对应', r'% Correspond to'),
    (r'%\s*转换', r'% Convert'),
    (r'%\s*变换', r'% Transform'),
    (r'%\s*更新', r'% Update'),
    (r'%\s*重置', r'% Reset'),
    (r'%\s*初始化', r'% Initialize'),
    (r'%\s*开始', r'% Start'),
    (r'%\s*结束', r'% End'),
    (r'%\s*停止', r'% Stop'),
    (r'%\s*暂停', r'% Pause'),
    (r'%\s*继续', r'% Continue'),
    (r'%\s*重复', r'% Repeat'),
    (r'%\s*循环', r'% Loop'),
    (r'%\s*迭代', r'% Iterate'),
    (r'%\s*遍历', r'% Traverse'),
    (r'%\s*调用', r'% Call'),
    (r'%\s*执行', r'% Execute'),
    (r'%\s*运行', r'% Run'),
    (r'%\s*加载', r'% Load'),
    (r'%\s*保存', r'% Save'),
    (r'%\s*读取', r'% Read'),
    (r'%\s*写入', r'% Write'),
    (r'%\s*显示', r'% Display'),
    (r'%\s*打印', r'% Print'),
    (r'%\s*绘制', r'% Plot'),
    (r'%\s*画图', r'% Plot'),
    (r'%\s*标注', r'% Annotate'),
    (r'%\s*注释', r'% Comment'),
    (r'%\s*说明', r'% Description'),
    (r'%\s*描述', r'% Description'),
    (r'%\s*信息', r'% Information'),
    (r'%\s*数据', r'% Data'),
    (r'%\s*变量', r'% Variable'),
    (r'%\s*常量', r'% Constant'),
    (r'%\s*函数', r'% Function'),
    (r'%\s*方法', r'% Method'),
    (r'%\s*类', r'% Class'),
    (r'%\s*对象', r'% Object'),
    (r'%\s*结构', r'% Structure'),
    (r'%\s*数组', r'% Array'),
    (r'%\s*矩阵', r'% Matrix'),
    (r'%\s*向量', r'% Vector'),
    (r'%\s*标量', r'% Scalar'),
    (r'%\s*元素', r'% Element'),
    (r'%\s*分量', r'% Component'),
    (r'%\s*维度', r'% Dimension'),
    (r'%\s*大小', r'% Size'),
    (r'%\s*长度', r'% Length'),
    (r'%\s*宽度', r'% Width'),
    (r'%\s*高度', r'% Height'),
    (r'%\s*深度', r'% Depth'),
    (r'%\s*范围', r'% Range'),
    (r'%\s*区间', r'% Interval'),
    (r'%\s*区域', r'% Region'),
    (r'%\s*区域', r'% Area'),
    (r'%\s*边界', r'% Boundary'),
    (r'%\s*中心', r'% Center'),
    (r'%\s*中间', r'% Middle'),
    (r'%\s*内部', r'% Internal'),
    (r'%\s*外部', r'% External'),
    (r'%\s*左侧', r'% Left'),
    (r'%\s*右侧', r'% Right'),
    (r'%\s*上方', r'% Above'),
    (r'%\s*下方', r'% Below'),
    (r'%\s*前面', r'% Front'),
    (r'%\s*后面', r'% Back'),
    (r'%\s*顶部', r'% Top'),
    (r'%\s*底部', r'% Bottom'),
    (r'%\s*起点', r'% Start point'),
    (r'%\s*终点', r'% End point'),
    (r'%\s*原点', r'% Origin'),
    (r'%\s*参考点', r'% Reference point'),
    (r'%\s*基准点', r'% Benchmark point'),
    (r'%\s*关键点', r'% Key point'),
    (r'%\s*临界点', r'% Critical point'),
    (r'%\s*转折点', r'% Turning point'),
    (r'%\s*峰值点', r'% Peak point'),
    (r'%\s*谷值点', r'% Valley point'),
    (r'%\s*零点', r'% Zero point'),
    (r'%\s*极点', r'% Pole'),
    (r'%\s*奇点', r'% Singularity'),
    (r'%\s*节点', r'% Node'),
    (r'%\s*顶点', r'% Vertex'),
    (r'%\s*交点', r'% Intersection'),
    (r'%\s*切点', r'% Tangent point'),
    (r'%\s*触点', r'% Contact point'),
    (r'%\s*中点', r'% Midpoint'),
    (r'%\s*重心', r'% Center of gravity'),
    (r'%\s*质心', r'% Centroid'),
    (r'%\s*焦点', r'% Focus'),
    (r'%\s*中心点', r'% Center point'),
]

def translate_comments_in_file(filepath):
    """Translate Chinese comments in a single .m file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.split('\n')
    translated_lines = []
    changes = []
    
    for line in original_lines:
        original_line = line
        # Check if line is a comment containing Chinese
        stripped = line.lstrip()
        if stripped.startswith('%') and re.search(r'[\u4e00-\u9fff]', line):
            translated_line = line
            for pattern, replacement in replacements:
                translated_line = re.sub(pattern, replacement, translated_line)
            
            if translated_line != original_line:
                changes.append((original_line, translated_line))
            translated_lines.append(translated_line)
        else:
            translated_lines.append(line)
    
    new_content = '\n'.join(translated_lines)
    
    # Only write if there were changes
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True, changes
    return False, []

def main(ctx):
    ws_dir = r"C:\Users\Administrator\Documents\Kimi\Workspaces\mgfsk_viterbi"
    
    m_files = [f for f in sorted(os.listdir(ws_dir)) if f.endswith('.m')]
    
    total_changes = 0
    modified_files = []
    
    for fname in m_files:
        fpath = os.path.join(ws_dir, fname)
        modified, changes = translate_comments_in_file(fpath)
        if modified:
            modified_files.append(fname)
            total_changes += len(changes)
            print(f"Modified {fname}: {len(changes)} lines changed")
    
    print(f"\nTotal: {len(modified_files)} files modified, {total_changes} lines changed")
    return {
        "modified_files": modified_files,
        "total_changes": total_changes
    }

if __name__ == '__main__':
    main({})
