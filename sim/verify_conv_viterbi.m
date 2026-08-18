function verify_conv_viterbi()
%VERIFY_CONV_VITERBI Verify my_convenc/my_vitdec against MATLAB built-ins
%   Run this to check if the pure-MATLAB implementations match convenc/vitdec.

    clc;
    fprintf('=== Verifying my_convenc / my_vitdec ===\n\n');

    %% Test codes
    codes = {
        struct('name','(7,5)',  'K',3, 'gen',[7 5]);
        struct('name','(15,13)','K',4, 'gen',[15 13]);
        struct('name','(23,35)','K',5, 'gen',[23 35]);
        struct('name','(171,133)','K',7, 'gen',[171 133]);
    };

    for c = 1:length(codes)
        code = codes{c};
        trellis = poly2trellis(code.K, code.gen);
        tblen = 5*code.K;
        N = 1000;

        fprintf('--- %s ---\n', code.name);

        %% 1. Verify my_convenc against convenc
        tx = randi([0 1], N, 1);
        enc_builtin = convenc(tx, trellis);
        enc_custom  = my_convenc(tx, trellis);

        match_enc = isequal(enc_builtin, enc_custom);
        fprintf('  convenc match: %s (len: built-in=%d, custom=%d)\n', ...
            string(match_enc), length(enc_builtin), length(enc_custom));
        if ~match_enc
            fprintf('  FIRST DIFF at index %d\n', find(enc_builtin ~= enc_custom, 1));
            fprintf('  built-in: %s\n', sprintf('%d', enc_builtin(1:20)'));
            fprintf('  custom:   %s\n', sprintf('%d', enc_custom(1:20)'));
        end

        %% 2. Verify my_vitdec (hard) against vitdec (hard)
        % BPSK AWGN channel
        tx_mod = 1 - 2*enc_builtin;  % 0->+1, 1->-1
        snr = 5;  % moderate SNR
        rx = awgn(tx_mod, snr, 'measured');
        rx_bits = rx < 0;

        dec_builtin_hard = vitdec(rx_bits, trellis, tblen, 'trunc', 'hard');
        dec_custom_hard  = my_vitdec(rx_bits, trellis, tblen, 'trunc', 'hard');

        match_hard = isequal(dec_builtin_hard, dec_custom_hard);
        ber_builtin = mean(tx(1:end) ~= dec_builtin_hard(1:end)');
        ber_custom  = mean(tx(1:end) ~= dec_custom_hard(1:end)');
        fprintf('  vitdec hard match: %s (BER: built-in=%.4f, custom=%.4f)\n', ...
            string(match_hard), ber_builtin, ber_custom);
        if ~match_hard
            fprintf('  FIRST DIFF at index %d\n', find(dec_builtin_hard ~= dec_custom_hard, 1));
        end

        %% 3. Verify my_vitdec (soft) against vitdec (soft)
        nsdec = 8;
        % Convert hard bits to soft metrics for fair comparison
        rx_soft = (rx_bits == 0) * 0 + (rx_bits == 1) * (2^nsdec - 1);

        dec_builtin_soft = vitdec(rx_soft, trellis, tblen, 'trunc', 'soft', nsdec);
        dec_custom_soft  = my_vitdec(rx_soft, trellis, tblen, 'trunc', 'soft', nsdec);

        match_soft = isequal(dec_builtin_soft, dec_custom_soft);
        ber_builtin_s = mean(tx(1:end) ~= dec_builtin_soft(1:end)');
        ber_custom_s  = mean(tx(1:end) ~= dec_custom_soft(1:end)');
        fprintf('  vitdec soft match: %s (BER: built-in=%.4f, custom=%.4f)\n', ...
            string(match_soft), ber_builtin_s, ber_custom_s);
        if ~match_soft
            fprintf('  FIRST DIFF at index %d\n', find(dec_builtin_soft ~= dec_custom_soft, 1));
        end

        %% 4. Verify punctured path if applicable
        puncvec = [1 1 1 0 0 1];  % 3/4 rate
        enc_builtin_punc = convenc(tx, trellis);
        enc_builtin_punc = puncture_bits(enc_builtin_punc, puncvec);
        enc_custom_punc  = my_convenc(tx, trellis);
        enc_custom_punc  = puncture_bits(enc_custom_punc, puncvec);

        % AWGN
        tx_mod_p = 1 - 2*enc_builtin_punc;
        rx_p = awgn(tx_mod_p, snr, 'measured');
        rx_bits_p = rx_p < 0;

        dec_builtin_punc = vitdec(rx_bits_p, trellis, tblen, 'trunc', 'hard', puncvec);
        dec_custom_punc  = my_vitdec(rx_bits_p, trellis, tblen, 'trunc', 'hard', puncvec);

        match_punc = isequal(dec_builtin_punc, dec_custom_punc);
        ber_builtin_p = mean(tx(1:end) ~= dec_builtin_punc(1:end)');
        ber_custom_p  = mean(tx(1:end) ~= dec_custom_punc(1:end)');
        fprintf('  vitdec punctured match: %s (BER: built-in=%.4f, custom=%.4f)\n', ...
            string(match_punc), ber_builtin_p, ber_custom_p);
        if ~match_punc
            fprintf('  FIRST DIFF at index %d\n', find(dec_builtin_punc ~= dec_custom_punc, 1));
        end

        fprintf('\n');
    end

    fprintf('=== Verification complete ===\n');
end
