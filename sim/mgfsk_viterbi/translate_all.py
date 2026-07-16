import os, re

ws_dir = r"C:\Users\Administrator\Documents\Kimi\Workspaces\mgfsk_viterbi"

replacements = [
    # Longest phrases first (12+ chars)
    ("峰值在全局时间轴上的位置", "Peak position on global time axis"),
    ("标记三种采样策略的位置", "Mark positions of three sampling strategies"),
    ("采样点窗口内的峰值位置", "Peak position within sampling point window"),
    ("添加轻微偏移避免多条线", "Add slight offset to avoid overlapping lines"),
    ("标记各分支的最优相位", "Mark optimal phase of each branch"),
    ("个前驱分支的累积度量", "predecessor branches' cumulative metrics"),
    ("符号上标记峰值位置", "Mark peak position on symbol"),
    ("符号内的采样点位置", "Sampling point position within symbol"),
    ("采样点的次大分支", "Second largest branch at sampling point"),
    ("是否在信道通带内", "Whether within channel passband"),
    ("用于决定线条样式", "Used to determine line style"),
    ("符号的峰值位置", "Symbol's peak position"),
    ("模拟某种相关性", "Simulate some correlation"),
    ("信号并经过信道", "Signal passing through channel"),
    ("发送分支的峰值", "Peak of transmitted branch"),
    ("与精确理论接近", "Close to exact theory"),
    ("点窗口内的位置", "Position within point window"),
    ("该分支的累积值", "Cumulative value of this branch"),
    ("越接近正确路径", "Closer to correct path"),
    ("生成但加入趋势", "Generate but add trend"),
    ("单次波形示意", "Single waveform illustration"),
    ("前发送符号的", "Previous transmitted symbol's"),
    ("防止数值溢出", "Prevent numerical overflow"),
    ("最大干扰分支", "Maximum interference branch"),
    ("该符号的峰值", "Peak of this symbol"),
    ("并启动并行池", "And start parallel pool"),
    ("只在第一个子", "Only in first subplot"),
    ("在偏移采样点", "At offset sampling point"),
    ("时有稍高概率", "Has slightly higher probability when"),
    ("时间连续波形", "Time-continuous waveform"),
    ("逐符号最大模", "Per-symbol maximum magnitude"),
    ("标记理论符号", "Mark theoretical symbol"),
    ("重新生成信号", "Regenerate signal"),
    ("的最优相位", "optimal phase"),
    ("或梯形规则", "Or trapezoidal rule"),
    ("的符号序列", "symbol sequence"),
    ("橙色中等线", "Orange medium line"),
    ("符号有值的", "Symbol has value"),
    ("但利用内层", "But use inner layer"),
    ("的误差地板", "error floor"),
    ("后的采样点", "sampling point after"),
    ("采样点一致", "Sampling point consistent"),
    ("格子的数值", "Grid cell value"),
    ("处理并记录", "Process and record"),
    ("复包络信号", "Complex envelope signal"),
    ("与代码一致", "Consistent with code"),
    ("和峰值位置", "And peak position"),
    ("符号和比特", "Symbol and bit"),
    ("带轻微曲线", "With slight curve"),
    ("但频率变了", "But frequency changed"),
    ("自然二进制", "Natural binary"),
    ("最大模判决", "Maximum magnitude decision"),
    ("的峰值位置", "peak position"),
    ("不支持嵌套", "Does not support nesting"),
    ("取该点前后", "Take before and after this point"),
    ("在接收端的", "At receiver side"),
    ("为脉冲序列", "As pulse sequence"),
    ("的累积度量", "cumulative metric"),
    ("转移都允许", "All transitions allowed"),
    ("根据累积值", "According to cumulative value"),
    ("符号内位置", "Position within symbol"),
    ("通常足够", "Usually sufficient"),
    ("单位功率", "Unit power"),
    ("该符号的", "This symbol's"),
    ("标记符号", "Mark symbol"),
    ("接收前端", "Receiver frontend"),
    ("偏移后的", "After offset"),
    ("略有差异", "Slightly different"),
    ("发送符号", "Transmitted symbol"),
    ("采样点的", "Sampling point's"),
    ("红色粗线", "Red thick line"),
    ("区分度比", "Discrimination ratio"),
    ("前阶数的", "Previous order's"),
    ("越深表示", "Darker means"),
    ("找出哪个", "Find which"),
    ("重新设计", "Redesign"),
    ("发送分支", "Transmitted branch"),
    ("串行回退", "Serial fallback"),
    ("采样索引", "Sampling index"),
    ("相位偏移", "Phase offset"),
    ("更好度量", "Better metric"),
    ("接收后端", "Receiver backend"),
    ("标记理论", "Mark theory"),
    ("避免重叠", "Avoid overlap"),
    ("符号索引", "Symbol index"),
    ("名义起始", "Nominal start"),
    ("避免依赖", "Avoid dependency"),
    ("接收信号", "Received signal"),
    ("连续波形", "Continuous waveform"),
    ("序列检测", "Sequence detection"),
    ("前符号值", "Previous symbol value"),
    ("数值积分", "Numerical integration"),
    ("发送频率", "Transmit frequency"),
    ("生成信号", "Generate signal"),
    ("采样点与", "Sampling point and"),
    ("精确公式", "Exact formula"),
    ("个采样点", "sampling points"),
    ("前驱状态", "Predecessor state"),
    ("发送序列", "Transmit sequence"),
    ("延迟重新", "Delay re-"),
    ("线条粗细", "Line thickness"),
    ("符号叠加", "Symbol superposition"),
    ("线条样式", "Line style"),
    ("灰色细线", "Gray thin line"),
    ("行为一致", "Behavior consistent"),
    ("防止溢出", "Prevent overflow"),
    ("窗口起始", "Window start"),
    ("每符号", "Per symbol"),
    ("为全局", "As global"),
    ("用新的", "Use new"),
    ("器不变", "Filter unchanged"),
    ("器瞬态", "Filter transient"),
    ("度量值", "Metric value"),
    ("越大越", "Larger means more"),
    ("蓝色系", "Blue color scheme"),
    ("强制列", "Force column"),
    ("软度量", "Soft metric"),
    ("比特级", "Bit-level"),
    ("前状态", "Previous state"),
    ("各自在", "Each at"),
    ("工具箱", "Toolbox"),
    ("可能因", "May due to"),
    ("值越高", "Higher value"),
    ("个分支", "branches"),
    ("含边距", "Include margin"),
    ("采样点", "Sampling point"),
    ("分支的", "Branch's"),
    ("不影响", "Does not affect"),
    ("无约束", "Unconstrained"),
    ("时只看", "Only look at"),
    ("最外侧", "Outermost"),
    ("符号为", "Symbol is"),
    ("新状态", "New state"),
    ("的波形", "waveform"),
    ("重新预", "Re-precompute"),
    ("延迟", "Delay"),
    ("被积", "Integrand"),
    ("包含", "Include"),
    ("积分", "Integrate"),
    ("默认", "Default"),
    ("低通", "Lowpass"),
    ("感知", "Aware"),
    ("构建", "Build"),
    ("确保", "Ensure"),
    ("推导", "Derive"),
    ("引入", "Introduce"),
    ("编码", "Encode"),
    ("全帧", "Full-frame"),
    ("越高", "Higher"),
    ("近似", "Approximate"),
    ("隔离", "Isolate"),
    ("安全", "Safe"),
    ("排除", "Exclude"),
    ("发送", "Transmit"),
    ("信道", "Channel"),
    ("精确", "Exact"),
    ("因果", "Causal"),
    ("标记", "Mark"),
    ("解码", "Decode"),
    ("一致", "Consistent"),
    ("采样", "Sample"),
    ("上界", "Upper bound"),
    ("正确", "Correct"),
    ("模值", "Magnitude"),
    ("度量", "Metric"),
    ("检测", "Detect"),
    ("比特", "Bit"),
    ("序列", "Sequence"),
    ("颜色", "Color"),
    ("参数", "Parameters"),
    ("根据", "According to"),
    ("符号", "Symbol"),
    ("需要", "Need"),
    ("只有", "Only"),
    ("前驱", "Predecessor"),
    ("相邻", "Adjacent"),
    ("内联", "Inline"),
    ("分支", "Branch"),
    ("这里", "Here"),
    ("瀑布", "Waterfall"),
    ("变了", "Changed"),
    ("以此", "By this"),
    ("理想", "Ideal"),
    ("模拟", "Simulate"),
    ("不变", "Unchanged"),
    ("窗口", "Window"),
    ("到基", "To baseband"),
    ("找出", "Find"),
    ("模板", "Template"),
    ("避免", "Avoid"),
    ("重叠", "Overlap"),
    ("重新", "Re-"),
    ("转移", "Transfer"),
    ("状态", "State"),
    ("连线", "Connection"),
    ("生成", "Generate"),
    ("变化", "Change"),
    ("个", ""),
    ("型", "Type"),
    ("共", "Total"),
    ("例", "Example"),
    ("行", "Row"),
    ("绘", "Plot"),
    ("在", "At"),
    ("已", "Already"),
    ("值", "Value"),
    ("为", "As"),
    ("高", "High"),
    ("与", "With"),
    ("的", "of"),
    ("器", "Filter"),
    ("码", "Code"),
    ("从", "From"),
    ("新", "New"),
    ("是", "Is"),
    ("到", "To"),
    ("度", "Degree"),
    ("预", "Pre-"),
    ("列", "Column"),
    ("让", "Let"),
    ("对", "For"),
    ("和", "And"),
    ("轴", "Axis"),
    ("取", "Take"),
    ("推", "Push"),
    ("或", "Or"),
    ("只", "Only"),
    ("子", "Sub-"),
    ("不", "Not"),
]

def translate_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    changed = 0
    
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if not stripped.startswith('%'):
            continue
        if not re.search(r'[\u4e00-\u9fff]', line):
            continue
        
        original = line
        for old, new in replacements:
            if old in line:
                line = line.replace(old, new)
        
        if line != original:
            lines[i] = line
            changed += 1
    
    new_content = '\n'.join(lines)
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True, changed
    return False, 0

def main(ctx):
    ws_dir = r"C:\Users\Administrator\Documents\Kimi\Workspaces\mgfsk_viterbi"
    m_files = [f for f in sorted(os.listdir(ws_dir)) if f.endswith('.m')]
    
    total_changed = 0
    modified_files = []
    
    for fname in m_files:
        fpath = os.path.join(ws_dir, fname)
        modified, count = translate_file(fpath)
        if modified:
            modified_files.append(fname)
            total_changed += count
            print(f"Modified {fname}: {count} lines changed")
    
    print(f"\nTotal: {len(modified_files)} files modified, {total_changed} lines changed")
    return {"modified_files": modified_files, "total_changed": total_changed}

if __name__ == '__main__':
    main({})
