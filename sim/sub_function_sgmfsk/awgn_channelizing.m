function [out_sig] = awgn_channelizing(in_sig,ENo_dB,Rb,fs,fs_rx,noise_en)
    % SIN signal, means no channel noise added
    % NO_dB = ENo_dB - 10*log10(Rb/(fs_rx/10));
    % NO_power = (10^(NO_dB/10))/2;
    % ADC_noise = sqrt(NO_power/2) * randn(size(real(in_sig)));
    % % quantization noise ratio: 6.02*N+1.76+10*log10((fs / fs_rx)/BW +5%)
    % % 10*log10(BW/(fs/2)): ADC process Gain

    % for complex signal: SNR_dB = ENo_dB + 10*log10(Rb/fs), Rb = BW
    % for real signal:    SNR_dB = ENo_dB + 10*log10(2*Rb/fs)

    % Anyway, we are using SNR_dB = ENo_dB +10*log10(10),
    % for complex signal: SNR_dB = symbol_energy +10*log10(B/fs) + 10*log10(10),
    % k = fs_rx/BW, means bits per symbol or Rb*samp
    % for real signal:    SNR_dB = ENo_dB + 10*log10(2*Rb/fs) + 10*log10(k)
    % BW = (1+a)*Rb, BW:signal bandwidth, a: roll-off factor, for pure GFSK is BT value
    % % BW = (1+0.0)*Rb;
    % % R_over_samp = fs_rx/Rb/16/2; % symbol-bit number
    % % SNR_dB = ENo_dB +10*log10(BW/fs) +10*log10(R_over_samp) -10*log10(2);
    % % %noise_power = var(in_sig)/10^(SNR_dB/10);
    % % %noise_amp = sqrt(noise_power/2);


    % calculate power of input signal then Eb: bit energy
    P_sig = (in_sig'*in_sig)/length(in_sig);
    Eb_dB = 10*log10(1/Rb*P_sig);
    % calculate power density in dB according to given ENo_dB
    No_dB = Eb_dB - ENo_dB;
    %No_power_dB = 10*log10(10^(No_dB/10)*(fs)); % noise power
    No_power_dB = No_dB+10*log10(fs/2)+3; % extra 3dB to eliminate TX complex iq, if TX real cos(*), no need this 3dB


    if noise_en
        out_sig = in_sig + wgn(length(in_sig),1,No_power_dB,'complex');
        %out_sig = ampgt(in_sig,SNR_dB,'measured');
    else
        out_sig = in_sig;
    end
    % calc ENo below
    % P_sig = (in_sig'*in_sig)/length(in_sig);
    % ENo_dB = 10*log10(1/(P*Rb*P_sig));
    % noise = out_sig - in_sig;
    % [psd,f] = pwelch(noise,[],[],1,fs);
    % psd_noise = mean(psd);
    % No_dB = 10*log10(psd_noise);
    % ENo_cal = Eb_dB - No_dB;

    % %hbi = fir1(34,0.2,'high');
    % %Nois_sig = filter(hbi,1,out_sig);
end