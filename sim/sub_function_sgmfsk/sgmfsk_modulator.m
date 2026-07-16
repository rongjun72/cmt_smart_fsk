function [bits,tx_sig,time_tx,fig_num] = sgmfsk_modulator(Nsym,seg_type,sps,fs,fs_tx,F_dev,fc,fig_num)
    % Parameters:
    % Nsym:      symbol number need to be generated
    % seg_type:  segment type, random data or synchronize frame. 'rand','syn'
    % sps:       samples per symbol
    % fs:        RX sample rate
    % fs_tx:     TX code sample rate
    % F_dev:     modulation frequency offset(Hz)
    % fc:        intermediate frequency
    % gauss_coef: Gaussian filter coefficients
    % generate random symbols/bits, fsk modulating(not quadrature modulation/IQ)
    % GFSK modulation/IQ)
    global DEBUG FLT N_32M_start last_tx_phase % zf_gaus
    tstart = tic;
    %------------------- GFSK TX side -------------------
    rng('shuffle');%random seeds
    %mg(0);
    % 高斯滤波器
    % t_gauss = -T:1/fs_tx:T;
    % sigma = sqrt((log(2))/(2*(pi*timeBWproduct));
    % g1 = exp(-t_gauss.^2/(2*(sigma^2*T^2)));
    % g2 = 1/(sqrt(2*pi)*sigma);
    % gauss_coef = g1*g2;
    % gauss_coef = gauss_coef / sum(gauss_coef);
    g.TBW = 0.5;
    g.span = 4;
    g.sps = sps;%$16;
    gauss_coef = gausspulsdesign(g.TBW,g.span,g.sps);
    % figure(fig_num);fig_num=fig_num+10;impz(gauss_coef);
    % figure(fig_num);fig_num=fig_num+10;freqz(gauss_coef);
    %
    if(DEBUG)
        Nfft = 1024;
        freq_norm = ((1:Nfft)-Nfft/2+1)/Nfft/2;
        gauss_fft = fftshift(fft(gauss_coef,Nfft));%/length(gauss_coef);
        gauss_spectrum = 20*log10(abs(gauss_fft));
        gauss_phase = angle(gauss_fft);
        figure(fig_num);fig_num=fig_num+10;subplot(3,1,1),plot(gauss_coef,'-ro'),grid on;
        title('Gauss filter coefficient');
        subplot(3,1,2),plot(freq_norm,gauss_spectrum,'r');grid on;
        xlim([0 1]);xlabel('normalized frequency');ylabel('magnitude (dB)');
        title('magnitude-frequency response');
        subplot(3,1,3),plot(freq_norm,gauss_phase(1:end),'r');grid on;
        xlim([0 1]);xlabel('normalized frequency');ylabel('Phase (rad)');
        title('phase-frequency response');
        % f=linspace(0,fs_tx,1000);
        % h_f = exp(-2*(pi*sigma*f).^2);
        % ,plot(f,mag2db(h_f));
    end
    %
    % 调制模块
    if strcmp(seg_type,"rand")
        bits = randi([0 1],Nsym*2,1);%$ bits(21:40)=[1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1];
        %tbits = replem(randi([0 1],1,4),Nsym,2);%tbits(21:40)=[1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1];
    elseif strcmp(seg_type,"syn")
        bits = code2bin([0;1;2;3],Nsym*2);
    elseif strcmp(seg_type,"ref")
        padding = zeros(20,1);
        bits = code2bin([padding;0;0;padding;0;1;padding;0;2;padding;0;3;...
                         padding;1;0;padding;1;1;padding;1;2;padding;1;3;...
                         padding;2;0;padding;2;1;padding;2;2;padding;2;3;...
                         padding;3;0;padding;3;1;padding;3;2;padding;3;3],Nsym*2);
    end
    %
    % 4FSK mapping: bit | quaternary | freq_dev
    %               00 | 0          | -3F_dev
    %               01 | 1          | -F_dev
    %               11 | 2          | +F_dev
    %               10 | 3          | 3F_dev
    %codes = reshape(bits,2,Nsym)';
    %cds_sh = [zeros(Nsym,1) codes(:,1)]; % code right shift
    %cds_xor = bitxor(cds_sh,cds_sh);     % grey coding
    %symbols = cds_xor*2+1-2:3;
    %$$symbols = reshape(bits,2,Nsym)'*[2;1]*2-3;
    %$$xx = 2.7632; yy = 1.0365; aa = xx+yy; bb = xx-yy;
    xx = 3.0; yy = 1.0; aa = xx+yy; bb = xx-yy;
    symbols = reshape(bits,2,Nsym)'*[aa;bb] - (aa+bb)/2;
    upsampled = repelem(symbols,sps,1);
    filtered = FLT.gaussWin(upsampled); % input MUST be N*1 array
    if(DEBUG)
        figure;
        time_16k = 1:Nsym*sps;((1:Nsym*sps)-1)/fs_tx;
        phi_tx = 2*pi*F_dev*cumsum(filtered)/fs_tx +0.39*pi;  % ∫s(t)dt $-1.3164 for xy:2.7632,1.0365
        tmp_sig = cos(phi_tx);
        subplot(4,1,1);plot(time_16k,upsampled);ylim([min(upsampled) max(upsampled)]);
        title('Modulating Symbols');xlim([1 320]);grid on;
        subplot(4,1,2);plot(time_16k,filtered);ylim([min(filtered)*1.1 max(filtered)*1.1]);
        title('Modulating Symbols (Gaussian filter)');xlim([1 320]);grid on;
        subplot(4,1,3);plot(time_16k,phi_tx/pi);ylim([min(phi_tx/pi)*1.1 max(phi_tx/pi)*1.1]);
        title('cumulated phase based on TX Gaussian modulating');xlim([1 320]);grid on;
        subplot(4,1,4);plot(time_16k,tmp_sig);ylim([min(tmp_sig)*1.1 max(tmp_sig)*1.1]);
        title('base-band modulated signal');xlim([1 320]);grid on;
        fig_num = fftTransform(tmp_sig,fs_tx,'spectrum-of-modulated-sig',fig_num,'b',false);
        steps = [64, 80, 96, 112, 128]; % phase step start point of f0,f1,f2,f3
        cum_steps = steps*grpdelay(FLT.gaussWin,1);
        cum_phi = phi_tx(cum_steps)'; disp(cum_phi);
        delta_phi = diff(cum_phi)/pi; disp(delta_phi);
    end
    %
    if(DEBUG)
        figure(fig_num);fig_num=fig_num+10;
        plot(filtered,'-ro','MarkerSize',2);title('tx-signal bf/af GaussianFilter');
        hold on;plot(upsampled,'-b*','MarkerSize',2);grid on;
        ylim([-2 2]); legend('bf-gaussian','af-gaussian');
        fig_num = fftTransform(upsampled,fs_tx,'spectrum bf Gaussian',fig_num,'r',true);
        fig_num = fftTransform(filtered,fs_tx,'spectrum af Gaussian',fig_num,'b',false);
        ylim([-90 inf]);
        legend('bf-gaussian','af-gaussian');
    end
    %
    filtered_up_samp = resample(filtered,fs/fs_tx,1);
    N_32M_stop = N_32M_start+length(filtered_up_samp)-1;
    time_tx = (N_32M_start:N_32M_stop)'/fs;
    N_32M_start = N_32M_start+length(filtered_up_samp);
    phase_integra = 2*pi*F_dev*cumsum(filtered_up_samp)/fs+last_tx_phase; % ∫s(t)dt
    last_tx_phase = phase_integra(end);
    if(DEBUG)
        tmp_sig =exp(1i*phase_integra);
        figure(fig_num);fig_num=fig_num+10;
        subplot(2,1,1);plot(time_tx,real(tmp_sig));grid on;title('Tx-signal-real');xlim([0 0.01]);
        subplot(2,1,2);plot(time_tx,imag(tmp_sig));grid on;title('Tx-signal-imag');xlim([0 0.01]);
        % pwelch(tmp_sig);
        fig_num = fftTransform(tmp_sig,fs,'power-of-Tx-base-signal',fig_num,'b',false);
    end
    %
    if(DEBUG)
        figure(fig_num);fig_num=fig_num+10;
        subplot(211),plot(time_tx,phase_integra,'r');title('Tx-signal-phase');
        hold on;plot(upsampled,'k');grid on;
        subplot(212),plot(diff(phase_integra),'b');grid on;title('pha-diff-aft-Tx-sig-gaud');
        frq_pha = diff(phase_integra);
        figure(fig_num),fig_num=fig_num+10;
        plot(diff(frq_pha),'r');grid on;title('frq-phase-diff');
    end
    phase_tx = 2*pi*fc*time_tx +phase_integra;
    % phase_tx = phase_integra;
    %%mod_signal = cos(phase_tx);%$$+0.39*pi);%$-1.3164);
    mod_signal = exp(1i*phase_tx);
    % upsample for tx-signal
    tx_sig = mod_signal;
    if(DEBUG)
        figure(fig_num),fig_num=fig_num+10;
        plot(real(tx_sig),'-ro');grid on;
        fig_num = fftTransform(tx_sig,fs,'power-of-Tx-Md-signal',fig_num,'b',false);
    end
    if(DEBUG)
        figure(fig_num),fig_num=fig_num+10;
        plot(real(tx_sig),'r');grid on;title('time_tx domain: TX signal');
        ylim(1.5*[min(tx_sig) max(tx_sig)]);
    end
    %
    if(0)
        mod_signal2 = exp(1i*phase_tx);
        phase_test = atan2(imag(mod_signal2),real(mod_signal2));
        phase_test2 = unwrap(phase_test);
        figure(fig_num),fig_num=fig_num+10;
        subplot(211),plot(phase_test,'-ro');grid on;title('Tx-signal-phase-of-with-fc');
        subplot(212),plot(phase_test2,'-ro');grid on;title('Tx-signal-phase-unwrap-of-with-fc');
    end
    %tdura = toc(tstart);
    %fprintf('gfsk_modulator(%d)... proc_time = %6.1f\n',Nsym,tdura);
end

function [bits_out] = code2bin(code,Nup)
    % input code should be Nx1 vector
    bits_out = zeros(Nup,1);
    bits = str2num(reshape(dec2bin(code)',[],1));
    Ntimes = fix(Nup/length(bits));
    bits_out(1:Ntimes*length(bits)) = repmat(bits,Ntimes,1);
end

function coef = gausspulsdesign(TBW,span,sps)
    % Design Gaussian filter coefficients
    t = -span*sps/2:span*sps/2;
    sigma = sqrt((log(2))/(2*(pi*TBW)^2));
    g1 = exp(-t.^2/(2*(sigma^2)));
    g2 = 1/(sqrt(2*pi)*sigma);
    coef = g1.*g2;
    coef = coef / sum(coef);
end