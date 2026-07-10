function [fig_num] = fftTransform(rx_data,Fs,text_name,fig_num,color,hold_fig)
    fft_in = rx_data(1:fft_points);
    fft_len = length(fft_in);
    fft_out = fft(fft_in)./fft_len;
    fft_out = fftshift(fft_out);
    fft_out_power = 10*log10(abs(fft_out).^2);
    % fft_out_power = fft_out_power - max(fft_out_power);
    % fft_out_power = abs(fft_out).^2;

    df = Fs/fft_len;
    if (mod(fft_len,2)==1)
        freq = (-(fft_len-1)/2:(fft_len-1)/2)*df;
    else
        freq = (-fft_len/2:fft_len/2-1)*df;
    end
    max_f = max(freq);
    xlab = 'frequency(Hz)';
    if max_f>10000 && max_f<10000000
        freq = freq/1000;
        xlab = 'frequency(kHz)';
    elseif max_f>10000000
        freq = freq/1000000;
        xlab = 'frequency(MHz)';
    end
    figure(fig_num);plot(freq,fft_out_power,color);title(text_name);
    grid on;
    ylabel('amplitude(dB)');
    xlabel(xlab);
    if hold_fig == true
        %fig_num = fig_num;
        hold on;
    else
        fig_num = fig_num+10;
        hold off;
    end
end
