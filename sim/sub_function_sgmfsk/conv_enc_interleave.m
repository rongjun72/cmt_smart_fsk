function [encoded_interleaved, Nrow, Ncol] = conv_enc_interleave(info_bits, trellis, Nrow, Ncol)
%CONV_ENC_INTERLEAVE 卷积编码 + 块交织
%   对输入信息比特进行 (7,5) 卷积编码，然后进行块交织。
%   MATLAB convenc 自动在末尾添加 K-1 个尾比特使编码器回到全零状态。
%
%   输入:
%     info_bits - 信息比特序列 (列向量或行向量), 长度 = N
%     trellis   - 卷积码 trellis 结构, 如 poly2trellis(3,[7 5])
%     Nrow, Ncol - 交织器行列数 (可选). 若省略则自动选择接近方阵的尺寸
%
%   输出:
%     encoded_interleaved - 编码并交织后的比特序列 (列向量)
%     Nrow, Ncol - 实际使用的交织器维度

    %% 1. 卷积编码 (自动添加尾比特)
    encoded = convenc(info_bits(:), trellis);
    L = length(encoded);

    %% 2. 确定交织器维度
    if nargin < 3 || isempty(Nrow) || isempty(Ncol)
        Ncol = ceil(sqrt(L));
        Nrow = ceil(L / Ncol);
    end

    %% 3. 零填充到完整的交织矩阵大小
    mat_size = Nrow * Ncol;
    pad_len = mat_size - L;
    if pad_len > 0
        encoded = [encoded; zeros(pad_len, 1)];
    end

    %% 4. 块交织: 按行写入矩阵, 按列读出
    % reshape 按列填充 -> 转置后等效于按行填充
    mat = reshape(encoded, Ncol, Nrow)';
    encoded_interleaved = mat(:);
end
