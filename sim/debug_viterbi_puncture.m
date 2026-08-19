% Debug script: noiseless punctured Viterbi comparison
% Run this in MATLAB to isolate puncture-specific issues.

trellis = poly2trellis(3, [7 5]);
N = 60;  % 60*2 = 120, divisible by 6
tblen = 15;
puncvec = [1 1 1 0 0 1];  % 3/4 rate

tx = randi([0 1], N, 1);
enc = convenc(tx, trellis);
enc_punc = puncture_bits(enc, puncvec);

fprintf('=== Noiseless punctured hard-decision test ===\n');
fprintf('tx        : %s\n', sprintf('%d', tx'));
fprintf('enc       : %s\n', sprintf('%d', enc'));
fprintf('enc_punc  : %s\n', sprintf('%d', enc_punc'));

dec_builtin = vitdec(enc_punc, trellis, tblen, 'trunc', 'hard', puncvec);
dec_custom  = my_vitdec(enc_punc, trellis, tblen, 'trunc', 'hard', puncvec);

fprintf('built     : %s\n', sprintf('%d', dec_builtin'));
fprintf('custo     : %s\n', sprintf('%d', dec_custom'));
fprintf('match     : %d\n', isequal(dec_builtin, dec_custom));
fprintf('BER built : %.4f\n', mean(tx ~= dec_builtin));
fprintf('BER custo : %.4f\n', mean(tx ~= dec_custom));

if ~isequal(dec_builtin, dec_custom)
    first_d = find(dec_builtin ~= dec_custom, 1);
    fprintf('FIRST DIFF at index %d\n', first_d);
    fprintf('builtin: %s\n', sprintf('%d', dec_builtin(max(1,first_d-5):min(length(dec_builtin),first_d+5))'));
    fprintf('custom : %s\n', sprintf('%d', dec_custom(max(1,first_d-5):min(length(dec_custom),first_d+5))'));
end
