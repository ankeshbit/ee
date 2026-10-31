function window = validateMeasurementWindow(time_s, faultInsertionTime_s, systemFrequency_Hz, options)
% validateMeasurementWindow Validate time vector and define simulation measurement windows.
%
% Syntax:
%   window = validateMeasurementWindow(time_s, faultInsertionTime_s)
%   window = validateMeasurementWindow(time_s, faultInsertionTime_s, systemFrequency_Hz)
%   window = validateMeasurementWindow(time_s, faultInsertionTime_s, systemFrequency_Hz, options)
%
% Inputs:
%   time_s               - Monotonically increasing time vector in seconds.
%   faultInsertionTime_s - Time of fault inception in seconds.
%   systemFrequency_Hz   - Fundamental power frequency (default: 50 Hz).
%   options              - (optional) struct:
%                          minSamplesPerCycle  : Minimum samples per cycle (default: 16)
%                          minCyclesForWindow  : Minimum steady-state cycles required (default: 1.0)
%                          cyclesToSkipTransient: Cycles skipped after fault insertion to avoid
%                                                 subtransient / DC offset (default: 1.0)
%
% Outputs:
%   window               - Struct with fields:
%                          isValid                : Boolean (true ONLY when all criteria are satisfied)
%                          prefaultIndices        : Indices for prefault steady-state
%                          faultWindowIndices     : Indices for complete post-fault window
%                          steadyStateIndices     : Indices for post-transient steady-state window
%                          t_start_s              : Start time of steady-state window
%                          t_end_s                : End time of steady-state window
%                          nominalFrequency_Hz    : Fundamental frequency
%                          period_s               : Period of one cycle (1 / f0)
%                          effectiveSampleRate_Hz : Estimated sample rate
%                          samplesPerCycle        : Estimated samples per cycle
%                          numCycles              : Number of full cycles in steady-state window
%                          warningMessage         : Char explaining any deficiencies

    % 1. Validate fundamental frequency
    if nargin < 3 || isempty(systemFrequency_Hz)
        systemFrequency_Hz = 50.0;
    end
    if ~isnumeric(systemFrequency_Hz) || ~isscalar(systemFrequency_Hz) || ...
       ~isreal(systemFrequency_Hz) || ~isfinite(systemFrequency_Hz) || systemFrequency_Hz <= 0
        window = p_makeInvalidWindow(NaN, 'systemFrequency_Hz must be a finite, real, positive numeric scalar.');
        return;
    end

    % 2. Validate options struct
    if nargin < 4 || isempty(options)
        options = struct();
    end
    if ~isstruct(options) || ~isscalar(options)
        window = p_makeInvalidWindow(systemFrequency_Hz, 'options must be a scalar structure.');
        return;
    end

    minSamplesPerCycle = 16;
    if isfield(options, 'minSamplesPerCycle') && ~isempty(options.minSamplesPerCycle)
        val = options.minSamplesPerCycle;
        if ~isnumeric(val) || ~isscalar(val) || ~isreal(val) || ~isfinite(val) || val < 1
            window = p_makeInvalidWindow(systemFrequency_Hz, 'options.minSamplesPerCycle must be a real, finite scalar >= 1.');
            return;
        end
        minSamplesPerCycle = double(val);
    end

    minCyclesForWindow = 1.0;
    if isfield(options, 'minCyclesForWindow') && ~isempty(options.minCyclesForWindow)
        val = options.minCyclesForWindow;
        if ~isnumeric(val) || ~isscalar(val) || ~isreal(val) || ~isfinite(val) || val <= 0
            window = p_makeInvalidWindow(systemFrequency_Hz, 'options.minCyclesForWindow must be a real, finite scalar > 0.');
            return;
        end
        minCyclesForWindow = double(val);
    end

    cyclesToSkipTransient = 1.0;
    if isfield(options, 'cyclesToSkipTransient') && ~isempty(options.cyclesToSkipTransient)
        val = options.cyclesToSkipTransient;
        if ~isnumeric(val) || ~isscalar(val) || ~isreal(val) || ~isfinite(val) || val < 0
            window = p_makeInvalidWindow(systemFrequency_Hz, 'options.cyclesToSkipTransient must be a real, finite scalar >= 0.');
            return;
        end
        cyclesToSkipTransient = double(val);
    end

    window = p_makeInvalidWindow(systemFrequency_Hz, '');

    % 3. Validate faultInsertionTime_s
    if nargin < 2 || isempty(faultInsertionTime_s) || ~isnumeric(faultInsertionTime_s) || ...
       ~isscalar(faultInsertionTime_s) || ~isreal(faultInsertionTime_s) || ~isfinite(faultInsertionTime_s)
        window.warningMessage = 'faultInsertionTime_s must be a finite, real numeric scalar.';
        return;
    end

    % 4. Validate time_s vector
    if isempty(time_s) || ~isnumeric(time_s) || ~isvector(time_s)
        window.warningMessage = 'Time vector is empty or not a numeric vector.';
        return;
    end

    time_s = double(time_s(:));
    if numel(time_s) < 2
        window.warningMessage = 'Time vector contains fewer than 2 samples.';
        return;
    end

    if any(~isfinite(time_s))
        window.warningMessage = 'Time vector contains non-finite (NaN or Inf) values.';
        return;
    end

    dt = diff(time_s);
    if any(dt <= 0)
        window.warningMessage = 'Time vector is not strictly monotonically increasing.';
        return;
    end

    medianDt = median(dt);
    if medianDt <= 0
        window.warningMessage = 'Median sample interval is non-positive.';
        return;
    end

    fs = 1.0 / medianDt;
    samplesPerCycle = fs / systemFrequency_Hz;
    window.effectiveSampleRate_Hz = fs;
    window.samplesPerCycle = samplesPerCycle;

    if samplesPerCycle < minSamplesPerCycle
        window.warningMessage = sprintf( ...
            'Insufficient sampling rate: %0.1f samples/cycle (minimum required is %g).', ...
            samplesPerCycle, minSamplesPerCycle);
        return;
    end

    T = window.period_s;

    % 5. Fault timing bounds
    t_start = time_s(1);
    t_max   = time_s(end);

    if faultInsertionTime_s < t_start
        window.warningMessage = sprintf('Fault insertion time (%.4f s) precedes simulation start time (%.4f s).', ...
            faultInsertionTime_s, t_start);
        return;
    end

    if faultInsertionTime_s >= t_max
        window.warningMessage = sprintf('Simulation stopped at %.4f s before fault inception at %.4f s.', ...
            t_max, faultInsertionTime_s);
        return;
    end

    % Prefault window: samples strictly before faultInsertionTime_s
    prefaultIdx = find(time_s < faultInsertionTime_s);
    window.prefaultIndices = prefaultIdx;

    % Complete fault window: samples at or after faultInsertionTime_s
    faultIdx = find(time_s >= faultInsertionTime_s);
    window.faultWindowIndices = faultIdx;

    if isempty(faultIdx)
        window.warningMessage = sprintf('Simulation stopped before fault inception at %g s.', faultInsertionTime_s);
        return;
    end

    % 6. Post-transient steady-state window calculation
    steadyStart_t = faultInsertionTime_s + (cyclesToSkipTransient * T);

    % CRITICAL: Never silently fall back to faultInsertionTime_s when duration is short!
    if t_max < steadyStart_t
        window.warningMessage = sprintf( ...
            ['Simulation duration (%.4f s) is insufficient to skip post-fault transient interval; ', ...
             'requires at least %.4f s to skip %.2f transient cycles at %g Hz.'], ...
            t_max, steadyStart_t, cyclesToSkipTransient, systemFrequency_Hz);
        return;
    end

    availableDuration = t_max - steadyStart_t;
    numFullCycles = floor(availableDuration / T + 1e-9);

    if numFullCycles < minCyclesForWindow
        window.warningMessage = sprintf( ...
            ['Post-transient steady-state window duration (%0.4f s) spans %0.2f cycles; ', ...
             'requires at least %0.2f cycles.'], ...
            availableDuration, availableDuration / T, minCyclesForWindow);
        return;
    end

    steadyEnd_t = steadyStart_t + (numFullCycles * T);
    steadyIdx = find(time_s >= (steadyStart_t - 1e-9 * T) & time_s <= (steadyEnd_t + 1e-9 * T));

    reqMinSamples = round(numFullCycles * minSamplesPerCycle);
    if numel(steadyIdx) < reqMinSamples
        window.warningMessage = sprintf( ...
            'Insufficient samples in designated steady-state window (%d found, requires at least %d).', ...
            numel(steadyIdx), reqMinSamples);
        return;
    end

    window.steadyStateIndices = steadyIdx;
    window.t_start_s = steadyStart_t;
    window.t_end_s = steadyEnd_t;
    window.numCycles = numFullCycles;
    window.isValid = true;
end

function w = p_makeInvalidWindow(f0, msg)
    w = struct();
    w.isValid = false;
    w.prefaultIndices = [];
    w.faultWindowIndices = [];
    w.steadyStateIndices = [];
    w.t_start_s = NaN;
    w.t_end_s = NaN;
    w.nominalFrequency_Hz = f0;
    if isfinite(f0) && f0 > 0
        w.period_s = 1.0 / f0;
    else
        w.period_s = NaN;
    end
    w.effectiveSampleRate_Hz = NaN;
    w.samplesPerCycle = NaN;
    w.numCycles = 0;
    w.warningMessage = char(msg);
end
