% % % standard 3nd order type-3 PLL FllDemod
function freq_demod = pll_demode_typeIII(rx_iq,fs)
    global pll_state pll_config pll_integ FLT;
    [Nlen,Ncol] = size(rx_iq);
    [phi_in,phi_err,fvco] = deal(zeros(Nlen,Ncol));
    for n = 1:Nlen
        phi_in(n)        = angle(rx_iq(n));
        phi_err(n)       = phi_in(n) - pll_state.phivco; %need wrapping!!!!!!!!!!!!!
        s2               = sin(phi_err(n));
        
        s3               = pll_config.G*s2;
        s4               = pll_config.a1*s3;
        sda              = s4 - pll_config.a2*pll_state.s5 + pll_state.w2d/fs;   % loop filter integrator input
        
        wid              = s3*pll_config.a3 + pll_state.w2d;
        pll_state.w2d    = s3*pll_config.a3 + wid;
        
        wlb              = sda + pll_state.w2b;
        pll_state.w2b    = wlb;
        pll_state.s5     = wlb/fs;
        
        s6               = s3 + pll_state.s5;
        wlc              = s6 + pll_state.w2c;
        pll_state.w2c    = wlc;
        pll_state.phivco = wlc/fs; % update integrator in nco
        fvco(n)          = s6/pi;
    end
    freq_demod = FLT.LPF_poal(fvco);
    % % %figure;plot(freq_demod);grid on;title('after compensate LPF');
    % % %figure;plot(fvco);grid on;title('Loop filter out');
end