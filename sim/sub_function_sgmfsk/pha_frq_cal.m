function [frq,pha] = pha_frq_cal(sig_in,fs_rx)
    pha = angle(sig_in);
    pha = unwrap(pha);
    frq = diff(pha)*fs_rx/2/pi;
end