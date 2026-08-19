function encoded = my_convenc(info_bits, trellis, Build_in)
%MY_CONVENC Convolutional encoder (pure MATLAB, replaces Communications Toolbox convenc)
%   Encodes a binary sequence using the specified trellis structure.
%   Matches MATLAB convenc behavior: NO tail bits are appended automatically.
%   If termination is needed, append zeros to info_bits before calling.
%
%   Input:
%     info_bits - Column vector of info bits (0 or 1)
%     trellis   - Structure from poly2trellis with fields: nextStates, outputs
%     Build_in  - Optional: 0 = use custom implementation (default), 1 = use built-in convenc
%
%   Output:
%     encoded   - Column vector of encoded bits, length = length(info_bits) * n

    if nargin < 3 || isempty(Build_in)
        Build_in = 0;
    end

    if Build_in
        encoded = convenc(info_bits, trellis);
        return;
    end

    info_bits = info_bits(:);
    nInfoBits = length(info_bits);

    numStates = size(trellis.nextStates, 1);
    numInputs = size(trellis.nextStates, 2);      % should be 2 for binary
    numOutputs = max(trellis.outputs(:)) + 1;       % 2^n for n output bits
    nOutputBits = round(log2(numOutputs));

    % Pre-allocate encoded output (no tail bits, same as MATLAB convenc)
    encoded = zeros(nInfoBits * nOutputBits, 1);

    state = 0;  % MATLAB trellis uses 0-indexed states
    outIdx = 1;

    for t = 1:nInfoBits
        input_bit = info_bits(t);
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
