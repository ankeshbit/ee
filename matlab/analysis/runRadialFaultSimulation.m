function simResult = runRadialFaultSimulation(scenario, options)
% runRadialFaultSimulation Execute time-domain simulation of the 33/11 kV radial network.
%
% Syntax:
%   simResult = runRadialFaultSimulation()
%   simResult = runRadialFaultSimulation(scenario)
%   simResult = runRadialFaultSimulation(scenario, options)
%
% Inputs:
%   scenario - struct with optional fields:
%              scenarioId           : char, identifier (default: 'SCN_3PH_BUS_B')
%              faultType            : char, '3PH', 'SLG', 'LL', 'DLG', or 'HEALTHY' (default: '3PH')
%                                     Supported aliases:
%                                       - SLG: 'AG', 'LG', 'SLG'
%                                       - LL:  'BC', 'LL'
%                                       - DLG: 'BCG', 'LLG', 'DLG'
%                                       - HEALTHY: 'NONE', 'HEALTHY'
%              faultedBus           : char, 'BUS_B' (default: 'BUS_B')
%              Zf_Ohm               : double, fault / contact resistance in Ohms (default: 0.001)
%              Zg_Ohm               : double, ground path resistance in Ohms (default: equal to Zf_Ohm)
%              faultInsertionTime_s : double, fault inception time (default: 0.05)
%              faultDuration_s      : double, fault duration (default: stopTime - insertionTime)
%              simulationStopTime_s : double, simulation stop time (default: 0.15)
%
%   options  - struct with optional fields:
%              quiet                : boolean, suppress console output (default: false)
%              forceRebuild         : boolean, rebuild model from scratch (default: false)
%              overrides            : struct of capability overrides for testing
%
% Outputs:
%   simResult - validated result schema (createSimulationResultSchema) adhering
%               to the Phase B/D simulation output contract.

    if nargin < 1 || isempty(scenario)
        scenario = struct();
    end
    if nargin < 2 || isempty(options)
        options = struct();
    end

    if ~isfield(options, 'quiet')
        options.quiet = false;
    end
    if ~isfield(options, 'forceRebuild')
        options.forceRebuild = false;
    end

    % 1. Scenario ID
    if ~isfield(scenario, 'scenarioId') || isempty(scenario.scenarioId)
        if isfield(scenario, 'id') && ~isempty(scenario.id)
            scenario.scenarioId = char(scenario.id);
        else
            scenario.scenarioId = 'SCN_3PH_BUS_B';
        end
    end
    scenarioId = scenario.scenarioId;

    % 2. Fault Type Validation & Mapping
    if ~isfield(scenario, 'faultType') || isempty(scenario.faultType)
        scenario.faultType = '3PH';
    end
    rawFaultType = upper(strtrim(char(scenario.faultType)));

    switch rawFaultType
        case {'3PH', 'ABC', '3P', 'THREE_PHASE'}
            canonicalFaultType = '3PH';
            simscapeFaultOption = 'ee.enum.fault_type_option.abc';
            isHealthy = false;
        case {'SLG', 'AG', 'LG', 'SINGLE_LINE_TO_GROUND'}
            canonicalFaultType = 'SLG';
            simscapeFaultOption = 'ee.enum.fault_type_option.ag';
            isHealthy = false;
        case {'LL', 'BC', 'LINE_TO_LINE'}
            canonicalFaultType = 'LL';
            simscapeFaultOption = 'ee.enum.fault_type_option.bc';
            isHealthy = false;
        case {'DLG', 'BCG', 'LLG', 'DOUBLE_LINE_TO_GROUND'}
            canonicalFaultType = 'DLG';
            simscapeFaultOption = 'ee.enum.fault_type_option.bcg';
            isHealthy = false;
        case {'HEALTHY', 'NONE', 'NO_FAULT'}
            canonicalFaultType = 'HEALTHY';
            simscapeFaultOption = 'ee.enum.fault_type_option.abc'; % inactive
            isHealthy = true;
        otherwise
            error('runRadialFaultSimulation:UnsupportedFaultType', ...
                'Unsupported fault type "%s". Supported types: 3PH, SLG, LL, DLG, HEALTHY.', ...
                rawFaultType);
    end
    scenario.faultType = canonicalFaultType;

    % 3. Faulted Bus Validation
    if ~isfield(scenario, 'faultedBus') || isempty(scenario.faultedBus)
        scenario.faultedBus = 'BUS_B';
    end
    faultedBusStr = upper(strtrim(char(scenario.faultedBus)));
    if ~strcmp(faultedBusStr, 'BUS_B')
        error('runRadialFaultSimulation:UnsupportedBus', ...
            'Faulted bus "%s" is not supported. Only "BUS_B" is supported in the current radial network.', ...
            faultedBusStr);
    end

    % 4. Fault Resistances
    if ~isfield(scenario, 'Zf_Ohm') || isempty(scenario.Zf_Ohm)
        if isfield(scenario, 'Zf_pu') && ~isempty(scenario.Zf_pu)
            % 11 kV base: Zbase = 11000^2 / 10e6 = 12.10 Ohm
            scenario.Zf_Ohm = scenario.Zf_pu * 12.10;
        else
            scenario.Zf_Ohm = 0.001; % Bolted fault default
        end
    end
    validateattributes(scenario.Zf_Ohm, {'numeric'}, {'scalar', 'nonnegative', 'finite'}, ...
        'runRadialFaultSimulation', 'Zf_Ohm');

    if ~isfield(scenario, 'Zg_Ohm') || isempty(scenario.Zg_Ohm)
        scenario.Zg_Ohm = scenario.Zf_Ohm;
    end
    validateattributes(scenario.Zg_Ohm, {'numeric'}, {'scalar', 'nonnegative', 'finite'}, ...
        'runRadialFaultSimulation', 'Zg_Ohm');

    % 5. Timing Parameters
    if ~isfield(scenario, 'faultInsertionTime_s') || isempty(scenario.faultInsertionTime_s)
        scenario.faultInsertionTime_s = 0.05;
    end
    validateattributes(scenario.faultInsertionTime_s, {'numeric'}, {'scalar', 'nonnegative', 'finite'}, ...
        'runRadialFaultSimulation', 'faultInsertionTime_s');

    if ~isfield(scenario, 'simulationStopTime_s') || isempty(scenario.simulationStopTime_s)
        scenario.simulationStopTime_s = 0.15;
    end
    validateattributes(scenario.simulationStopTime_s, {'numeric'}, {'scalar', 'positive', 'finite'}, ...
        'runRadialFaultSimulation', 'simulationStopTime_s');

    if ~isHealthy && scenario.simulationStopTime_s <= scenario.faultInsertionTime_s
        error('runRadialFaultSimulation:InvalidTiming', ...
            'Simulation stop time (%g s) must be strictly greater than fault insertion time (%g s).', ...
            scenario.simulationStopTime_s, scenario.faultInsertionTime_s);
    end

    if ~isfield(scenario, 'faultDuration_s') || isempty(scenario.faultDuration_s)
        scenario.faultDuration_s = max(0.01, scenario.simulationStopTime_s - scenario.faultInsertionTime_s + 0.05);
    end

    modelName = 'radial_fault_study_network';
    thisDir = fileparts(mfilename('fullpath'));
    projectRoot = fullfile(thisDir, '..', '..');
    modelFile = fullfile(projectRoot, 'simulink', 'models', [modelName, '.slx']);

    % Step 1: Run capability diagnostic
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
            fprintf('\n[SIMULATION BLOCKED] Cannot run radial fault simulation:\n');
            fprintf('  Status: %s\n', diag.status);
            fprintf('  Reason: %s\n\n', diag.message);
        end

        validateSimulationResult(simResult);
        return;
    end

    % Step 3: Build or load model
    try
        if ~exist(modelFile, 'file') || options.forceRebuild
            modelDir = fullfile(projectRoot, 'simulink', 'models');
            addpath(genpath(fullfile(projectRoot, 'scripts')));
            modelFile = build_radial_fault_model(modelDir);
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

    % Step 4: Configure scenario in model
    faultBlock = [modelName, '/Fault_BusB'];

    try
        if isHealthy
            % Healthy: set fault start time far beyond simulation stop time
            set_param(faultBlock, ...
                'enable_temporal_fault', 'ee.enum.enable.yes', ...
                'fault_type_option', 'ee.enum.fault_type_option.abc', ...
                'fault_start_time', '999.0');
        else
            % Configure active fault mode
            rPn = max(1e-4, scenario.Zf_Ohm);
            rNg = max(1e-4, scenario.Zg_Ohm);
            set_param(faultBlock, ...
                'enable_temporal_fault', 'ee.enum.enable.yes', ...
                'fault_type_option', simscapeFaultOption, ...
                'fault_start_time', num2str(scenario.faultInsertionTime_s), ...
                'fault_duration', num2str(scenario.faultDuration_s), ...
                'R_pn_fault', num2str(rPn), ...
                'R_ng_fault', num2str(rNg));
        end
        set_param(modelName, 'StopTime', num2str(scenario.simulationStopTime_s));

        % Step 5: Execute simulation
        simOut = sim(modelName);

        % Step 6: Extract output signals
        y = simOut.yout;
        if ~isa(y, 'Simulink.SimulationData.Dataset') || y.numElements < 4
            error('runRadialFaultSimulation:InvalidOutput', ...
                'Expected Dataset with at least 4 output channels (V_BusA, I_BusA, V_BusB, I_BusB).');
        end

        if isprop(simOut, 'tout') && ~isempty(simOut.tout)
            t = simOut.tout;
        else
            t = y{1}.Values.Time;
        end
        t = t(:);

        % Extract channels: V_BusA, I_BusA, V_BusB, I_BusB
        vBusA = squeeze(y{1}.Values.Data).';
        iBusA = squeeze(y{2}.Values.Data).';
        vBusB = squeeze(y{3}.Values.Data).';
        iBusB = squeeze(y{4}.Values.Data).';

        % Step 7: Populate result schema
        simResult = createSimulationResultSchema('SIMULATION_COMPLETED', scenarioId);
        simResult.isSimulated = true;
        simResult.modelId = modelName;
        simResult.modelPath = modelFile;
        simResult.time_s = t;

        % Store waveforms for primary faulted bus (Bus B)
        simResult.voltages_V = struct('Va', vBusB(:, 1), 'Vb', vBusB(:, 2), 'Vc', vBusB(:, 3));
        simResult.currents_A = struct('Ia', iBusB(:, 1), 'Ib', iBusB(:, 2), 'Ic', iBusB(:, 3));
        simResult.measurements = struct( ...
            'V_BusA', vBusA, ...
            'I_BusA', iBusA, ...
            'V_BusB', vBusB, ...
            'I_BusB', iBusB, ...
            'V_abc', vBusB, ...
            'I_abc', iBusB, ...
            'units', struct('voltage', 'V', 'current', 'A'));

        dt = median(diff(t));
        simResult.sampling = struct( ...
            'sampleTime_s', dt, ...
            'sampleRate_Hz', 1 / dt, ...
            'numSamples', numel(t));

        % Step 8: Validate measurement window and extract RMS & Phasors
        if isHealthy
            evalFaultTime = 0.0;
        else
            evalFaultTime = scenario.faultInsertionTime_s;
        end

        window = validateMeasurementWindow(t, evalFaultTime, 50.0);
        simResult.isValidMeasurementWindow = window.isValid;

        if window.isValid
            rmsV_BusB = extractSimulationRMS(t, vBusB, window);
            rmsI_BusB = extractSimulationRMS(t, iBusB, window);
            rmsV_BusA = extractSimulationRMS(t, vBusA, window);
            rmsI_BusA = extractSimulationRMS(t, iBusA, window);

            simResult.rms = struct( ...
                'V_RMS_phase', rmsV_BusB.steadyStateRMS, ...
                'I_RMS_phase', rmsI_BusB.steadyStateRMS, ...
                'V_RMS_BusA', rmsV_BusA.steadyStateRMS, ...
                'I_RMS_BusA', rmsI_BusA.steadyStateRMS, ...
                'V_peak', max(abs(vBusB(:))), ...
                'I_peak', max(abs(iBusB(:))));

            phasorV = estimateFundamentalPhasor(t, vBusB, window);
            phasorI = estimateFundamentalPhasor(t, iBusB, window);

            % Sequence component magnitudes (calculateSequenceComponents returns V0, V1, V2)
            i0Mag = abs(phasorI.sequencePhasors.V0);
            i1Mag = abs(phasorI.sequencePhasors.V1);
            i2Mag = abs(phasorI.sequencePhasors.V2);
            v0Mag = abs(phasorV.sequencePhasors.V0);
            v1Mag = abs(phasorV.sequencePhasors.V1);
            v2Mag = abs(phasorV.sequencePhasors.V2);

            simResult.phasors = struct( ...
                'V_phasors', phasorV, ...
                'I_phasors', phasorI, ...
                'I1_magnitude_A', i1Mag, ...
                'I0_magnitude_A', i0Mag, ...
                'I2_magnitude_A', i2Mag, ...
                'V1_magnitude_V', v1Mag, ...
                'V0_magnitude_V', v0Mag, ...
                'V2_magnitude_V', v2Mag, ...
                'I1_phasor', phasorI.sequencePhasors.V1, ...
                'I0_phasor', phasorI.sequencePhasors.V0, ...
                'I2_phasor', phasorI.sequencePhasors.V2, ...
                'V1_phasor', phasorV.sequencePhasors.V1, ...
                'V0_phasor', phasorV.sequencePhasors.V0, ...
                'V2_phasor', phasorV.sequencePhasors.V2);
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
            printRadialSummary(simResult, scenario, isHealthy);
        end

        if bdIsLoaded(modelName)
            close_system(modelName, 0);
        end

    catch ME
        simResult = createSimulationResultSchema('SIMULATION_FAILED', scenarioId);
        simResult.isSimulated = false;
        simResult.time_s = [];
        simResult.errors{end+1} = sprintf('Simulation execution failed: %s (%s)', ME.message, ME.identifier);
        if bdIsLoaded(modelName)
            close_system(modelName, 0);
        end
        if ~options.quiet
            fprintf('\n[SIMULATION FAILED] %s\n\n', ME.message);
        end
    end

    validateSimulationResult(simResult);
end

function printRadialSummary(res, scn, isHealthy)
    fprintf('\n============================================================\n');
    fprintf(' 33/11 KV RADIAL FAULT STUDY SIMULATION RESULTS\n');
    fprintf('============================================================\n');
    fprintf(' Scenario:             %s\n', res.scenarioId);
    fprintf(' Status:               [%s]\n', res.status);
    fprintf(' Physical Simulation:  %s\n', mat2str(res.isSimulated));
    fprintf(' Fault Type:           %s\n', scn.faultType);
    fprintf(' Time Steps:           %d (dt ~ %0.2f us)\n', ...
        res.sampling.numSamples, res.sampling.sampleTime_s * 1e6);
    fprintf(' Duration:             %0.4f s\n', res.time_s(end));
    fprintf('------------------------------------------------------------\n');
    if res.isValidMeasurementWindow && isfield(res.rms, 'V_RMS_phase')
        if isHealthy
            fprintf(' HEALTHY STEADY STATE:\n');
            fprintf('   Bus B Voltage RMS:  [%0.2f, %0.2f, %0.2f] V (Nominal ~6351 V)\n', ...
                res.rms.V_RMS_phase(1), res.rms.V_RMS_phase(2), res.rms.V_RMS_phase(3));
            fprintf('   Bus B Current RMS:  [%0.2f, %0.2f, %0.2f] A (Load ~53 A)\n', ...
                res.rms.I_RMS_phase(1), res.rms.I_RMS_phase(2), res.rms.I_RMS_phase(3));
        else
            fprintf(' FAULT STEADY STATE (%s AT %s):\n', scn.faultType, scn.faultedBus);
            fprintf('   Bus B Voltage RMS:  [%0.2f, %0.2f, %0.2f] V\n', ...
                res.rms.V_RMS_phase(1), res.rms.V_RMS_phase(2), res.rms.V_RMS_phase(3));
            fprintf('   Bus A Voltage RMS:  [%0.2f, %0.2f, %0.2f] V\n', ...
                res.rms.V_RMS_BusA(1), res.rms.V_RMS_BusA(2), res.rms.V_RMS_BusA(3));
            fprintf('   Phase Current RMS:  [%0.2f, %0.2f, %0.2f] A\n', ...
                res.rms.I_RMS_phase(1), res.rms.I_RMS_phase(2), res.rms.I_RMS_phase(3));
            fprintf('   Fundamental I1:     %0.2f A\n', res.phasors.I1_magnitude_A);
            fprintf('   Fundamental I0:     %0.2f A\n', res.phasors.I0_magnitude_A);
            fprintf('   Fundamental I2:     %0.2f A\n', res.phasors.I2_magnitude_A);
            fprintf('   Peak Transient:     %0.2f A\n', res.rms.I_peak);
        end
    end
    fprintf('============================================================\n\n');
end
