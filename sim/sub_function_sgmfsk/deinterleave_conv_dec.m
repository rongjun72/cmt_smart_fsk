function [info_bits_est] = deinterleave_conv_dec(rx_encoded_bits, trellis, Nrow, Ncol, tblen, puncvec, decision_type)
%DEINTERLEAVE_CONV_DEC Deinterleaving + (optional depuncturing) + Viterbi decoding
%   Block-deinterleave the received encoded bit sequence, then Viterbi decode.
%   Supports both hard-decision and unquantized (soft) Viterbi decoding.
%   If puncture vector puncvec is provided, vitdec automatically handles depuncturing internally.
%
%   Input:
%     rx_encoded_bits - Received encoded bit sequence (0/1 for hard, real values for unquant)
%     trellis         - Convolutional code trellis structure
%     Nrow, Ncol      - Interleaver row/column count
%     tblen           - Viterbi traceback length (optional, default 5*K)
%     puncvec         - Puncture vector (optional). Same as encoder side
%     decision_type   - 'hard' or 'unquant' (optional, default 'hard')
%
%   Output:
%     info_bits_est   - Decoded info bits (column vector)

    if nargin < 7 || isempty(decision_type)
        decision_type = 'hard';
    end

    if nargin < 6
        puncvec = [];
    end

    L = length(rx_encoded_bits);
    mat_size = Nrow * Ncol;

    %% 1. Zero-pad to full matrix size
    if L < mat_size
        rx_padded = [rx_encoded_bits(:); zeros(mat_size - L, 1)];
    else
        rx_padded = rx_encoded_bits(:);
    end

    %% 2. Block deinterleaving: write by column, read by row
    mat = reshape(rx_padded(1:mat_size), Nrow, Ncol)';
    deinterleaved = mat(:);

    %% 3. Viterbi decode (hard or unquant mode, optional puncturing)
    if nargin < 5 || isempty(tblen)
        K = log2(trellis.numStates) + 1;
        tblen = 5 * K;
    end

    if ~isempty(puncvec)
        info_bits_est = vitdec(deinterleaved, trellis, tblen, 'trunc', decision_type, puncvec);
    else
        info_bits_est = vitdec(deinterleaved, trellis, tblen, 'trunc', decision_type);
    end
end
