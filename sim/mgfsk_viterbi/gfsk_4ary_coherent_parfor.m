function gfsk_4ary_coherent_parfor()
% gfsk_4ary_coherent_parfor.m
% 4-ary GFSK coherent demodulation simulation — parallel (parfor) version
% Identical architecture to gfsk_4ary_coherent_final.m, but EbN0 sweep uses parfor
% for multi-core acceleration. Requires Parallel Computing Toolbox.
%
% Core architecture:
%   1. Tx: continuous-phase GFSK, gaussdesign(BT,span,sps) Gaussian pulse shaping
%   2. Channel: AWGN + 80dB out-of-band rejection channel filter
%   3. Rx: 4-branch tone-mixer coherent detection + Chebyshev window LPF + maximum magnitude decision
%   4. Comparison: per-symbol hard decision vs theoretical M-ary orthogonal FSK BER

%% ========================================================================
% 0. Configurable parameters
%% ========================================================================
Rs      = 1e3;          % Symbol rate (Hz)
Fs      = 16e3;         % Sampling rate (Hz)
nsps    = Fs/Rs;        % Samples per symbol = 16
M       = 4;            % 4-ary
k       = log2(M);      % 2 bits/symbol
h       = 1.0;          % Modulation index: adjacent tone spacing = h*Rs = 1000 Hz
BT      = 0.5;          % Gaussian filter BT
span    = 4;            % Gaussian filter span（Symbol count）
Nsym    = 10000;        % Total symbol count (excluding preamble/postamble)

EbN0_dB = 12*log10(1:1.9:20)/log10(20);  % Nonlinear EbN0 distribution: 0~12dB, dense at low SNR region
Nsim    = 1;            % Simulations per point (Monte Carlo, 1 run already smooth enough)

%% ========================================================================
% 1. Filter design and delay calculation
%% ========================================================================
% 1.1 Gaussian frequency pulse (transmitter)
gauss_filt = gaussdesign(BT, span, nsps);
delay_gauss = grpdelay(gauss_filt,1,1)+0;

% 1.2 Channel filter: 80dB out-of-band rejection, lowpass FIR
% Optimization: Fp slightly larger than 4GFSK effective spectrum (±1750 Hz), reduce noise passage
Fp = 2.0e3;   Fs_stop = 2.8e3;
ch_filter = designfilt('lowpassfir', ...
    'PassbandFrequency', Fp, 'StopbandFrequency', Fs_stop, ...
    'PassbandRipple', 1, 'StopbandAttenuation', 80, ...
    'SampleRate', Fs);
delay_ch = grpdelay(ch_filter.Coefficients,1,1)+0;
ch_coeffs = ch_filter.Coefficients;

% 1.3 Tone mixer lowpass filter: Chebyshev window, 36-tap, fc=0.75*tone spacing
tone_spacing = h * Rs;
Fc_tone = 0.75 * tone_spacing;
tone_coeffs = fir1(36, Fc_tone/(Fs/2), 'low', chebwin(37, 80));
delay_tone = grpdelay(tone_coeffs,1,1)+0;

% Total delay = tx Gaussian + channel + rx tone LPF
total_delay = round(delay_gauss + delay_ch + delay_tone);
N_pre  = ceil(total_delay/nsps) + 5;
N_post = ceil(total_delay/nsps) + 5;
Nsym_total = Nsym + N_pre + N_post;
Ns_total   = Nsym_total * nsps;

% Sampling instant: symbol midpoint + total delay compensation
sample_idx = (N_pre + (0:Nsym-1)) * nsps + nsps/2 + total_delay;
if sample_idx(1) < 1 || sample_idx(end) > Ns_total
    error('Sampling index out of bounds');
end

fprintf('=== 4-ary GFSK Coherent (parfor) ===\n');
fprintf('Parameters: Rs=%d, Fs=%d, nsps=%d, h=%.2f, BT=%.2f, span=%d\n', ...
    Rs, Fs, nsps, h, BT, span);

%% ========================================================================
% 2. Gray encoding/decoding mapping
%% ========================================================================
gray_enc = [0; 1; 3; 2];
gry2nat = zeros(4,1);
for i = 0:3, gry2nat(gray_enc(i+1)+1) = i; end

freq_no = [-3; -1; 1; 3];
tone_freq = freq_no * h * Rs / 2;

%% ========================================================================
% 3. Helper function: generate GFSK signal (inline for parfor)
%% ========================================================================
    function s = generate_gfsk(sym_seq)
        Nsym_in = length(sym_seq);
        Ns_in = Nsym_in * nsps;
        sym_gray_in = gray_enc(sym_seq + 1);
        f_seq = freq_no(sym_gray_in + 1);
        f_up = repelem(f_seq, nsps);
        f_smooth = filter(gauss_filt, 1, f_up);
        dphi = 2*pi * f_smooth * h * Rs / 2 / Fs;
        phase = cumsum(dphi);
        s = exp(1j * phase);
        if length(s) < Ns_in
            s = [s; zeros(Ns_in - length(s), 1)];
        else
            s = s(1:Ns_in);
        end
    end

%% ========================================================================
% 4. Main simulation: Eb/N0 sweep with parfor
%% ========================================================================
EbN0_lin = 10.^(EbN0_dB/10);
BER_sim = zeros(size(EbN0_dB));
SER_sim = zeros(size(EbN0_dB));

pool = gcp('nocreate');
if isempty(pool)
    parpool('local');
end

tic;
parfor idx = 1:length(EbN0_dB)
    ebno = EbN0_lin(idx);
    N0 = 8 / ebno;
    noise_var = N0;
    
    bit_err_local = 0;
    sym_err_local = 0;
    
    for sim = 1:Nsim
        rng(idx*100 + sim, 'twister');
        sym_tx = randi([0, M-1], Nsym_total, 1);
        
        % Inline generate_gfsk (parfor compatible)
        Nsym_in = length(sym_tx);
        Ns_in = Nsym_in * nsps;
        sym_gray_in = gray_enc(sym_tx + 1);
        f_seq = freq_no(sym_gray_in + 1);
        f_up = repelem(f_seq, nsps);
        f_smooth = filter(gauss_filt, 1, f_up);
        dphi = 2*pi * f_smooth * h * Rs / 2 / Fs;
        phase = cumsum(dphi);
        s = exp(1j * phase);
        if length(s) < Ns_in
            s = [s; zeros(Ns_in - length(s), 1)];
        else
            s = s(1:Ns_in);
        end
        
        noise = sqrt(noise_var/2) * (randn(Ns_total, 1) + 1j*randn(Ns_total, 1));
        r = s + noise;
        r_ch = filter(ch_coeffs, 1, r);
        
        % Inline detect_coherent (parfor compatible)
        Ns_r = length(r_ch);
        t = (0:Ns_r-1)' / Fs;
        branch_metric = zeros(M, Nsym);
        for m = 1:M
            y_mix = r_ch .* exp(-1j * 2*pi * tone_freq(m) * t);
            y_lpf = filter(tone_coeffs, 1, y_mix);
            y_sample = y_lpf(sample_idx);
            branch_metric(m, :) = abs(y_sample).';
        end
        [~, det_gray] = max(branch_metric, [], 1);
        det_gray = det_gray(:) - 1;
        det_sym = gry2nat(det_gray + 1);
        
        sym_tx_valid = sym_tx(N_pre+1 : N_pre+Nsym);
        sym_err_local = sym_err_local + sum(det_sym ~= sym_tx_valid);
        
        for i = 1:Nsym
            bit_err_local = bit_err_local + ...
                (bitget(sym_tx_valid(i), 2) ~= bitget(det_sym(i), 2)) + ...
                (bitget(sym_tx_valid(i), 1) ~= bitget(det_sym(i), 1));
        end
    end
    
    BER_sim(idx) = bit_err_local / (Nsym * k * Nsim);
    SER_sim(idx) = sym_err_local / (Nsym * Nsim);
end
fprintf('Total parfor time: %.2f s\n', toc);

%% ========================================================================
% 5. Theoretical BER
%% ========================================================================
BER_theory = zeros(size(EbN0_dB));
for idx = 1:length(EbN0_dB)
    ebno = EbN0_lin(idx);
    sqrt_term = sqrt(2 * ebno * log2(M));
    y_min = -5*sqrt_term - 10;
    y_max = 10;
    if y_min < -50, y_min = -50; end
    Ny = 2000;
    y = linspace(y_min, y_max, Ny);
    phi_y = (1/sqrt(2*pi)) * exp(-y.^2/2);
    Q_term = qfunc(y + sqrt_term);
    integrand = phi_y .* (1 - Q_term).^(M-1);
    P_s = 1 - trapz(y, integrand);
    BER_theory(idx) = P_s / log2(M);
end
BER_bound = (M-1)/log2(M) * qfunc(sqrt(EbN0_lin * log2(M)));

%% ========================================================================
% 6. Visualization
%% ========================================================================
figure('Name', 'BER/SER Performance (parfor)', 'Position', [100 100 800 600]);
semilogy(EbN0_dB, BER_sim, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 8, 'DisplayName', 'Simulated BER');
hold on;
semilogy(EbN0_dB, SER_sim, 'rs--', 'LineWidth', 1.5, 'MarkerSize', 8, 'DisplayName', 'Simulated SER');
semilogy(EbN0_dB, BER_theory, 'g-', 'LineWidth', 1, 'DisplayName', 'Theory BER');
semilogy(EbN0_dB, BER_bound, 'm:', 'LineWidth', 1.5, 'DisplayName', 'Union Bound');
grid on;
xlabel('E_b/N_0 (dB)');
ylabel('Bit Error Rate / Symbol Error Rate');
legend('Location', 'southwest');
title(sprintf('4-ary GFSK Coherent Detection (parfor, h=%.1f, BT=%.1f)', h, BT));
axis([min(EbN0_dB) max(EbN0_dB) 1e-4 1]);

%% ========================================================================
% 7. Results summary
%% ========================================================================
fprintf('\n========== RESULT SUMMARY ==========\n');
fprintf('Eb/N0(dB) |  Sim BER  |  Sim SER  | Theory BER | Union Bound\n');
fprintf('----------|-----------|-----------|------------|------------\n');
for idx = 1:length(EbN0_dB)
    fprintf('%7.1f   | %.4e | %.4e |  %.4e  | %.4e\n', ...
        EbN0_dB(idx), BER_sim(idx), SER_sim(idx), BER_theory(idx), BER_bound(idx));
end
fprintf('\nSimulation complete.\n');

end
