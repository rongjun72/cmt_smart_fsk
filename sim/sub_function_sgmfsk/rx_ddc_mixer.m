% local mixing with off ppm --DDC
function [rx_baseband,sig_len] = rx_ddc_mixer(rx_signal,Flo,f_off,time_rx)
    rx_baseband = rx_signal.*exp(-1i*2*pi*(Flo+f_off).*time_rx);
    sig_len     = length(rx_baseband);
end