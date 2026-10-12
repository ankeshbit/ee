function result = calculateBreakerClearingTime(relayOperatingTime_s, ...
    breakerOpeningDelay_s)
% calculateBreakerClearingTime Separate relay time from breaker opening delay.

validateattributes(relayOperatingTime_s, {'numeric'}, ...
    {'scalar', 'real', 'nonnegative'});
if ~(isfinite(relayOperatingTime_s) || isinf(relayOperatingTime_s))
    error('calculateBreakerClearingTime:InvalidRelayTime', ...
        'relayOperatingTime_s must be a nonnegative finite value or Inf.');
end
validateattributes(breakerOpeningDelay_s, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});

result.relayOperatingTime_s = relayOperatingTime_s;
result.breakerOpeningDelay_s = breakerOpeningDelay_s;
if isinf(relayOperatingTime_s)
    result.totalClearingTime_s = Inf;
else
    result.totalClearingTime_s = relayOperatingTime_s + ...
        breakerOpeningDelay_s;
end
end
