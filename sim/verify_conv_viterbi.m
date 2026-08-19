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

        %% 1. Verify my_convenc against convenc (length and content)
        tx = randi([0 1], N, 1);
        enc_builtin = convenc(tx, trellis);
        enc_custom  = my_convenc(tx, trellis);

        match_enc = isequal(enc_builtin, enc_custom);
        fprintf('  convenc match: %s (len: built-in=%d, custom=%d)\n', ...
            string(match_enc), length(enc_builtin), length(enc_custom));
        if ~match_enc
            minlen = min(length(enc_builtin), length(enc_custom));
            first_diff = find(enc_builtin(1:minlen) ~= enc_custom(1:minlen), 1);
            fprintf('  FIRST DIFF at index %d\n', first_diff);
            fprintf('  built-in: %s\n', sprintf('%d', enc_builtin(1:20)'));
            fprintf('  custom:   %s\n', sprintf('%d', enc_custom(1:20)'));
        end

        %% 2. Verify my_vitdec (hard) against vitdec (hard) - trunc mode
        % BPSK modulation + AWGN
        tx_mod = 2*enc_builtin - 1;
        rx = awgn(tx_mod, 5, 'measured');
        rx_bits = (rx > 0)';

        dec_builtin_hard = vitdec(rx_bits, trellis, tblen, 'trunc', 'hard');
        dec_custom_hard  = my_vitdec(rx_bits, trellis, tblen, 'trunc', 'hard');

        match_hard = isequal(dec_builtin_hard(:), dec_custom_hard(:));
        ber_builtin = mean(tx(:) ~= dec_builtin_hard(:));
        ber_custom  = mean(tx(:) ~= dec_custom_hard(:));
        fprintf('  vitdec hard (trunc) match: %s (BER: built-in=%.4f, custom=%.4f)\n', ...
            string(match_hard), ber_builtin, ber_custom);
        if ~match_hard
            first_d = find(dec_builtin_hard(:) ~= dec_custom_hard(:), 1);
            fprintf('  FIRST DIFF at index %d\n', first_d);
        end

        %% 3. Verify my_vitdec (soft) against vitdec (soft) - trunc mode
        nsdec = 8;
        % Convert hard bits to soft metrics for fair comparison
        rx_soft = (rx_bits == 0) * 0 + (rx_bits == 1) * (2^nsdec - 1);

        dec_builtin_soft = vitdec(rx_soft, trellis, tblen, 'trunc', 'soft', nsdec);
        dec_custom_soft  = my_vitdec(rx_soft, trellis, tblen, 'trunc', 'soft', nsdec);

        match_soft = isequal(dec_builtin_soft(:), dec_custom_soft(:));
        ber_builtin_s = mean(tx(:) ~= dec_builtin_soft(:));
        ber_custom_s  = mean(tx(:) ~= dec_custom_soft(:));
        fprintf('  vitdec soft (trunc) match: %s (BER: built-in=%.4f, custom=%.4f)\n', ...
            string(match_soft), ber_builtin_s, ber_custom_s);
        if ~match_soft
            first_d = find(dec_builtin_soft(:) ~= dec_custom_soft(:), 1);
            fprintf('  FIRST DIFF at index %d\n', first_d);
        end

        %% 4. Verify punctured path - hard decision
        % Ensure encoded length is integer multiple of puncture period (6)
        Npunc = 996;  % 996*2 = 1992, divisible by 6
        tx_punc = randi([0 1], Npunc, 1);
        puncvec = [1 1 1 0 0 1];  % 3/4 rate
        enc_builtin_punc = convenc(tx_punc, trellis);
        enc_builtin_punc = puncture_bits(enc_builtin_punc, puncvec);
        enc_custom_punc  = my_convenc(tx_punc, trellis);
        enc_custom_punc  = puncture_bits(enc_custom_punc, puncvec);

        % BPSK
        tx_mod_p = 1 - 2*enc_builtin_punc;
        rx_p = awgn(tx_mod_p, 5, 'measured');
        rx_bits_p = rx_p < 0;

        dec_builtin_punc = vitdec(rx_bits_p, trellis, tblen, 'trunc', 'hard', puncvec);
        dec_custom_punc  = my_vitdec(rx_bits_p, trellis, tblen, 'trunc', 'hard', puncvec);

        match_punc = isequal(dec_builtin_punc(:), dec_custom_punc(:));
        ber_builtin_p = mean(tx_punc(:) ~= dec_builtin_punc(:));
        ber_custom_p  = mean(tx_punc(:) ~= dec_custom_punc(:));
        fprintf('  vitdec punctured match: %s (BER: built-in=%.4f, custom=%.4f)\n', ...
            string(match_punc), ber_builtin_p, ber_custom_p);
        if ~match_punc
            first_d = find(dec_builtin_punc(:) ~= dec_custom_punc(:), 1);
            fprintf('  FIRST DIFF at index %d\n', first_d);
        end

        %% 5. Verify terminated mode (term)
        tx_term = [tx; zeros(code.K-1, 1)];  % Append tail bits for term mode
        enc_builtin_term = convenc(tx_term, trellis);
        enc_custom_term  = my_convenc(tx_term, trellis);

        tx_mod_term = 1 - 2*enc_builtin_term;
        rx_term = awgn(tx_mod_term, 5, 'measured');
        rx_bits_term = rx_term < 0;

        dec_builtin_term = vitdec(rx_bits_term, trellis, tblen, 'term', 'hard');
        dec_custom_term  = my_vitdec(rx_bits_term, trellis, tblen, 'term', 'hard');

        match_term = isequal(dec_builtin_term(:), dec_custom_term(:));
        ber_builtin_t = mean(tx_term(:) ~= dec_builtin_term(:));
        ber_custom_t  = mean(tx_term(:) ~= dec_custom_term(:));
        ber_custom_t  = mean(tx(:) ~= dec_custom_term(:));
        fprintf('  vitdec term match: %s (BER: built-in=%.4f, custom=%.4f)\n', ...
            string(match_term), ber_builtin_t, ber_custom_t);
        if ~match_term
            first_d = find(dec_builtin_term(:) ~= dec_custom_term(:), 1);
            fprintf('  FIRST DIFF at index %d\n', first_d);
        end

        fprintf('\n');
    end

    fprintf('=== Verification complete ===\n');
end
