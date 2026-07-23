%smart_gmfsk_16x.m
%smart_gmfsk_16x.m
clc;clear;close all;
clearvars -global;
addpath('.\sub_function_sgmfsk\');
filename_res = 'mfsk_ber_16x.txt';
global FLT Samp_IDET Mfsk ref_metric; % global filter object array
global DEBUG Demod_method last_pm;
global N_32M_start N_4K_start last_rx_phase last_tx_phase last_iq;
%% DEBUG enable
DEBUG = 0;
fig_num = 1;
filter_type = 0;
NOISE_EN = 1;%1;
CORDIC_EN = 0;
%% 系统参数
Mfsk = 4;
Mlog2 = log2(Mfsk);
BR = Mlog2*1e3;              % 比特速率
Tsym = 1/(BR/Mlog2);         % 符号周期 (s)
fs = 32e6;%%32e6;            % 采样率 (Hz)
sps = 16;                    % 发送端每个符号采样点数
fs_tx = sps*(BR/Mlog2);      % 发射带的码元采样率
BW = 1/Tsym;                 % 发射带宽
% fs_rx = fs_tx;             % 接收信号的采样率
q_span = 4;
fs_rx = 16*BW;%fs_tx*BW;     % 接收信号的采样率
Flo = 500e3;%%500e3;         % 中频频率 (Hz)
f_rf = 433.92e6;             % 载波频率 (Hz)
sps_rx = fs_rx*Tsym;         % 接收端每个符号采样点数
timeBwProduct = 0.50;%0.50;  % 带宽-时间积
% timeBwProduct = BW*Tsym;   % 带宽-时间积
h = 0.5;                     % 调制指数, h = F_dev*Tsym = F_dev/SymbRate
F_dev = h/Tsym;              % 最大频偏(Hz)
% F_dev = 500Hz;
% dev = 250e3;
% F_dev = dev;
Nsym_total = 200*1000; % 发射符号数
Nsym_segment = 2000;
%%EbNo_dB = 20*(1-2.^((0:1:-20)'));%% 0+(0:2:25);
EbNo_dB = 0 + 16*log10(1:1.9:20)/log10(20);
f_off_ppm = 0;%0.5e-6;%6;%20ppm
f_off_hz = f_rf*f_off_ppm;
%%
FI = fimath('ProductMode','FullPrecision','SumMode','FullPrecision',...
            'RoundingMethod','Round','OverflowAction','Saturate');
%%
Demod_method_list = {"CCOH-THER","NCOH-THER","MIX-LPF","MIX-LPF-ISI"};%,"MIX-LPF"; % "MIX-LPF": "FREQ-DET"; "NCOH-REF";
N_method = length(Demod_method_list);
EbNo_len = length(EbNo_dB);
[BER_rot, BER_est, error_count, bits_count] = ber_state_init(filename_res,Demod_method_list,EbNo_dB,'newFile');
%%BER theory  co FSK: 1/2*erfc(sqrt(Eb/No)/2) = 1/2*erfc(sqrt(r)/2),r=Eb/No
BER_theory_coh = berawgn(EbNo_dB,'fsk',2,'coherent');
BER_theory_ncoh = berawgn(EbNo_dB,'fsk',2,'noncoherent');
BER_est(1,:) = BER_theory_coh;
BER_est(2,:) = BER_theory_ncoh;
fd_proc = figure;
ui_proc = uitable(fd_proc,'Data',[zeros(EbNo_len,1) EbNo_dB' BER_est'],'ColumnName',['idx_lp' 'EbNo' Demod_method_list],...
    'Units','normalized','Position',[0.01 0.05 0.95 0.9],'FontSize',10);
ui_proc.ColumnFormat = {'numeric','bank','short e','short e','short e','short e'};
tatart0 = tic;
for idx_method = 3:(N_method-1)
    Demod_method = Demod_method_list{idx_method};
    %% filter series delay
    [filt_dly] = sgmfsk_filter_series(BW,fs,BR,fs_rx,timeBwProduct,q_span,sps,F_dev);
    ref_metric = ref_metric_gen(Nsym_segment,sps,fs,fs_tx,fs_rx,sps_rx,F_dev,Flo,filt_dly);
    for idx_EbNo = 1:EbNo_len
        reset_filter_objs(FLT);
        error_pos = 0; tsss = tic;
        [N_32M_start,N_4K_start,last_rx_phase,last_tx_phase,last_iq,Samp_IDET,freq_off] = deal(0);
        last_tx_iq = zeros(1,Nsym_segment*sps_rx); last_pm = inf;
        last_rx_iq = zeros(Nsym_segment*sps_rx,1);
        tx_snr = EbNo_dB(idx_EbNo);
        %% N symb loop = round(Nsym_total/Nsym_segment)+1;
        N_symb_loop = round(Nsym_total/Nsym_segment)+1;
        tx_bits = zeros(N_symb_loop-1,Nsym_segment*Mlog2);
        weight_cma = zeros(21,1); weight_cma(11)=1;
        for idx_symb = 0:N_symb_loop
            tatart = tic;
            %% synchronization processing at first frame
            if idx_symb==0
                % generate first synchronization frame
                [~,tx_sig_rf,time_tx,fig_num] = sgmfsk_modulator(Nsym_segment,'syn',sps,fs,fs_tx,F_dev,Flo,fig_num);
                %%---- AWGN Channelization on air ------
                rx_sig_rf = awgn_channelizing(tx_sig_rf,tx_snr,BR,fs,fs_rx,NOISE_EN);
                [rx_sig_bb,rx_bb_len] = rx_ddc_mixer(rx_sig_rf,Flo,f_off_hz,time_tx);
                [rx_sig,rx_len] = sgmfsk_decimation(rx_sig_bb,fs,fs_tx,filter_type);
                [rx_cmix_out,time_rx] = rx_cmix(rx_sig,rx_len,0,fs_rx,CORDIC_EN);
                curr_rx_iq = FLT.chFilter(double(rx_cmix_out));
                demod_in = circshift(curr_rx_iq,-filt_dly);
                [rx_bits,rx_bits_len,~] = sgmfsk_CoDemod(time_rx,demod_in,fs_rx,sps_rx,F_dev,freq_off,'syn');
                breakb=1;
            end
            if idx_symb<N_symb_loop && idx_symb>0
                %% Gfsk generate()
                [tx_bits(idx_symb,:),tx_sig_rf,time_tx,fig_num] = sgmfsk_modulator(Nsym_segment,'rand',sps,fs,fs_tx,F_dev,Flo,fig_num);
                %%---- AWGN Channelization on air ------
                rx_sig_rf = awgn_channelizing(tx_sig_rf,tx_snr,BR,fs,fs_rx,NOISE_EN);
                [rx_sig_bb,rx_bb_len] = rx_ddc_mixer(rx_sig_rf,Flo,f_off_hz,time_tx);
                [rx_sig,rx_len] = sgmfsk_decimation(rx_sig_bb,fs,fs_tx,filter_type);
                %% multi_channel_recv()
                %[rssI,snr] = rssi_ant_estimation(rx_sig,fs_rx);
                %freq_off = frequency_estimation(rx_sig,fs_rx);
                [rx_cmix_out,time_rx] = rx_cmix(rx_sig,rx_len,0,fs_rx,CORDIC_EN);
                curr_rx_iq = FLT.chFilter(double(rx_cmix_out));
            end %idx_symb<N_symb_loop
            if idx_symb>1
                demod_in = [last_rx_iq(filt_dly+1:end); curr_rx_iq(1:filt_dly)];
                %[rx_bits,rx_bits_len] = gfsk_demodulator(demod_in,sps_rx,freq_off);
                [rx_bits,rx_bits_len,rx_bits_mlse] = sgmfsk_CoDemod(time_rx,demod_in,fs_rx,sps_rx,F_dev,freq_off,'norm');
                % BER calculation
                Nst = (1+0+(idx_symb==2)*ceil(7*filt_dly/sps_rx))*Mlog2-1;%40
                Ncmp = (Nsym_segment -20 - (idx_symb==N_symb_loop)*ceil(7*filt_dly/sps_rx))*Mlog2;%960;
                [err_cnt,bit_cnt,~] = error_stat(tx_bits(idx_symb-1,Nst:Ncmp),rx_bits(Nst:Ncmp));
                [err_cnt_mlse,bit_cnt_mlse,~] = error_stat(tx_bits(idx_symb-1,Nst:Ncmp),rx_bits_mlse(Nst:Ncmp));
                error_count(idx_method,idx_EbNo) = error_count(idx_method,idx_EbNo) + err_cnt;
                bits_count(idx_method,idx_EbNo) = bits_count(idx_method,idx_EbNo) + bit_cnt;
                BER_est(idx_method,idx_EbNo) = error_count(idx_method,idx_EbNo) / (bits_count(idx_method,idx_EbNo) + eps);
                error_count(idx_method+1,idx_EbNo) = error_count(idx_method+1,idx_EbNo) + err_cnt_mlse;
                bits_count(idx_method+1,idx_EbNo) = bits_count(idx_method+1,idx_EbNo) + bit_cnt_mlse;
                BER_est(idx_method+1,idx_EbNo) = error_count(idx_method+1,idx_EbNo) / (bits_count(idx_method,idx_EbNo) + eps);
            end %idx_symb>1
        
            last_rx_iq = curr_rx_iq;
            tdura = toc(tatart);
            %fprintf('idx:EbNo,symb. = %d:%d, EbNo = %3.1f, BER = %6.5e, proc time = %3.1f\n',idx_EbNo,idx_symb,tx_snr,BER_est(idx_method,idx_EbNo),tdura);
            fprintf('idx:EbNo.symb = %d:%d, EbNo = %3.1f, BER0 = %4.3e, BER1 = %4.3e\n',idx_EbNo,idx_symb,tx_snr,BER_est(idx_method,idx_EbNo),BER_est(idx_method+1,idx_EbNo));
            %fprintf('error pos : %d\n',error_pos);
            ui_proc.Data(idx_EbNo,1) = idx_symb;
            ui_proc.Data(idx_EbNo,idx_method+2) = BER_est(idx_method,idx_EbNo);
            ui_proc.Data(idx_EbNo,idx_method+3) = BER_est(idx_method+1,idx_EbNo);
            drawnow;
        end
        BER_tot = ber_result_save(filename_res,bits_count,error_count,EbNo_dB,tsss);
    end
end
ttotal = toc(tatart0);
fprintf('proc time = %3.1f\n',ttotal);
%%
sensitivities = sensitivity_calc(EbNo_dB,BER_est,0.001);
% print BER table
fprintf('EbNo\t');
for idx = 1:length(Demod_method_list);fprintf('%s\t',Demod_method_list{idx});end
fprintf('\n');
for idx_EbNo = 1:EbNo_len
    fprintf('%3.1f\t',EbNo_dB(idx_EbNo));
    for idx = 1:N_method;fprintf('%6.5e\t',BER_est(idx,idx_EbNo));end
    fprintf('\n');
end
%%
fd = figure;
ui1 = uitable(fd,'Data',[EbNo_dB' BER_est'],'ColumnName',['EbNo' Demod_method_list],...
    'Units','normalized','Position',[0.01 0.35 0.95 0.6]);
ui2 = uitable(fd,'Data',[sensitivities],'ColumnName',[Demod_method_list],'RowName','Sensitivity(dB)',...
    'Units','normalized','Position',[0.01 0.20 0.95 0.1]);
%% 绘图
figure;
semilogy(EbNo_dB,BER_est(1,:),'r--','LineWidth',2); hold on; % BER_theory_ncoh
semilogy(EbNo_dB,BER_est(2,:),'g--','LineWidth',2); % BER_theory_coh
for idx_method = 3:N_method
    semilogy(EbNo_dB,BER_est(idx_method,:),'o-','LineWidth',2);
end
grid on;
xlabel('E_b/N_0 (dB)','Interpreter','none');
ylabel('BER_est','Interpreter','none');
title(sprintf('BER curve: fs_rx = %2.1fKSpS', fs_rx/1000));
ylim([1e-6 1e0]);text(0.2,5e-4,sprintf('BT=%.1f, h=%.1f, chFilt:[1.72,2.365]kHz',timeBwProduct,h));
ylim([1e-6 1e0]);text(0.2,1e-4,sprintf('mix: +/-500,1500Hz, LPF fc: 750Hz(chebwin,Nrd=36)'));
legend(cellstr(Demod_method_list(1:N_method)),'Location','southwest');
disp('end');

function reset_filter_objs(filter_array)
    fields = fieldnames(filter_array);
    for idx = 1:length(fields)
        fit_name = fields{idx};
        reset(filter_array.(fit_name));
    end
end

%% CMA 均衡函数
function [y_out, W_cma] = cma_eq(x_in, W_cma, miu)
    xlen = length(x_in);
    kw = length(W_cma);
    if miu == 0
        y_out = x_in;
    else
        [y_out, E_cma] = deal(zeros(size(x_in)));
        for k = 1:xlen-kw
            mov_win = fliplr(x_in(k:k+kw-1));
            y_out(k) = W_cma' * mov_win;
            E_cma(k) = y_out(k) * (y_out(k)*y_out(k)' - 1); % CMA 误差函数
            W_cma = W_cma - miu * conj(E_cma(k)) * mov_win; % 权重更新
        end
    end
end

%% BER 状态初始化函数
function [BER_tot, BER_est, error_count, bits_count] = ber_state_init(filename_res, Demod_methods, EbNo_dB, newFile)
    N_method = length(Demod_methods);
    EbNo_len = length(EbNo_dB);
    if strcmp(newFile, 'newFile') || exist(filename_res, 'file') ~= 2
        % 新建文件
        fd_res = fopen(filename_res, 'w+');
        [BER_tot, BER_est, error_count, bits_count] = deal(zeros(N_method, EbNo_len));
        fprintf(fd_res, 'EbNo\t');
        for i = 3:N_method; fprintf(fd_res,'%s_cnt\t%s_err\t%s_ber\t',Demod_methods{i},Demod_methods{i},Demod_methods{i});end
        fprintf(fd_res, '\n-1\t'); for i = 3:N_method; fprintf(fd_res,'-1\t-1\t0\t'); end
        fprintf(fd_res, '\n');
        for ii = 1:EbNo_len
            fprintf(fd_res, '%f\t', EbNo_dB(ii));
            for iii = 3:N_method; fprintf(fd_res,'%d\t%d\t%e\t',bits_count(iii,ii),error_count(iii,ii),BER_tot(iii,ii)); end
            fprintf(fd_res, '\n');
        end
        fclose(fd_res);
    else
        % 读取已有文件
        [BER_tot, BER_est, error_count, bits_count] = deal(zeros(N_method, EbNo_len));
        table = importdata(filename_res);
        [row, col] = size(table.data);
        if ~isempty(find(table.data(row-EbNo_len, 1:2) >= 0))
            fprintf('WRONG format in file: %s\n', filename_res);
            return;
        else
            last_record = table.data(row-EbNo_len+1:row, 2:col)';
            bits_count(3:N_method, :) = last_record(1:3:col-1, :);
            error_count(3:N_method, :) = last_record(2:3:col-1, :);
            BER_tot(3:N_method,:) = last_record(3:3:col-1,:);
        end
    end
end

function [BER_new] = ber_result_save(filename_res,bits_count,error_count,EbNo_dB,tstart)
    [row,col] = size(bits_count);
    N_method = row; EbNo_len = col;
    table = importdata(filename_res);
    [row,col] = size(table.data);
    [BER_new] = deal(zeros(N_method,EbNo_len));
    td_frame = toc(tstart);
    if col ~= 3*(N_method-2)+1
        fprintf('data structure not in accordance with ...');
        return;
    end
    if ~isempty(find(table.data(row-EbNo_len,1:2)>=0))
        fprintf('WRONG format in file: %s ',filename_res);
        return;
    else
        %last_record = table.data(row-EbNo_len+1:row,2:col);
        %bits_count_last(3:N_method,:) = last_record(1:2:col-1,:);
    %error_count_last(3:N_method,:) = last_record(2:2:col-1,:);
        % 更新计数矩阵
        %error_count = error_count + error_count_last;
        %bits_count = bits_count + bits_count_last;
        % 计算新的BER
        BER_new = (error_count+eps)./(bits_count+eps);
        new_idx = mean(table.data(row-EbNo_len,1:2))-1;
        fd_res = fopen(filename_res,'a+');
        fprintf(fd_res,'%d\t',new_idx);for i = 3:N_method; fprintf(fd_res,'%d\t%d\t%f\t',new_idx,new_idx,td_frame);end
        fprintf(fd_res,'\n');
        for ii = 1:EbNo_len
            fprintf(fd_res,'%f\t',EbNo_dB(ii));
            for iii = 3:N_method;fprintf(fd_res,'%d\t%d\t%e\t',bits_count(iii,ii),error_count(iii,ii),BER_new(iii,ii));end
            fprintf(fd_res,'\n');
        end
        fclose(fd_res);
    end
end

function [err_count,bit_count,error_status] = error_stat(tx_bits,rx_bits)
    bit_count = length(rx_bits);
    err_count = length(find(tx_bits ~= rx_bits));
    error_status = [];
    % if err_count>0
    %     tx_symbol = tx_bits(1:2:end)*2 + tx_bits(2:2:end)*1;
    %     rx_symbol = rx_bits(1:2:end)*2 + rx_bits(2:2:end)*1;
    %     error_pos = find(tx_symbol ~= rx_symbol);
    %     st_pos = [];
    %     %for idx = 1:length(error_pos)
    %     %    if error_pos(idx)>1
    %     %        st_pos = [st_pos error_pos(idx)-1,error_pos(idx),error_pos(idx)+1];
    %     %    else
    %     %        st_pos = [st_pos error_pos(idx),error_pos(idx)+1];
    %     %    end
    %     %end
    %     error_status = zeros(3,length(st_pos));
    %     error_status(1,:) = st_pos;
    %     error_status(2,:) = tx_symbol(st_pos);
    %     error_status(3,:) = rx_symbol(st_pos);
    %     fprintf('error_pos = ');
    %     for idx=1:length(error_pos)
    %         fprintf('%d,',error_pos(idx));
    %     end
    %     fprintf('\n');
    % end
end