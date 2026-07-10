function [rssi, snr] = rssi_snr_estimation(iq_in, fs_rx)
    % IIR biquad filter
    global zf_rssi zf_snr1 zf_snr1;
    Ns = length(iq_in);
    
    amplitude = abs(iq_in);
    amp_avg = FLT.RSSIlpf(amplitude);
    amp_diff = FLT.SNRhpf(amplitude);
    amp_noise = FLT.SNRlpf(abs(amp_diff));
    amp_signal = amp_avg - amp_noise;
    rssi = 20*log10(amp_avg) +25;
    snr = 20*log10(amp_signal/amp_noise);
    
    figure;plot(1:Ns,amplitude,'r',1:Ns,amp_avg,'b');grid on;
    figure;plot(1:Ns,snr,'r',1:Ns,rssi,'b');grid on;ylim([0 inf]);legend('snr','rssi');
    
    h_fig = figure(100);
    for idx = 1:Ns-3
        plot(iq_in(idx:idx+3),'o');
        xlim([-1 1]);ylim([-1 1]);grid on;
        title(sprintf('%04d/%04d',idx,Ns));
        pause(0.04);
    end
end
