function decoded = my_vitdec(rx_bits, trellis, tblen, mode, decision_type, varargin)
%MY_VITDEC Viterbi decoder (vectorized pure MATLAB, replaces Communications Toolbox vitdec)
%   Optimized version: replaces nested state loops with matrix operations.
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

    % Check if last varargin element is Build_in flag (0 or 1)
    Build_in = 0;
    if ~isempty(varargin)
        last_arg = varargin{end};
        if isnumeric(last_arg) && isscalar(last_arg) && ismember(last_arg, [0, 1])
            Build_in = last_arg;
            varargin = varargin(1:end-1);
        end
    end

    if Build_in
        decoded = vitdec(rx_bits, trellis, tblen, mode, decision_type, varargin{:});
        return;
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

    %% ----------------------------------------------------------------
    % Pre-compute output bit patterns (nOutputBits x numStates x numInputs)
    % ----------------------------------------------------------------
    output_bits = zeros(nOutputBits, numStates, numInputs);
    for s = 1:numStates
        for u = 1:numInputs
            sym = trellis.outputs(s, u);
            for b = 1:nOutputBits
                output_bits(b, s, u) = bitget(sym, nOutputBits - b + 1);
            end
        end
    end

    %% ----------------------------------------------------------------
    % Pre-compute transition tables for vectorized forward pass
    % ----------------------------------------------------------------
    % For a rate-1/n binary code, total transitions = numStates * numInputs
    nTrans = numStates * numInputs;
    trans_from = zeros(nTrans, 1, 'uint16');
    trans_to   = zeros(nTrans, 1, 'uint16');
    idx = 1;
    for s = 1:numStates
        for u = 1:numInputs
            trans_from(idx) = s - 1;                 % 0-indexed state
            trans_to(idx)   = trellis.nextStates(s, u); % 0-indexed next state
            idx = idx + 1;
        end
    end

    % incoming{next_s}: linear indices of transitions that end at next_s (0-indexed)
    incoming = cell(numStates, 1);
    for next_s = 0:numStates-1
        incoming{next_s+1} = find(trans_to == next_s);
    end

    % input_lut(prev_s+1, next_s+1) = input bit that causes this transition
    input_lut = zeros(numStates, numStates, 'int8') - 1;
    for s = 1:numStates
        for u = 1:numInputs
            next_s = trellis.nextStates(s, u);
            input_lut(s, next_s + 1) = u - 1;
        end
    end

    %% ----------------------------------------------------------------
    % Viterbi forward pass (vectorized branch metrics)
    % ----------------------------------------------------------------
    NEG_INF = -1e9;
    pathMetric = zeros(numStates, nRxSymbols + 1);
    pathMetric(:, 1) = NEG_INF;
    pathMetric(1, 1) = 0;
    survivor = zeros(numStates, nRxSymbols, 'uint16');

    % Pre-scale output bits for soft mode (done once, outside time loop)
    if strcmp(decision_type, 'soft')
        output_bits_soft = output_bits * (2^nsdec - 1);
        soft_scale = (2^nsdec - 1);
    end

    for t = 1:nRxSymbols
        rx_vec = rx_sym(:, t);
        if ~isempty(mask_sym)
            mask_t = mask_sym(:, t);
        else
            mask_t = ones(nOutputBits, 1);
        end

        % --- Vectorized branch metrics for ALL transitions (numStates x numInputs) ---
        % MATLAB implicit expansion: rx_vec(nOutputBits x 1) expands to match
        % output_bits(nOutputBits x numStates x numInputs)
        if strcmp(decision_type, 'soft')
            diff_all = abs(rx_vec - output_bits_soft);
            bm_all = reshape(sum((soft_scale - diff_all) .* mask_t, 1), numStates, numInputs);
        else
            match_all = (rx_vec == output_bits);
            bm_all = reshape(sum(match_all .* mask_t, 1), numStates, numInputs);
        end

        % --- Update path metrics: iterate over next_states only ---
        % For each next_state, pick the best among its incoming transitions
        pm_candidates = pathMetric(:, t) + bm_all;   % numStates x numInputs
        pm_flat = pm_candidates(:);                  % nTrans x 1 (column-major)

        for next_s = 1:numStates
            inc = incoming{next_s};
            [best_pm, best_idx] = max(pm_flat(inc));
            pathMetric(next_s, t+1) = best_pm;
            survivor(next_s, t) = trans_from(inc(best_idx));
        end
    end

    %% ----------------------------------------------------------------
    % Traceback (using pre-computed input lookup table)
    % ----------------------------------------------------------------
    decoded = zeros(nRxSymbols, 1);

    if strcmp(mode, 'term')
        state = 0;
    else
        [~, bestState] = max(pathMetric(:, end));
        state = bestState - 1;
    end

    for t = nRxSymbols:-1:1
        prev_state = survivor(state + 1, t);
        decoded(t) = input_lut(prev_state + 1, state + 1);
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

    % Pre-allocate output (avoid dynamic array growth)
    total_out = nPeriods * p;
    if remainder > 0
        total_out = total_out + p;
    end
    rx_depunc = zeros(total_out, 1);
    idx_in = 1;
    idx_out = 1;

    for per = 1:nPeriods
        for b = 1:p
            if puncvec(b) == 1
                rx_depunc(idx_out) = rx_bits(idx_in);
                idx_in = idx_in + 1;
            else
                rx_depunc(idx_out) = erasure_val;
            end
            idx_out = idx_out + 1;
        end
    end

    if remainder > 0
        for b = 1:p
            if puncvec(b) == 1
                if idx_in <= length(rx_bits)
                    rx_depunc(idx_out) = rx_bits(idx_in);
                    idx_in = idx_in + 1;
                else
                    rx_depunc(idx_out) = erasure_val;
                end
            else
                rx_depunc(idx_out) = erasure_val;
            end
            idx_out = idx_out + 1;
        end
    end
end
