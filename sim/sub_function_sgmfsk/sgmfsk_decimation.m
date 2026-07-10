function [rx_iq,rx_len] = sgmfsk_decimation(rx_baseband,fs,fs_tx,Direct_resample)
    global FLT MSk;
    global DEBUG ;
    %global zf_dec5 zf_int1 zf_dif1 zf_int2 zf_dif2 zf_int3 zf_dif3 zf_int4 zf_dif4 zf_int5 zf_dif5;
    fig_num = 12345;
    Dec1 = FLT.DEC_stage1.DecimationFactor; R1 = FLT.DEC_stage1.NumSections;
    Dec2 = FLT.DEC_stage2.DecimationFactor; R2 = FLT.DEC_stage2.NumSections;
    Dec3 = FLT.DEC_stage3.DecimationFactor; R3 = FLT.DEC_stage3.NumSections;
    Dec4 = FLT.DEC_stage4.DecimationFactor; R4 = FLT.DEC_stage4.NumSections;
    Dec5 = FLT.DEC_stage5.DecimationFactor; 
    fs_rx = fs/Dec1/Dec2/Dec3/Dec4/Dec5;

    if Direct_resample~=0
        rx_iq = resample(double(rx_baseband),1,fs/fs_rx);
        %debug: plot curves
        if(DEBUG)
            fig_num = fftTransform(rx_iq,fs/(Dec1*Dec2*Dec3*Dec4*Dec5),'power-of-Tx-base-signal',fig_num,'b',false);
        end
        return;
    end


    % decimation: 32Msps --2-->--2-->--2-->--125-->--4-->-- 8Ksps
    dec_out_step1 = FLT.DEC_stage1(rx_baseband) / (Dec1*R1);    % R = 2,  N = 5, M = 1
    dec_out_step2 = FLT.DEC_stage2(dec_out_step1) / (Dec2*R2);  % R = 2,  N = 5, M = 1
    dec_out_step3 = FLT.DEC_stage3(dec_out_step2) / (Dec3*R3);  % R = 2,  N = 5, M = 1
    dec_out_step4 = FLT.DEC_stage4(dec_out_step3) / (Dec4*R4);  % R = 125, N = 5, M = 1
    dec_out_step5 = FLT.DEC_stage5(dec_out_step4);              
    output.cic_o5_d2_out2 = dec_out_step2;
    output.cic_o5_d8_out  = dec_out_step4;
    output.hbf_out        = dec_out_step5;
    rx_iq                 = dec_out_step5;
    rx_len                = length(rx_iq);


    %debug: plot curves
    if(0)
        %%cic o5 d2 out1 = cic_o5_d2_out1.signals.values;
        % figure(fig_num),fig_num=fig_num+10;
        % pwelch(cic_o5_d2_out1,64,32,64,fs_tx,'centered','power');title('pwd-aft-cic1');
        %fig_num = fftTransform(cic_o5_d2_out1,fs/2,'power-of-Tx-base-signal',fig_num,'b',false);
        
        %%cic o5 d2 out2 = cic_o5_d2_out2.signals.values;
        % figure(fig_num),fig_num=fig_num+10;
        % pwelch(cic_o5_d2_out2,64,32,64,fs_tx,'centered','power');title('pwd-aft-cic2');
        fig_num = fftTransform(output.cic_o5_d2_out2,fs/(Dec1*Dec2),'power-of-Tx-base-signal',fig_num,'b',false);
        
        %%cic o5 d8 out = cic_o5_d8_out.signals.values;
        % figure,pwelch(cic_o5_d8_out,64,32,64,fs_tx,'centered','power');title('pwd-aft-cic2');
        fig_num = fftTransform(output.cic_o5_d8_out,fs/(Dec1*Dec2*Dec3*Dec4),'power-of-Tx-base-signal',fig_num,'b',false);
        
        %%hbf out1 = hbf_out1.signals.values;
        figure,pwelch(output.hbf_out,64,32,64,fs/(Dec1*Dec2*Dec3*Dec4*Dec5),'centered','power');title('pwd-aft-hbf');
        fig_num = fftTransform(output.hbf_out,fs/(Dec1*Dec2*Dec3*Dec4*Dec5),'power-of-Tx-base-signal',fig_num,'b',false);
        
        %%cordic out1 = cordic_out1.signals.values;
        %cordic_out1 = reshape(cordic_out1,16,[]);
        % figure,pwelch(cordic_out1,64,32,64,fs_tx,'centered','power');title('pwd-aft-hbf');
        %fig_num = fftTransform(cordic_out1,fs/(2^3*500*2),'power-of-Tx-base-signal',fig_num,'b',false);
    end

    %rx_sig_bas_fd = f1(rx_sig_bas,1,16,10,'RoundingMethod','Round');
end
