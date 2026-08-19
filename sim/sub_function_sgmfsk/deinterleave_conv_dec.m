function [info_bits_est] = deinterleave_conv_dec(rx_encoded_bits, trellis, Nrow, Ncol, tblen, puncvec, decision_type, nsdec, Build_in)
%DEINTERLEAVE_CONV_DEC Deinterleaving + (optional depuncturing) + Viterbi decoding
%   Block-deinterleave the received encoded bit sequence, then Viterbi decode.
%
%   Input:
%     rx_encoded_bits - Received encoded bit sequence (0/1 for hard, real values for soft/unquant)
%     trellis         - Convolutional code trellis structure
%     Nrow, Ncol      - Interleaver row/column count
%     tblen           - Viterbi traceback length (optional, default 5*K)
%     puncvec         - Puncture vector (optional). Same as encoder side
%     decision_type   - 'hard' | 'soft' | 'unquant' (optional, default 'hard')
%     nsdec           - Soft-decision quantization bits for 'soft' mode (optional, default 8)
%     Build_in        - Optional: 0 = use custom my_vitdec (default), 1 = use built-in vitdec
%
%   Output:
%     info_bits_est   - Decoded info bits (column vector)

    if nargin < 7 || isempty(decision_type)
        decision_type = 'hard';
    end
    if nargin < 8 || isempty(nsdec)
        nsdec = 8;
    end
    if nargin < 9 || isempty(Build_in)
        Build_in = 0;
    end
    if nargin < 6
        puncvec = [];
    end

    L = length(rx_encoded_bits);
    mat_size = Nrow * Ncol;

    %% 1. Zero-pad to full matrix size with appropriate value
    if strcmp(decision_type, 'soft')
        pad_val = 2^(nsdec-1);  % erasure (midpoint) for soft metrics
    else
        pad_val = 0;
    end
    if L < mat_size
        rx_padded = [rx_encoded_bits(:); pad_val * ones(mat_size - L, 1)];
    else
        rx_padded = rx_encoded_bits(:);
    end

    %% 2. Block deinterleaving: write by column, read by row
    mat = reshape(rx_padded(1:mat_size), Nrow, Ncol)';
    deinterleaved = mat(:);

    %% 3. Viterbi decode
    if nargin < 5 || isempty(tblen)
        K = log2(trellis.numStates) + 1;
        tblen = 5 * K;
    end

    if strcmp(decision_type, 'soft')
        deinterleaved_q = round((tanh(deinterleaved) + 1) * (2^nsdec - 1) / 2);
        deinterleaved_q = max(0, min(2^nsdec - 1, deinterleaved_q));
        if ~isempty(puncvec)
            info_bits_est = my_vitdec(deinterleaved_q, trellis, tblen, 'trunc', 'soft', nsdec, puncvec, Build_in);
        else
            info_bits_est = my_vitdec(deinterleaved_q, trellis, tblen, 'trunc', 'soft', nsdec, Build_in);
        end
    else
        if ~isempty(puncvec)
            info_bits_est = my_vitdec(deinterleaved, trellis, tblen, 'trunc', decision_type, puncvec, Build_in);
        else
            info_bits_est = my_vitdec(deinterleaved, trellis, tblen, 'trunc', decision_type, Build_in);
        end
    end
end
