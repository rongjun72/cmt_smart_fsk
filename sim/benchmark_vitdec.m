%BENCHMARK_VITDEC  Benchmark and verify optimized my_vitdec vs MATLAB built-in vitdec
%   Tests correctness (noiseless) and BER consistency (noisy) across all
%   supported convolutional codes, plus measures speedup.

clc; clear; close all;

code_types = {'(7,5)', '(15,13)', '(23,35)', '(171,133)'};
K_list = [3, 4, 5, 7];
gen_list = {[7 5], [15 13], [23 35], [171 133]};
nCodes = length(code_types);

fprintf('=== Viterbi Decoder Optimization Benchmark ===\n\n');

%% ------------------------------------------------------------------------
% 1. Noiseless correctness test
%% ------------------------------------------------------------------------
fprintf('--- 1. Noiseless correctness test ---\n');
all_pass = true;
for idx = 1:nCodes
    K = K_list(idx);
    gen = gen_list{idx};
    trellis = poly2trellis(K, gen);
    tblen = 5*K;
    nInfo = 10000;
    tx = randi([0 1], nInfo, 1);
    enc = convenc(tx, trellis);

    % Hard decision
    dec_builtin_h = vitdec(enc, trellis, tblen, 'trunc', 'hard');
    dec_custom_h  = my_vitdec(enc, trellis, tblen, 'trunc', 'hard', 0);
    match_h = isequal(dec_builtin_h, dec_custom_h);

    % Soft decision (perfect soft metrics: 0 or 255)
    nsdec = 8;
    enc_soft = enc * (2^nsdec - 1);
    dec_builtin_s = vitdec(enc_soft, trellis, tblen, 'trunc', 'soft', nsdec);
    dec_custom_s  = my_vitdec(enc_soft, trellis, tblen, 'trunc', 'soft', nsdec, 0);
    match_s = isequal(dec_builtin_s, dec_custom_s);

    % Punctured hard
    puncvec = [1 1 1 0 0 1];  % 3/4 rate
    enc_p = puncture_bits(enc, puncvec);
    dec_builtin_p = vitdec(enc_p, trellis, tblen, 'trunc', 'hard', puncvec);
    dec_custom_p  = my_vitdec(enc_p, trellis, tblen, 'trunc', 'hard', puncvec, 0);
    match_p = isequal(dec_builtin_p, dec_custom_p);

    fprintf('  %s: hard=%d, soft=%d, punctured=%d\n', code_types{idx}, match_h, match_s, match_p);
    all_pass = all_pass && match_h && match_s && match_p;
end
if all_pass
    fprintf('  >>> ALL NOISELESS TESTS PASSED <<<\n\n');
else
    fprintf('  >>> SOME NOISELESS TESTS FAILED <<<\n\n');
end

%% ------------------------------------------------------------------------
% 2. Noisy BER consistency test
%% ------------------------------------------------------------------------
fprintf('--- 2. Noisy BER consistency test (EbNo = 6 dB) ---\n');
EbNo_dB = 6;
all_ber_match = true;
for idx = 1:nCodes
    K = K_list(idx);
    gen = gen_list{idx};
    trellis = poly2trellis(K, gen);
    tblen = 5*K;
    nInfo = 500000;
    tx = randi([0 1], nInfo, 1);
    enc = convenc(tx, trellis);

    % AWGN channel (BPSK-like soft metrics)
    nsdec = 8;
    max_soft = 2^nsdec - 1;
    snr_lin = 10^(EbNo_dB/10);
    bpsk = 2*enc - 1;
    noise = randn(length(bpsk), 1) / sqrt(2*snr_lin);
    rx_soft = round((bpsk + noise + 1) * max_soft / 2);
    rx_soft = max(0, min(max_soft, rx_soft));

    dec_builtin = vitdec(rx_soft, trellis, tblen, 'trunc', 'soft', nsdec);
    dec_custom  = my_vitdec(rx_soft, trellis, tblen, 'trunc', 'soft', nsdec, 0);

    ber_builtin = mean(tx(:) ~= dec_builtin(:));
    ber_custom  = mean(tx(:) ~= dec_custom(:));
    ber_diff = abs(ber_builtin - ber_custom);
    match = ber_diff < 1e-6;

    fprintf('  %s: built-in BER=%.4e, custom BER=%.4e, diff=%.2e, match=%d\n', ...
        code_types{idx}, ber_builtin, ber_custom, ber_diff, match);
    all_ber_match = all_ber_match && match;
end
if all_ber_match
    fprintf('  >>> ALL BER TESTS PASSED <<<\n\n');
else
    fprintf('  >>> SOME BER TESTS FAILED <<<\n\n');
end

%% ------------------------------------------------------------------------
% 3. Speed benchmark
%% ------------------------------------------------------------------------
fprintf('--- 3. Speed benchmark ---\n');
nInfo = 500000;  % Large enough for stable timing
nRuns = 3;

for idx = 1:nCodes
    K = K_list(idx);
    gen = gen_list{idx};
    trellis = poly2trellis(K, gen);
    tblen = 5*K;
    tx = randi([0 1], nInfo, 1);
    enc = convenc(tx, trellis);

    % Add some noise for soft-decision test
    nsdec = 8;
    max_soft = 2^nsdec - 1;
    snr_lin = 10^(6/10);
    bpsk = 2*enc - 1;
    noise = randn(length(bpsk), 1) / sqrt(2*snr_lin);
    rx_soft = round((bpsk + noise + 1) * max_soft / 2);
    rx_soft = max(0, min(max_soft, rx_soft));

    % Warm-up (first call may be slower due to JIT)
    my_vitdec(rx_soft, trellis, tblen, 'trunc', 'soft', nsdec, 0);

    % Time built-in vitdec
    t_builtin = inf;
    for r = 1:nRuns
        tic;
        vitdec(rx_soft, trellis, tblen, 'trunc', 'soft', nsdec);
        t = toc;
        if t < t_builtin, t_builtin = t; end
    end

    % Time custom vitdec
    t_custom = inf;
    for r = 1:nRuns
        tic;
        my_vitdec(rx_soft, trellis, tblen, 'trunc', 'soft', nsdec, 0);
        t = toc;
        if t < t_custom, t_custom = t; end
    end

    speedup = t_builtin / t_custom;
    fprintf('  %s (%2d states): built-in=%6.3fs, custom=%6.3fs, speedup=%5.2fx\n', ...
        code_types{idx}, 2^(K-1), t_builtin, t_custom, speedup);
end

fprintf('\n=== Benchmark complete ===\n');
