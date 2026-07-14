function [ref_metric] = ref_metric_gen(Nsym_segment,sps,fs,fs_tx,fs_rx,sps_rx,F_dev,Flo,filt_dly)
    global Mfsk FLT N_32M_start N_4K_start last_tx_phase;
    [N_32M_start, N_4K_start, last_tx_phase, freq_off] = deal(0);
    ref_metric = zeros(Mfsk,Mfsk,Mfsk);

    [~,rx_sig_rf,time_tx,~] = sgmfsk_modulator(Nsym_segment,'ref',sps,fs,fs_tx,F_dev,Flo,11);
    [rx_sig_bb,rx_bb_len]   = rx_ddc_mixer(rx_sig_rf,Flo,0,time_tx);
    [rx_sig,rx_len]         = sgmfsk_decimation(rx_sig_bb,fs,fs_tx,0);
    [rx_cmix_out,time_rx]   = rx_cmix(rx_sig,rx_len,0,fs_rx,0);
    rx_iq                   = FLT.chFilter(double(rx_cmix_out));
    %%%[rx_bits,rx_bits_len]  = sgmsk_Codemod(time_rx,rx_iq,fs_rx,sps_rx,F_dev,freq_off,'norm');
    if sps_rx == 8
        ratio_dev = 1.1266;
    elseif sps_rx == 16
        ratio_dev = 1.0;%1.08;
    end

    % +F_dev and -F_dev mixer and LPF
    rx_iq_mat = repelem(rx_iq,1,Mfsk);
    %%Ftone_arr = [1550 450 -450 -1650];
    Ftone_arr = [1500 500 -500 -1500];
    mix_result   = rx_iq_mat.*exp(1i*2*pi*time_rx*Ftone_arr);
    lpf_abs(:,1) = abs(FLT.LPF_f1(mix_result(:,1)))*ratio_dev;%%/1.0489;%%1.1266; % f0
    lpf_abs(:,2) = abs(FLT.LPF_f2(mix_result(:,2))); % f1
    lpf_abs(:,3) = abs(FLT.LPF_f3(mix_result(:,3))); % f2
    lpf_abs(:,4) = abs(FLT.LPF_f4(mix_result(:,4)))*ratio_dev;%%/1.0489;%%1.1266; % f3
    %plot_time_freq_response(lpf_abs(:,1),fs_rx,40,'title','after LPF(positive/negative)','hold','on','double-side','on');
    %plot_time_freq_response(lpf_abs(:,2),fs_rx,40,'title','after LPF(positive/negative)','hold','on','double-side','on');
    %plot_time_freq_response(lpf_abs(:,3),fs_rx,40,'title','after LPF(positive/negative)','hold','on','double-side','on');
    %plot_time_freq_response(lpf_abs(:,4),fs_rx,40,'title','after LPF(positive/negative)','hold','on','double-side','on');

    for prev_g = 0:(Mfsk-1)
        for curr_g = 0:(Mfsk-1)
            Nref_idx = (20+2)*sps_rx*(prev_g*Mfsk+curr_g+1) + filt_dly - sps_rx/2;
            ref_metric(prev_g+1,curr_g+1,1) = lpf_abs(Nref_idx,1)+lpf_abs(Nref_idx,1);%4;
            ref_metric(prev_g+1,curr_g+1,2) = lpf_abs(Nref_idx,2)+lpf_abs(Nref_idx+1,2);%5;
            ref_metric(prev_g+1,curr_g+1,3) = lpf_abs(Nref_idx,3)+lpf_abs(Nref_idx+1,3);%5;
            ref_metric(prev_g+1,curr_g+1,4) = lpf_abs(Nref_idx,4)+lpf_abs(Nref_idx,4);%4;
        end
    end

    % % Verify reference templates
    % fprintf('Reference templates computed.\n');
    % for prev_g = 0:3
    %     for curr_g = 0:3
    %         ref = squeeze(ref_metric(prev_g+1,curr_g+1,:));
    %         [~, peak] = max(ref);
    %         fprintf(' (prev=%d, curr=%d): peak branch=%d, norm=%.3f\n', ...
    %             prev_g, curr_g, peak-1, norm(ref));
    %     end
    % end
    % fprintf('\n');
end
