function [rx_cmix_out,time_rx] = rx_cmix(rx_bb_4k,rx_len,f_off_hz,fs_rx,CORDIC_EN)
    global N_4K_start;
    time_rx = (N_4K_start:N_4K_start+rx_len-1)'*(1/fs_rx);
    N_4K_start = N_4K_start+rx_len;
    rx_phase = 2*pi*f_off_hz*time_rx;
    
    if(CORDIC_EN)
        %$$rx_cmix_out = mixer_fix(rx_bb_4k,rx_phase);
        rx_cmix_out = cordic_rotation(rx_bb_4k,rx_phase);
    else
        rx_cmix_out = rx_bb_4k.*exp(1i*rx_phase);
    end
end
