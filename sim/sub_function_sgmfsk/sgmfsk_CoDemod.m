function [rx_bits,rx_bits_len,rx_bits_mse] = sgmfsk_CoDemod(time_rx,rx_iq,fs_rx,sps_rx,f_dev,freq_off,sync)
    global last_tx_phase Filt_Samp_1DET fskDemod_Demod_method last_IQ_Msk; 
    global b_lpf_BDly_b bpfbp bpfbn bpfbday b_zf_p b_zf_n b_lpf_p b_lpf_n ;
    %method = 'NCCH-REF';%'MIX-LPF';%'FS-BAND';%'MIX-LPF';%'FREQ-DET';%'NCCH-REF'
    Nsymb = length(rx_iq);
    rx_len_bits = log2(Msk)*rx_len_sps_rx;

    if(0)
        figure(1001); pwelch(rx_iq,rx_len/len,rx_len/len,rx_len/2,fs_rx,'centered','power');title('pwd-bef-fir');
        figure(1003); subplot(211);plot(real(rx_iq),'r');grid on;title('rx-I-signal');xlim([1 450]);
        subplot(212);plot(imag(rx_iq),'r');grid on;title('rx-Q-signal');xlim([1 450]);

        [freq_phase_rx] = pha_freq_cal(rx_iq,fs_rx);
        temp_syms = repmat(linspace(1,rx_len_sps_rx,sps_rx),1,Nsymb);
        figure(1004); subplot(211);plot(phase_rx,'r');grid on;title('rx-sig-phase');xlim([1 450]);
        hold on;plot(temp_syms(1:rx_len_sps_rx*Nsymb),'k');
        subplot(212);plot(frq,'b');grid on;title('rx-sig-phase-diff');xlim([1 450]);
    end

    switch Demod_method
        case "MIX-LPF"
            if sps_rx == 8
                ratio_dev = 1.1266;
            elseif sps_rx == 16
                ratio_dev = 1.0;%1.08;
            end

            % +/-F_dev mixer and LPF
            rx_iq_mat = repmat(rx_iq,Msk,1);
            %freq_err = (2*(Msk:1:1)-(Msk+1))*F_dev;
            %freq_err = [2000 500 -500 -2000];
            %freq_err = [1150 500 -500 -1150];
            %freq_err = [1350 450 -450 -1350];
            Ftone_arr = [];
            mix_result = rx_iq_mat.*exp(1j*2*pi*time_rx*Ftone_arr);
            lpf_abst(:,1) = abs(filt(FLT_LPF1,mix_result(:,1))); % ratio_dev\1.089;%1.1266; % r0
            lpf_abst(:,2) = abs(filt(FLT_LPF2,mix_result(:,2))); % ratio_dev\1.089;%1.1266; % r1
            lpf_abst(:,3) = abs(filt(FLT_LPF3,mix_result(:,3))); % r2
            lpf_abst(:,4) = abs(filt(FLT_LPF4,mix_result(:,4))); % ratio_dev\1.089;%1.1266; % r3

            % 时频响应绘图（多个绘图函数调用，此处简化保留结构）
            plot_time_freq_response(mix_result(:,1),fs_rx,30,'title','after +/-F_dev mixing','hold','on','double-side','on');
            plot_time_freq_response(mix_result(:,2),fs_rx,30,'title','after +/-F_dev mixing','hold','on','double-side','on');
            plot_time_freq_response(mix_result(:,3),fs_rx,30,'title','after +/-F_dev mixing','hold','on','double-side','on');
            plot_time_freq_response(mix_result(:,4),fs_rx,30,'title','after +/-F_dev mixing','hold','on','double-side','on');
            plot_time_freq_response(lpf_abst(:,1),fs_rx,40,'title','after LPF(positive/negative)','hold','on','double-side','on');
            plot_time_freq_response(lpf_abst(:,2),fs_rx,40,'title','after LPF(positive/negative)','hold','on','double-side','on');
            plot_time_freq_response(lpf_abst(:,3),fs_rx,40,'title','after LPF(positive/negative)','hold','on','double-side','on');
            plot_time_freq_response(lpf_abst(:,4),fs_rx,40,'title','after LPF(positive/negative)','hold','on','double-side','on');
            plot_time_freq_response(lpf_abst(:,1)-lpf_abst(:,2),fs_rx,50,'title','after LPF(positive-negative)','hold','on','double-side','on');

            figure(10); plot(time_rx,lpf_abst(:,1),'-o','time_rx,lpf_abst(:,2),'+',time_rx,lpf_abst(:,3),'+',time_rx,lpf_abst(:,4),'-x');
            legend('r0','r1','r2','r3');xlim([0 0.04]);ylim([-0.6 0.6]);
            figure(11); plot(1:rx_len_sps_rx*Nsymb,lpf_abst(:,1),'-o','1:rx_len_sps_rx*Nsymb,lpf_abst(:,2),'+',...
                '1:rx_len_sps_rx*Nsymb,lpf_abst(:,3),'+','1:rx_len_sps_rx*Nsymb,lpf_abst(:,4),'-x');
            grid on;legend('r0','r1','r2','r3');
            tM = 12000; ylim([-0.6 0.6]);
            [t1,~,tmp_pos] = max(lpf_abst(1:sps_rx:end,:),[],2);tmp_pos = tmp_pos+1;%find all peak positions corresponding to symbol position
            [t1,~,tmp_pos] = max(lpf_abst(sps_rx/2:sps_rx:end,:),[],2);tmp_pos = tmp_pos+1;
            samp_freq(1,:) = lpf_abst(sps_rx/2:sps_rx:end,1)+lpf_abst(sps_rx/2:sps_rx:end,1);%4
            samp_freq(2,:) = lpf_abst(sps_rx/2:sps_rx:end,2)+lpf_abst(sps_rx/2:sps_rx:end,2);%5
            samp_freq(3,:) = lpf_abst(sps_rx/2:sps_rx:end,3)+lpf_abst(sps_rx/2:sps_rx:end,3);%5
            samp_freq(4,:) = lpf_abst(sps_rx/2:sps_rx:end,4)+lpf_abst(sps_rx/2:sps_rx:end,4);%4
            [~,tmp_pos] = max(samp_freq,[],2);
            %%%peak_stat = peak_statistic(tmp_pos,lpf_abst); % for debug
            rx_bits = str2num(reshape(dec2bin(tmp_pos-1),[],1)');
            det_sym = viterbi_decode_isi(samp_freq');
            rx_bits_mse = str2num(reshape(dec2bin(det_sym),[],1)');
        case "FREQ-DET"
            diff_conj = rx_iq.*conj([last_iq;rx_iq(1:end-1)]);last_iq = rx_iq(end);
            tdiff_map = filt(FLT_LPF_pos1,diff_conj);
            phase_diff = filt(FLT_LPF_pos1,angle(diff_conj)); %% add LPF remove spurs!!!
            rx_sig_len = floor(length(phase_diff)/(sps_rx))-0;
            % phase(k) = 2*pi*Fdev*t*h, where: Ts = 1/fs, for GFSK h=1, Fdev=500Hz
            % phase_diff(k) = phase(k)-phase(k-1) = 2*pi*Fdev/Ts = ~0.7854(Unit in rad)
            % here we can calculate mean(phase_diff) and mean(abs(phase_diff))
            % and estimate frequency offset caused by RF carrier ppm
            % phase_diff_center = (mean(max(phase_diff))+mean(min(phase_diff)))/2
            % frequency_offset = phase_diff_center*fs_rx/(2*pi) (phase_diff unit is rad)
            % phase_diff_center = phase_diff_max_min(phase_diff,4000);
            % Th_judge,Freq_off = phase_diff_max_min(phase_diff,fs_rx)
            Th_judge = Fdev*freq_off/1000;
            diff_samp = reshape(phase_diff(1:rx_sig_len*sps_rx),[sps_rx rx_sig_len]);
            rx_bits = diff_samp(:,1)>Th_judge;
            rx_bits_len = length(rx_bits);
    
            %figure;plot(phase_diff);grid on;
            %figure;plot(1:rx_sig_len,len_sum,'b',1:rx_sig_len,3+2*(tx_bits(1:rx_sig_len)-0.5),'g');grid on;
    
        case "NCCH-REF"
            % +/-F_dev and F_dev mixer and LPF
            rx_bits = fskDemod(rx_iq);
            rx_bits_len = length(rx_bits);
    end
end

function [Ph_diff_center,Freq_off] = phase_diff_max_min(phase_diff,fs_rx)
    % for Freq_off=0, Fdev=500Hz
    % phase(k) = 2*pi*Fdev*k*Ts;
    % phase(k+1) - phase(k) = 2*pi*Fdev*Ts = 2*pi*500/4000 = 0.7854
    ph_mean = mean(phase_diff);
    ph_max_mean = mean(phase_diff(find(phase_diff>ph_mean+0.7854*3/4)));
    ph_min_mean = mean(phase_diff(find(phase_diff<ph_mean-0.7854*3/4)));
    Ph_diff_center(1) = (ph_max_mean+ph_min_mean)/2;
    Freq_off(1) = Ph_diff_center*fs_rx/(2*pi);
    % if frequency offset exit, sum(phase_diff)=2*pi*freq_off*length(phase_diff)/fs_rx
    % that is: freq_off=fs_rx*sum(phase_diff)/(2*pi*length(phase_diff))
    Ph_diff_center(2)=sum(phase_diff)/length(phase_diff);
    Freq_off(2)=Ph_diff_center(2)*fs_rx/(2*pi);
end

function [samp_set] = crossing_stats(sig_in,sps_rx)
    xrange = 1:length(sig_in);
    sign_vals = sign(sign(sig_in)-0.5);
    sig_diff = [0; diff(sign_vals)];
    zerox_pos = find(sig_diff~=0);
    zero_crossings = zeros(1,length(zerox_pos));
    for idx = 1:length(zerox_pos)
        x_step = xrange(zerox_pos(idx))-xrange(zerox_pos(idx)-1);
        y0 = sig_in(zerox_pos(idx)-1);
        y1 = sig_in(zerox_pos(idx));
        zero_crossings(idx) = xrange(zerox_pos(idx)-1) + x_step*y0/(y0-y1);
    end
    figure;
    histogram(mod(zero_crossings,sps_rx),'NumBins',100);grid on;xlim([0 sps_rx]);
    samp_set = 0;
end

function [Nsamp] = sync_search(m_diff,sps_rx)
    Nsamp = [];
    hit_pos = (length(m_diff)+1)*ones(round(sps_rx),50);
    hit_num = zeros(round(sps_rx),1);
    for idx = 1:round(sps_rx)
        samp_pos = round(sps_rx):sps_rx:length(m_diff);
        rx_bits = m_diff(samp_pos)<0;
        rx_bits_len = length(rx_bits);nidx = 1;
        for ii = 1:length(rx_bits)-12+1
            if isequal(rx_bits(ii:ii+12-1),[0,1,0,1,1,0,1,0,0,1,0,1])
                hit_pos(idx,nidx) = ii;nidx = nidx+1;
                hit_num(idx) = hit_num(idx)+1;
                Nsamp = [Nsamp,idx];
                continue;
            end
        end
    end

    [min_idx,col]=min(hit_pos,[],1);
    if min_idx > length(m_diff)
        Nsamp = 1 + round(sps_rx/2);
    else
        m_start = 1+round((min_idx-1)*sps_rx);
        m_diff_cap = m_diff(m_start:m_start+round(12*sps_rx)-1);
        Nsamp = mod(round(crossing_weight(m_diff_cap,sps_rx)+sps_rx/2),sps_rx);
        if Nsamp == 0
            Nsamp = sps_rx;
        end
    end
    nn=1;
end

function [samp_set] = crossing_weight(sig_in,sps_rx)
    xrange = 1:length(sig_in);
    sign_vals = sign(sign(sig_in)-0.5);
    sig_diff = [0; diff(sign_vals)];
    zerox_pos = find(sig_diff~=0);
    zero_crossings = zeros(1,length(zerox_pos));
    for idx = 1:length(zerox_pos)
        x_step = xrange(zerox_pos(idx))-xrange(zerox_pos(idx)-1);
        y0 = sig_in(zerox_pos(idx)-1);
        y1 = sig_in(zerox_pos(idx));
        zero_crossings(idx) = xrange(zerox_pos(idx)-1) + x_step*y0/(y0-y1);
    end
    figure;
    histogram(mod(zero_crossings,sps_rx),'NumBins',sps_rx*3);grid on;xlim([0 sps_rx]);
    samp_det = zeros(1,sps_rx); w_det = [ones(1,4),zeros(sps_rx*2-4,1)];
    for idx = 1:sps_rx
        samp_det(idx) = circshift(h_Values,(-idx+1)*2)*w_det;
    end
    [~,samp_set] = max(samp_det);
    %samp_set = round(mean(mod(zero_crossings,sps_rx)));
end

function [peak_stat] = peak_statistic(tmp_pos,lpf_abt)
    % Nsym = length(tmp_pos);
    Nsym = length(tmp_pos);
    [Ncol,Nrow] = size(lpf_abt);
    sps = Ncol/Nsym; Nintp = 4;
    lpf_int = zeros(Ncol*Nintp,Nrow);
    for ir = 1:Nrow
        lpf_int((1:Ncol-1)*Nintp+1,:) = spline(1:Ncol,lpf_abt(:,ir),1:Nintp:Ncol*Nintp);
    end
    peak_pos = zeros(size(tmp_pos));
    for idx = 1:Nsym
        tmp_segment = lpf_int((tmp_pos(idx)-1)*sps*Nintp+1:idx*sps*Nintp,tmp_pos(idx));
        [m_val,m_pos] = max(tmp_segment);
        peak_pos(idx) = (m_pos-1)/Nintp;
    end
    peak_stat = zeros(1,4);
    f0_peaks = peak_pos(find(tmp_pos==1));%find all peak positions corresponding to f0
    f1_peaks = peak_pos(find(tmp_pos==2));%find all peak positions corresponding to f0
    f2_peaks = peak_pos(find(tmp_pos==3));%find all peak positions corresponding to f0
    f3_peaks = peak_pos(find(tmp_pos==4));%find all peak positions corresponding to f0
    [N1] = histcounts(f0_peaks,10,5:8); peak_stat(1) = N1/sum(N1);
    [N2] = histcounts(f1_peaks,10,5:8); peak_stat(2) = N2/sum(N2);
    [N3] = histcounts(f2_peaks,10,5:8); peak_stat(3) = N3/sum(N3);
    [N4] = histcounts(f3_peaks,10,5:8); peak_stat(4) = N4/sum(N4);
end
