function studyResults = runIntegratedFaultStudy( ...
    network, scenarios, relays, coordinationPairs)
% runIntegratedFaultStudy Run radial fault and protection studies.
% network is validated by validateRadialNetwork. Scenarios are scalar
% structures with id, faultedBus, faultType, and Zf_pu fields; Vth_pu is
% optional and defaults to the network source voltage. Relay pickup values
% are CT secondary amperes. Coordination pairs contain
% primaryRelayId, backupRelayId, and minimumCTI_s.
%
% This model uses the source plus the unique radial path to the faulted bus
% as each sequence Thevenin impedance. A relay sees current only when its
% measurement element lies on that path. Legacy relays with protectedBranch
% use the branch from-bus as their measurement side.

validateRadialNetwork(network);
validateScenarios(scenarios, network);
validateRelays(relays, network);
validatePairs(coordinationPairs, relays);

studyResults = repmat(struct( ...
    'scenarioId', '', ...
    'faultedBus', '', ...
    'faultType', '', ...
    'faultImpedance_pu', [], ...
    'faultCurrent_pu', [], ...
    'faultCurrent_A', [], ...
    'faultCurrentMagnitude_A', [], ...
    'phaseCurrents_pu', [], ...
    'sequenceCurrents_pu', [], ...
    'relayResults', struct([]), ...
    'coordinationResults', struct([]), ...
    'assumptions', {{}}, ...
    'warnings', {{}}), 1, numel(scenarios));

for scenarioIndex = 1:numel(scenarios)
    scenario = scenarios(scenarioIndex);
    [pathElements, pathBranches, Z1, Z2, Z0, zeroSequenceSupported] = ...
        pathToBus(network, char(scenario.faultedBus));
    if ~zeroSequenceSupported && isZeroSequenceFault(scenario.faultType)
        error('runIntegratedFaultStudy:BlockedZeroSequence', ...
            'Zero-sequence current calculation across delta-grounded-wye transformer boundary is unsupported for %s.', ...
            char(scenario.faultedBus));
    end
    Vth = network.source.Vth_pu;
    if isfield(scenario, 'Vth_pu')
        Vth = scenario.Vth_pu;
    end
    fault = solveFault(char(scenario.faultType), Vth, Z1, Z2, Z0, ...
        scenario.Zf_pu);
    bus = network.buses(strcmp({network.buses.id}, char(scenario.faultedBus)));
    bases = calculateBaseValues(network.base.SbaseVA, bus.VbaseV);
    [faultCurrent_pu, phaseCurrents_pu, sequenceCurrents_pu] = ...
        extractFaultCurrent(fault, char(scenario.faultType));
    faultCurrent_A = faultCurrent_pu * bases.IbaseA;
    relayResults = evaluateRelays( ...
        relays, pathElements, faultCurrent_pu, network);
    coordinationResults = evaluatePairs( ...
        coordinationPairs, relayResults, relays);

    studyResults(scenarioIndex).scenarioId = char(scenario.id);
    studyResults(scenarioIndex).faultedBus = char(scenario.faultedBus);
    studyResults(scenarioIndex).faultType = char(scenario.faultType);
    studyResults(scenarioIndex).faultImpedance_pu = scenario.Zf_pu;
    studyResults(scenarioIndex).faultCurrent_pu = faultCurrent_pu;
    studyResults(scenarioIndex).faultCurrent_A = faultCurrent_A;
    studyResults(scenarioIndex).faultCurrentMagnitude_A = abs(faultCurrent_A);
    studyResults(scenarioIndex).faultCurrentMagnitude_pu = abs(faultCurrent_pu);
    studyResults(scenarioIndex).faultedBusVoltageBaseV = bus.VbaseV;
    studyResults(scenarioIndex).phaseCurrents_pu = phaseCurrents_pu;
    studyResults(scenarioIndex).sequenceCurrents_pu = sequenceCurrents_pu;
    studyResults(scenarioIndex).relayResults = relayResults;
    studyResults(scenarioIndex).coordinationResults = coordinationResults;
    studyResults(scenarioIndex).assumptions = { ...
        'Source plus radial path impedances form the sequence Thevenin equivalent.', ...
        'All impedances are per-unit on one common network base.', ...
        'Relay pickup settings are CT secondary amperes.'};
    studyResults(scenarioIndex).warnings = { ...
        'Illustrative analytical model; not a validated engineering network.', ...
        'Relay current is represented by the fault-current magnitude on path branches.'};
end
end

function fault = solveFault(faultType, Vth, Z1, Z2, Z0, Zf)
switch lower(strtrim(faultType))
    case {'three phase', 'threephase', '3ph'}
        fault = calculateThreePhaseFault(Vth, Z1, Zf);
    case {'slg', 'single line to ground', 'single-line-to-ground'}
        fault = calculateSLGFault(Vth, Z1, Z2, Z0, Zf);
    case {'ll', 'line to line', 'line-to-line'}
        fault = calculateLLFault(Vth, Z1, Z2, Zf);
    case {'dlg', 'double line to ground', 'double-line-to-ground'}
        fault = calculateDLGFault(Vth, Z1, Z2, Z0, Zf);
    otherwise
        error('runIntegratedFaultStudy:UnsupportedFaultType', ...
            'Unsupported fault type: %s.', faultType);
end
end

function [current, phase, sequence] = extractFaultCurrent(fault, faultType)
switch lower(strtrim(faultType))
    case {'three phase', 'threephase', '3ph'}
        current = fault;
        phase = [fault; -0.5*fault - 1i*sqrt(3)/2*fault; ...
            -0.5*fault + 1i*sqrt(3)/2*fault];
        sequence = [0; fault; 0];
    otherwise
        sequence = [fault.I0_pu; fault.I1_pu; fault.I2_pu];
        phase = [fault.Ia_pu; fault.Ib_pu; fault.Ic_pu];
        current = max(abs(phase));
end
end

function relayResults = evaluateRelays(relays, pathElements, faultCurrent_pu, network)
relayResults = repmat(struct( ...
    'relayId', '', 'protectedBranch', '', 'measurementElementType', '', ...
    'measurementElementId', '', 'measurementSide', '', ...
    'protectedDirection', '', ...
    'measurementBus', '', 'measurementVoltageBaseV', [], ...
    'isOnFaultPath', false, ...
    'faultCurrentPrimary_A', 0, 'relayCurrentSecondary_A', 0, ...
    'pickupRatio', 0, 'operatingTime_s', Inf, 'operates', false, ...
    'reason', ''), 1, numel(relays));
for relayIndex = 1:numel(relays)
    relay = relays(relayIndex);
    [elementType, elementId, side] = relayLocation(relay);
    pathIndex = find(strcmp({pathElements.type}, elementType) & ...
        strcmp({pathElements.id}, elementId), 1);
    onPath = ~isempty(pathIndex);
    measurementBus = '';
    if onPath
        measurementBus = measurementBusForElement( ...
            pathElements(pathIndex), side);
    end
    if onPath
        bus = network.buses(strcmp({network.buses.id}, measurementBus));
        measurementBase = calculateBaseValues( ...
            network.base.SbaseVA, bus.VbaseV);
        relayCurrent = abs(faultCurrent_pu) * measurementBase.IbaseA;
        measurementVoltageBaseV = bus.VbaseV;

    else
        relayCurrent = 0;
        measurementVoltageBaseV = [];
    end
    secondary = convertPrimaryToSecondaryCurrent( ...
        relayCurrent, relay.CTprimary_A, relay.CTsecondary_A);
    operatingTime = calculateRelayOperatingTime( ...
        secondary, relay.pickupCurrent_A, relay.TMS, relay.curveType);
    relayResults(relayIndex).relayId = char(relay.id);
    if isfield(relay, 'protectedBranch')
        relayResults(relayIndex).protectedBranch = char(relay.protectedBranch);
    end
    relayResults(relayIndex).measurementElementType = elementType;
    relayResults(relayIndex).measurementElementId = elementId;
    relayResults(relayIndex).measurementSide = side;
    if isfield(relay, 'protectedDirection')
        relayResults(relayIndex).protectedDirection = ...
            char(relay.protectedDirection);
    end
    relayResults(relayIndex).measurementBus = measurementBus;
    relayResults(relayIndex).measurementVoltageBaseV = measurementVoltageBaseV;
    relayResults(relayIndex).isOnFaultPath = onPath;
    relayResults(relayIndex).faultCurrentPrimary_A = relayCurrent;
    relayResults(relayIndex).relayCurrentSecondary_A = secondary;
    relayResults(relayIndex).pickupRatio = secondary / relay.pickupCurrent_A;
    relayResults(relayIndex).operatingTime_s = operatingTime;
    relayResults(relayIndex).operates = isfinite(operatingTime);
    if ~onPath
        relayResults(relayIndex).reason = 'Protected branch is not on fault path.';
    elseif ~isfinite(operatingTime)
        relayResults(relayIndex).reason = 'Relay current is at or below pickup.';
    else
        relayResults(relayIndex).reason = 'Relay operates above pickup.';
    end
end
end

function coordinationResults = evaluatePairs(pairs, relayResults, relays)
coordinationResults = repmat(struct( ...
    'primaryRelayId', '', 'backupRelayId', '', 'minimumCTI_s', [], ...
    'primaryOperatingTime_s', Inf, 'backupOperatingTime_s', Inf, ...
    'coordinationInterval_s', Inf, 'isCoordinated', false, ...
    'primaryOperates', false, 'backupOperates', false, ...
    'coordinationStatus', ''), 1, numel(pairs));
for pairIndex = 1:numel(pairs)
    pair = pairs(pairIndex);
    primary = findRelay(relayResults, char(pair.primaryRelayId));
    backup = findRelay(relayResults, char(pair.backupRelayId));
    if primary.faultCurrentPrimary_A == backup.faultCurrentPrimary_A
        primaryConfig = relays(strcmp({relays.id}, char(pair.primaryRelayId)));
        backupConfig = relays(strcmp({relays.id}, char(pair.backupRelayId)));
        coordination = checkRelayCoordination( ...
            primary.faultCurrentPrimary_A, primaryConfig, backupConfig, ...
            pair.minimumCTI_s);
    else
        coordination = coordinateRelayResults(primary, backup, ...
            pair.minimumCTI_s);
    end
    coordinationResults(pairIndex).primaryRelayId = char(pair.primaryRelayId);
    coordinationResults(pairIndex).backupRelayId = char(pair.backupRelayId);
    coordinationResults(pairIndex).minimumCTI_s = pair.minimumCTI_s;
    coordinationResults(pairIndex).primaryOperatingTime_s = ...
        coordination.primaryOperatingTime_s;
    coordinationResults(pairIndex).backupOperatingTime_s = ...
        coordination.backupOperatingTime_s;
    coordinationResults(pairIndex).coordinationInterval_s = ...
        coordination.coordinationInterval_s;
    coordinationResults(pairIndex).isCoordinated = coordination.isCoordinated;
    coordinationResults(pairIndex).primaryOperates = coordination.primaryOperates;
    coordinationResults(pairIndex).backupOperates = coordination.backupOperates;
    coordinationResults(pairIndex).coordinationStatus = ...
        coordination.coordinationStatus;
end
end

function coordination = coordinateRelayResults(primary, backup, minimumCTI_s)
coordination.primaryOperatingTime_s = primary.operatingTime_s;
coordination.backupOperatingTime_s = backup.operatingTime_s;
coordination.minimumCTI_s = minimumCTI_s;
coordination.primaryOperates = primary.operates;
coordination.backupOperates = backup.operates;
if primary.operates && backup.operates
    coordination.coordinationInterval_s = ...
        backup.operatingTime_s - primary.operatingTime_s;
    coordination.isCoordinated = ...
        coordination.coordinationInterval_s >= minimumCTI_s;
    coordination.coordinationStatus = 'Both relays operate';
elseif ~primary.operates && ~backup.operates
    coordination.coordinationInterval_s = Inf;
    coordination.isCoordinated = false;
    coordination.coordinationStatus = 'Neither relay operates';
elseif ~primary.operates
    coordination.coordinationInterval_s = Inf;
    coordination.isCoordinated = false;
    coordination.coordinationStatus = 'Primary relay does not operate';
else
    coordination.coordinationInterval_s = Inf;
    coordination.isCoordinated = false;
    coordination.coordinationStatus = 'Backup relay does not operate';
end
end

function relay = findRelay(relayResults, relayId)
relay = relayResults(strcmp({relayResults.relayId}, relayId));
end

function [pathElements, pathBranches, Z1, Z2, Z0, zeroSequenceSupported] = ...
        pathToBus(network, busId)
pathElements = struct('type', {}, 'id', {}, 'fromBus', {}, 'toBus', {});
pathBranches = {};
Z1 = network.source.Z1_pu;
Z2 = network.source.Z2_pu;
Z0 = network.source.Z0_pu;
zeroSequenceSupported = true;
currentBus = busId;
while ~strcmp(currentBus, char(network.sourceBus))
    branchIndex = find(strcmp({network.branches.toBus}, currentBus), 1);
    transformerIndex = [];
    if isfield(network, 'transformers')
        transformerIndex = find(strcmp({network.transformers.lowVoltageBus}, ...
            currentBus), 1);
    end
    if isempty(branchIndex) && isempty(transformerIndex)
        error('runIntegratedFaultStudy:UnreachableBus', ...
            'Faulted bus %s is not reachable from the source.', busId);
    end
    if ~isempty(transformerIndex)
        transformer = network.transformers(transformerIndex);
        pathElements = [struct('type', 'transformer', ...
            'id', char(transformer.id), ...
            'fromBus', char(transformer.highVoltageBus), ...
            'toBus', char(transformer.lowVoltageBus)), pathElements];
        Z1 = Z1 + transformer.Z1_pu;
        Z2 = Z2 + transformer.Z2_pu;
        if strcmpi(strtrim(transformer.windingConnection), ...
                'delta-grounded-wye')
            zeroSequenceSupported = false;
        elseif isfinite(Z0)
            Z0 = Z0 + transformer.Z0_pu;
        end
        currentBus = char(transformer.highVoltageBus);
    else
        branch = network.branches(branchIndex);
        pathElements = [struct('type', 'branch', ...
            'id', char(branch.id), ...
            'fromBus', char(branch.fromBus), ...
            'toBus', char(branch.toBus)), pathElements];
        pathBranches = [{char(branch.id)}, pathBranches];
        Z1 = Z1 + branch.Z1_pu;
        Z2 = Z2 + branch.Z2_pu;
        if isfinite(Z0)
            Z0 = Z0 + branch.Z0_pu;
        end
        currentBus = char(branch.fromBus);
    end
end
end

function busId = measurementBusForElement(element, side)
if strcmp(element.type, 'branch')
    if strcmp(side, 'from')
        busId = element.fromBus;
    else
        busId = element.toBus;
    end
elseif strcmp(side, 'high')
    busId = element.fromBus;
else
    busId = element.toBus;
end
end

function [elementType, elementId, side] = relayLocation(relay)
if isfield(relay, 'measurementElementType')
    elementType = lower(strtrim(char(relay.measurementElementType)));
    elementId = char(relay.measurementElementId);
    side = lower(strtrim(char(relay.measurementSide)));
else
    elementType = 'branch';
    elementId = char(relay.protectedBranch);
    side = 'from';
end
end

function isFault = isZeroSequenceFault(faultType)
isFault = any(strcmp(lower(strtrim(faultType)), ...
    {'slg', 'single line to ground', 'single-line-to-ground', ...
    'dlg', 'double line to ground', 'double-line-to-ground'}));
end

function validateScenarios(scenarios, network)
if ~isstruct(scenarios) || isempty(scenarios)
    error('runIntegratedFaultStudy:InvalidScenarios', ...
        'scenarios must be a nonempty structure array.');
end
requireFields(scenarios, {'id', 'faultedBus', 'faultType', 'Zf_pu'}, 'scenario');
busIds = {network.buses.id};
for index = 1:numel(scenarios)
    scenario = scenarios(index);
    if ~ischar(scenario.id) || isempty(scenario.id) || ...
            ~ischar(scenario.faultedBus) || ~any(strcmp(busIds, scenario.faultedBus))
        error('runIntegratedFaultStudy:InvalidScenario', ...
            'Scenario identifiers and faulted buses must be valid.');
    end
    if ~isnumeric(scenario.Zf_pu) || ~isscalar(scenario.Zf_pu) || ...
            ~isfinite(scenario.Zf_pu)
        error('runIntegratedFaultStudy:InvalidFaultImpedance', ...
            'Scenario fault impedance must be a finite numeric scalar.');
    end
end
end

function validateRelays(relays, network)
if ~isstruct(relays) || isempty(relays)
    error('runIntegratedFaultStudy:InvalidRelays', ...
        'relays must be a nonempty structure array.');
end
requireFields(relays, {'id', 'pickupCurrent_A', ...
    'TMS', 'curveType', 'CTprimary_A', 'CTsecondary_A'}, 'relay');
branchIds = {network.branches.id};
transformerIds = {};
if isfield(network, 'transformers')
    transformerIds = {network.transformers.id};
end
relayIds = {relays.id};
if numel(unique(relayIds)) ~= numel(relayIds)
    error('runIntegratedFaultStudy:DuplicateRelayId', ...
        'Relay identifiers must be unique.');
end
for index = 1:numel(relays)
    relay = relays(index);
    if isfield(relay, 'measurementElementType')
        requiredLocationFields = {'measurementElementId', 'measurementSide'};
        for fieldIndex = 1:numel(requiredLocationFields)
            if ~isfield(relay, requiredLocationFields{fieldIndex})
                error('runIntegratedFaultStudy:MissingRelayLocationField', ...
                    'Relay %s is missing %s.', relay.id, ...
                    requiredLocationFields{fieldIndex});
            end
        end
        elementType = lower(strtrim(char(relay.measurementElementType)));
        elementId = char(relay.measurementElementId);
        side = lower(strtrim(char(relay.measurementSide)));
        if strcmp(elementType, 'branch')
            validId = any(strcmp(branchIds, elementId));
            validSides = {'from', 'to'};
        elseif strcmp(elementType, 'transformer')
            validId = any(strcmp(transformerIds, elementId));
            validSides = {'high', 'low'};
        else
            validId = false;
            validSides = {};
        end
        if ~validId
            error('runIntegratedFaultStudy:InvalidRelayLocation', ...
                'Relay %s references an unknown measurement element.', relay.id);
        end
        if ~any(strcmp(validSides, side))
            error('runIntegratedFaultStudy:InvalidRelayLocation', ...
                'Relay %s has an invalid measurement side.', relay.id);
        end
        if isfield(relay, 'protectedDirection') && ...
                ~any(strcmpi(strtrim(char(relay.protectedDirection)), ...
                {'downstream', 'upstream'}))
            error('runIntegratedFaultStudy:InvalidRelayDirection', ...
                'Relay %s has an invalid protected direction.', relay.id);
        end
    elseif isfield(relay, 'protectedBranch')
        if ~any(strcmp(branchIds, relay.protectedBranch))
            error('runIntegratedFaultStudy:InvalidRelayBranch', ...
                'Relay %s references an unknown branch.', relay.id);
        end
    else
        error('runIntegratedFaultStudy:MissingRelayLocationField', ...
            'Relay %s must define an explicit location or protectedBranch.', ...
            relay.id);
    end
end
end

function validatePairs(pairs, relays)
if isempty(pairs)
    return;
end
if ~isstruct(pairs)
    error('runIntegratedFaultStudy:InvalidCoordinationPairs', ...
        'coordinationPairs must be a structure array.');
end
requireFields(pairs, {'primaryRelayId', 'backupRelayId', 'minimumCTI_s'}, ...
    'coordination pair');
relayIds = {relays.id};
for index = 1:numel(pairs)
    if ~any(strcmp(relayIds, pairs(index).primaryRelayId)) || ...
            ~any(strcmp(relayIds, pairs(index).backupRelayId))
        error('runIntegratedFaultStudy:UnknownRelayInPair', ...
            'Coordination pair references an unknown relay.');
    end
end
end

function requireFields(value, fields, name)
if ~isstruct(value) || isempty(value)
    error('runIntegratedFaultStudy:InvalidFieldContainer', ...
        '%s must be a nonempty structure.', name);
end
for fieldIndex = 1:numel(fields)
    if ~isfield(value, fields{fieldIndex})
        error('runIntegratedFaultStudy:MissingField', ...
            '%s is missing required field %s.', name, fields{fieldIndex});
    end
end
end
