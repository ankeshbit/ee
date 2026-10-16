function result = calculateNetworkPhasors(network, scenario, relays)
% calculateNetworkPhasors Calculate supported radial sequence/phase phasors.
% The supported solution is a source-plus-unique-path equivalent. Per-unit
% voltages use the configured bus voltage base; physical currents use the
% measurement bus current base.

validateRadialNetwork(network);
if ~isstruct(scenario) || ~isscalar(scenario)
    error('calculateNetworkPhasors:InvalidScenario', ...
        'scenario must be a scalar structure.');
end
required = {'id', 'faultedBus', 'faultType', 'Zf_pu'};
for index = 1:numel(required)
    if ~isfield(scenario, required{index})
        error('calculateNetworkPhasors:MissingScenarioField', ...
            'scenario is missing %s.', required{index});
    end
end
if ~isempty(relays) && ~isstruct(relays)
    error('calculateNetworkPhasors:InvalidRelays', ...
        'relays must be a structure array.');
end

[path, Z1, Z2, Z0, hasGroundedNeutral] = pathData( ...
    network, char(scenario.faultedBus));
if ~hasGroundedNeutral && isZeroSequenceFault(scenario.faultType)
    error('calculateNetworkPhasors:NoGroundedNeutral', ...
        'Zero-sequence current calculation cannot proceed because there is no grounded neutral on the fault path.');
end
Vth = network.source.Vth_pu;
if isfield(scenario, 'Vth_pu')
    Vth = scenario.Vth_pu;
end
faultStudy = runIntegratedFaultStudy(network, scenario, ...
    relaysForStudy(network, relays), []);
fault = faultStudy(1);
Iseq = fault.sequenceCurrents_pu(:);
VseqFault = [ ...
    -Z0 * Iseq(1); ...
    Vth - Z1 * Iseq(2); ...
    -Z2 * Iseq(3)];

result.scenarioId = char(scenario.id);
result.faultedBus = char(scenario.faultedBus);
result.faultType = char(scenario.faultType);
result.supportStatus = 'supportedRadialPathEquivalent';
result.faultStudyResult = fault;
result.sequenceCurrents_pu = Iseq;
result.faultedBusSequenceVoltages_pu = VseqFault;
result.faultedBusPhaseVoltages_pu = sequenceToPhase(VseqFault);
result.faultedBusVoltageMagnitude_pu = abs(result.faultedBusPhaseVoltages_pu);
result.busResults = busPhasors(network, path, Vth, Iseq);
result.relayMeasurements = relayPhasors( ...
    network, path, relays, Vth, Iseq);
result.assumptions = { ...
    'Source plus unique source-to-fault path is the sequence equivalent.', ...
    'Off-path network load and parallel contributions are not solved.', ...
    'Delta-grounded-wye zero-sequence isolation modeled on wye side; Dyn11 phase rotation (+30 deg positive sequence) modeled on HV side.'};
result.warnings = {'Analytical phasors are not Simscape simulation results.'};
end

function relaysOut = relaysForStudy(network, relays)
if isempty(relays)
    relaysOut = struct( ...
        'id', 'PHASOR_RELAY', ...
        'measurementElementType', 'branch', ...
        'measurementElementId', char(network.branches(1).id), ...
        'measurementSide', 'from', ...
        'pickupCurrent_A', 1, 'TMS', 1, 'curveType', 'Very Inverse', ...
        'CTprimary_A', 1, 'CTsecondary_A', 1);
else
    relaysOut = relays;
end
end

function results = busPhasors(network, path, Vth, Iseq)
% Dyn11 vector group: Low-voltage leads High-voltage by +30 deg (+pi/6 rad) in positive sequence
DELTA_WYE_PHASE_SHIFT_RAD = -pi / 6;

deltaWyeIdx = find(strcmp({path.type}, 'transformer') & ...
    strcmpi(strtrim({path.windingConnection}), 'delta-grounded-wye'), 1);

results = repmat(struct( ...
    'busId', '', 'voltageBaseV', [], 'currentBaseA', [], ...
    'sequenceVoltages_pu', [], 'phaseVoltages_pu', [], ...
    'sequenceCurrents_pu', [], 'phaseCurrents_pu', [], ...
    'supportStatus', ''), 1, numel(path) + 1);
for index = 1:numel(results)
    if index == 1
        busId = char(network.sourceBus);
        Z = cumulativeImpedance(network, path, 0);
    else
        busId = path(index - 1).toBus;
        Z = cumulativeImpedance(network, path, index - 1);
    end
    bus = network.buses(strcmp({network.buses.id}, busId));

    isHvBus = false;
    if ~isempty(deltaWyeIdx) && index <= deltaWyeIdx
        isHvBus = true;
    end

    if isHvBus
        Iseq_bus = [0; ...
            Iseq(2) * exp(1i * DELTA_WYE_PHASE_SHIFT_RAD); ...
            Iseq(3) * exp(-1i * DELTA_WYE_PHASE_SHIFT_RAD)];
    else
        Iseq_bus = Iseq;
    end

    Vseq = [-Z(1) * Iseq(1); Vth - Z(2) * Iseq(2); ...
        -Z(3) * Iseq(3)];
    results(index).busId = busId;
    results(index).voltageBaseV = bus.VbaseV;
    results(index).currentBaseA = calculateBaseValues( ...
        network.base.SbaseVA, bus.VbaseV).IbaseA;
    results(index).sequenceVoltages_pu = Vseq;
    results(index).phaseVoltages_pu = sequenceToPhase(Vseq);
    results(index).sequenceCurrents_pu = Iseq_bus;
    results(index).phaseCurrents_pu = sequenceToPhase(Iseq_bus);
    results(index).supportStatus = 'supportedOnFaultPath';
end
end

function results = relayPhasors(network, path, relays, Vth, Iseq)
% Dyn11 vector group: Low-voltage leads High-voltage by +30 deg (+pi/6 rad) in positive sequence
DELTA_WYE_PHASE_SHIFT_RAD = -pi / 6;

deltaWyeIdx = find(strcmp({path.type}, 'transformer') & ...
    strcmpi(strtrim({path.windingConnection}), 'delta-grounded-wye'), 1);

results = repmat(struct( ...
    'relayId', '', 'measurementElementType', '', ...
    'measurementElementId', '', 'measurementSide', '', ...
    'measurementBus', '', 'voltageBaseV', [], 'currentBaseA', [], ...
    'sequenceCurrents_pu', [], 'phaseCurrents_pu', [], ...
    'sequenceCurrents_A', [], 'phaseCurrents_A', [], ...
    'sequenceVoltages_pu', [], 'phaseVoltages_pu', [], ...
    'directionalResult', struct(), 'supportStatus', ''), 1, numel(relays));
for index = 1:numel(relays)
    relay = relays(index);
    [type, id, side] = relayLocation(relay);
    pathIndex = find(strcmp({path.type}, type) & strcmp({path.id}, id), 1);
    results(index).relayId = char(relay.id);
    results(index).measurementElementType = type;
    results(index).measurementElementId = id;
    results(index).measurementSide = side;
    if isempty(pathIndex)
        results(index).supportStatus = 'unsupportedOffFaultPath';
        results(index).directionalResult = ...
            evaluateDirectionalSupervision(struct(), struct());
        continue;
    end
    busId = measurementBus(path(pathIndex), side);
    bus = network.buses(strcmp({network.buses.id}, busId));
    bases = calculateBaseValues(network.base.SbaseVA, bus.VbaseV);
    Z = measurementImpedance(network, path, pathIndex, side);
    Vseq = [-Z(1) * Iseq(1); Vth - Z(2) * Iseq(2); ...
        -Z(3) * Iseq(3)];

    isHvSide = false;
    if ~isempty(deltaWyeIdx)
        if pathIndex < deltaWyeIdx || (pathIndex == deltaWyeIdx && strcmp(side, 'high'))
            isHvSide = true;
        end
    end

    if isHvSide
        Iseq_relay = [0; ...
            Iseq(2) * exp(1i * DELTA_WYE_PHASE_SHIFT_RAD); ...
            Iseq(3) * exp(-1i * DELTA_WYE_PHASE_SHIFT_RAD)];
    else
        Iseq_relay = Iseq;
    end

    Iphase = sequenceToPhase(Iseq_relay);
    Vphase = sequenceToPhase(Vseq);
    results(index).measurementBus = busId;
    results(index).voltageBaseV = bus.VbaseV;
    results(index).currentBaseA = bases.IbaseA;
    results(index).sequenceCurrents_pu = Iseq_relay;
    results(index).phaseCurrents_pu = Iphase;
    results(index).sequenceCurrents_A = Iseq_relay * bases.IbaseA;
    results(index).phaseCurrents_A = Iphase * bases.IbaseA;
    results(index).sequenceVoltages_pu = Vseq;
    results(index).phaseVoltages_pu = Vphase;
    settings = struct();
    if isfield(relay, 'directionalSettings')
        settings = relay.directionalSettings;
    end
    results(index).directionalResult = evaluateDirectionalSupervision( ...
        settings, struct('currentPhasor', Iseq_relay(2), ...
        'polarizingVoltagePhasor', Vseq(2)));
    results(index).supportStatus = 'supportedOnFaultPath';
end
end

function [path, Z1, Z2, Z0, hasGroundedNeutral, deltaWyeIndex] = pathData(network, busId)
[path, Z1, Z2, Z0, hasGroundedNeutral, deltaWyeIndex] = traceRadialPath(network, busId);
end

function phases = sequenceToPhase(sequence)
a = exp(1i * 2*pi/3);
phases = [1, 1, 1; 1, a^2, a; 1, a, a^2] * sequence;
end

function [type, id, side] = relayLocation(relay)
if isfield(relay, 'measurementElementType')
    type = lower(strtrim(char(relay.measurementElementType)));
    id = char(relay.measurementElementId);
    side = lower(strtrim(char(relay.measurementSide)));
else
    type = 'branch';
    id = char(relay.protectedBranch);
    side = 'from';
end
end

function busId = measurementBus(element, side)
if strcmp(element.type, 'transformer')
    if strcmp(side, 'high')
        busId = element.fromBus;
    else
        busId = element.toBus;
    end

elseif strcmp(side, 'from')
    busId = element.fromBus;
else
    busId = element.toBus;
end
end

function Z = measurementImpedance(network, path, elementIndex, side)
Z = cumulativeImpedance(network, path, elementIndex - 1);
if strcmp(path(elementIndex).type, 'transformer') && strcmp(side, 'low')
    Z = Z + path(elementIndex).Z;
elseif strcmp(path(elementIndex).type, 'branch') && strcmp(side, 'to')
    Z = Z + path(elementIndex).Z;
end
end

function Z = cumulativeImpedance(network, path, count)
Z = [network.source.Z0_pu; network.source.Z1_pu; network.source.Z2_pu];
for index = 1:count
    Z = Z + path(index).Z;
end
end

function value = isZeroSequenceFault(type)
value = any(strcmp(lower(strtrim(type)), {'slg', ...
    'single line to ground', 'single-line-to-ground', 'dlg', ...
    'double line to ground', 'double-line-to-ground'}));
end
