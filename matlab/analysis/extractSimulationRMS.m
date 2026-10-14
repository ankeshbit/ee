function rmsResult = extractSimulationRMS(time_s, signal, window)
% extractSimulationRMS Extract true RMS, peak transient, and windowed statistics.
%
% Syntax:
%   rmsResult = extractSimulationRMS(time_s, signal, window)
%
% Inputs:
%   time_s  - Monotonically increasing time vector (N-by-1).
%   signal  - Instantaneous values (N-by-1 or N-by-M for multi-phase signals).
%   window  - Window struct returned by validateMeasurementWindow.
%
% Outputs:
%   rmsResult - Struct containing:
%               steadyStateRMS  - 1-by-M steady-state RMS value(s) over window
%               peakTransient   - 1-by-M maximum absolute value during entire fault
%               prefaultRMS     - 1-by-M prefault RMS value(s)
%               isValid         - Boolean indicating calculation success

    validateattributes(time_s, {'numeric'}, {'vector', 'finite'}, ...
        'extractSimulationRMS', 'time_s');
    validateattributes(signal, {'numeric'}, {'2d', 'finite'}, ...
        'extractSimulationRMS', 'signal');
    validateattributes(window, {'struct'}, {'scalar'}, ...
        'extractSimulationRMS', 'window');

    time_s = time_s(:);
    nTime = numel(time_s);

    if size(signal, 1) ~= nTime
        if size(signal, 2) == nTime
            signal = signal.';
        else
            error('extractSimulationRMS:DimensionMismatch', ...
                'Signal first dimension (%d) must match length of time vector (%d).', ...
                size(signal, 1), nTime);
        end
    end

    nSignals = size(signal, 2);
    rmsResult = struct();
    rmsResult.steadyStateRMS = NaN(1, nSignals);
    rmsResult.peakTransient = NaN(1, nSignals);
    rmsResult.prefaultRMS = NaN(1, nSignals);
    rmsResult.isValid = false;

    if ~window.isValid || isempty(window.steadyStateIndices)
        return;
    end

    % 1. Steady-state RMS using trapezoidal integration over window
    idxSS = window.steadyStateIndices;
    tSS = time_s(idxSS);
    sigSS = signal(idxSS, :);
    durationSS = tSS(end) - tSS(1);

    if durationSS <= 0
        return;
    end

    ssRMS = zeros(1, nSignals);
    for col = 1:nSignals
        integratedSquare = trapz(tSS, sigSS(:, col).^2);
        ssRMS(col) = sqrt(integratedSquare / durationSS);
    end
    rmsResult.steadyStateRMS = ssRMS;

    % 2. Peak transient over entire fault duration
    if ~isempty(window.faultWindowIndices)
        idxFault = window.faultWindowIndices;
        sigFault = signal(idxFault, :);
        rmsResult.peakTransient = max(abs(sigFault), [], 1);
    else
        rmsResult.peakTransient = max(abs(sigSS), [], 1);
    end

    % 3. Prefault RMS if prefault window available
    if ~isempty(window.prefaultIndices) && numel(window.prefaultIndices) >= 2
        idxPre = window.prefaultIndices;
        tPre = time_s(idxPre);
        sigPre = signal(idxPre, :);
        durPre = tPre(end) - tPre(1);
        if durPre > 0
            preRMS = zeros(1, nSignals);
            for col = 1:nSignals
                preRMS(col) = sqrt(trapz(tPre, sigPre(:, col).^2) / durPre);
            end
            rmsResult.prefaultRMS = preRMS;
        end
    end

    rmsResult.isValid = true;
end
