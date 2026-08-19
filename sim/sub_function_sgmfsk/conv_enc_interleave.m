function [encoded_interleaved, Nrow, Ncol, puncvec] = conv_enc_interleave(info_bits, trellis, Nrow, Ncol, puncvec, Build_in)
%CONV_ENC_INTERLEAVE Convolutional encoding + (optional puncturing) + block interleaving
%   Perform convolutional encoding on input info bits, optional puncturing, then block interleaving.
%
%   Input:
%     info_bits - Info bit sequence (column or row vector), length = N
%     trellis   - Convolutional code trellis structure
%     Nrow, Ncol - Interleaver row/column count (optional). Auto-selected if omitted
%     puncvec   - Puncture vector (optional). Punctures after encoding if provided
%     Build_in  - Optional: 0 = use custom my_convenc (default), 1 = use built-in convenc
%
%   Output:
%     encoded_interleaved - Encoded (punctured) and interleaved bit sequence
%     Nrow, Ncol - Actual interleaver dimensions used
%     puncvec    - Puncture vector (returned as-is for decoder use)

    if nargin < 5
        puncvec = [];
    end
    if nargin < 6 || isempty(Build_in)
        Build_in = 0;
    end

    %% 1. Convolutional encoding
    encoded = my_convenc(info_bits(:), trellis, Build_in);

    %% 2. Puncturing (optional)
    if ~isempty(puncvec)
        % Pad encoded bits to integer multiple of puncture period
        % so that punctured length is integer multiple of sum(puncvec)
        p = length(puncvec);
        rem_len = mod(length(encoded), p);
        if rem_len > 0
            encoded = [encoded; zeros(p - rem_len, 1)];
        end
        encoded = puncture_bits(encoded, puncvec);
    end
    L = length(encoded);

    %% 3. Determine interleaver dimensions
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

    %% 4. Zero-pad to full interleaver matrix size
    mat_size = Nrow * Ncol;
    pad_len = mat_size - L;
    if pad_len > 0
        encoded = [encoded; zeros(pad_len, 1)];
    end

    %% 5. Block interleaving: write by row, read by column
    mat = reshape(encoded, Ncol, Nrow)';
    encoded_interleaved = mat(:);
end
