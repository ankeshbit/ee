function result = evaluateDirectionalSupervision(settings, faultData)
% evaluateDirectionalSupervision Apply only defensible phasor-based inputs.
% The integrated radial study does not currently provide polarizing voltage
% phasors, so its default result is explicit unsupported status.

if nargin < 1 || isempty(settings)
    settings = struct();
end
if ~isstruct(settings) || ~isscalar(settings)
    error('evaluateDirectionalSupervision:InvalidSettings', ...
        'settings must be a scalar structure.');
end
result.status = 'unsupported';
result.reason = 'Polarizing voltage and relay reference phasors are unavailable.';
result.currentReference = '';
result.voltageReference = '';
result.characteristicAngle_deg = [];

if isfield(settings, 'enabled') && settings.enabled
    required = {'currentPhasor', 'polarizingVoltagePhasor'};
    if ~isstruct(faultData) || any(~isfield(faultData, required))
        result.status = 'unsupported';
        result.reason = 'Directional phasor inputs are incomplete.';
        return;
    end
    validateattributes(settings.characteristicAngle_deg, {'numeric'}, ...
        {'scalar', 'real', 'finite'});
    I = faultData.currentPhasor;
    V = faultData.polarizingVoltagePhasor;
    if ~isnumeric(I) || ~isscalar(I) || ~isnumeric(V) || ~isscalar(V)
        error('evaluateDirectionalSupervision:InvalidPhasor', ...
            'Directional phasors must be numeric scalars.');
    end
    if abs(V) <= eps
        result.status = 'indeterminate';
        result.reason = 'Polarizing voltage is zero.';
        return;
    end
    torque = real(I * conj(V) * exp(-1i * ...
        deg2rad(settings.characteristicAngle_deg)));
    result.status = ternary(torque >= 0, 'forward', 'reverse');
    result.reason = 'Simplified polarizing torque criterion.';
    result.currentReference = 'Configured relay current reference';
    result.voltageReference = 'Configured polarizing voltage reference';
    result.characteristicAngle_deg = settings.characteristicAngle_deg;
end
end

function value = ternary(condition, trueValue, falseValue)
if condition
    value = trueValue;
else
    value = falseValue;
end
end
