function delay_n = sgmfsk_filter_series(BW,fs,BR,fs_rx,g_TBW,g_span,g_sps,F_dev)
    %%% CIC filter
    global FLT Demod_method Mfsk;
    %%Dec1 = 2; Dec2 = 2; Dec3 = 2; Dec4 = 125;
    Dec1 = 1; Dec2 = 1; Dec3 = 1; Dec4 = 1;
    fs_cic_out = fs/Dec1/Dec2/Dec3/Dec4; Dec5 = fs_cic_out/fs_rx;
    
    switch BW
        case 1e3
            FLT.DEC_stage1 = dsp.CICDecimator('DecimationFactor',Dec1,'NumSections',5,'DifferentialDelay',1); fs_in1 = fs;
            FLT.DEC_stage2 = dsp.CICDecimator('DecimationFactor',Dec2,'NumSections',5,'DifferentialDelay',1); fs_in2 = fs/Dec1;
            FLT.DEC_stage3 = dsp.CICDecimator('DecimationFactor',Dec3,'NumSections',5,'DifferentialDelay',1); fs_in3 = fs/Dec1/Dec2;
            FLT.DEC_stage4 = dsp.CICDecimator('DecimationFactor',Dec4,'NumSections',5,'DifferentialDelay',1); fs_in4 = fs/Dec1/Dec2/Dec3;
            % cicCompPilt = dsp.CICCompensationDecimator('DecimationFactor',500,...
            %    'PassbandFrequency',2000,'StopbandFrequency',4000,'SampleRate',fs_in4/500);
            % fvtool(FLT.DEC_stage1,FLT.DEC_stage2,FLT.DEC_stage3,FLT.DEC_stage4);
            % fvtool(cascade(FLT.DEC_stage1,FLT.DEC_stage2,FLT.DEC_stage3,FLT.DEC_stage4),'Fs',[fs fs/2 fs/4 fs/8]);
            
            filt_dec_dly(1) = (Dec1~=1)*grpdelay(FLT.DEC_stage1,1)/fs_in1;
            filt_dec_dly(2) = (Dec2~=1)*grpdelay(FLT.DEC_stage2,1)/fs_in2;
            filt_dec_dly(3) = (Dec3~=1)*grpdelay(FLT.DEC_stage3,1)/fs_in3;
            filt_dec_dly(4) = (Dec4~=1)*grpdelay(FLT.DEC_stage4,1)/fs_in4;
    end
    
    %%% HBF filter
    switch BW
        case 1e3
            FLT.DEC_stage5 = dsp.FIRDecimator(Dec5,firhalfband(18,0.25));
            fs_hbFilt = fs/(Dec1*Dec2*Dec3*Dec4);
            filt_dec_dly(5) = (Dec5~=1)*grpdelay(FLT.DEC_stage5,1)/fs_hbFilt;
            fs_chFilt = fs/(Dec1*Dec2*Dec3*Dec4*Dec5);
            fs_gauss_in = BW*16;
    end
    
    %%% channel filter design (FIR)
    N = 48; Astop = 80; % Order, Stopband Attenuation(dB)
    BW_fsk = (BW*1.0+(1+2*(Mfsk/2-1))*F_dev)-300+50*(-1);
    Wp = 2.0e3/(fs_chFilt/2);%0.8*BW_fsk/(fs_chFilt/2); % 0.8 0.34 normalized Passband Frequency [1/2, 1.0] for better BER @ lower SNR
    Ws = 2.8e3/(fs_chFilt/2);%%1.3*BW_fsk/(fs_chFilt/2); % 1.1 0.8 normalized Stopband Frequency [1/3, 0.8] for better BER @ lower SNR
    Hd_fir = fdesign.lowpass('n,fp,fst,ast', N, Wp, Ws, Astop);
    Hd_fir = design(Hd_fir, 'equiripple', 'FilterStructure', 'dfsymfir');
    FLT.chFilter = dsp.FIRFilter(Hd_fir.Numerator);
    fd = fvtool(FLT.chFilter,'Fs',fs_rx);  %%fvtool(FLT.chFilter,'Fs',fs_chFilt);
    fd.Name = 'chFilt'; ax = fd.CurrentAxes;
    title(ax,sprintf('channel filter, [Wp,Ws]:[%.1f %.1f]',Wp*(fs_chFilt/2),Ws*(fs_chFilt/2)));
    
    % [bb,~] = mix_lpf_build(N,1900,80,fs_rx);
    % FLT.chFilter = dsp.FIRFilter(bb);
    
    FLT.gaussWin = dsp.FIRFilter(gaussdesign(g_TBW,g_span,g_sps));
    
    switch BW
        case 1e3
            ch_filt_dly = (grpdelay(FLT.chFilter,1))/fs_chFilt;
            filt_gauss_dly = grpdelay(FLT.gaussWin,1)/fs_gauss_in;
            % cic,hbf,fir dly is on the RX path, gaussian filter is on the TX path
            filt_total_t = sum(filt_dec_dly)+mean(ch_filt_dly)+sum(filt_gauss_dly);
            delay_n = (filt_total_t/(1/fs_rx));
    end
    
    %%% FIR filters in CoDemod stage
    %%%NbpF = 36; NlpF = 20;%%14
    %%%NbpF = 28; NlpF = 20;
    %%%[bb,~,b_bpfp,~,b_bpfn,~] = bpf_pair_fir_design(NbpF,F_dev*1.60,F_dev,fs_rx);
    NlpF = 36; NbpF = 20;%%14
    [bb,aa] = mix_lpf_build(NlpF,F_dev*1.50,80,fs_rx);
    fd = fvtool(bb,aa,'Fs',fs_rx); 
    fd.Name = 'mixLPF'; ax = fd.CurrentAxes;title(ax,sprintf('mix-LPF, fc = %.1fHz',F_dev*1.80));
    b_lpf = fir1(NlpF,1.0*BR/log2(Mfsk)*2/fs_rx);
    
    %%%b_bpfp = fir1(NbpF,F_dev/(fs_rx/2));
    FLT.LPF_f1 = dsp.FIRFilter(bb);
    FLT.LPF_f2 = dsp.FIRFilter(bb);
    FLT.LPF_f3 = dsp.FIRFilter(bb);
    FLT.LPF_f4 = dsp.FIRFilter(bb);
    
    FLT.LPF_pos0 = dsp.FIRFilter(bb);
    FLT.LPF_neg0 = dsp.FIRFilter(bb);
    FLT.LPF_pos1 = dsp.FIRFilter(b_lpf);
    FLT.LPF_neg1 = dsp.FIRFilter(b_lpf);
    
    %%%EQ = comm.LinearEqualizer('Algorithm','LMS','NumTaps',5);
    % fvtool(b_lpf,1,'Fs',fs_rx);
    % title(sprintf('LPF for PLL fvco, fc=%.1fHz',1.0*BR/log2(Mfsk)));
    switch Demod_method
        case "MIX-LPF"
            delay_n = round(delay_n + grpdelay(FLT.LPF_f1,1));
        case "FREQ-DET"
            delay_n = round(delay_n + grpdelay(FLT.LPF_pos1,1));
        case "PLL-DMD"
            delay_n = round(delay_n + grpdelay(FLT.LPF_pos1,1));
        case "NCOH-REF"
            delay_n = round(delay_n);
    end
    
    %%% IIR biquad filter for SNR and RSSI
    wn = 35/(fs_rx/2);
    [z,p,k] = butter(4,wn,'low');
    [s,g] = zp2sos(z,p,k);
    FLT.RSSIip = dsp.BiquadFilter(s,g,'Structure','Direct form I');
    FLT.SNRlip = dsp.BiquadFilter(s,g,'Structure','Direct form I');
    b_hpf = [0.5,-0.5]; %high pass filter for SNR/CNR calculation
    FLT.SNRhpf = dsp.FIRFilter(b_hpf);
end

function [b, a] = mix_lpf_build(Nord,F_dev,Astop,fs)
    Wp = F_dev*1.0/(fs/2);
    Ws = F_dev*2.0/(fs/2);
    Wc = F_dev/(fs/2); % stop band edge frequecy
    %b = fir1(Nord,Wc); a=1; %default hamming
    %b = fir1(Nord,Wc, hann(Nord+1)); a=1;
    b = fir1(Nord,Wc, chebwin(Nord+1)); a=1;
    
    %%%Hd_fir = fdesign.lowpass('n,fp,fst,ast', Nlpf, Wp, Ws, Astop);
    %%%Hd_fir = design(Hd_fir, 'equiripple', 'FilterStructure', 'dfsymfir');
    %%%[b,a] = tf(Hd_fir);
    
    %%fvtool(b,a,'Fs',fs); title('mix-LPF design');
end