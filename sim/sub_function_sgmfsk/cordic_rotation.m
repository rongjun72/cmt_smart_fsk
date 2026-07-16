%%%function [iq_out,res,gain] = cordic_rotation(iq_in, angle)
function [iq_out] = cordic_rotation(iq_in, angle)
    Niter = 16; Nint = 1;
    %角度预处理：将角度分解成象限值和[0,pi/2)范围的残留角
    [angle_residual, quadrant] = angle_preprocessing(angle);
    % 初始化CORDIC角度表
    angle_table = atan(2.^(-(0:(Niter+Nint-1))));
    %%[iq_out,ceo,gain] = deal(zeros(size(iq_in)));
    iq_out = zeros(size(iq_in));

    for idx = 1:length(iq_in)
        % CORDIC ROTATION CORDIC旋转模式
        rot = angle_residual(idx);
        
        % 根据angle象限对向量(x,y)进行pi/2整数倍预旋转
        % 第二或第四象限：交换x和y，并调整符号
        % 第三象限：x和y都取反符号
        if quadrant(idx) == 1
            x = -imag(iq_in(idx));
            y = real(iq_in(idx));
        elseif(quadrant(idx)==2)
            x = -real(iq_in(idx));
            y = -imag(iq_in(idx));
        elseif(quadrant(idx) == 3)
            x = imag(iq_in(idx));
            y = -real(iq_in(idx));
        else
            x = real(iq_in(idx));
            y = imag(iq_in(idx));
        end
        
        % 对(x,y)进行残留角迭代旋转
        %%%[~,pmin] = min(abs(rot-angle_table(1:Nint)));
        Niter0 = 0;%pmin-1; %replace 0
        for i = Niter0:Niter0+Niter-1
            % 旋转方向判决
            d = sign(sign(rot)+0.5);
            % 计算下一步的值
            x_next = x - d * y * 2^(-i);
            y_next = y + d * x * 2^(-i);
            z_next = rot - d * angle_table(i+1);
            % 更新变量
            x = x_next;
            y = y_next;
            rot = z_next;
        end
        % 衰减补偿
        K = 1;
        for i = Niter0:Niter0+Niter-1
            K = K/(sqrt(1+2^(-2*i)));
        end
        %%%res(idx)=rot; gain(idx)=K;
        x_out = x*K;
        y_out = y*K;
        iq_out(idx) = complex(x_out,y_out);
    end
end