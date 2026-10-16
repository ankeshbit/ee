function margin_s = computeCoordinationMargin(tBackupRelay_s, tPrimaryRelay_s, tPrimaryBreakerOpening_s)
% computeCoordinationMargin Compute protection coordination margin.
%
% Formula:
%   margin_s = t_backup_relay - (t_primary_relay + t_primary_breaker_opening)
%
% Rules:
%   Returns NaN if any of the three times is non-finite (~isfinite), NaN, or empty.
%   Never returns Inf or -Inf.

    if nargin < 3 || isempty(tBackupRelay_s) || isempty(tPrimaryRelay_s) || isempty(tPrimaryBreakerOpening_s)
        margin_s = NaN;
        return;
    end

    if ~isfinite(tBackupRelay_s) || ~isfinite(tPrimaryRelay_s) || ~isfinite(tPrimaryBreakerOpening_s)
        margin_s = NaN;
        return;
    end

    margin_s = tBackupRelay_s - (tPrimaryRelay_s + tPrimaryBreakerOpening_s);
    if ~isfinite(margin_s)
        margin_s = NaN;
    end
end
