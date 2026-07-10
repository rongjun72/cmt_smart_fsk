function [amp_freq] = plot_time_freq_response(signal,fs,fig_num,varargin)
    ttitle = 'after FSK Demo';    %% 'title'
    len_sig = length(signal);
    nfft = len_sig;              %% 'nfft'
    freq_amp_range = [0 fs/2/1e6 -80 5];    %% 'f_range'

    time_amp_range = [1:len_sig];    %% 't_range'
    hold_flag = 'off';              %% 'hold'
    ds_flag = 'off';                %% 'double-side'

    Nargin = nargin-3;
    if Nargin>0 && mod(Nargin,2)==0
        %%%%%%%%%%%%%%%%%%%%
        for ii = 1:2:Nargin
            if strcmp(cell2mat(varargin(ii)),'title')
                ttitle = cell2mat(varargin(ii+1));
            end
        end
        %%%%%%%%%%%%%%%%%%%%
        for ii = 1:2:Nargin
            if strcmp(cell2mat(varargin(ii)),'nfft')
                nfft = cell2mat(varargin(ii+1));
            end
        end
        %%%%%%%%%%%%%%%%%%%%
        for ii = 1:2:Nargin
            if strcmp(cell2mat(varargin(ii)),'hold')
                hold_flag = cell2mat(varargin(ii+1));
            end
        end
        %%%%%%%%%%%%%%%%%%%%
        for ii = 1:2:Nargin
            if strcmp(cell2mat(varargin(ii)),'double-side')
                ds_flag = cell2mat(varargin(ii+1));
            end
        end
    end

    m_fsk = 20*log10(abs(fftshift(fft(signal,nfft))));
    amp_freq = m_fsk - max(m_fsk);
    if round(fs/1e6)>=1; uu='MHz'; nn=1e6; elseif round(fs/1e3)>=1; uu='kHz'; nn=1e3; else; uu='Hz'; nn=1; end
    freq = fs*((1:nfft)-nfft/2+1)/nfft/nn; % unit of frequency axes in MHz
    time = (1:length(signal))/fs*1e6; % time in us
    figure(fig_num);

    if max(abs(imag(signal)))>0
        subplot(3,1,1);
        if strcmp(ds_flag,'on')
            freq_amp_range = [-fs/2/nn fs/2/nn -80 5];
            plot(freq,amp_freq); axis(freq_amp_range);
        else
            plot(freq,amp_freq); axis(freq_amp_range);
        end
        title(strcat('Spectrum: ',ttitle),'Interpreter','none');
        xlabel(sprintf('Frequency (%s)',uu)); ylabel('Amplitude (dB)'); grid on;
        if strcmp(hold_flag,'on')
            hold on;
        else
            hold off;
        end

        subplot(3,1,2);
        plot(time,real(signal));
        title(strcat('Waveform - real: ',ttitle),'Interpreter','none');
        xlabel('Time (us)'); ylabel('Amplitude (V)'); grid on;
        if strcmp(hold_flag,'on'); hold on; else; hold off; end

        subplot(3,1,3);
        plot(time,imag(signal));
        title(strcat('Waveform - imag: ',ttitle),'Interpreter','none');
        xlabel('Time (us)'); ylabel('Amplitude (V)'); grid on;
        if strcmp(hold_flag,'on'); hold on; else; hold off; end
    else
        subplot(2,1,1);
        if strcmp(ds_flag,'on')
            freq_amp_range = [-fs/2/nn fs/2/nn -80 5];
            plot(freq,amp_freq); axis(freq_amp_range);
        else
            plot(freq,amp_freq); axis(freq_amp_range);
        end
        title(strcat('Spectrum: ',ttitle),'Interpreter','none');
        xlabel(sprintf('Frequency (%s)',uu)); ylabel('Amplitude (dB)'); grid on;
        if strcmp(hold_flag,'on'); hold on; else; hold off; end

        subplot(2,1,2);
        plot(time,real(signal));
        title(strcat('Waveform: ',ttitle),'Interpreter','none');
        xlabel('Time (us)'); ylabel('Amplitude (V)'); grid on;
        if strcmp(hold_flag,'on'); hold on; else; hold off; end
    end
end
