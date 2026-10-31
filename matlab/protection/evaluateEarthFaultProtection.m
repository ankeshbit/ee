function result = evaluateEarthFaultProtection(currents_A, settings)
% evaluateEarthFaultProtection ANSI 50N / 51N Earth-Fault (Ground Overcurrent) Protection.
%
% Evaluates residual earth current (3*I0 = Ia + Ib + Ic) or neutral current against
% instantaneous (50N) and inverse-time (51N) earth-fault elements.
%
% Syntax:
%   result = evaluateEarthFaultProtection(currents_A, settings)
%
% Inputs:
%   currents_A - Three-phase current phasors [Ia, Ib, Ic] or scalar neutral/residual current in amperes.
%   settings   - Struct with fields:
%                  enabled        : (logical) enable flag (default: true)
%                  pickupCurrent_A: (positive scalar) earth-fault pickup in primary amperes
%                  curveType      : IEC curve type ('standard inverse', 'very inverse', 'extremely inverse', or 'definite')
%                  TMS            : Time multiplier setting (positive scalar, default: 0.1)
%                  instPickup_A   : (optional) ANSI 50N instantaneous pickup threshold (default: Inf)
%
% Outputs:
%   result     - Struct with fields:
%                  operates           : (logical) true if either 51N or 50N trips
%                  tripStatus         : 'TRIPPED' or 'NO_TRIP'
%                  operatingTime_s    : double, overall operating time in seconds
%                  residualCurrent_A  : double, magnitude of 3*I0
%                  zeroSequence_A     : double, magnitude of I0
%                  operatingElement   : 'NONE', '50N_INSTANTANEOUS', or '51N_TIME_OVERCURRENT'

    if nargin < 2 || isempty(settings)
        settings = struct();
    end
    if ~isstruct(settings) || ~isscalar(settings)
        error('evaluateEarthFaultProtection:InvalidSettings', 'settings must be a scalar struct.');
    end

    if isempty(currents_A) || ~isnumeric(currents_A) || any(~isfinite(currents_A(:)))
        error('evaluateEarthFaultProtection:InvalidCurrent', 'currents_A must be a finite numeric array.');
    end

    enabled = true;
    if isfield(settings, 'enabled') && ~isempty(settings.enabled)
        enabled = logical(settings.enabled);
    end

    if ~isfield(settings, 'pickupCurrent_A') || isempty(settings.pickupCurrent_A) || ...
       ~isnumeric(settings.pickupCurrent_A) || ~isscalar(settings.pickupCurrent_A) || ...
       ~isreal(settings.pickupCurrent_A) || ~isfinite(settings.pickupCurrent_A) || settings.pickupCurrent_A <= 0
        error('evaluateEarthFaultProtection:InvalidPickup', ...
            'settings.pickupCurrent_A must be a finite, positive scalar.');
    end
    pickup_A = double(settings.pickupCurrent_A);

    curveType = 'standard inverse';
    if isfield(settings, 'curveType') && ~isempty(settings.curveType)
        curveType = char(settings.curveType);
    end

    TMS = 0.10;
    if isfield(settings, 'TMS') && ~isempty(settings.TMS)
        if ~isnumeric(settings.TMS) || ~isscalar(settings.TMS) || ~isreal(settings.TMS) || ...
           ~isfinite(settings.TMS) || settings.TMS <= 0
            error('evaluateEarthFaultProtection:InvalidTMS', 'settings.TMS must be a finite positive scalar.');
        end
        TMS = double(settings.TMS);
    end

    instPickup_A = Inf;
    if isfield(settings, 'instPickup_A') && ~isempty(settings.instPickup_A)
        if isnumeric(settings.instPickup_A) && isscalar(settings.instPickup_A) && ...
           isreal(settings.instPickup_A) && isfinite(settings.instPickup_A) && settings.instPickup_A > 0
            instPickup_A = double(settings.instPickup_A);
        end
    end

    % Calculate residual current 3*I0
    if numel(currents_A) >= 3
        c = currents_A(1:3);
        I_residual = abs(sum(c)); % Ia + Ib + Ic
        I0 = I_residual / 3.0;
    else
        I_residual = abs(currents_A(1));
        I0 = I_residual / 3.0;
    end

    result = struct();
    result.residualCurrent_A = I_residual;
    result.zeroSequence_A    = I0;
    result.pickupCurrent_A   = pickup_A;
    result.instPickup_A      = instPickup_A;
    result.curveType         = curveType;
    result.TMS               = TMS;
    result.enabled           = enabled;

    if ~enabled || I_residual <= 0
        result.operates = false;
        result.tripStatus = 'NO_TRIP';
        result.operatingTime_s = Inf;
        result.operatingElement = 'NONE';
        return;
    end

    % Check 50N (instantaneous)
    if I_residual >= instPickup_A
        result.operates = true;
        result.tripStatus = 'TRIPPED';
        result.operatingTime_s = 0.020; % 20 ms instantaneous operation
        result.operatingElement = '50N_INSTANTANEOUS';
        return;
    end

    % Check 51N (inverse time)
    if I_residual > pickup_A
        if strcmpi(curveType, 'definite')
            top = TMS; % treat TMS as definite time delay in seconds
        else
            top = calculateRelayOperatingTime(I_residual, pickup_A, TMS, curveType);
        end
        result.operates = true;
        result.tripStatus = 'TRIPPED';
        result.operatingTime_s = top;
        result.operatingElement = '51N_TIME_OVERCURRENT';
    else
        result.operates = false;
        result.tripStatus = 'NO_TRIP';
        result.operatingTime_s = Inf;
        result.operatingElement = 'NONE';
    end
end

