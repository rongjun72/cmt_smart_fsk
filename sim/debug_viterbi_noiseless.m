% Debug script: noiseless Viterbi comparison between my_vitdec and built-in vitdec
% Run this in MATLAB to check if my_vitdec matches vitdec in the simplest case.

trellis = poly2trellis(3, [7 5]);
N = 20;
tblen = 15;  % must be <= N

tx = randi([0 1], N, 1);
enc = convenc(tx, trellis);

fprintf('=== Noiseless hard-decision test ===\n');
fprintf('tx   : %s\n', sprintf('%d', tx'));
fprintf('enc  : %s\n', sprintf('%d', enc'));

dec_builtin = vitdec(enc, trellis, tblen, 'trunc', 'hard');
dec_custom  = my_vitdec(enc, trellis, tblen, 'trunc', 'hard');

fprintf('built: %s\n', sprintf('%d', dec_builtin'));
fprintf('custo: %s\n', sprintf('%d', dec_custom'));
fprintf('match (trunc hard): %d\n', isequal(dec_builtin, dec_custom));
fprintf('BER builtin: %.4f\n', mean(tx ~= dec_builtin));
fprintf('BER custom : %.4f\n', mean(tx ~= dec_custom));
