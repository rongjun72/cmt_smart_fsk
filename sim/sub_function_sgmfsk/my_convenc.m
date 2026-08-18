function encoded = my_convenc(info_bits, trellis)
%MY_CONVENC Convolutional encoder (pure MATLAB, replaces Communications Toolbox convenc)
%   Encodes a binary sequence using the specified trellis structure.
%   Assumes truncation mode: appends K-1 tail bits to return encoder to state 0.
%
%   Input:
%     info_bits - Column vector of info bits (0 or 1)
%     trellis   - Structure from poly2trellis with fields:
%                 numStates, numInputs, numOutputs, nextStates, outputs
%
%   Output:
%     encoded   - Column vector of encoded bits

    info_bits = info_bits(:);
    nInfoBits = length(info_bits);

    numStates = size(trellis.nextStates, 1);
    numInputs = size(trellis.nextStates, 2);      % should be 2 for binary
    numOutputs = max(trellis.outputs(:)) + 1;       % 2^n for n output bits
    nOutputBits = round(log2(numOutputs));

    % Determine constraint length K from numStates
    K = round(log2(numStates)) + 1;
    nTailBits = K - 1;

    % Total input bits including tail bits (all zeros for truncation)
    totalInputBits = nInfoBits + nTailBits;
    all_bits = [info_bits; zeros(nTailBits, 1)];

    % Pre-allocate encoded output
    encoded = zeros(totalInputBits * nOutputBits, 1);

    state = 0;  % MATLAB trellis uses 0-indexed states
    outIdx = 1;

    for t = 1:totalInputBits
        input_bit = all_bits(t);
        % trellis.nextStates and trellis.outputs are 0-indexed
        % Add 1 for MATLAB indexing
        next_state = trellis.nextStates(state + 1, input_bit + 1);
        output_sym = trellis.outputs(state + 1, input_bit + 1);

        % Convert output symbol (decimal) to nOutputBits binary bits
        % MSB first (same as MATLAB convenc convention)
        for b = nOutputBits:-1:1
            encoded(outIdx) = bitget(output_sym, b);
            outIdx = outIdx + 1;
        end

        state = next_state;
    end
end
