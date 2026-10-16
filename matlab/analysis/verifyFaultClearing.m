function cv = verifyFaultClearing(t, iBusB, tFault, openTimeB, openTimeA, thresh, fNom)
% verifyFaultClearing Verify fault current extinction following breaker operation.
%
% Uses a sliding one-cycle RMS per phase and requires the RMS current on all
% phases to drop below thresh and persist below thresh for at least one full
% cycle (1 / fNom).
%
% Syntax:
%   cv = verifyFaultClearing(t, iBusB, tFault, openTimeB, openTimeA, thresh, fNom)

    if nargin < 3 || isempty(tFault), tFault = t(1); end
    if nargin < 4, openTimeB = []; end
    if nargin < 5, openTimeA = []; end
    if nargin < 6 || isempty(thresh), thresh = 0.01; end
    if nargin < 7 || isempty(fNom), fNom = 50.0; end

    t = t(:);
    nT = numel(t);
    if size(iBusB, 1) ~= nT && size(iBusB, 2) == nT
        iBusB = iBusB.';
    end

    Tc = 1.0 / fNom;
    nPh = size(iBusB, 2);

    % Compute sliding one-cycle RMS per phase
    rmsPhases = zeros(nT, nPh);
    for p = 1:nPh
        F = cumtrapz(t, iBusB(:, p).^2);
        F_del = interp1(t, F, t - Tc, 'linear', 0);
        dtWin = min(t - t(1), Tc);
        dtWin(dtWin <= 0) = eps;
        rmsPhases(:, p) = sqrt(max(0, F - F_del) ./ dtWin);
    end
    maxRMS = max(rmsPhases, [], 2);

    faultCleared = false;
    extinctTime  = NaN;
    postPeak     = max(abs(iBusB(t > tFault + 0.01, :)), [], 'all');

    % Determine search reference time from breaker opening
    if isempty(openTimeB) && isempty(openTimeA)
        bestOpen = tFault;
    else
        bestOpen = min([openTimeB, openTimeA], [], 'omitnan');
    end

    if ~isnan(bestOpen)
        isLow = (maxRMS < thresh);
        candidateIdx = find(t >= bestOpen & isLow);
        for idx = candidateIdx'
            tk = t(idx);
            if tk + Tc <= t(end)
                persistMask = (t >= tk & t <= tk + Tc);
                if all(isLow(persistMask))
                    faultCleared = true;
                    extinctTime  = max(bestOpen, tk - Tc);
                    break;
                end
            end
        end

        if faultCleared
            postExtMask = (t > extinctTime & t <= extinctTime + 0.04);
            if any(postExtMask)
                postPeak = max(abs(iBusB(postExtMask, :)), [], 'all');
            else
                postPeak = 0;
            end
        end
    end

    cv = struct('faultCleared',              faultCleared, ...
                'extinctionTime_s',          extinctTime, ...
                'postClearingCurrentPeak_A', postPeak, ...
                'extinctionThreshold_A',     thresh);
end
