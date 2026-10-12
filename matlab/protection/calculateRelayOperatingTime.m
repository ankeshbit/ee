function operatingTime_s = calculateRelayOperatingTime( ...
    relayCurrent_A, pickupCurrent_A, TMS, curveType)
% calculateRelayOperatingTime Calculate an IEC inverse-time relay delay.
% Inputs:
%   relayCurrent_A  - RMS relay current in amperes.
%   pickupCurrent_A - Relay pickup threshold in amperes.
%   TMS             - Positive time multiplier setting.
%   curveType       - IEC curve name or alias.
% Output:
%   operatingTime_s - Operating time in seconds, or Inf when the relay
%                     does not pick up under the steady-state model.
%
% Supported curve names are Standard Inverse (SI), Very Inverse (VI), and
% Extremely Inverse (EI). Curve-name matching is case-insensitive.

validateCurrent(relayCurrent_A, 'relayCurrent_A');
validatePickupCurrent(pickupCurrent_A);
validateTMS(TMS);

curveName = normalizeCurveType(curveType);

if relayCurrent_A <= pickupCurrent_A
    operatingTime_s = Inf;
    return;
end

M = relayCurrent_A / pickupCurrent_A;

switch curveName
    case 'standard inverse'
        k = 0.14;
        alpha = 0.02;
    case 'very inverse'
        k = 13.5;
        alpha = 1;
    case 'extremely inverse'
        k = 80;
        alpha = 2;
end

operatingTime_s = TMS * k / (M^alpha - 1);
end

function validateCurrent(value, name)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value < 0
    error('calculateRelayOperatingTime:InvalidCurrent', ...
        '%s must be a finite, real, nonnegative numeric scalar.', name);
end
end

function validatePickupCurrent(value)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value <= 0
    error('calculateRelayOperatingTime:InvalidPickupCurrent', ...
        'pickupCurrent_A must be a finite, real, positive numeric scalar.');
end
end

function validateTMS(value)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value <= 0
    error('calculateRelayOperatingTime:InvalidTMS', ...
        'TMS must be a finite, real, positive numeric scalar.');
end
end

function curveName = normalizeCurveType(curveType)
if ischar(curveType)
    if ~isrow(curveType) || isempty(curveType)
        error('calculateRelayOperatingTime:InvalidCurveType', ...
            'curveType must be a nonempty character vector or scalar string.');
    end
    curveName = lower(strtrim(curveType));
elseif isstring(curveType)
    if ~isscalar(curveType) || ismissing(curveType) || ...
            strlength(curveType) == 0
        error('calculateRelayOperatingTime:InvalidCurveType', ...
            'curveType must be a nonempty character vector or scalar string.');
    end
    curveName = lower(strtrim(char(curveType)));
else
    error('calculateRelayOperatingTime:InvalidCurveType', ...
        'curveType must be a nonempty character vector or scalar string.');
end

switch curveName
    case {'standard inverse', 'si'}
        curveName = 'standard inverse';
    case {'very inverse', 'vi'}
        curveName = 'very inverse';
    case {'extremely inverse', 'ei'}
        curveName = 'extremely inverse';
    otherwise
        error('calculateRelayOperatingTime:UnsupportedCurve', ...
            'Unsupported IEC curve type: %s.', curveName);
end
end
