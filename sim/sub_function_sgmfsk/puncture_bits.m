function punctured = puncture_bits(bits, puncvec)
%PUNCTURE_BITS Periodic puncturing of encoded bit sequence
%   Input:
%     bits     - Encoded bit sequence (column vector)
%     puncvec  - Puncture vector, 1=keep, 0=delete, applied periodically
%   Output:
%     punctured - Punctured bit sequence
%
%   Example: puncvec = [1 1 0 1] means delete the 3rd bit every 4 bits

    if nargin < 2 || isempty(puncvec)
        punctured = bits(:);
        return;
    end
    
    p = length(puncvec);
    bits = bits(:);
    N = floor(length(bits) / p) * p;
    
    if N > 0
        bits_period = reshape(bits(1:N), p, []);
        mask = repmat(puncvec(:), 1, size(bits_period, 2));
        punctured = bits_period(mask == 1);
    else
        punctured = [];
    end
    
    % Handle remaining bits shorter than one period
    remainder = bits(N+1:end);
    if ~isempty(remainder)
        rem_mask = puncvec(1:length(remainder));
        punctured = [punctured; remainder(rem_mask == 1)];
    end
end