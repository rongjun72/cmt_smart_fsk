% debug_vitdec_soft.m
% Test vitdec('soft') as workaround for 'unquant' bug

clc; clear;

K = 3;
gen_poly = [7 5];
trellis = poly2trellis(K, gen_poly);
tblen = 5*K;

N = 1000;
info_bits = randi([0 1], N, 1);
encoded = convenc(info_bits, trellis);

% Perfect +/-1 soft input
soft_perfect = 2*double(encoded) - 1;

% Test 1: 'soft' mode with 3-bit quantization
nsdec = 3;
soft_quant3 = round((soft_perfect + 1) * (2^nsdec - 1) / 2);
soft_quant3 = max(0, min(2^nsdec - 1, soft_quant3));
decoded_soft3 = vitdec(soft_quant3, trellis, tblen, 'trunc', 'soft', nsdec);
ber_soft3 = sum(decoded_soft3 ~= info_bits) / N;
fprintf('Test 1 - soft mode (3-bit) BER: %.4f\n', ber_soft3);

% Test 2: 'soft' mode with 4-bit quantization
nsdec = 4;
soft_quant4 = round((soft_perfect + 1) * (2^nsdec - 1) / 2);
soft_quant4 = max(0, min(2^nsdec - 1, soft_quant4));
decoded_soft4 = vitdec(soft_quant4, trellis, tblen, 'trunc', 'soft', nsdec);
ber_soft4 = sum(decoded_soft4 ~= info_bits) / N;
fprintf('Test 2 - soft mode (4-bit) BER: %.4f\n', ber_soft4);

% Test 3: 'soft' mode with 8-bit quantization
nsdec = 8;
soft_quant8 = round((soft_perfect + 1) * (2^nsdec - 1) / 2);
soft_quant8 = max(0, min(2^nsdec - 1, soft_quant8));
decoded_soft8 = vitdec(soft_quant8, trellis, tblen, 'trunc', 'soft', nsdec);
ber_soft8 = sum(decoded_soft8 ~= info_bits) / N;
fprintf('Test 3 - soft mode (8-bit) BER: %.4f\n', ber_soft8);

% Test 4: hard mode (baseline)
decoded_hard = vitdec(encoded, trellis, tblen, 'trunc', 'hard');
ber_hard = sum(decoded_hard ~= info_bits) / N;
fprintf('Test 4 - hard mode BER: %.4f\n', ber_hard);

% Test 5: 'unquant' mode (confirm bug)
decoded_unquant = vitdec(soft_perfect, trellis, tblen, 'trunc', 'unquant');
ber_unquant = sum(decoded_unquant ~= info_bits) / N;
fprintf('Test 5 - unquant mode BER: %.4f\n', ber_unquant);
