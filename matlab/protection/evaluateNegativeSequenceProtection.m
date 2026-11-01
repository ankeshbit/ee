function result = evaluateNegativeSequenceProtection(currents_A, settings)
% evaluateNegativeSequenceProtection ANSI 46 Phase Unbalance / Negative-Sequence Overcurrent.
%
% Computes the negative-sequence current I2 from three-phase current phasors
% and evaluates against thermal unbalance thresholds: I2^2 * t = K or definite time.
%
% Syntax:
%   result = evaluateNegativeSequenceProtection(currents_A, settings)
%
% Inputs:
%   currents_A - 3-element vector of complex phase current phasors [Ia, Ib, Ic] in amperes.
%   settings   - Struct with fields:
%                  enabled        : (logical) enable flag (default: true)
%                  pickupCurrent_A: (positive scalar) negative-sequence pickup in primary amperes
%                  thermalK       : (optional positive scalar) generator/system constant for I2^2 * t = K
%                  definiteDelay_s: (optional positive scalar) definite time delay (default: 1.0 s)
%                  mode           : 'thermal' or 'definite' (default: 'definite')
%
% Outputs:
%   result     - Struct with fields:
%                  operates          : (logical) true if I2 >= pickup
%                  tripStatus        : 'TRIPPED' or 'NO_TRIP'
%                  operatingTime_s   : double, operating delay in seconds (Inf if no trip)
%                  I2_magnitude_A    : double, negative-sequence current magnitude
%                  I1_magnitude_A    : double, positive-sequence current magnitude
%                  unbalanceRatio_pct: double, 100 * (I2 / I1)

    if nargin < 2 || isempty(settings)
        settings = struct();
    end
    if ~isstruct(settings) || ~isscalar(settings)
        error('evaluateNegativeSequenceProtection:InvalidSettings', 'settings must be a scalar struct.');
    end

    if isempty(currents_A) || ~isnumeric(currents_A) || ~isvector(currents_A) || numel(currents_A) ~= 3 || any(~isfinite(currents_A(:)))
        error('evaluateNegativeSequenceProtection:InvalidCurrent', ...
            'currents_A must be a 3-element finite numeric array [Ia, Ib, Ic].');
    end

    enabled = true;
    if isfield(settings, 'enabled') && ~isempty(settings.enabled)
        if ~islogical(settings.enabled) && ~(isnumeric(settings.enabled) && isscalar(settings.enabled) && (settings.enabled == 0 || settings.enabled == 1))
            error('evaluateNegativeSequenceProtection:InvalidEnabled', 'settings.enabled must be a scalar logical.');
        end
        enabled = logical(settings.enabled);
    end

    if ~isfield(settings, 'pickupCurrent_A') || isempty(settings.pickupCurrent_A) || ...
       ~isnumeric(settings.pickupCurrent_A) || ~isscalar(settings.pickupCurrent_A) || ...
       ~isreal(settings.pickupCurrent_A) || ~isfinite(settings.pickupCurrent_A) || settings.pickupCurrent_A <= 0
        error('evaluateNegativeSequenceProtection:InvalidPickup', ...
            'settings.pickupCurrent_A must be a finite, positive scalar.');
    end
    pickup_A = double(settings.pickupCurrent_A);

    mode = 'definite';
    if isfield(settings, 'mode') && ~isempty(settings.mode)
        if ~ischar(settings.mode) && ~isstring(settings.mode)
            error('evaluateNegativeSequenceProtection:InvalidMode', 'settings.mode must be a char or string.');
        end
        mode = lower(strtrim(char(settings.mode)));
        if ~any(strcmp(mode, {'definite', 'thermal'}))
            error('evaluateNegativeSequenceProtection:InvalidMode', ...
                'Unsupported settings.mode "%s". Must be ''definite'' or ''thermal''.', mode);
        end
    end

    definiteDelay_s = 1.0;
    if isfield(settings, 'definiteDelay_s') && ~isempty(settings.definiteDelay_s)
        if ~isnumeric(settings.definiteDelay_s) || ~isscalar(settings.definiteDelay_s) || ...
           ~isreal(settings.definiteDelay_s) || ~isfinite(settings.definiteDelay_s) || settings.definiteDelay_s < 0
            error('evaluateNegativeSequenceProtection:InvalidDefiniteDelay', ...
                'settings.definiteDelay_s must be a finite non-negative scalar.');
        end
        definiteDelay_s = double(settings.definiteDelay_s);
    end

    thermalK = 10.0;
    if isfield(settings, 'thermalK') && ~isempty(settings.thermalK)
        if ~isnumeric(settings.thermalK) || ~isscalar(settings.thermalK) || ...
           ~isreal(settings.thermalK) || ~isfinite(settings.thermalK) || settings.thermalK <= 0
            error('evaluateNegativeSequenceProtection:InvalidThermalK', ...
                'settings.thermalK must be a finite positive scalar.');
        end
        thermalK = double(settings.thermalK);
    end

    % Calculate sequence components using Fortescue transformation
    I_fund = currents_A(1:3);
    I_seq = calculateSequenceComponents(I_fund(:));
    if isstruct(I_seq)
        I0 = abs(I_seq.V0);
        I1 = abs(I_seq.V1);
        I2 = abs(I_seq.V2);
    else
        I0 = abs(I_seq(1));
        I1 = abs(I_seq(2));
        I2 = abs(I_seq(3));
    end

    if I1 > 1e-6
        unbalanceRatio_pct = 100.0 * (I2 / I1);
    else
        if I2 > 1e-6
            unbalanceRatio_pct = Inf; % Pure negative-sequence: infinite unbalance ratio
        else
            unbalanceRatio_pct = 0.0; % Zero current: 0% unbalance
        end
    end

    operates = enabled && (I2 >= pickup_A);

    if operates
        if strcmp(mode, 'thermal')
            % t = K / (I2 / Inom)^2 or t = K / I2^2
            top = max(0.05, thermalK / max(eps, (I2 / pickup_A)^2));
        else
            top = definiteDelay_s;
        end
        tripStatus = 'TRIPPED';
    else
        top = Inf;
        tripStatus = 'NO_TRIP';
    end

    result = struct();
    result.operates           = operates;
    result.tripStatus         = tripStatus;
    result.operatingTime_s    = top;
    result.I2_magnitude_A     = I2;
    result.I1_magnitude_A     = I1;
    result.unbalanceRatio_pct = unbalanceRatio_pct;
    result.pickupCurrent_A    = pickup_A;
    result.mode               = mode;
    result.enabled            = enabled;
end
