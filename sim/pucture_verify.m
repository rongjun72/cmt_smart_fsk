%% 4/5 打孔性能对比测试（修正版）
clear; clc; close all;

EbN0 = 0:2:12;
numSymBlock = 1e5;

% 4/5 打孔向量
puncvec_4_5 = puncture_config("6/10");
%puncvec_4_5 = [1 1 0 1 0 1 0 1];

codes = {
    struct('poly', [7 5],       'name', '(7,5), K=3',    'K', 3);
    struct('poly', [15 13],     'name', '(15,13), K=4',  'K', 4);
    struct('poly', [23 35],     'name', '(23,35), K=5',  'K', 5);
    struct('poly', [171 133],   'name', '(171,133), K=7', 'K', 7);
};

figure('Position', [100 100 800 500]);
colors = lines(length(codes));
hold on;

for c = 1:length(codes)
    % 修正：直接用 struct 里定义的 K，或通过二进制位数计算
    K = codes{c}.K;
    trellis = poly2trellis(K, codes{c}.poly);
    
    ber = zeros(size(EbN0));
    for i = 1:length(EbN0)
        % 生成随机比特
        numSymbols = numSymBlock*length(puncvec_4_5);
        data = randi([0 1], 1, numSymbols);
        
        % 卷积编码 + 打孔
        encoded = my_convenc(data(:), trellis);
        encoded = puncture_bits(encoded, puncvec_4_5);
        
        % BPSK 调制（简化，避免 QPSK 复数处理）
        tx = 1 - 2*encoded;  % 0->+1, 1->-1
        
        % AWGN
        % Eb/N0 = SNR - 10*log10(码率) - 10*log10(每符号比特数)
        % BPSK: 每符号1比特; 码率 = 4/5
        snr_linear = 10^((EbN0(i) + 10*log10(4/5))/10);
        noiseVar = 1 / (2*snr_linear);
        noise = sqrt(noiseVar) * randn(size(tx));
        rx = tx + noise;
        
        % BPSK 硬判决
        rxBits = rx < 0;
        
        % Viterbi 译码
        tbdepth = 5*K;  % 截断深度 = 5*K 是经验值
        decoded = my_vitdec(rxBits, trellis, tbdepth, 'trunc', 'hard', puncvec_4_5);
        
        % 计算 BER（去掉尾比特）
        len = min(length(data), length(decoded));
        ber(i) = sum(data(1:len) ~= decoded(1:len)) / len;
        
        fprintf('  %s @ EbN0=%2d dB: BER = %.4f\n', codes{c}.name, EbN0(i), ber(i));
    end
    
    semilogy(EbN0, ber + eps, 'o-', 'Color', colors(c,:), ...
        'LineWidth', 1.5, 'DisplayName', codes{c}.name, 'MarkerSize', 6);
end

xlabel('E_b/N_0 (dB)'); 
ylabel('BER');
title('不同母码在 4/5 打孔下的 BER 性能对比');
legend('Location', 'southwest');
grid on;
ylim([1e-5 1]);
xlim([0 12]);

fprintf('\n=== 测试完成 ===\n');


function [puncvec] = puncture_config(PUNCTURE)
    % PUNCTURE: 'n/m' means for m-bit code puncture (m-n)bits 
    % for convolation code (7,5),(15,13),(23,35),(171,133).
    % Puncture pattern selection (mother code rate 1/2)
    % | targetcode rate | puncvec                   | puncture  |
    % | :---    | :-------------------------------- |:--------- |
    % | 2/3     | [1 1 1 0]                         | keep 3/4  |
    % | 3/4     | [1 1 0 1 0 1]                     | keep 4/6  |
    % | 4/5     | [1 1 0 1 0 1 0 1]                 | keep 5/8  |
    % | 5/6     | [1 1 0 1 0 1 0 1 0 1]             | keep 6/10 |
    % | 6/7     | [1 1 0 1 0 1 0 1 0 1 0 1]         | keep 7/12 |
    % | 7/8     | [1 1 0 1 0 1 0 1 0 1 0 1 0 1]     | keep 8/14 |
    % | 8/9     | [1 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1] | keep 9/16 |
    switch PUNCTURE
        case '2/2'
            puncvec = [];                                % puncture disabled
        case '3/4'
            puncvec = [1 1 1 0];                         % 2/3 code rate (period 4, keep 3/4)
        case '4/6'
            puncvec = [1 1 0 1 0 1];                     % 3/4 code rate (period 6, keep 4/6)
        case '5/8'
            puncvec = [1 1 0 1 0 1 0 1];                 % 4/5 code rate (period 6, keep 5/8)
        case '6/10'
            puncvec = [1 1 0 1 0 1 0 1 0 1];             % 5/6 code rate (period 8, keep 6/10)
        case '7/12'
            puncvec = [1 1 0 1 0 1 0 1 0 1 0 1];         % 6/7 code rate (period 10, keep 7/12)
        case '8/14'
            puncvec = [1 1 0 1 0 1 0 1 0 1 0 1 0 1];     % 7/8 code rate (period 14, keep 8/14)
        case '9/16'
            puncvec = [1 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1]; % 8/9 code rate (period 16, keep 9/16)
        otherwise
            error('Unsupported puncture type: %s', PUNCTURE);
    end
end
