trellis = poly2trellis(3, [7 5]);
tx = randi([0 1], 1000, 1);
tx_term = [tx; zeros(2, 1)];
enc = convenc(tx_term, trellis);
rx = awgn(1-2*enc, 5, 'measured') < 0;
dec_builtin = vitdec(rx, trellis, 15, 'term', 'hard');
dec_custom  = my_vitdec(rx, trellis, 15, 'term', 'hard');
fprintf('builtin size = %s, custom size = %s\n', mat2str(size(dec_builtin)), mat2str(size(dec_custom)));
fprintf('match = %d\n', isequal(dec_builtin, dec_custom));