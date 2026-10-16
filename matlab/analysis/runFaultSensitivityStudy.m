function study = runFaultSensitivityStudy(network, scenarios, relays, ...
    coordinationPairs, options)
% runFaultSensitivityStudy Add breaker, zone, direction, and CT screening.

if nargin < 5 || isempty(options)
    options = struct();
end
if ~isstruct(options) || ~isscalar(options)
    error('runFaultSensitivityStudy:InvalidOptions', ...
        'options must be a scalar structure.');
end
breakers = getOption(options, 'breakers', struct([]));
zones = getOption(options, 'zones', struct([]));
failureScenarios = getOption(options, 'breakerFailureScenarios', struct([]));
includePhasors = getOption(options, 'includePhasors', false);
validateBreakers(breakers, relays);
validateProtectionZones(zones, network, relays, breakers);

baseResults = runIntegratedFaultStudy( ...
    network, scenarios, relays, coordinationPairs);
relayRows = struct([]);
coordinationRows = struct([]);
failureRows = struct([]);
phasorResults = struct([]);
selectivityTables = {};
for scenarioIndex = 1:numel(baseResults)
    base = baseResults(scenarioIndex);
    if includePhasors
        phasors = calculateNetworkPhasors( ...
            network, scenarios(scenarioIndex), relays);
        phasorResults = appendRow(phasorResults, phasors);
        selectivityTables{end + 1} = phasors; %#ok<AGROW>
    end
    for relayIndex = 1:numel(base.relayResults)
        relayResult = base.relayResults(relayIndex);
        relay = relays(strcmp({relays.id}, relayResult.relayId));
        breaker = breakerForRelay(breakers, relayResult.relayId);
        delay = 0;
        breakerId = '';
        if ~isempty(breaker)
            delay = breaker.openingDelay_s;
            breakerId = char(breaker.id);
        end
        clearing = calculateBreakerClearingTime( ...
            relayResult.operatingTime_s, delay);
        threshold = getRelayThreshold(options, relayResult.relayId);
        ct = screenCTSaturation( ...
            relayResult.faultCurrentPrimary_A, relay, threshold);
        directionSettings = getRelayDirection(options, relayResult.relayId);
        direction = evaluateDirectionalSupervision(directionSettings, struct());
        row = struct( ...
            'scenarioId', base.scenarioId, ...
            'faultedBus', base.faultedBus, ...
            'faultType', base.faultType, ...
            'faultImpedance_pu', base.faultImpedance_pu, ...
            'faultCurrent_pu', base.faultCurrent_pu, ...
            'faultCurrent_A', base.faultCurrentMagnitude_A, ...
            'relayId', relayResult.relayId, ...
            'relayCurrentPrimary_A', relayResult.faultCurrentPrimary_A, ...
            'relayCurrentSecondary_A', relayResult.relayCurrentSecondary_A, ...
            'pickupRatio', relayResult.pickupRatio, ...
            'relayOperatingTime_s', relayResult.operatingTime_s, ...
            'breakerId', breakerId, ...
            'breakerOpeningDelay_s', delay, ...
            'totalClearingTime_s', clearing.totalClearingTime_s, ...
            'directionalStatus', direction.status, ...
            'ctScreeningStatus', ct.status, ...
            'ctScreeningWarning', ct.warning, ...
            'reason', relayResult.reason);
        relayRows = appendRow(relayRows, row);
    end
    for pairIndex = 1:numel(base.coordinationResults)
        pair = base.coordinationResults(pairIndex);
        primary = base.relayResults(strcmp( ...
            {base.relayResults.relayId}, pair.primaryRelayId));
        backup = base.relayResults(strcmp( ...
            {base.relayResults.relayId}, pair.backupRelayId));
        primaryBreaker = breakerForRelay(breakers, primary.relayId);
        backupBreaker = breakerForRelay(breakers, backup.relayId);
        primaryDelay = breakerDelay(primaryBreaker);
        backupDelay = breakerDelay(backupBreaker);
        primaryClear = calculateBreakerClearingTime( ...
            primary.operatingTime_s, primaryDelay);
        backupClear = calculateBreakerClearingTime( ...
            backup.operatingTime_s, backupDelay);
        margin = computeCoordinationMargin(backup.operatingTime_s, ...
            primary.operatingTime_s, primaryDelay);
        cti = computeCoordinationMargin(backup.operatingTime_s, ...
            primary.operatingTime_s, 0);
        row = struct( ...
            'scenarioId', base.scenarioId, ...
            'primaryRelayId', pair.primaryRelayId, ...
            'backupRelayId', pair.backupRelayId, ...
            'coordinationInterval_s', cti, ...
            'minimumCTI_s', pair.minimumCTI_s, ...
            'primaryTotalClearingTime_s', primaryClear.totalClearingTime_s, ...
            'backupTotalClearingTime_s', backupClear.totalClearingTime_s, ...
            'clearingTimeMargin_s', margin, ...
            'isCoordinated', pair.isCoordinated);
        coordinationRows = appendRow(coordinationRows, row);
    end
    for failureIndex = 1:numel(failureScenarios)
        failureScenario = failureScenarios(failureIndex);
        if isfield(failureScenario, 'scenarioId') && ...
                ~strcmp(failureScenario.scenarioId, base.scenarioId)
            continue;
        end
        failureResult = evaluateBreakerFailureScenario( ...
            base, zones, relays, breakers, failureScenario);
        failureRows = appendRow(failureRows, failureResult);
    end
end
study.scenarioResults = baseResults;
study.relayResults = relayRows;
study.coordinationResults = coordinationRows;
study.breakerFailureResults = failureRows;
study.relayTable = struct2table(relayRows);
study.coordinationTable = struct2table(coordinationRows);
if isempty(failureRows)
    study.breakerFailureTable = table();
else
    study.breakerFailureTable = struct2table(failureRows);
end
if includePhasors
    study.phasorResults = phasorResults;
    matrixTables = cell(size(selectivityTables));
    for index = 1:numel(selectivityTables)
        matrixTables{index} = buildProtectionSelectivityMatrix( ...
            selectivityTables{index}, study);
    end
    study.selectivityMatrix = concatenateTables(matrixTables);
else
    study.phasorResults = struct([]);
    study.selectivityMatrix = table();
end
study.assumptions = {'Breaker delay is added after relay operating time.', ...
    'Directional status is unsupported without polarizing phasors.', ...
    'CT screening thresholds are warnings, not saturation predictions.'};
end

function output = concatenateTables(values)
output = table();
for index = 1:numel(values)
    if isempty(values{index})
        continue;
    end
    if isempty(output)
        output = values{index};
    else
        output = [output; values{index}]; %#ok<AGROW>
    end
end
end

function value = getOption(options, name, default)
if isfield(options, name)
    value = options.(name);
else
    value = default;
end
end

function validateBreakers(breakers, relays)
if isempty(breakers)
    return;
end
required = {'id', 'relayId', 'openingDelay_s'};
relayIds = {relays.id};
for index = 1:numel(breakers)
    for fieldIndex = 1:numel(required)
        if ~isfield(breakers, required{fieldIndex})
            error('runFaultSensitivityStudy:MissingBreakerField', ...
                'Breaker is missing %s.', required{fieldIndex});
        end
    end
    if ~any(strcmp(relayIds, breakers(index).relayId))
        error('runFaultSensitivityStudy:InvalidBreakerRelay', ...
            'Breaker %s references an unknown relay.', breakers(index).id);
    end
    if ~isnumeric(breakers(index).openingDelay_s) || ...
            ~isscalar(breakers(index).openingDelay_s) || ...
            ~isfinite(breakers(index).openingDelay_s) || ...
            breakers(index).openingDelay_s < 0
        error('runFaultSensitivityStudy:InvalidBreakerDelay', ...
            'Breaker openingDelay_s must be finite and nonnegative.');
    end
end
end

function breaker = breakerForRelay(breakers, relayId)
breaker = struct([]);
if ~isempty(breakers)
    match = strcmp({breakers.relayId}, relayId);
    if any(match)
        breaker = breakers(find(match, 1));
    end
end
end

function delay = breakerDelay(breaker)
if isempty(breaker)
    delay = 0;
else
    delay = breaker.openingDelay_s;
end
end

function threshold = getRelayThreshold(options, relayId)
threshold = [];
if isfield(options, 'ctScreeningThresholds') && ...
        isstruct(options.ctScreeningThresholds)
    if isfield(options.ctScreeningThresholds, relayId)
        threshold = options.ctScreeningThresholds.(relayId);
    end
end
end

function settings = getRelayDirection(options, relayId)
settings = struct();
if isfield(options, 'directionalSettings') && ...
        isstruct(options.directionalSettings) && ...
        isfield(options.directionalSettings, relayId)
    settings = options.directionalSettings.(relayId);
end
end

function rows = appendRow(rows, row)
if isempty(rows)
    rows = row;
else
    rows(end + 1) = row;
end
end
