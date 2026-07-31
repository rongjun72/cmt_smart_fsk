function punctured = puncture_bits(bits, puncvec)
%PUNCTURE_BITS 对编码比特序列进行周期性打孔
%   输入:
%     bits     - 编码比特序列 (列向量)
%     puncvec  - 打孔向量, 1=保留, 0=删除, 周期性重复应用
%   输出:
%     punctured - 打孔后的比特序列
%
%   示例: puncvec = [1 1 0 1] 表示每 4 个比特删除第 3 个

    if nargin < 2 || isempty(puncvec)
        punctured = bits(:);
        return;
    end
    
    p = length(puncvec);
    bits = bits(:);
    N = floor(length(bits) / p) * p;
    
    if N > 0
        bits_period = reshape(bits(1:N), p, []);
        mask = repmat(puncvec(:), 1, size(bits_period, 2));
        punctured = bits_period(mask == 1);
    else
        punctured = [];
    end
    
    % 处理不足一个周期的剩余比特
    remainder = bits(N+1:end);
    if ~isempty(remainder)
        rem_mask = puncvec(1:length(remainder));
        punctured = [punctured; remainder(rem_mask == 1)];
    end
end
