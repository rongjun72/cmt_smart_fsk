function [bb,aa,bp,an,bn] = bpf_pair_fir_design(Nord,fc,fr,fs)
    % fs = 32e3;
    % fc = 2e3;
    % Rs = 60; % stop band attenuation in dB
    % Nord = 4;
    % fr = -2e3; % center pass-band frequency of desired bandpass filter (complex/asymmetric)
    % an=1;
    % design a normal IIR low-pass filter
    Wc = fc/(fs/2); % stop band edge frequency
    bb = fir1(Nord,Wc);
    % bb = cfir1(Nord,[-fs/2 -1600 -1400 800 1000 1000 fs/2]/(fs/2),@lowpass);
    % %bb = fir1(Nord,Wc,'low',hamming(Nord+1));
    % %bb = fir1(Nord,Wc,'low',chebwin(Nord+1,67)); % N=20,ap=67
    % %bb = fir1(Nord,Wc,'low',blackman(Nord+1)); % N=28
    % [p,gain] = tf2zp(bb,aa);
    % %fvtool(bb,1,'Fs',fs);

    theta_rot = 2*pi*fr/fs;
    % zeros/poles rotating forming a new asymmetric band-pass filter
    % positive/anti-clockwise rotation
    zr = z*exp(1i*theta_rot); % zeros-point rotate
    pr = p*exp(1i*theta_rot); % poles-point rotate
    warning off; sys_p = zpk(zr,pr,gain); warning on;
    tf_p = tf(sys_p);
    bp = cell2mat({tf_p.Numerator});
    ap = cell2mat({tf_p.Denominator});

    % negative/clockwise rotation
    zr = z*exp(-1i*theta_rot); % zeros-point rotate
    pr = p*exp(-1i*theta_rot); % poles-point rotate
    warning off; sys_p = zpk(zr,pr,gain); warning on;
    tf_p = tf(sys_p);
    bn = cell2mat({tf_p.Numerator});
    an = cell2mat({tf_p.Denominator});

    leg0 = sprintf('LPF');
    if round(fr/1e3)>=1; uu='MHz';nn=1e6; else; if round(fr/1e3)>=1; uu='kHz';nn=1e3;else; uu='Hz';nn=1; end
    legp = sprintf('fshift: +44.2f%s',fr/nn,uu);
    legn = sprintf('fshift: -44.2f%s',fr/nn,uu);
    fvtool(bb,1,bp,ap,bn,an,'Fs',fs); title('band-pass filter design');legend(leg0,legp,legn);

    % bb = cfir1(Nord,[-fs/2 -250 0 fc fc+250 fs/2]/(fs/2),@lowpass);
    % bp = cfir1(Nord,[-fs/2 -fc-250 -fc 0 250 fc+250 fs/2]/(fs/2),@lowpass);
    % ap = cfir1(Nord,[-fs/2 -fc-250 -fc 0 250 fc+250 fs/2]/(fs/2),@lowpass);
    % if round(fr/1e3)>=1; uu='MHz';nn=1e6; elseif round(fr/1e3)>=1; uu='kHz';nn=1e3;else; uu='Hz';nn=1; end
    % legp = sprintf('fshift: +44.2f%s',fr/nn,uu);
    % legn = sprintf('fshift: -44.2f%s',fr/nn,uu);
    % fvtool(bp,ap,bn,an,'Fs',fs); title('band-pass filter design');legend(legp,legn);
end
