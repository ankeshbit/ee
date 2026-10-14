function phasorResult = estimateFundamentalPhasor(time_s, signal, window)
% estimateFundamentalPhasor Estimate fundamental-frequency complex phasor via Fourier integral.
%
% Syntax:
%   phasorResult = estimateFundamentalPhasor(time_s, signal, window)
%
% Inputs:
%   time_s  - Monotonically increasing time vector (N-by-1).
%   signal  - Instantaneous values (N-by-1 or N-by-3 for three-phase signals).
%   window  - Window struct returned by validateMeasurementWindow.
%
% Outputs:
%   phasorResult - Struct containing:
%                  phasorRMS         - Complex RMS phasor(s) (1-by-M)
%                  magnitudeRMS      - Magnitude in RMS units (1-by-M)
%                  angle_deg         - Phase angle in degrees (1-by-M)
%                  sequencePhasors   - (if 3-phase) Struct with V0/I0, V1/I1, V2/I2
%                  isValid           - Boolean indicating calculation success

    validateattributes(time_s, {'numeric'}, {'vector', 'finite'}, ...
        'estimateFundamentalPhasor', 'time_s');
    validateattributes(signal, {'numeric'}, {'2d', 'finite'}, ...
        'estimateFundamentalPhasor', 'signal');
    validateattributes(window, {'struct'}, {'scalar'}, ...
        'estimateFundamentalPhasor', 'window');

    time_s = time_s(:);
    nTime = numel(time_s);

    if size(signal, 1) ~= nTime
        if size(signal, 2) == nTime
            signal = signal.';
        else
            error('estimateFundamentalPhasor:DimensionMismatch', ...
                'Signal first dimension (%d) must match length of time vector (%d).', ...
                size(signal, 1), nTime);
        end
    end

    nSignals = size(signal, 2);
    phasorResult = struct();
    phasorResult.phasorRMS = NaN(1, nSignals);
    phasorResult.magnitudeRMS = NaN(1, nSignals);
    phasorResult.angle_deg = NaN(1, nSignals);
    phasorResult.sequencePhasors = struct();
    phasorResult.isValid = false;

    if ~window.isValid || isempty(window.steadyStateIndices)
        return;
    end

    idxSS = window.steadyStateIndices;
    tSS = time_s(idxSS);
    sigSS = signal(idxSS, :);
    f0 = window.nominalFrequency_Hz;
    durationSS = tSS(end) - tSS(1);

    if durationSS <= 0
        return;
    end

    omega0 = 2 * pi * f0;
    cosRef = cos(omega0 * tSS);
    sinRef = sin(omega0 * tSS);

    phasors = complex(zeros(1, nSignals));

    for col = 1:nSignals
        % Orthogonal Fourier projection over integer cycles
        realComp = (2 / durationSS) * trapz(tSS, sigSS(:, col) .* cosRef);
        imagComp = -(2 / durationSS) * trapz(tSS, sigSS(:, col) .* sinRef);
        peakPhasor = complex(realComp, imagComp);
        % Convert peak phasor to RMS phasor:
        phasors(col) = peakPhasor / sqrt(2);
    end

    phasorResult.phasorRMS = phasors;
    phasorResult.magnitudeRMS = abs(phasors);
    phasorResult.angle_deg = angle(phasors) * (180 / pi);

    % If 3-phase signal, compute symmetrical sequence components
    if nSignals == 3
        try
            threePhasePhasors = phasors(:);
            seq = calculateSequenceComponents(threePhasePhasors);
            phasorResult.sequencePhasors = seq;
        catch
            % calculateSequenceComponents not on path or failed
            phasorResult.sequencePhasors = struct();
        end
    end

    phasorResult.isValid = true;
end
