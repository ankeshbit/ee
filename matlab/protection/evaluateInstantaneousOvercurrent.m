function result = evaluateInstantaneousOvercurrent(current_A, settings)
% evaluateInstantaneousOvercurrent ANSI 50 Instantaneous Overcurrent Protection.
%
% Syntax:
%   result = evaluateInstantaneousOvercurrent(current_A, settings)
%
% Inputs:
%   current_A - Measured phase or peak RMS current in amperes (scalar or 3-phase vector).
%   settings  - Struct with fields:
%                 enabled        : (logical) enable flag (default: true)
%                 pickupCurrent_A: (positive scalar) instantaneous threshold in primary amperes
%                 operatingDelay_s: (optional scalar) intentional delay (default: 0.0 s)
%
% Outputs:
%   result    - Struct with fields:
%                 operates         : (logical) true if current >= pickup
%                 tripStatus       : 'TRIPPED' or 'NO_TRIP'
%                 operatingTime_s  : double, operating delay in seconds (Inf if no trip)
%                 measuredCurrent_A: double, maximum measured current
%                 pickupCurrent_A  : double, pickup current threshold
%                 pickupRatio      : double, measuredCurrent_A / pickupCurrent_A

    if nargin < 2 || isempty(settings)
        settings = struct();
    end
    if ~isstruct(settings) || ~isscalar(settings)
        error('evaluateInstantaneousOvercurrent:InvalidSettings', 'settings must be a scalar struct.');
    end

    if isempty(current_A) || ~isnumeric(current_A) || any(~isfinite(current_A(:)))
        error('evaluateInstantaneousOvercurrent:InvalidCurrent', 'current_A must be a finite numeric array.');
    end

    enabled = true;
    if isfield(settings, 'enabled') && ~isempty(settings.enabled)
        enabled = logical(settings.enabled);
    end

    if ~isfield(settings, 'pickupCurrent_A') || isempty(settings.pickupCurrent_A) || ...
       ~isnumeric(settings.pickupCurrent_A) || ~isscalar(settings.pickupCurrent_A) || ...
       ~isreal(settings.pickupCurrent_A) || ~isfinite(settings.pickupCurrent_A) || settings.pickupCurrent_A <= 0
        error('evaluateInstantaneousOvercurrent:InvalidPickup', ...
            'settings.pickupCurrent_A must be a finite, positive scalar.');
    end
    pickup_A = double(settings.pickupCurrent_A);

    delay_s = 0.0;
    if isfield(settings, 'operatingDelay_s') && ~isempty(settings.operatingDelay_s)
        if ~isnumeric(settings.operatingDelay_s) || ~isscalar(settings.operatingDelay_s) || ...
           ~isreal(settings.operatingDelay_s) || ~isfinite(settings.operatingDelay_s) || settings.operatingDelay_s < 0
            error('evaluateInstantaneousOvercurrent:InvalidDelay', ...
                'settings.operatingDelay_s must be a finite, non-negative scalar.');
        end
        delay_s = double(settings.operatingDelay_s);
    end

    I_max = max(abs(current_A(:)));
    pickupRatio = I_max / pickup_A;

    operates = enabled && (I_max >= pickup_A);

    result = struct();
    result.operates          = operates;
    result.tripStatus        = p_ternary(operates, 'TRIPPED', 'NO_TRIP');
    result.operatingTime_s   = p_ternary(operates, delay_s, Inf);
    result.measuredCurrent_A = I_max;
    result.pickupCurrent_A   = pickup_A;
    result.pickupRatio       = pickupRatio;
    result.enabled           = enabled;
end

function v = p_ternary(cond, tVal, fVal)
    if cond, v = tVal; else, v = fVal; end
end

