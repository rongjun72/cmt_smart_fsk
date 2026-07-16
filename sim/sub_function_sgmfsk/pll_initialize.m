function [pll_state,pll_config,pll_integ] = pll_initialize(f_dev,BW,fs)
    % input parameter definition:
    % wn : natural angular frequency in hertz, = 2*pi*fn
    %%% PLL configurations setting/initialization
    wn = 2*pi*(f_dev + BW*0.35);
    pll_config.zeta    = 0.99*sqrt(1/sqrt(2));
    pll_config.lambda  = 0.1;
    zeta = pll_config.zeta; lambda = pll_config.lambda;
    pll_config.G       = wn/(zeta+sqrt(zeta*zeta-lambda));
    pll_config.a       = wn/(zeta+sqrt(zeta*zeta-lambda)); % open loop gain
    pll_config.a1      = pll_config.a*(-lambda);          % filter parameter
    pll_config.a2      = pll_config.a*lambda;
    pll_config.a3      = pll_config.a2*pll_config.a2/2;
    % plot root locus diagram of PLL
    gs_num = [1 pll_config.a1+pll_config.a2];
    gs_den = [1 pll_config.a2 0];
    gs_sys = tf(gs_num,gs_den);
    figure; rlocus(gs_sys);grid on;title('PLL: root locus');

    %%% PLL states initialization
    pll_state.w2b = 0;
    pll_state.w2c = 0;
    pll_state.w2d = 0;
    pll_state.phivco = 0;
    pll_state.Oout = 1;
    pll_state.s5 = 0;
    %%% filters/integrator object
    b=[1,1]/fs;a=[1,-1];
    pll_integ.s1    = dsp.IIRFilter('Numerator',b,'Denominator',a);
    pll_integ.s2    = dsp.IIRFilter('Numerator',b,'Denominator',a);
    pll_integ.nco   = dsp.IIRFilter('Numerator',b,'Denominator',a);
end