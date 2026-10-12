function If_pu = calculateThreePhaseFault(Vth_pu, Z1th_pu, Zf_pu)
% calculateThreePhaseFault Calculate balanced three-phase fault current.
% All inputs and the output are in per-unit.
% Vth_pu: Prefault Thevenin voltage in per-unit.
% Z1th_pu: Positive-sequence Thevenin impedance in per-unit.
% Zf_pu: Fault impedance in per-unit.

    validateattributes(Vth_pu, {'numeric'}, ...
        {'scalar','finite'});
    validateattributes(Z1th_pu, {'numeric'}, ...
        {'scalar','finite'});
    validateattributes(Zf_pu, {'numeric'}, ...
        {'scalar','finite'});

    Ztotal = Z1th_pu + Zf_pu;

    if abs(Ztotal) < eps
        error('calculateThreePhaseFault:ZeroImpedance', ...
            'Total fault-path impedance must be nonzero.');
    end

    If_pu = Vth_pu / Ztotal;
end
