function result = screenCTSaturation(faultCurrentPrimary_A, relay, threshold)
% screenCTSaturation Screen configured CT-current limits.
% This is not a CT electromagnetic saturation simulation.

validateattributes(faultCurrentPrimary_A, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
if ~isstruct(relay) || ~isscalar(relay) || ...
        ~isfield(relay, 'CTprimary_A') || ~isfield(relay, 'CTsecondary_A')
    error('screenCTSaturation:InvalidRelay', ...
        'relay must contain CTprimary_A and CTsecondary_A.');
end
validateattributes(relay.CTprimary_A, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(relay.CTsecondary_A, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});

result.status = 'insufficientData';
result.primaryMultiple = faultCurrentPrimary_A / relay.CTprimary_A;
result.secondaryCurrent_A = convertPrimaryToSecondaryCurrent( ...
    faultCurrentPrimary_A, relay.CTprimary_A, relay.CTsecondary_A);
result.threshold_A = [];
result.warning = 'No configured CT screening threshold; saturation is not assessed.';

if nargin >= 3 && ~isempty(threshold)
    validateattributes(threshold, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    result.threshold_A = threshold;
    if result.secondaryCurrent_A > threshold
        result.status = 'exceedsConfiguredThreshold';
        result.warning = ['Threshold exceedance is a screening warning, not ', ...
            'proof of CT saturation.'];
    else
        result.status = 'withinConfiguredLimits';
        result.warning = ['Remaining below the threshold is not proof that ', ...
            'CT saturation cannot occur.'];
    end
end
end
