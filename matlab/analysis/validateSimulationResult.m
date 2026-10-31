function isValid = validateSimulationResult(result)
% validateSimulationResult Verify that a simulation result struct satisfies the contract.
%
% Syntax:
%   isValid = validateSimulationResult(result)
%
% Enforces the integrity contract:
%   - Required fields must exist.
%   - Status must be one of the recognized contract statuses.
%   - Non-simulated results (BLOCKED, NOT_RUN, BUILD_FAILED, SIMULATION_FAILED)
%     must NOT claim isSimulated == true and must NOT contain fabricated waveforms.
%   - If isSimulated is true, status must be SIMULATION_COMPLETED or VALIDATION_COMPLETED,
%     time_s must be a non-empty, strictly increasing finite numeric vector,
%     and all waveforms must have row dimensions matching numel(time_s) and finite values.

    validateattributes(result, {'struct'}, {'scalar'}, ...
        'validateSimulationResult', 'result');

    requiredFields = { ...
        'status', 'scenarioId', 'modelId', 'modelPath', ...
        'time_s', 'voltages_V', 'currents_A', 'measurements', ...
        'sampling', 'rms', 'phasors', 'warnings', 'errors', ...
        'solverDiagnostics', 'isValidMeasurementWindow', ...
        'isSimulated', 'provenance' ...
    };

    for idx = 1:numel(requiredFields)
        fName = requiredFields{idx};
        if ~isfield(result, fName)
            error('validateSimulationResult:MissingField', ...
                'Simulation result is missing required contract field: %s', fName);
        end
    end

    validStatuses = { ...
        'NOT_RUN', ...
        'BLOCKED', ...
        'BUILD_FAILED', ...
        'SIMULATION_FAILED', ...
        'SIMULATION_COMPLETED', ...
        'MEASUREMENTS_INVALID', ...
        'VALIDATION_COMPLETED' ...
    };

    status = upper(char(result.status));
    if ~any(strcmp(validStatuses, status))
        error('validateSimulationResult:InvalidStatus', ...
            'Unrecognized result status: %s', status);
    end

    % Check isSimulated integrity
    if ~islogical(result.isSimulated) && ~(isnumeric(result.isSimulated) && isscalar(result.isSimulated))
        error('validateSimulationResult:InvalidIsSimulated', ...
            'isSimulated field must be a boolean scalar.');
    end

    % Validate sampling, rms, phasors, provenance structs
    if ~isstruct(result.sampling)
        error('validateSimulationResult:InvalidSampling', 'sampling field must be a struct.');
    end
    if ~isstruct(result.rms)
        error('validateSimulationResult:InvalidRMS', 'rms field must be a struct.');
    end
    if ~isstruct(result.phasors)
        error('validateSimulationResult:InvalidPhasors', 'phasors field must be a struct.');
    end
    if ~isstruct(result.provenance)
        error('validateSimulationResult:InvalidProvenance', 'provenance field must be a struct.');
    end

    nonSimulatedStatuses = {'NOT_RUN', 'BLOCKED', 'BUILD_FAILED', 'SIMULATION_FAILED'};
    if any(strcmp(nonSimulatedStatuses, status))
        if result.isSimulated
            error('validateSimulationResult:FalseSimulationClaim', ...
                'Result status is "%s" but isSimulated is true. Unsimulated results must never claim simulation execution.', ...
                status);
        end
        if ~isempty(result.time_s)
            error('validateSimulationResult:InventedMeasurements', ...
                'Result status is "%s" but contains non-empty time/measurement data. Blocked or failed runs must not contain fake data.', ...
                status);
        end
        if p_hasNonEmptyWaveforms(result.voltages_V) || p_hasNonEmptyWaveforms(result.currents_A) || ...
           p_hasNonEmptyWaveforms(result.measurements)
            error('validateSimulationResult:InventedMeasurements', ...
                'Result status is "%s" but contains fabricated voltage/current waveforms.', status);
        end
    end

    if result.isSimulated
        if ~strcmp(status, 'SIMULATION_COMPLETED') && ~strcmp(status, 'VALIDATION_COMPLETED')
            error('validateSimulationResult:InconsistentSimulatedStatus', ...
                'isSimulated is true but status is "%s". Must be SIMULATION_COMPLETED or VALIDATION_COMPLETED.', ...
                status);
        end
        if isempty(result.time_s) || ~isnumeric(result.time_s) || ~isvector(result.time_s)
            error('validateSimulationResult:MissingSimulatedTime', ...
                'A simulated result must contain a non-empty numeric time vector.');
        end
        time_s = result.time_s(:);
        nT = numel(time_s);
        if any(~isfinite(time_s)) || any(diff(time_s) <= 0)
            error('validateSimulationResult:InvalidTimeVector', ...
                'Simulation time vector must be strictly monotonically increasing and finite.');
        end

        % Validate waveform dimensions and finiteness if present
        p_validateWaveformArray(result.voltages_V, nT, 'voltages_V');
        p_validateWaveformArray(result.currents_A, nT, 'currents_A');
        p_validateWaveformArray(result.measurements, nT, 'measurements');

        % Validate RMS finiteness if fields exist
        rmsFields = fieldnames(result.rms);
        for f = 1:numel(rmsFields)
            val = result.rms.(rmsFields{f});
            if isnumeric(val) && any(~isfinite(val(:)))
                error('validateSimulationResult:NonFiniteRMS', ...
                    'RMS field "%s" contains non-finite (NaN or Inf) values.', rmsFields{f});
            end
        end

        % Validate Phasors finiteness if fields exist
        phFields = fieldnames(result.phasors);
        for f = 1:numel(phFields)
            val = result.phasors.(phFields{f});
            if isnumeric(val) && any(~isfinite(val(:)))
                error('validateSimulationResult:NonFinitePhasor', ...
                    'Phasor field "%s" contains non-finite (NaN or Inf) values.', phFields{f});
            end
        end
    end

    isValid = true;
end

function hasData = p_hasNonEmptyWaveforms(w)
    hasData = false;
    if isempty(w), return; end
    if isnumeric(w)
        hasData = ~isempty(w);
    elseif isstruct(w)
        fn = fieldnames(w);
        for i = 1:numel(fn)
            val = w.(fn{i});
            if isnumeric(val) && ~isempty(val)
                hasData = true;
                return;
            end
        end
    end
end

function p_validateWaveformArray(w, nT, fieldName)
    if isempty(w), return; end
    if isnumeric(w)
        if size(w, 1) ~= nT
            error('validateSimulationResult:DimensionMismatch', ...
                'Field "%s" row count (%d) does not match time vector length (%d).', ...
                fieldName, size(w, 1), nT);
        end
        if any(~isfinite(w(:)))
            error('validateSimulationResult:NonFiniteData', ...
                'Field "%s" contains non-finite (NaN or Inf) values.', fieldName);
        end
    elseif isstruct(w)
        fn = fieldnames(w);
        for i = 1:numel(fn)
            val = w.(fn{i});
            if isnumeric(val) && ~isempty(val)
                if size(val, 1) ~= nT
                    error('validateSimulationResult:DimensionMismatch', ...
                        'Waveform "%s.%s" row count (%d) does not match time vector length (%d).', ...
                        fieldName, fn{i}, size(val, 1), nT);
                end
                if any(~isfinite(val(:)))
                    error('validateSimulationResult:NonFiniteData', ...
                        'Waveform "%s.%s" contains non-finite (NaN or Inf) values.', fieldName, fn{i});
                end
            end
        end
    end
end
