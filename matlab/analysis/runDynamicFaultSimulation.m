function simResult = runDynamicFaultSimulation(network, scenario, simConfig, measurementLocations, options)
% runDynamicFaultSimulation Safe, deterministic entry point for dynamic fault simulation.
%
% Syntax:
%   simResult = runDynamicFaultSimulation(network, scenario)
%   simResult = runDynamicFaultSimulation(network, scenario, simConfig)
%   simResult = runDynamicFaultSimulation(network, scenario, simConfig, measurementLocations)
%   simResult = runDynamicFaultSimulation(network, scenario, simConfig, measurementLocations, options)
%
% This function implements the 11-step execution workflow:
%   1.  Validate input network and fault scenario.
%   2.  Run the capability diagnostic (checkSimulationCapabilities).
%   3.  Stop with an informative blocked status if required capabilities are unavailable.
%   4.  Check that the chosen component implementations are supported.
%   5.  Build or load a model only when prerequisites are satisfied.
%   6.  Configure the requested scenario.
%   7.  Execute the actual Simulink simulation.
%   8.  Extract actual output measurements.
%   9.  Validate output integrity and units.
%   10. Return the structured result adhering to Phase B contract.
%   11. Capture errors without misrepresenting failed execution as success.
%
% When licensing or required toolboxes are unavailable, the function halts
% at Step 3, returns status 'BLOCKED', and emits actionable diagnostic advice
% without attempting unsupported model construction or fabricating measurements.

    narginchk(2, 5);

    if nargin < 3
        simConfig = struct();
    end
    if nargin < 4
        measurementLocations = {};
    end
    if nargin < 5 || isempty(options)
        options = struct();
    end

    scenarioId = 'UNKNOWN_SCENARIO';
    if isfield(scenario, 'scenarioId')
        scenarioId = char(scenario.scenarioId);
    elseif isfield(scenario, 'id')
        scenarioId = char(scenario.id);
        scenario.scenarioId = scenarioId;
    end

    % Step 1: Validate input network and scenario
    try
        validConfig = validateSimulationInput(network, scenario, simConfig, measurementLocations);
    catch ME
        simResult = createSimulationResultSchema('BUILD_FAILED', scenarioId);
        simResult.errors{end+1} = sprintf('Input validation failed: %s', ME.message);
        if ~isfield(options, 'quiet') || ~options.quiet
            warning('runDynamicFaultSimulation:InputValidationFailed', '%s', ME.message);
        end
        return;
    end

    % Step 2: Run capability diagnostic
    if isfield(options, 'diagnostic') && ~isempty(options.diagnostic)
        diag = options.diagnostic;
    else
        diagOptions = struct('quiet', true);
        if isfield(options, 'allowPowerSystemBlocks')
            diagOptions.allowPowerSystemBlocks = options.allowPowerSystemBlocks;
        end
        if isfield(options, 'overrides')
            diagOptions.overrides = options.overrides;
        end
        diag = checkSimulationCapabilities(diagOptions);
    end

    % Step 3: Check prerequisites. If blocked, return deterministic blocked result
    if ~strcmp(diag.status, 'READY')
        simResult = createSimulationResultSchema('BLOCKED', validConfig.scenario.scenarioId);
        simResult.warnings{end+1} = sprintf('Dynamic simulation blocked by environment state: %s', diag.status);
        simResult.warnings{end+1} = diag.message;
        for mIdx = 1:numel(diag.missingRequirements)
            simResult.warnings{end+1} = sprintf('Missing: %s', diag.missingRequirements{mIdx});
        end
        simResult.provenance.source = 'SIMULATION_BLOCKED_BY_ENVIRONMENT';

        if ~isfield(options, 'quiet') || ~options.quiet
            fprintf('\n[SIMULATION BLOCKED] Cannot run dynamic simulation:\n');
            fprintf('  Status: %s\n', diag.status);
            fprintf('  Reason: %s\n', diag.message);
            fprintf('  Action required: Ensure Simscape Electrical license is installed and active.\n\n');
        end

        validateSimulationResult(simResult);
        return;
    end

    % Step 4: Verify component library blocks
    if ~diag.componentsAvailable
        simResult = createSimulationResultSchema('BUILD_FAILED', validConfig.scenario.scenarioId);
        simResult.errors{end+1} = 'Required Simscape Electrical library blocks are not available in installed release.';
        validateSimulationResult(simResult);
        return;
    end

    % Step 4.5: Check network and scenario physical compatibility
    compat = p_checkNetworkPhysicalCompatibility(validConfig.network, validConfig.scenario);
    if ~compat.isCompatible
        simResult = createSimulationResultSchema('UNSUPPORTED', validConfig.scenario.scenarioId);
        simResult.errors{end+1} = sprintf('Physical model does not support this scenario: %s', compat.reason);
        simResult.isSimulated = false;
        validateSimulationResult(simResult);
        return;
    end

    % Step 5 to Step 10: Model construction, configuration, and execution backend
    try
        modelId = sprintf('sim_fault_%s', regexprep(validConfig.scenario.scenarioId, '\W', '_'));
        simResult = executePhysicalSimulation(validConfig, modelId, options);
    catch ME
        % Step 11: Capture errors safely without misrepresenting failure as success
        simResult = createSimulationResultSchema('SIMULATION_FAILED', validConfig.scenario.scenarioId);
        simResult.errors{end+1} = sprintf('Simulation execution failed: %s', ME.message);
        simResult.isSimulated = false;
    end

    validateSimulationResult(simResult);
end

function simResult = executePhysicalSimulation(validConfig, modelId, options)
% executePhysicalSimulation Fully implemented native Simscape Electrical simulation backend.

    if nargin < 3 || isempty(options)
        options = struct();
    end

    scenario   = validConfig.scenario;
    network    = validConfig.network;
    simConfig  = validConfig.simConfig;
    scenarioId = scenario.scenarioId;

    % 1. Map fault type to Simscape Electrical fault block options
    rawFaultType = upper(strtrim(char(scenario.faultType)));
    switch rawFaultType
        case {'3PH', 'ABC', 'THREE_PHASE'}
            simscapeFaultOption = 'ee.enum.fault_type_option.abc';
            isHealthy = false;
        case {'SLG', 'AG', 'LG', 'SINGLE_LINE_TO_GROUND'}
            simscapeFaultOption = 'ee.enum.fault_type_option.ag';
            isHealthy = false;
        case {'LL', 'BC', 'LINE_TO_LINE'}
            simscapeFaultOption = 'ee.enum.fault_type_option.bc';
            isHealthy = false;
        case {'DLG', 'BCG', 'LLG', 'DOUBLE_LINE_TO_GROUND'}
            simscapeFaultOption = 'ee.enum.fault_type_option.bcg';
            isHealthy = false;
        case {'HEALTHY', 'NONE', 'NO_FAULT'}
            simscapeFaultOption = 'ee.enum.fault_type_option.abc';
            isHealthy = true;
        otherwise
            error('runDynamicFaultSimulation:UnsupportedFaultType', ...
                'Unsupported fault type: %s', rawFaultType);
    end

    % 2. Calculate physical fault resistance from Zf_pu
    % Determine voltage base at faulted bus
    faultedBusId = scenario.faultedBus;
    busVbase = 11e3; % default LV side
    if isfield(network, 'buses') && isstruct(network.buses)
        matchIdx = find(strcmp({network.buses.id}, faultedBusId), 1);
        if ~isempty(matchIdx) && isfield(network.buses(matchIdx), 'VbaseV')
            busVbase = network.buses(matchIdx).VbaseV;
        end
    end
    Sbase = 10e6;
    if isfield(network, 'base') && isfield(network.base, 'SbaseVA')
        Sbase = network.base.SbaseVA;
    end
    Zbase = (busVbase^2) / Sbase;
    Zf_Ohm = max(1e-4, scenario.Zf_pu * Zbase);
    Zg_Ohm = Zf_Ohm;

    % 3. Locate or build model
    modelName = 'radial_fault_study_network';
    thisDir = fileparts(mfilename('fullpath'));
    projectRoot = fullfile(thisDir, '..', '..');
    modelFile = fullfile(projectRoot, 'simulink', 'models', [modelName, '.slx']);

    forceRebuild = isfield(options, 'forceRebuild') && options.forceRebuild;
    if ~exist(modelFile, 'file') || forceRebuild
        modelDir = fullfile(projectRoot, 'simulink', 'models');
        addpath(genpath(fullfile(projectRoot, 'scripts')));
        modelFile = build_radial_fault_model(modelDir);
    end

    if ~bdIsLoaded(modelName)
        load_system(modelFile);
    end

    % 4. Configure parameters on model according to requested fault location
    faultedBus = upper(strtrim(char(scenario.faultedBus)));
    if strcmp(faultedBus, 'BUS_A')
        activeFaultBlock = [modelName, '/Fault_BusA'];
        inactiveFaultBlock = [modelName, '/Fault_BusB'];
    elseif strcmp(faultedBus, 'BUS_B')
        activeFaultBlock = [modelName, '/Fault_BusB'];
        inactiveFaultBlock = [modelName, '/Fault_BusA'];
    else
        error('runDynamicFaultSimulation:UnsupportedFaultLocation', ...
            'Faulted bus "%s" cannot be represented in physical model.', scenario.faultedBus);
    end

    % Ensure inactive fault block is disabled
    try
        set_param(inactiveFaultBlock, ...
            'enable_temporal_fault', 'ee.enum.enable.no', ...
            'fault_start_time', '999.0');
    catch
        % In case block is not present, ignore
    end

    if isHealthy
        set_param(activeFaultBlock, ...
            'enable_temporal_fault', 'ee.enum.enable.no', ...
            'fault_type_option', 'ee.enum.fault_type_option.abc', ...
            'fault_start_time', '999.0');
    else
        faultDuration = max(0.01, scenario.simulationStopTime_s - scenario.faultInsertionTime_s + 0.05);
        set_param(activeFaultBlock, ...
            'enable_temporal_fault', 'ee.enum.enable.yes', ...
            'fault_type_option', simscapeFaultOption, ...
            'fault_start_time', num2str(scenario.faultInsertionTime_s), ...
            'fault_duration', num2str(faultDuration), ...
            'R_pn_fault', num2str(Zf_Ohm), ...
            'R_ng_fault', num2str(Zg_Ohm));
    end

    set_param(modelName, 'StopTime', num2str(scenario.simulationStopTime_s));
    if isfield(simConfig, 'solver') && ~isempty(simConfig.solver)
        set_param(modelName, 'Solver', simConfig.solver);
    end

    % 5. Execute simulation
    simOut = sim(modelName);

    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end

    % 6. Extract signals with validation
    y = simOut.yout;
    if isempty(y)
        error('runDynamicFaultSimulation:MissingMeasurementPorts', ...
            'Simulation output is empty.');
    end

    if isa(y, 'Simulink.SimulationData.Dataset') || ismethod(y, 'numElements') || isprop(y, 'numElements')
        numElementsY = y.numElements;
    elseif iscell(y)
        numElementsY = numel(y);
    else
        numElementsY = 0;
    end

    if numElementsY < 4
        error('runDynamicFaultSimulation:MissingMeasurementPorts', ...
            'Simulation output is missing required measurement ports (expected at least 4, found %d).', numElementsY);
    end

    if isprop(simOut, 'tout') && ~isempty(simOut.tout)
        t = double(simOut.tout(:));
    else
        t = double(y{1}.Values.Time(:));
    end

    if isempty(t) || any(~isfinite(t)) || any(diff(t) <= 0)
        error('runDynamicFaultSimulation:InvalidTimeVector', ...
            'Simulation time vector is empty, non-finite, or non-monotonic.');
    end

    vBusA = double(squeeze(y{1}.Values.Data));
    iBusA = double(squeeze(y{2}.Values.Data));
    vBusB = double(squeeze(y{3}.Values.Data));
    iBusB = double(squeeze(y{4}.Values.Data));

    % Ensure orientation [nT x 3]
    nT = numel(t);
    if size(vBusA, 1) ~= nT && size(vBusA, 2) == nT, vBusA = vBusA.'; end
    if size(iBusA, 1) ~= nT && size(iBusA, 2) == nT, iBusA = iBusA.'; end
    if size(vBusB, 1) ~= nT && size(vBusB, 2) == nT, vBusB = vBusB.'; end
    if size(iBusB, 1) ~= nT && size(iBusB, 2) == nT, iBusB = iBusB.'; end

    if size(vBusA, 1) ~= nT || size(iBusA, 1) ~= nT || size(vBusB, 1) ~= nT || size(iBusB, 1) ~= nT
        error('runDynamicFaultSimulation:DimensionMismatch', ...
            'Measurement waveform row count does not match time vector length (%d).', nT);
    end

    if any(~isfinite(vBusA(:))) || any(~isfinite(iBusA(:))) || ...
       any(~isfinite(vBusB(:))) || any(~isfinite(iBusB(:)))
        error('runDynamicFaultSimulation:CorruptMeasurementData', ...
            'Extracted waveforms contain non-finite (NaN or Inf) values.');
    end

    % 7. Validate measurement window
    f0 = 50.0;
    if isfield(simConfig, 'systemFrequency_Hz') && ~isempty(simConfig.systemFrequency_Hz)
        f0 = simConfig.systemFrequency_Hz;
    end
    winOptions = struct('minSamplesPerCycle', 16, 'minCyclesForWindow', 1.0, 'cyclesToSkipTransient', 1.0);
    window = validateMeasurementWindow(t, scenario.faultInsertionTime_s, f0, winOptions);

    % 8. Extract RMS and Fundamental Phasors for both buses
    rmsCurrentA = extractSimulationRMS(t, iBusA, window);
    rmsVoltageA = extractSimulationRMS(t, vBusA, window);
    rmsCurrentB = extractSimulationRMS(t, iBusB, window);
    rmsVoltageB = extractSimulationRMS(t, vBusB, window);

    phasorCurrentA = estimateFundamentalPhasor(t, iBusA, window);
    phasorCurrentB = estimateFundamentalPhasor(t, iBusB, window);

    if strcmp(faultedBus, 'BUS_A')
        rmsCurrentFault = rmsCurrentA;
        rmsVoltageFault = rmsVoltageA;
        phasorCurrentFault = phasorCurrentA;
    else
        rmsCurrentFault = rmsCurrentB;
        rmsVoltageFault = rmsVoltageB;
        phasorCurrentFault = phasorCurrentB;
    end

    % Symmetrical components calculation
    if isfield(phasorCurrentFault, 'sequencePhasors') && isstruct(phasorCurrentFault.sequencePhasors) && isfield(phasorCurrentFault.sequencePhasors, 'V1')
        I_seq = phasorCurrentFault.sequencePhasors;
    else
        I_fund = phasorCurrentFault.phasorRMS;
        I_seq = calculateSequenceComponents(I_fund(:));
    end

    % 9. Assemble standardized result structure
    simResult = createSimulationResultSchema('SIMULATION_COMPLETED', scenarioId);
    simResult.modelId = modelId;
    simResult.modelPath = modelFile;
    simResult.isSimulated = true;
    simResult.time_s = t;
    simResult.isValidMeasurementWindow = window.isValid;
    simResult.faultedBus = faultedBus;

    simResult.voltages_V = struct('V_BusA', vBusA, 'V_BusB', vBusB);
    simResult.currents_A = struct('I_BusA', iBusA, 'I_BusB', iBusB);
    simResult.measurements = struct( ...
        'V_BusA', vBusA, 'I_BusA', iBusA, ...
        'V_BusB', vBusB, 'I_BusB', iBusB);

    medianDt = median(diff(t));
    simResult.sampling = struct( ...
        'sampleTime_s', medianDt, ...
        'sampleRate_Hz', 1.0 / medianDt, ...
        'numSamples', nT, ...
        'effectiveSampleRate_Hz', window.effectiveSampleRate_Hz, ...
        'samplesPerCycle', window.samplesPerCycle);

    simResult.rms = struct( ...
        'faultedBus', faultedBus, ...
        'BUS_A', max(rmsCurrentA.steadyStateRMS), ...
        'BUS_B', max(rmsCurrentB.steadyStateRMS), ...
        'faultCurrent_A', max(rmsCurrentFault.steadyStateRMS), ...
        'I_RMS_phase', rmsCurrentFault.steadyStateRMS, ...
        'V_RMS_phase', rmsVoltageFault.steadyStateRMS, ...
        'I_peak', max(rmsCurrentFault.peakTransient), ...
        'V_peak', max(rmsVoltageFault.peakTransient));

    if isstruct(I_seq)
        I0_mag = abs(I_seq.V0);
        I1_mag = abs(I_seq.V1);
        I2_mag = abs(I_seq.V2);
        I_seq_arr = [I_seq.V0; I_seq.V1; I_seq.V2];
    else
        I0_mag = abs(I_seq(1));
        I1_mag = abs(I_seq(2));
        I2_mag = abs(I_seq(3));
        I_seq_arr = I_seq(:);
    end

    simResult.phasors = struct( ...
        'faultedBus', faultedBus, ...
        'BUS_A', abs(phasorCurrentA.phasorRMS(1)), ...
        'BUS_B', abs(phasorCurrentB.phasorRMS(1)), ...
        'I1_magnitude_A', I1_mag, ...
        'I2_magnitude_A', I2_mag, ...
        'I0_magnitude_A', I0_mag, ...
        'I_fundamental_phase', phasorCurrentFault.phasorRMS, ...
        'I_sequence_012', I_seq_arr);

    simResult.provenance.source = 'SIMSCAPE_PHYSICAL_SIMULATION';
    simResult.provenance.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
end

function compat = p_checkNetworkPhysicalCompatibility(network, scenario)
% p_checkNetworkPhysicalCompatibility Verify that the network and scenario match the physical model.
    compat = struct('isCompatible', true, 'reason', '');

    % 1. Check supported fault locations
    supportedBuses = {'BUS_A', 'BUS_B'};
    if ~any(strcmpi(strtrim(scenario.faultedBus), supportedBuses))
        compat.isCompatible = false;
        compat.reason = sprintf( ...
            'Physical model "radial_fault_study_network" only models faults at BUS_A and BUS_B. Requested fault location "%s" is unsupported.', ...
            scenario.faultedBus);
        return;
    end

    % 2. Check network voltage bases and transformer ratings if present
    if isfield(network, 'buses') && isstruct(network.buses)
        buses = network.buses;
        for bIdx = 1:numel(buses)
            if isfield(buses(bIdx), 'VbaseV') && ~isempty(buses(bIdx).VbaseV)
                v = buses(bIdx).VbaseV;
                % Supported model operates on 33 kV source and 11 kV feeder
                if v > 50e3 || v < 5e3
                    compat.isCompatible = false;
                    compat.reason = sprintf( ...
                        'Bus "%s" voltage base %g V is incompatible with 33/11 kV physical network model.', ...
                        buses(bIdx).id, v);
                    return;
                end
            end
        end
    end

    if isfield(network, 'transformers') && isstruct(network.transformers)
        tx = network.transformers;
        for tIdx = 1:numel(tx)
            if isfield(tx(tIdx), 'VprimaryV') && isfield(tx(tIdx), 'VsecondaryV')
                vp = tx(tIdx).VprimaryV;
                vs = tx(tIdx).VsecondaryV;
                if abs(vp - 33e3) > 5e3 || abs(vs - 11e3) > 2e3
                    compat.isCompatible = false;
                    compat.reason = sprintf( ...
                        'Transformer "%s" rating %g/%g V does not match 33/11 kV physical transformer.', ...
                        tx(tIdx).id, vp, vs);
                    return;
                end
            end
        end
    end
end
