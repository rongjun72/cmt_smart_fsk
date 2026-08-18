% 独立验证三种卷积码在理想 BPSK 硬判决下的性能
EbNo_dB = 0:1:10;
K = [3 4 5];
gen = {[7 5], [15 13], [23 35]};
for i = 1:3
    trellis = poly2trellis(K(i), gen{i});
    tblen = 5*K(i);
    % 1/2 rate, info bits = 1e5
    tx = randi([0 1], 1, 1e7);
    tx_enc = my_convenc(tx(:), trellis);
    % BPSK modulation + AWGN
    tx_mod = 2*tx_enc - 1;
    for idx = 1:length(EbNo_dB)
        rx = awgn(tx_mod, EbNo_dB(idx) - 10*log10(0.5), 'measured');
        rx_bits = (rx > 0)';
        rx_dec = my_vitdec(rx_bits, trellis, tblen, 'trunc', 'hard');
        ber(i, idx) = mean(tx(1:end) ~= rx_dec(1:end)');
    end
end
figure;semilogy(EbNo_dB, ber'); legend('(7,5)', '(15,13)', '(23,35)');