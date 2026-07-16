% standard 2nd order type-2 PLL FMDemod - using global filter object
function freq_demod = pll_demode(rx_iq,fs)
    global pll_state pll_config pll_integ FLT;
    [Nlen,Ncol] = size(rx_iq);
    [phi_in,phi_err,fvco] = deal(zeros(Nlen,Ncol));
    for n = 1:Nlen
        %%%%conj_mult      = rx_iq(n)*conj(pll_state.Oout)/max(abs(rx_iq(n)),0.1);
        %%%%phi_err(n)      = real(conj_mult)*imag(conj_mult)/2;
        %%%%s2              = phi_err(n); %
        phi_in(n)       = angle(rx_iq(n));
        phi_err(n)      = phi_in(n) - pll_state.phivco; %%%need wrapping!!!!!!!!!!!!!
        s2              = sin(phi_err(n));
        
        s3              = pll_config.G*s2;
        s4              = pll_config.a1*s3;
        s4a             = s4 - pll_config.a2*pll_state.s5; % s5:pll_state.integrator/2fs
        
        pll_state.s5    = pll_integ.s1(s4a);
        
        s6              = s3 + pll_state.s5;
        pll_state.phivco= pll_integ.nco(s6); % update integrator in nco
        
        %%%pll_state.Oout  = exp(1i*pll_state.phivco);
        fvco(n)         = s6/pi;
    end
    freq_demod = FLT.LPF_pos1(fvco);
    %%%figure;plot(freq_demod);grid on;title('after compensate LPF');
    %%%figure;plot(fvco);grid on;title('Loop filter out');
end