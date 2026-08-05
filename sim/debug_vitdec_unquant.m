% debug_vitdec_unquant.m
% Diagnostic script to test vitdec('unquant') with perfect soft inputs

clc; clear;

% Test 1: Simple (7,5) code with perfect +/-1 soft input
K = 3;
gen_poly = [7 5];
trellis = poly2trellis(K, gen_poly);
tblen = 5*K;

% Generate random info bits
N = 1000;
info_bits = randi([0 1], N, 1);

% Encode
encoded = convenc(info_bits, trellis);

% Perfect BPSK soft input: 0->-1, 1->+1
soft_perfect = 2*double(encoded) - 1;

% Decode with unquant
decoded_unquant = vitdec(soft_perfect, trellis, tblen, 'trunc', 'unquant');
ber_unquant = sum(decoded_unquant ~= info_bits) / N;
fprintf('Test 1 - Perfect +/-1 soft input BER: %.4f\n', ber_unquant);

% Decode with hard (for comparison)
decoded_hard = vitdec(encoded, trellis, tblen, 'trunc', 'hard');
ber_hard = sum(decoded_hard ~= info_bits) / N;
fprintf('Test 1 - Hard input BER: %.4f\n', ber_hard);

% Test 2: Same but with small amplitude soft input (like your rx_soft scale)
soft_small = soft_perfect * 1.4;  % scale to ~[-1.4, 1.4]
decoded_small = vitdec(soft_small, trellis, tblen, 'trunc', 'unquant');
ber_small = sum(decoded_small ~= info_bits) / N;
fprintf('Test 2 - Small amplitude (1.4x) soft input BER: %.4f\n', ber_small);

% Test 3: Check if vitdec 'unquant' has issues with 'trunc' mode
% Try 'cont' mode
decoded_cont = vitdec(soft_perfect, trellis, tblen, 'cont', 'unquant');
% cont mode has tblen delay at start
ber_cont = sum(decoded_cont(tblen+1:end) ~= info_bits(1:end-tblen)) / (N-tblen);
fprintf('Test 3 - Cont mode perfect soft input BER: %.4f\n', ber_cont);

% Test 4: Verify convenc/vitdec round-trip with unquant
% Use exact same sequence, no noise at all
encoded2 = convenc(info_bits, trellis);
soft_exact = 2*double(encoded2) - 1;
decoded_exact = vitdec(soft_exact, trellis, tblen, 'trunc', 'unquant');
ber_exact = sum(decoded_exact ~= info_bits) / N;
fprintf('Test 4 - Exact round-trip (enc->soft->dec) BER: %.4f\n', ber_exact);
