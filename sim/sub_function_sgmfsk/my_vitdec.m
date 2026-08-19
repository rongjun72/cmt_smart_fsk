function decoded = my_vitdec(rx_bits, trellis, tblen, mode, decision_type, varargin)
%MY_VITDEC Viterbi decoder (pure MATLAB, replaces Communications Toolbox vitdec)
%   Supports truncation mode, hard/soft decision, and puncturing.
%
%   Usage:
%     decoded = my_vitdec(rx_bits, trellis, tblen, 'trunc', 'hard')
%     decoded = my_vitdec(rx_bits, trellis, tblen, 'trunc', 'soft', nsdec)
%     decoded = my_vitdec(rx_bits, trellis, tblen, 'trunc', 'hard', puncvec)
%     decoded = my_vitdec(rx_bits, trellis, tblen, 'trunc', 'soft', nsdec, puncvec)
%
%   Inputs:
%     rx_bits       - Received encoded bits (0/1 for hard, 0..2^nsdec-1 for soft)
%     trellis       - Trellis structure from poly2trellis
%     tblen         - Traceback length (symbols, i.e. input symbol periods)
%     mode          - 'trunc' or 'term'
%     decision_type - 'hard' or 'soft'
%     varargin{1}   - nsdec (for soft) or puncvec (for hard with puncture)
%     varargin{2}   - puncvec (optional)
%
%   Output:
%     decoded       - Decoded info bits (column vector)

    %% Parse arguments
    if nargin < 5
        error('my_vitdec: requires at least 5 arguments');
    end

    puncvec = [];
    nsdec = 8;

    if strcmp(decision_type, 'soft')
        if ~isempty(varargin)
            nsdec = varargin{1};
        end
        if length(varargin) >= 2
            puncvec = varargin{2};
        end
    else
        if ~isempty(varargin)
            puncvec = varargin{1};
        end
    end

    if ~(strcmp(mode, 'trunc') || strcmp(mode, 'term'))
        error('my_vitdec: only ''trunc'' and ''term'' modes are supported');
    end

    numStates = size(trellis.nextStates, 1);
    numInputs = size(trellis.nextStates, 2);
    numOutputs = max(trellis.outputs(:)) + 1;
    nOutputBits = round(log2(numOutputs));

    rx_bits = rx_bits(:);

    %% Depuncturing and mask generation
    puncture_mask = [];
    if ~isempty(puncvec)
        rx_bits = my_depuncture(rx_bits, puncvec, decision_type, nsdec);
        p = length(puncvec);
        nPeriods = length(rx_bits) / p;
        puncture_mask = repmat(puncvec(:), nPeriods, 1);
    end

    nRxSymbols = length(rx_bits) / nOutputBits;
    if mod(length(rx_bits), nOutputBits) ~= 0
        error('my_vitdec: rx_bits length (%d) must be a multiple of nOutputBits (%d)', length(rx_bits), nOutputBits);
    end

    rx_sym = reshape(rx_bits, nOutputBits, nRxSymbols);
    if ~isempty(puncture_mask)
        mask_sym = reshape(puncture_mask, nOutputBits, nRxSymbols);
    else
        mask_sym = [];
    end

    %% Pre-compute output bit patterns
    output_bits = zeros(nOutputBits, numStates, numInputs);
    for s = 1:numStates
        for u = 1:numInputs
            sym = trellis.outputs(s, u);
            for b = 1:nOutputBits
                output_bits(b, s, u) = bitget(sym, nOutputBits - b + 1);
            end
        end
    end

    %% Viterbi forward pass (maximization metric)
    NEG_INF = -1e9;
    pathMetric = zeros(numStates, nRxSymbols + 1);
    pathMetric(:, 1) = NEG_INF;
    pathMetric(1, 1) = 0;
    survivor = zeros(numStates, nRxSymbols);

    for t = 1:nRxSymbols
        rx_vec = rx_sym(:, t);
        if ~isempty(mask_sym)
            mask_t = mask_sym(:, t);
        else
            mask_t = ones(nOutputBits, 1);
        end

        for next_s = 1:numStates
            best_pm = NEG_INF;
            best_prev = 0;

            for prev_s = 1:numStates
                for u = 1:numInputs
                    if trellis.nextStates(prev_s, u) == next_s - 1
                        expected = output_bits(:, prev_s, u);

                        if strcmp(decision_type, 'soft')
                            expected_soft = expected * (2^nsdec - 1);
                            diff = abs(rx_vec - expected_soft);
                            bm = sum(((2^nsdec - 1) - diff) .* mask_t);
                        else
                            match = (rx_vec == expected);
                            bm = sum(match .* mask_t);
                        end

                        pm = pathMetric(prev_s, t) + bm;
                        if pm > best_pm
                            best_pm = pm;
                            best_prev = prev_s - 1;
                        end
                    end
                end
            end

            pathMetric(next_s, t + 1) = best_pm;
            survivor(next_s, t) = best_prev;
        end
    end

    %% Traceback
    decoded = zeros(nRxSymbols, 1);

    if strcmp(mode, 'term')
        state = 0;
    else
        [~, bestState] = max(pathMetric(:, end));
        state = bestState - 1;
    end

    for t = nRxSymbols:-1:1
        prev_state = survivor(state + 1, t);
        for u = 1:numInputs
            if trellis.nextStates(prev_state + 1, u) == state
                decoded(t) = u - 1;
                break;
            end
        end
        state = prev_state;
    end
end

%% ------------------------------------------------------------------------
function rx_depunc = my_depuncture(rx_bits, puncvec, decision_type, nsdec)
    p = length(puncvec);
    nKeep = sum(puncvec);
    nPeriods = floor(length(rx_bits) / nKeep);
    remainder = length(rx_bits) - nPeriods * nKeep;

    if strcmp(decision_type, 'soft')
        erasure_val = 2^(nsdec - 1);
    else
        erasure_val = 0;
    end

    rx_depunc = [];
    idx = 1;

    for per = 1:nPeriods
        period_out = zeros(p, 1);
        for b = 1:p
            if puncvec(b) == 1
                period_out(b) = rx_bits(idx);
                idx = idx + 1;
            else
                period_out(b) = erasure_val;
            end
        end
        rx_depunc = [rx_depunc; period_out];
    end

    if remainder > 0
        period_out = zeros(p, 1);
        for b = 1:p
            if puncvec(b) == 1
                if idx <= length(rx_bits)
                    period_out(b) = rx_bits(idx);
                    idx = idx + 1;
                else
                    period_out(b) = erasure_val;
                end
            else
                period_out(b) = erasure_val;
            end
        end
        rx_depunc = [rx_depunc; period_out];
    end
end
