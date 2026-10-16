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
%                          isValid                : Boolean
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

    if nargin < 3 || isempty(systemFrequency_Hz)
        systemFrequency_Hz = 50.0;
    end
    if nargin < 4 || isempty(options)
        options = struct();
    end

    minSamplesPerCycle = 16;
    if isfield(options, 'minSamplesPerCycle') && ~isempty(options.minSamplesPerCycle)
        minSamplesPerCycle = options.minSamplesPerCycle;
    end

    minCyclesForWindow = 1.0;
    if isfield(options, 'minCyclesForWindow') && ~isempty(options.minCyclesForWindow)
        minCyclesForWindow = options.minCyclesForWindow;
    end

    cyclesToSkipTransient = 1.0;
    if isfield(options, 'cyclesToSkipTransient') && ~isempty(options.cyclesToSkipTransient)
        cyclesToSkipTransient = options.cyclesToSkipTransient;
    end

    window = struct();
    window.isValid = false;
    window.prefaultIndices = [];
    window.faultWindowIndices = [];
    window.steadyStateIndices = [];
    window.t_start_s = NaN;
    window.t_end_s = NaN;
    window.nominalFrequency_Hz = systemFrequency_Hz;
    window.period_s = 1.0 / systemFrequency_Hz;
    window.effectiveSampleRate_Hz = NaN;
    window.samplesPerCycle = NaN;
    window.numCycles = 0;
    window.warningMessage = '';

    % Check time_s validity
    if isempty(time_s) || ~isnumeric(time_s) || ~isvector(time_s)
        window.warningMessage = 'Time vector is empty or not a numeric vector.';
        return;
    end

    time_s = time_s(:);
    if numel(time_s) < 2
        window.warningMessage = 'Time vector contains fewer than 2 samples.';
        return;
    end

    dt = diff(time_s);
    if any(~isfinite(time_s)) || any(dt <= 0)
        window.warningMessage = 'Time vector is not finite or not strictly monotonically increasing.';
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
            'Insufficient sampling rate: %0.1f samples/cycle (minimum required is %d).', ...
            samplesPerCycle, minSamplesPerCycle);
        return;
    end

    T = window.period_s;

    % Prefault window: samples strictly before faultInsertionTime_s
    prefaultIdx = find(time_s < faultInsertionTime_s);
    window.prefaultIndices = prefaultIdx;

    % Complete fault window: samples at or after faultInsertionTime_s
    faultIdx = find(time_s >= faultInsertionTime_s);
    window.faultWindowIndices = faultIdx;

    if isempty(faultIdx)
        window.warningMessage = sprintf('Simulation stopped before fault inception at %g s.', ...
            faultInsertionTime_s);
        return;
    end

    % Steady-state fault window: skip transient interval
    steadyStart_t = faultInsertionTime_s + (cyclesToSkipTransient * T);
    t_max = time_s(end);

    if t_max < steadyStart_t
        % Not enough duration to skip full transient; fallback to evaluating if at least minCycles available
        steadyStart_t = faultInsertionTime_s;
    end

    availableDuration = t_max - steadyStart_t;
    numFullCycles = floor(availableDuration / T + 1e-9);

    if numFullCycles < minCyclesForWindow
        window.warningMessage = sprintf( ...
            'Post-fault window duration (%0.4f s) spans %0.2f cycles; requires at least %0.2f cycles.', ...
            availableDuration, availableDuration / T, minCyclesForWindow);
        return;
    end

    steadyEnd_t = steadyStart_t + (numFullCycles * T);
    steadyIdx = find(time_s >= steadyStart_t & time_s <= steadyEnd_t + 1e-9 * T);

    if numel(steadyIdx) < (numFullCycles * minSamplesPerCycle)
        window.warningMessage = 'Insufficient samples in designated steady-state window.';
        return;
    end

    window.steadyStateIndices = steadyIdx;
    window.t_start_s = steadyStart_t;
    window.t_end_s = steadyEnd_t;
    window.numCycles = numFullCycles;
    window.isValid = true;
end
