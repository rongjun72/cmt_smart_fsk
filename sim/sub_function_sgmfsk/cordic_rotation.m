%%%function [iq_out,res,gain] = cordic_rotation(iq_in, angle)
function [iq_out] = cordic_rotation(iq_in, angle)
    Niter = 16; Nint = 1;
    %Angle preprocessing: decompose angle into quadrant and residual angle in [0,pi/2)
    [angle_residual, quadrant] = angle_preprocessing(angle);
    % Initialize CORDIC angle table
    angle_table = atan(2.^(-(0:(Niter+Nint-1))));
    %%[iq_out,ceo,gain] = deal(zeros(size(iq_in)));
    iq_out = zeros(size(iq_in));

    for idx = 1:length(iq_in)
        % CORDIC ROTATION mode
        rot = angle_residual(idx);
        
        % Pre-rotate vector (x,y) by integer multiples of pi/2 according to angle quadrant
        % Second or fourth quadrant: swap x and y, and adjust sign
        % Third quadrant: negate both x and y
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
        
        % Iteratively rotate (x,y) by residual angle
        %%%[~,pmin] = min(abs(rot-angle_table(1:Nint)));
        Niter0 = 0;%pmin-1; %replace 0
        for i = Niter0:Niter0+Niter-1
            % Rotation direction decision
            d = sign(sign(rot)+0.5);
            % Compute next-step values
            x_next = x - d * y * 2^(-i);
            y_next = y + d * x * 2^(-i);
            z_next = rot - d * angle_table(i+1);
            % Update variables
            x = x_next;
            y = y_next;
            rot = z_next;
        end
        % Attenuation compensation
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