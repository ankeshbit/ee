function result = createSimulationResultSchema(status, scenarioId)
% createSimulationResultSchema Construct a standard dynamic simulation result structure.
%
% Syntax:
%   result = createSimulationResultSchema()
%   result = createSimulationResultSchema(status)
%   result = createSimulationResultSchema(status, scenarioId)
%
% Valid status values:
%   'NOT_RUN'
%   'BLOCKED'
%   'BUILD_FAILED'
%   'SIMULATION_FAILED'
%   'SIMULATION_COMPLETED'
%   'MEASUREMENTS_INVALID'
%   'VALIDATION_COMPLETED'
%
% The returned structure strictly adheres to the Phase B integration contract.
% By default, time_s and waveform measurements are empty and isSimulated is false.

    if nargin < 1 || isempty(status)
        status = 'NOT_RUN';
    end
    if nargin < 2 || isempty(scenarioId)
        scenarioId = '';
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

    status = upper(char(status));
    if ~any(strcmp(validStatuses, status))
        error('createSimulationResultSchema:InvalidStatus', ...
            'Invalid status "%s". Must be one of: %s', ...
            status, strjoin(validStatuses, ', '));
    end

    result = struct();
    result.status = status;
    result.scenarioId = char(scenarioId);
    result.modelId = '';
    result.modelPath = '';

    % Waveforms and raw samples (empty unless real simulation succeeded)
    result.time_s = [];
    result.voltages_V = struct();
    result.currents_A = struct();
    result.measurements = struct();

    % Sampling and timing metadata
    result.sampling = struct( ...
        'sampleTime_s', [], ...
        'sampleRate_Hz', [], ...
        'numSamples', 0);

    % Processed quantities
    result.rms = struct();
    result.phasors = struct();

    % Diagnostic and solver fields
    result.warnings = {};
    result.errors = {};
    result.solverDiagnostics = struct( ...
        'solver', '', ...
        'actualSteps', 0, ...
        'failedSteps', 0, ...
        'terminationMessage', '');

    % Integrity and provenance flags
    result.isValidMeasurementWindow = false;
    result.isSimulated = false;

    result.provenance = struct( ...
        'source', 'ENVIRONMENT_CHECK_OR_SCAFFOLD', ...
        'matlabRelease', ['R', version('-release')], ...
        'timestamp', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
end
