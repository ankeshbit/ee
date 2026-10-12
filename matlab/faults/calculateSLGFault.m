
function fault = calculateSLGFault(Vth_pu, Z1_pu, Z2_pu, Z0_pu, Zf_pu)
% calculateSLGFault Calculate a phase-A single-line-to-ground fault.
% All inputs and outputs are in per-unit.
%
% Vth_pu: Prefault positive-sequence Thevenin voltage.
% Z1_pu: Positive-sequence Thevenin impedance.
% Z2_pu: Negative-sequence Thevenin impedance.
% Z0_pu: Zero-sequence Thevenin impedance.
% Zf_pu: Phase-A-to-ground fault impedance.
%
% Output fields:
%   I0_pu, I1_pu, I2_pu: Sequence currents.
%   Ia_pu, Ib_pu, Ic_pu: Phase currents.

validateattributes(Vth_pu, {'numeric'}, ...
    {'scalar', 'finite'});
validateattributes(Z1_pu, {'numeric'}, ...
    {'scalar', 'finite'});
validateattributes(Z2_pu, {'numeric'}, ...
    {'scalar', 'finite'});
validateattributes(Z0_pu, {'numeric'}, ...
    {'scalar', 'finite'});
validateattributes(Zf_pu, {'numeric'}, ...
    {'scalar', 'finite'});

Ztotal = Z1_pu + Z2_pu + Z0_pu + 3*Zf_pu;

if abs(Ztotal) < eps
    error('calculateSLGFault:ZeroImpedance', ...
        'Total sequence-network impedance must be nonzero.');
end

Iseq = Vth_pu / Ztotal;

fault.I0_pu = Iseq;
fault.I1_pu = Iseq;
fault.I2_pu = Iseq;

% Convert sequence currents to phase currents.
a = exp(1i * 2*pi/3);

Tinv = [ ...
    1, 1, 1;
    1, a^2, a;
    1, a, a^2];

Iphase = Tinv * [Iseq; Iseq; Iseq];

fault.Ia_pu = Iphase(1);
fault.Ib_pu = Iphase(2);
fault.Ic_pu = Iphase(3);
end
