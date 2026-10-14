function simResult = runMinimalCircuitPrototype(options)
% runMinimalCircuitPrototype Execute the minimal Simscape Electrical circuit prototype.
%
% Syntax:
%   simResult = runMinimalCircuitPrototype()
%   simResult = runMinimalCircuitPrototype(options)
%
% Options fields:
%   options.quiet        - Boolean. If true, suppresses console output (default: false)
%   options.forceRebuild - Boolean. Rebuilds the .slx model from scratch (default: false)
%   options.stopTime_s   - Simulation duration (default: 0.04 s, 2 cycles at 50 Hz)
%   options.overrides    - Struct of simulated capabilities for testing
%
% Workflow (Phase 5):
%   1. Run capability diagnostic.
%   2. Validate prerequisites.
%   3. Build or load the model.
%   4. Execute the simulation using sim().
%   5. Extract actual output measurements.
%   6. Return explicit status and diagnostics conforming to Phase B contract.
%   7. Never label synthetic or analytical values as simulation measurements.

    if nargin < 1 || isempty(options)
        options = struct();
    end
    if ~isfield(options, 'quiet')
        options.quiet = false;
    end
    if ~isfield(options, 'forceRebuild')
        options.forceRebuild = false;
    end
    if ~isfield(options, 'stopTime_s')
        options.stopTime_s = 0.04;
    end

    scenarioId = 'MINIMAL_CIRCUIT_PROTOTYPE';
    modelName = 'minimal_circuit_prototype';
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    modelFile = fullfile(projectRoot, 'simulink', 'models', [modelName, '.slx']);

    % Step 1: Run capability diagnostic (enabling compatible Power_System_Blocks feature)
    diagOptions = struct('quiet', true, 'allowPowerSystemBlocks', true);
    if isfield(options, 'overrides')
        diagOptions.overrides = options.overrides;
    end
    diag = checkSimulationCapabilities(diagOptions);

    % Step 2: Validate prerequisites
    if ~strcmp(diag.status, 'READY')
        simResult = createSimulationResultSchema('BLOCKED', scenarioId);
        simResult.warnings{end+1} = sprintf('Dynamic simulation blocked by environment state: %s', diag.status);
        simResult.warnings{end+1} = diag.message;
        for mIdx = 1:numel(diag.missingRequirements)
            simResult.warnings{end+1} = sprintf('Missing: %s', diag.missingRequirements{mIdx});
        end
        simResult.provenance.source = 'SIMULATION_BLOCKED_BY_ENVIRONMENT';

        if ~options.quiet
            fprintf('\n[SIMULATION BLOCKED] Cannot run minimal circuit prototype:\n');
            fprintf('  Status: %s\n', diag.status);
            fprintf('  Reason: %s\n\n', diag.message);
        end

        validateSimulationResult(simResult);
        return;
    end

    % Step 3: Build or load model
    try
        if ~exist(modelFile, 'file') || options.forceRebuild
            modelFile = build_minimal_circuit_prototype(fullfile(pwd, 'simulink', 'models'));
        end
        if ~bdIsLoaded(modelName)
            load_system(modelFile);
        end
    catch ME
        simResult = createSimulationResultSchema('BUILD_FAILED', scenarioId);
        simResult.errors{end+1} = sprintf('Model build/load failed: %s', ME.message);
        if ~options.quiet
            fprintf('\n[BUILD FAILED] %s\n\n', ME.message);
        end
        validateSimulationResult(simResult);
        return;
    end

    % Step 4: Execute simulation using Simulink sim()
    simResult = createSimulationResultSchema('SIMULATION_FAILED', scenarioId);
    simResult.modelId = modelName;
    simResult.modelPath = modelFile;

    try
        set_param(modelName, 'StopTime', num2str(options.stopTime_s));
        simOut = sim(modelName);

        % Extract output signals
        y = simOut.yout;
        numSignals = 0;
        if isa(y, 'Simulink.SimulationData.Dataset')
            numSignals = y.numElements;
        elseif iscell(y) || isstruct(y)
            numSignals = numel(y);
        end

        if numSignals < 2
            error('runMinimalCircuitPrototype:MissingOutputs', 'Expected at least 2 output signals (V_abc, I_abc).');
        end

        if isprop(simOut, 'tout') && ~isempty(simOut.tout)
            t = simOut.tout;
        else
            t = y{1}.Values.Time;
        end
        t = t(:);

        if isempty(t) || ~isnumeric(t)
            error('runMinimalCircuitPrototype:EmptyTime', 'Simulation produced empty time vector.');
        end

        % Extract 3-phase voltage and current waveforms
        vRaw = y{1}.Values.Data;
        iRaw = y{2}.Values.Data;

        if ndims(vRaw) == 3 && size(vRaw, 1) == 1 && size(vRaw, 2) == 3
            vData = squeeze(vRaw).';
        elseif size(vRaw, 2) == numel(t) && size(vRaw, 1) == 3
            vData = vRaw.';
        else
            vData = vRaw;
        end

        if ndims(iRaw) == 3 && size(iRaw, 1) == 1 && size(iRaw, 2) == 3
            iData = squeeze(iRaw).';
        elseif size(iRaw, 2) == numel(t) && size(iRaw, 1) == 3
            iData = iRaw.';
        else
            iData = iRaw;
        end

        % Populate result fields with verified simulation data
        simResult.status = 'SIMULATION_COMPLETED';
        simResult.isSimulated = true;
        simResult.time_s = t(:);
        simResult.voltages_V = struct('Va', vData(:, 1), 'Vb', vData(:, 2), 'Vc', vData(:, 3));
        simResult.currents_A = struct('Ia', iData(:, 1), 'Ib', iData(:, 2), 'Ic', iData(:, 3));
        simResult.measurements = struct( ...
            'V_abc', vData, ...
            'I_abc', iData, ...
            'units', struct('voltage', 'V', 'current', 'A'));

        dt = median(diff(t));
        simResult.sampling = struct( ...
            'sampleTime_s', dt, ...
            'sampleRate_Hz', 1 / dt, ...
            'numSamples', numel(t));

        % Step 6: Process measurements (Window, RMS, Phasors)
        window = validateMeasurementWindow(t, 0.0, 50.0);
        simResult.isValidMeasurementWindow = window.isValid;

        if window.isValid
            rmsV = extractSimulationRMS(t, vData, window);
            rmsI = extractSimulationRMS(t, iData, window);
            simResult.rms = struct( ...
                'V_RMS_phase', rmsV.steadyStateRMS, ...
                'I_RMS_phase', rmsI.steadyStateRMS, ...
                'V_peak', max(abs(vData(:))), ...
                'I_peak', max(abs(iData(:))));

            phasorV = estimateFundamentalPhasor(t, vData, window);
            phasorI = estimateFundamentalPhasor(t, iData, window);
            simResult.phasors = struct( ...
                'V_phasors', phasorV, ...
                'I_phasors', phasorI);
        end

        simResult.solverDiagnostics = struct( ...
            'solver', get_param(modelName, 'Solver'), ...
            'actualSteps', numel(t), ...
            'terminationMessage', 'Simulation completed normally.');

        simResult.provenance = struct( ...
            'source', 'SIMSCAPE_ELECTRICAL_PHYSICAL_SIMULATION', ...
            'matlabRelease', ['R', version('-release')], ...
            'timestamp', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>

        if ~options.quiet
            printPrototypeSummary(simResult);
        end

    catch ME
        simResult.status = 'SIMULATION_FAILED';
        simResult.isSimulated = false;
        simResult.time_s = [];
        simResult.errors{end+1} = sprintf('Simulation execution failed: %s (%s)', ME.message, ME.identifier);
        if ~options.quiet
            fprintf('\n[SIMULATION FAILED] %s\n\n', ME.message);
        end
    end

    validateSimulationResult(simResult);
end

function printPrototypeSummary(res)
    fprintf('\n============================================================\n');
    fprintf(' MINIMAL CIRCUIT PROTOTYPE SIMULATION RESULTS\n');
    fprintf('============================================================\n');
    fprintf(' Model:                %s\n', res.modelId);
    fprintf(' Status:               [%s]\n', res.status);
    fprintf(' Physical Simulation:  %s\n', mat2str(res.isSimulated));
    fprintf(' Solver:               %s\n', res.solverDiagnostics.solver);
    fprintf(' Total Time Steps:     %d (dt ~ %0.2f us)\n', ...
        res.sampling.numSamples, res.sampling.sampleTime_s * 1e6);
    fprintf(' Simulated Duration:   %0.4f s\n', res.time_s(end));
    fprintf('------------------------------------------------------------\n');
    if res.isValidMeasurementWindow && isfield(res.rms, 'V_RMS_phase')
        fprintf(' MEASURED VALUES:\n');
        fprintf('   Phase Voltage RMS:  [%0.2f, %0.2f, %0.2f] V\n', ...
            res.rms.V_RMS_phase(1), res.rms.V_RMS_phase(2), res.rms.V_RMS_phase(3));
        fprintf('   Phase Current RMS:  [%0.2f, %0.2f, %0.2f] A\n', ...
            res.rms.I_RMS_phase(1), res.rms.I_RMS_phase(2), res.rms.I_RMS_phase(3));
        fprintf('   Peak Voltage:       %0.2f V\n', res.rms.V_peak);
        fprintf('   Peak Current:       %0.2f A\n', res.rms.I_peak);
    end
    fprintf('============================================================\n\n');
end
