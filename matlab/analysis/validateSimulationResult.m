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
%     and time_s must be a non-empty, strictly increasing finite numeric vector.

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
        if any(~isfinite(result.time_s)) || any(diff(result.time_s) <= 0)
            error('validateSimulationResult:InvalidTimeVector', ...
                'Simulation time vector must be strictly monotonically increasing and finite.');
        end
    end

    isValid = true;
end
