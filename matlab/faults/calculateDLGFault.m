
function fault = calculateDLGFault(Vth_pu, Z1_pu, Z2_pu, Z0_pu, Zf_pu)
% calculateDLGFault Calculate a phase-B/C double-line-to-ground fault.
% All inputs and outputs are in per-unit.
%
% Zf_pu is the impedance from each faulted phase to ground.
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

Zg = Z0_pu + 3*Zf_pu;
Zden = Z2_pu + Zg;

if abs(Zden) < eps
    error('calculateDLGFault:ZeroImpedance', ...
        'Negative- and zero-sequence parallel impedance denominator must be nonzero.');
end

Z20 = Z2_pu * Zg / Zden;
Ztotal = Z1_pu + Z20;

if abs(Ztotal) < eps
    error('calculateDLGFault:ZeroImpedance', ...
        'Total equivalent sequence impedance must be nonzero.');
end

I1 = Vth_pu / Ztotal;
I2 = -I1 * Zg / Zden;
I0 = -I1 * Z2_pu / Zden;

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
