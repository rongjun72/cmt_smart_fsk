function [encoded_interleaved, Nrow, Ncol, puncvec] = conv_enc_interleave(info_bits, trellis, Nrow, Ncol, puncvec)
%CONV_ENC_INTERLEAVE 卷积编码 + (可选打孔) + 块交织
%   对输入信息比特进行卷积编码，可选打孔，然后进行块交织。
%
%   输入:
%     info_bits - 信息比特序列 (列向量或行向量), 长度 = N
%     trellis   - 卷积码 trellis 结构
%     Nrow, Ncol - 交织器行列数 (可选). 若省略则自动选择
%     puncvec   - 打孔向量 (可选). 若提供则在编码后打孔
%
%   输出:
%     encoded_interleaved - 编码(打孔)并交织后的比特序列
%     Nrow, Ncol - 实际使用的交织器维度
%     puncvec    - 打孔向量 (原样返回供解调端使用)

    if nargin < 5
        puncvec = [];
    end

    %% 1. 卷积编码
    encoded = convenc(info_bits(:), trellis);

    %% 2. 打孔 (可选)
    if ~isempty(puncvec)
        encoded = puncture_bits(encoded, puncvec);
    end
    L = length(encoded);

    %% 3. 确定交织器维度
    if nargin < 3 || isempty(Nrow) || isempty(Ncol)
        Ncol = floor(sqrt(L));
        while Ncol > 1
            if mod(L, Ncol) == 0
                break;
            end
            Ncol = Ncol - 1;
        end
        Nrow = L / Ncol;
    end

    %% 4. 零填充到完整的交织矩阵大小
    mat_size = Nrow * Ncol;
    pad_len = mat_size - L;
    if pad_len > 0
        encoded = [encoded; zeros(pad_len, 1)];
    end

    %% 5. 块交织: 按行写入矩阵, 按列读出
    mat = reshape(encoded, Ncol, Nrow)';
    encoded_interleaved = mat(:);
end
