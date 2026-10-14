function validConfig = validateSimulationInput(network, scenario, simConfig, measurementLocations)
% validateSimulationInput Validate and normalize inputs for dynamic fault simulation.
%
% Syntax:
%   validConfig = validateSimulationInput(network, scenario)
%   validConfig = validateSimulationInput(network, scenario, simConfig)
%   validConfig = validateSimulationInput(network, scenario, simConfig, measurementLocations)
%
% Inputs:
%   network              - Radial network structure (validated by validateRadialNetwork)
%   scenario             - Struct defining fault scenario:
%                          scenarioId            : Non-empty string
%                          faultedBus            : Identifier of bus to fault
%                          faultType             : '3PH', 'SLG', 'LL', 'DLG', or 'HEALTHY'
%                          Zf_pu                 : Non-negative fault impedance in per-unit
%                          faultInsertionTime_s  : (optional) Fault inception time, default 0.05 s
%                          simulationStopTime_s  : (optional) Simulation duration, default 0.20 s
%   simConfig            - (optional) Struct of solver/simulation settings:
%                          solver               : Solver name (default 'ode23t')
%                          maxStepSize_s        : Max solver step (default 5e-5 s)
%                          sampleTime_s         : Output sample time (default 1e-4 s)
%                          systemFrequency_Hz   : Fundamental frequency (default 50 Hz)
%   measurementLocations - (optional) Cell array of bus and/or branch IDs to monitor.
%
% Outputs:
%   validConfig          - Validated and normalized configuration structure.

    narginchk(2, 4);

    % 1. Validate Network
    validateRadialNetwork(network);

    % 2. Validate Scenario
    validateattributes(scenario, {'struct'}, {'scalar'}, ...
        'validateSimulationInput', 'scenario');

    reqFields = {'scenarioId', 'faultedBus', 'faultType', 'Zf_pu'};
    for fIdx = 1:numel(reqFields)
        fName = reqFields{fIdx};
        if ~isfield(scenario, fName)
            error('validateSimulationInput:MissingScenarioField', ...
                'Scenario is missing required field: %s', fName);
        end
    end

    scenarioId = char(scenario.scenarioId);
    if isempty(strtrim(scenarioId))
        error('validateSimulationInput:EmptyScenarioId', ...
            'Scenario ID must not be empty.');
    end

    faultedBus = char(scenario.faultedBus);
    networkBuses = {network.buses.id};
    if ~any(strcmp(networkBuses, faultedBus))
        error('validateSimulationInput:InvalidFaultedBus', ...
            'Faulted bus "%s" does not exist in the network.', faultedBus);
    end

    validFaultTypes = {'3PH', 'SLG', 'LL', 'DLG', 'HEALTHY', 'NO_FAULT'};
    faultType = upper(char(scenario.faultType));
    if ~any(strcmp(validFaultTypes, faultType))
        error('validateSimulationInput:InvalidFaultType', ...
            'Unsupported fault type "%s". Must be one of: 3PH, SLG, LL, DLG, HEALTHY.', faultType);
    end

    validateattributes(scenario.Zf_pu, {'numeric'}, {'scalar', 'nonnegative', 'finite'}, ...
        'validateSimulationInput', 'scenario.Zf_pu');
    Zf_pu = double(scenario.Zf_pu);

    % Timing parameters
    faultInsertionTime_s = 0.05;
    if isfield(scenario, 'faultInsertionTime_s') && ~isempty(scenario.faultInsertionTime_s)
        validateattributes(scenario.faultInsertionTime_s, {'numeric'}, ...
            {'scalar', 'nonnegative', 'finite'}, 'validateSimulationInput', 'faultInsertionTime_s');
        faultInsertionTime_s = double(scenario.faultInsertionTime_s);
    end

    simulationStopTime_s = 0.20;
    if isfield(scenario, 'simulationStopTime_s') && ~isempty(scenario.simulationStopTime_s)
        validateattributes(scenario.simulationStopTime_s, {'numeric'}, ...
            {'scalar', 'positive', 'finite'}, 'validateSimulationInput', 'simulationStopTime_s');
        simulationStopTime_s = double(scenario.simulationStopTime_s);
    end

    if simulationStopTime_s <= faultInsertionTime_s
        error('validateSimulationInput:InvalidStopTime', ...
            'simulationStopTime_s (%g s) must be strictly greater than faultInsertionTime_s (%g s).', ...
            simulationStopTime_s, faultInsertionTime_s);
    end

    % 3. Validate Simulation Config
    if nargin < 3 || isempty(simConfig)
        simConfig = struct();
    else
        validateattributes(simConfig, {'struct'}, {'scalar'}, ...
            'validateSimulationInput', 'simConfig');
    end

    solver = 'ode23t';
    if isfield(simConfig, 'solver') && ~isempty(simConfig.solver)
        solver = char(simConfig.solver);
    end

    maxStepSize_s = 5e-5;
    if isfield(simConfig, 'maxStepSize_s') && ~isempty(simConfig.maxStepSize_s)
        validateattributes(simConfig.maxStepSize_s, {'numeric'}, ...
            {'scalar', 'positive', 'finite'}, 'validateSimulationInput', 'maxStepSize_s');
        maxStepSize_s = double(simConfig.maxStepSize_s);
    end

    sampleTime_s = 1e-4;
    if isfield(simConfig, 'sampleTime_s') && ~isempty(simConfig.sampleTime_s)
        validateattributes(simConfig.sampleTime_s, {'numeric'}, ...
            {'scalar', 'positive', 'finite'}, 'validateSimulationInput', 'sampleTime_s');
        sampleTime_s = double(simConfig.sampleTime_s);
    end

    systemFrequency_Hz = 50.0;
    if isfield(simConfig, 'systemFrequency_Hz') && ~isempty(simConfig.systemFrequency_Hz)
        validateattributes(simConfig.systemFrequency_Hz, {'numeric'}, ...
            {'scalar', 'positive', 'finite'}, 'validateSimulationInput', 'systemFrequency_Hz');
        systemFrequency_Hz = double(simConfig.systemFrequency_Hz);
    end

    % 4. Validate Measurement Locations
    if nargin < 4 || isempty(measurementLocations)
        % Default: monitor faulted bus and network source bus
        measurementLocations = {network.sourceBus, faultedBus};
    else
        if ischar(measurementLocations) || isstring(measurementLocations)
            measurementLocations = cellstr(measurementLocations);
        elseif ~iscell(measurementLocations)
            error('validateSimulationInput:InvalidMeasurementLocations', ...
                'measurementLocations must be a cell array of location identifiers.');
        end
    end

    % Check that requested locations are in network buses or branches
    allElementIds = [networkBuses, {network.branches.id}];
    if isfield(network, 'transformers') && ~isempty(network.transformers)
        allElementIds = [allElementIds, {network.transformers.id}];
    end

    for mIdx = 1:numel(measurementLocations)
        loc = char(measurementLocations{mIdx});
        if ~any(strcmp(allElementIds, loc))
            error('validateSimulationInput:UnknownMeasurementLocation', ...
                'Measurement location "%s" does not exist in network buses, branches, or transformers.', loc);
        end
    end

    % Build standardized validated config
    validConfig = struct();
    validConfig.network = network;
    validConfig.scenario = struct( ...
        'scenarioId', scenarioId, ...
        'faultedBus', faultedBus, ...
        'faultType', faultType, ...
        'Zf_pu', Zf_pu, ...
        'faultInsertionTime_s', faultInsertionTime_s, ...
        'simulationStopTime_s', simulationStopTime_s);
    validConfig.simConfig = struct( ...
        'solver', solver, ...
        'maxStepSize_s', maxStepSize_s, ...
        'sampleTime_s', sampleTime_s, ...
        'systemFrequency_Hz', systemFrequency_Hz);
    validConfig.measurementLocations = unique(measurementLocations, 'stable');
end
