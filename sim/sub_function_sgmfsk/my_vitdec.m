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
    K = round(log2(numStates)) + 1;

    rx_bits = rx_bits(:);

    %% Depuncturing and mask generation
    puncture_mask = [];
    if ~isempty(puncvec)
        rx_bits = my_depuncture(rx_bits, puncvec, decision_type, nsdec);
        % Build mask: 1 = kept bit, 0 = punctured (erasure)
        p = length(puncvec);
        nPeriods = length(rx_bits) / p;
        puncture_mask = repmat(puncvec(:), nPeriods, 1);
    end

    % Length check: rx_bits should be a multiple of nOutputBits
    nRxSymbols = length(rx_bits) / nOutputBits;
    if mod(length(rx_bits), nOutputBits) ~= 0
        error('my_vitdec: rx_bits length (%d) must be a multiple of nOutputBits (%d)', length(rx_bits), nOutputBits);
    end

    % Reshape into symbols (each column is one received symbol vector)
    rx_sym = reshape(rx_bits, nOutputBits, nRxSymbols);
    if ~isempty(puncture_mask)
        mask_sym = reshape(puncture_mask, nOutputBits, nRxSymbols);
    else
        mask_sym = [];
    end

    %% Pre-compute output bit patterns for all (state, input) pairs
    % MATLAB poly2trellis docs: outputs(s,u) uses MSB = first output bit.
    % convenc serializes bits in generator-poly order (first poly first).
    % So output_bits(1,:) must be the first generator-poly output = MSB.
    output_bits = zeros(nOutputBits, numStates, numInputs);
    for s = 1:numStates
        for u = 1:numInputs
            sym = trellis.outputs(s, u);
            for b = 1:nOutputBits
                output_bits(b, s, u) = bitget(sym, nOutputBits - b + 1);
            end
        end
    end

    %% Viterbi forward pass
    % MATLAB vitdec uses correlation-like metrics (maximize).
    % For hard decision: branch metric = number of matching bits.
    % For soft decision: branch metric = sum of matching confidence.
    NEG_INF = -1e9;
    pathMetric = zeros(numStates, nRxSymbols + 1);
    pathMetric(:, 1) = NEG_INF;
    pathMetric(1, 1) = 0;  % Start from state 0

    % survivor(next_s, t) stores the BEST PREVIOUS STATE (0-indexed) that
    % leads to state next_s-1 at time t.
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
                            % Soft metric: correlation-like (maximize)
                            expected_soft = expected * (2^nsdec - 1);
                            diff = abs(rx_vec - expected_soft);
                            bm = sum(((2^nsdec - 1) - diff) .* mask_t);
                        else
                            % Hard metric: number of matching bits (maximize)
                            match = (rx_vec == expected);
                            bm = sum(match .* mask_t);
                        end

                        pm = pathMetric(prev_s, t) + bm;

                        if pm > best_pm
                            best_pm = pm;
                            best_prev = prev_s - 1;  % 0-indexed previous state
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
        % Terminated mode: encoder ended at state 0 (tail bits were appended)
        state = 0;
    else
        % Truncation mode: start traceback from best final state
        [~, bestState] = max(pathMetric(:, end));
        state = bestState - 1;  % 0-indexed
    end

    for t = nRxSymbols:-1:1
        prev_state = survivor(state + 1, t);

        % Derive input from (prev_state, state) transition
        for u = 1:numInputs
            if trellis.nextStates(prev_state + 1, u) == state
                decoded(t) = u - 1;
                break;
            end
        end

        state = prev_state;
    end

    %% Remove tail bits only for terminated mode
    % NOTE: MATLAB vitdec 'term' mode returns ALL decoded symbols (including
    % tail bits), so we do NOT truncate the output here.
    % The caller should discard tail bits if needed.
    % if strcmp(mode, 'term')
    %     nTailBits = K - 1;
    %     if length(decoded) > nTailBits
    %         decoded = decoded(1:end - nTailBits);
    %     end
    % end
    if strcmp(mode, 'term')
        nTailBits = K - 1;
        if length(decoded) > nTailBits
            decoded = decoded(1:end - nTailBits);
        end
    end
end

%% ------------------------------------------------------------------------
function rx_depunc = my_depuncture(rx_bits, puncvec, decision_type, nsdec)
%MY_DEPUNCTURE Insert erasures where bits were punctured out
%   Inverse of puncture_bits: given a punctured sequence, reconstruct the
%   original length by inserting placeholder values.
%
%   Inputs:
%     rx_bits       - Punctured received sequence
%     puncvec       - Puncture vector (1=keep, 0=punctured)
%     decision_type - 'hard' or 'soft'
%     nsdec         - Soft-decision quantization bits

    p = length(puncvec);
    nKeep = sum(puncvec);
    nPeriods = floor(length(rx_bits) / nKeep);
    remainder = length(rx_bits) - nPeriods * nKeep;

    % Determine erasure value
    if strcmp(decision_type, 'soft')
        erasure_val = 2^(nsdec - 1);  % Midpoint = no confidence
    else
        erasure_val = 0;  % For hard decision, default to 0
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

    % Handle remainder: only insert as many bits as actually received
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
