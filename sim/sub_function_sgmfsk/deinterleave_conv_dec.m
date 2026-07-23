function [info_bits_est] = deinterleave_conv_dec(rx_encoded_bits, trellis, Nrow, Ncol, tblen)
%DEINTERLEAVE_CONV_DEC 解交织 + 维特比硬判决译码
%   对接收到的编码比特序列先进行块解交织，再用维特比算法硬判决译码。
%
%   输入:
%     rx_encoded_bits - 接收端编码比特序列 (0/1)
%     trellis         - 卷积码 trellis 结构
%     Nrow, Ncol      - 交织器行列数
%     tblen           - 维特比回溯长度 (可选, 默认 5*K)
%
%   输出:
%     info_bits_est   - 译码后的信息比特 (列向量)

    L = length(rx_encoded_bits);
    mat_size = Nrow * Ncol;

    %% 1. 零填充到完整矩阵大小
    if L < mat_size
        rx_padded = [rx_encoded_bits(:); zeros(mat_size - L, 1)];
    else
        rx_padded = rx_encoded_bits(:);
    end

    %% 2. 块解交织: 按列写入矩阵, 按行读出
    mat = reshape(rx_padded(1:mat_size), Nrow, Ncol)';
    deinterleaved = mat(:);

    %% 3. 维特比译码 (硬判决, trunc 模式)
    if nargin < 5 || isempty(tblen)
        K = log2(trellis.numStates) + 1;
        tblen = 5 * K;
    end

    info_bits_est = vitdec(deinterleaved, trellis, tblen, 'trunc', 'hard');
end
