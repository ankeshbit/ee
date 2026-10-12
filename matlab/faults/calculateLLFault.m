function fault = calculateLLFault(Vth_pu, Z1_pu, Z2_pu, Zf_pu)
% calculateLLFault Calculate a phase-B/C line-to-line fault.
% All inputs and outputs are in per-unit.
%
% Vth_pu: Prefault positive-sequence Thevenin voltage.
% Z1_pu: Positive-sequence Thevenin impedance.
% Z2_pu: Negative-sequence Thevenin impedance.
% Zf_pu: Impedance between the two faulted phases.
%
% The fault is defined between phases B and C, so phase A carries no
% fault current and the zero-sequence current is zero.

validateattributes(Vth_pu, {'numeric'}, ...
    {'scalar', 'finite'});
validateattributes(Z1_pu, {'numeric'}, ...
    {'scalar', 'finite'});
validateattributes(Z2_pu, {'numeric'}, ...
    {'scalar', 'finite'});
validateattributes(Zf_pu, {'numeric'}, ...
    {'scalar', 'finite'});

Ztotal = Z1_pu + Z2_pu + Zf_pu;

if abs(Ztotal) < eps
    error('calculateLLFault:ZeroImpedance', ...
        'Total fault-path impedance must be nonzero.');
end

I1 = Vth_pu / Ztotal;
I0 = 0;
I2 = -I1;

a = exp(1i * 2*pi/3);
Tinv = [ ...
    1, 1, 1;
    1, a^2, a;
    1, a, a^2];

Iphase = Tinv * [I0; I1; I2];

fault.I0_pu = I0;
fault.I1_pu = I1;
fault.I2_pu = I2;
fault.Ia_pu = Iphase(1);
fault.Ib_pu = Iphase(2);
fault.Ic_pu = Iphase(3);
end
