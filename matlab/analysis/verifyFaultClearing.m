function cv = verifyFaultClearing(t, iBusB, tFault, openTimeB, openTimeA, thresh, fNom)
% verifyFaultClearing Verify fault current extinction following breaker operation.
%
% Uses sliding one-cycle RMS per phase and requires RMS current on all
% phases to drop below thresh and persist below thresh for at least one full
% cycle (1 / fNom).
%
% Syntax:
%   cv = verifyFaultClearing(t, iBusB, tFault, openTimeB, openTimeA, thresh, fNom)
%
% Outputs:
%   cv - Struct with fields:
%        faultCleared              : Boolean (true ONLY when verified extinct and persisted)
%        extinctionTime_s          : Double (time of extinction, or NaN)
%        postClearingCurrentPeak_A : Double (peak current post clearing, or NaN)
%        extinctionThreshold_A     : Double (threshold used)
%        status                    : Char ('CLEARED', 'NOT_CLEARED', 'INSUFFICIENT_DATA', 'INVALID_INPUT')
%        explanation               : Char describing outcome

    % 1. Parameter defaults & input validation
    if nargin < 6 || isempty(thresh), thresh = 0.01; end
    if nargin < 7 || isempty(fNom),   fNom   = 50.0; end

    if ~isnumeric(thresh) || ~isscalar(thresh) || ~isreal(thresh) || ~isfinite(thresh) || thresh <= 0
        cv = p_makeResult(false, NaN, NaN, 0.01, 'INVALID_INPUT', 'extinctionThreshold_A must be a positive finite scalar.');
        return;
    end
    if ~isnumeric(fNom) || ~isscalar(fNom) || ~isreal(fNom) || ~isfinite(fNom) || fNom <= 0
        cv = p_makeResult(false, NaN, NaN, thresh, 'INVALID_INPUT', 'fNom must be a positive finite scalar.');
        return;
    end

    % 2. Validate time vector
    if isempty(t) || ~isnumeric(t) || ~isvector(t)
        cv = p_makeResult(false, NaN, NaN, thresh, 'INVALID_INPUT', 'Time vector is empty or not a numeric vector.');
        return;
    end
    t = double(t(:));
    nT = numel(t);
    if nT < 2 || any(~isfinite(t)) || any(diff(t) <= 0)
        cv = p_makeResult(false, NaN, NaN, thresh, 'INVALID_INPUT', 'Time vector must have at least 2 finite, strictly increasing samples.');
        return;
    end

    % 3. Validate phase currents
    if isempty(iBusB) || ~isnumeric(iBusB)
        cv = p_makeResult(false, NaN, NaN, thresh, 'INVALID_INPUT', 'Phase current waveform is empty or not numeric.');
        return;
    end
    if size(iBusB, 1) ~= nT && size(iBusB, 2) == nT
        iBusB = iBusB.';
    end
    if size(iBusB, 1) ~= nT
        cv = p_makeResult(false, NaN, NaN, thresh, 'INVALID_INPUT', ...
            sprintf('Phase current row count (%d) does not match time vector length (%d).', size(iBusB, 1), nT));
        return;
    end
    if any(~isfinite(iBusB(:)))
        cv = p_makeResult(false, NaN, NaN, thresh, 'INVALID_INPUT', 'Phase currents contain non-finite (NaN or Inf) values.');
        return;
    end

    % 4. Validate fault inception time
    if nargin < 3 || isempty(tFault)
        tFault = t(1);
    elseif ~isnumeric(tFault) || ~isscalar(tFault) || ~isreal(tFault) || ~isfinite(tFault)
        cv = p_makeResult(false, NaN, NaN, thresh, 'INVALID_INPUT', 'tFault must be a finite real scalar.');
        return;
    end

    if nargin < 4, openTimeB = []; end
    if nargin < 5, openTimeA = []; end

    Tc = 1.0 / fNom;
    nPh = size(iBusB, 2);

    % 5. Compute sliding one-cycle RMS per phase
    rmsPhases = zeros(nT, nPh);
    for p = 1:nPh
        ip = iBusB(:, p);
        F = cumtrapz(t, ip.^2);
        F_del = interp1(t, F, t - Tc, 'linear', 0);
        dtWin = min(t - t(1), Tc);
        dtWin(dtWin <= 0) = eps;
        rmsPhases(:, p) = sqrt(max(0, F - F_del) ./ dtWin);
    end
    maxRMS = max(rmsPhases, [], 2);

    % 6. Determine search reference time from breaker opening
    validOpen = [];
    if ~isempty(openTimeB) && isnumeric(openTimeB)
        vB = openTimeB(isfinite(openTimeB) & openTimeB >= tFault);
        validOpen = [validOpen; vB(:)]; %#ok<AGROW>
    end
    if ~isempty(openTimeA) && isnumeric(openTimeA)
        vA = openTimeA(isfinite(openTimeA) & openTimeA >= tFault);
        validOpen = [validOpen; vA(:)]; %#ok<AGROW>
    end

    if isempty(validOpen)
        % Breaker opening not specified: check from fault inception
        bestOpen = tFault;
    else
        bestOpen = min(validOpen);
    end

    postFaultIdx = find(t >= tFault);
    if isempty(postFaultIdx)
        cv = p_makeResult(false, NaN, NaN, thresh, 'INSUFFICIENT_DATA', ...
            'Simulation contains no samples at or after fault inception.');
        return;
    end

    % Default peak after fault inception
    recentSamples = find(t > tFault + 0.01);
    if isempty(recentSamples)
        postPeak = max(abs(iBusB(postFaultIdx, :)), [], 'all');
    else
        postPeak = max(abs(iBusB(recentSamples, :)), [], 'all');
    end

    % 7. Search for extinction persisting for at least 1 full cycle
    isLow = (maxRMS < thresh);
    candidateIdx = find(t >= bestOpen & isLow);

    faultCleared = false;
    extinctTime  = NaN;
    insufficientData = false;

    for idx = candidateIdx'
        tk = t(idx);
        if tk + Tc <= t(end)
            persistMask = (t >= tk & t <= tk + Tc);
            if all(isLow(persistMask))
                faultCleared = true;
                extinctTime  = max(bestOpen, tk - Tc);
                break;
            end
        else
            % Simulation ended before full cycle persistence could be evaluated
            insufficientData = true;
        end
    end

    if ~faultCleared && ~insufficientData
        if t(end) < bestOpen + Tc
            insufficientData = true;
        end
    end

    if faultCleared
        postExtMask = (t > extinctTime & t <= extinctTime + 2 * Tc);
        if any(postExtMask)
            postPeak = max(abs(iBusB(postExtMask, :)), [], 'all');
        else
            postPeak = 0;
        end
        status = 'CLEARED';
        explanation = sprintf('Current extinguished at %.4f s and persisted below %.4f A threshold.', ...
            extinctTime, thresh);
    elseif insufficientData
        status = 'INSUFFICIENT_DATA';
        explanation = 'Simulation ended before current extinction could be verified for a complete cycle.';
    else
        status = 'NOT_CLEARED';
        explanation = sprintf('Fault current failed to extinguish below %.4f A threshold.', thresh);
    end

    cv = p_makeResult(faultCleared, extinctTime, postPeak, thresh, status, explanation);
end

function cv = p_makeResult(cleared, extTime, postPeak, thresh, status, msg)
    cv = struct('faultCleared',              cleared, ...
                'extinctionTime_s',          extTime, ...
                'postClearingCurrentPeak_A', postPeak, ...
                'extinctionThreshold_A',     thresh, ...
                'status',                    status, ...
                'explanation',               msg);
end
