function sensitivity = sensitivity_calc(EbNo_dB,BER_estimation,BER_th)
    BERlog10 = log10(BER_estimation);
    [rows,cols] = size(BER_estimation);
    sensitivity = zeros(1,rows);
    for i=1:rows
        sensitivity(i) = zero_crossing_find(EbNo_dB,BERlog10(i,:)-log10(BER_th));
    end
end

function [zero_crossings] = zero_crossing_find(xrange,yvalues)
    % 找到所有过零点及对应距离
    % 输入参数 xrange 和 yvalues 维度必须相同
    sign_vals = sign(sign(yvalues)-0.5);
    sig_diff = [0 diff(sign_vals)];
    zerox_pos = find(sig_diff~=0);
    if isempty(zerox_pos)
        zero_crossings = inf;
        return;
    else
        zero_crossings = zeros(1,length(zerox_pos));
        for idx = 1:length(zerox_pos)
            x_step = xrange(zerox_pos(idx))-xrange(zerox_pos(idx)-1);
            y0 = yvalues(zerox_pos(idx)-1);
            y1 = yvalues(zerox_pos(idx));
            zero_crossings(idx) = xrange(zerox_pos(idx)-1) + x_step*y0/(y0-y1);
        end
    end
end
