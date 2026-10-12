function result = evaluateBreakerFailureScenario(faultStudyResult, ...
    protectionZones, relays, breakers, failureScenario)
% evaluateBreakerFailureScenario Evaluate normal or breaker-failure clearing.
% The faultStudyResult is one result from runIntegratedFaultStudy.

validateInput(faultStudyResult, protectionZones, relays, breakers, ...
    failureScenario);
relayResults = faultStudyResult.relayResults;
applicable = applicableZones(protectionZones, faultStudyResult);

result.scenarioId = faultStudyResult.scenarioId;
result.failureScenarioId = char(failureScenario.id);
result.faultedBus = faultStudyResult.faultedBus;
result.applicableZoneIds = {applicable.id};
result.zoneStatus = zoneStatus(applicable);
result.primaryRelayId = '';
result.primaryBreakerId = '';
result.backupRelayIds = {};
result.backupBreakerIds = {};
result.primaryRelayOperatingTime_s = Inf;
result.primaryBreakerOpeningDelay_s = [];
result.primaryClearingTime_s = Inf;
result.backupRelayOperatingTime_s = Inf;
result.backupBreakerOpeningDelay_s = [];
result.backupClearingTime_s = Inf;
result.relayCTI_s = Inf;
result.clearingTimeMargin_s = Inf;
result.minimumRequiredMargin_s = [];
result.primaryPicksUp = false;
result.primaryBreakerClears = false;
result.backupOperates = false;
result.directionalStatus = 'notApplicable';
result.overallStatus = 'NOT_CLEARED_BY_MODELED_PROTECTION';
result.reason = '';

if isempty(applicable)
    result.zoneStatus = 'missingOrAmbiguous';
    result.reason = 'No protection zone applies to the faulted bus.';
    return;
end
if numel(applicable) > 1
    result.zoneStatus = 'overlap';
    result.reason = 'Multiple protection zones apply; primary selection is ambiguous.';
    return;
end

zone = applicable(1);
result.primaryRelayId = char(zone.primaryRelayId);
result.primaryBreakerId = breakerIdForRelay( ...
    breakers, result.primaryRelayId);
result.backupRelayIds = normalizeIds(zone.backupRelayIds);
result.backupBreakerIds = cellfun(@(id) breakerIdForRelay(breakers, id), ...
    result.backupRelayIds, 'UniformOutput', false);
result.minimumRequiredMargin_s = zone.minimumCTI_s;
primary = findRelayResult(relayResults, result.primaryRelayId);
if isempty(primary)
    result.reason = 'Primary relay result is unavailable.';
    return;
end
result.primaryRelayOperatingTime_s = primary.operatingTime_s;
result.primaryPicksUp = primary.operates && ...
    ~isDisabled(failureScenario, result.primaryRelayId);
primaryBreaker = breakerForRelay(breakers, result.primaryRelayId);
if isempty(primaryBreaker)
    result.reason = 'Primary breaker configuration is missing.';
    return;
end
result.primaryBreakerOpeningDelay_s = primaryBreaker.openingDelay_s;
failedPrimary = breakerFailed(failureScenario, result.primaryBreakerId);
result.primaryBreakerClears = result.primaryPicksUp && ...
    breakerCanClear(primaryBreaker) && ~failedPrimary;
if result.primaryBreakerClears
    clearing = calculateBreakerClearingTime( ...
        result.primaryRelayOperatingTime_s, ...
        result.primaryBreakerOpeningDelay_s);
    result.primaryClearingTime_s = clearing.totalClearingTime_s;
    result.overallStatus = 'CLEARED_BY_PRIMARY_PROTECTION';
    result.reason = 'Primary relay operated and primary breaker cleared.';
    return;
end

best = struct([]);
for index = 1:numel(result.backupRelayIds)
    backupId = result.backupRelayIds{index};
    backup = findRelayResult(relayResults, backupId);
    backupBreaker = breakerForRelay(breakers, backupId);
    if isempty(backup) || isempty(backupBreaker) || ...
            ~backup.operates || isDisabled(failureScenario, backupId)
        continue;
    end
    directional = directionalStatus(failureScenario, backupId);
    if strcmp(directional, 'reverse') || strcmp(directional, 'blocked') || ...
            strcmp(directional, 'unsupported') || strcmp(directional, 'indeterminate')
        continue;
    end
    if breakerFailed(failureScenario, backupBreaker.id) || ...
            ~breakerCanClear(backupBreaker)
        continue;
    end
    candidate = struct('relay', backup, 'breaker', backupBreaker, ...
        'direction', directional);
    if isempty(best) || backup.operatingTime_s + ...
            backupBreaker.openingDelay_s < best.relay.operatingTime_s + ...
            best.breaker.openingDelay_s
        best = candidate;
    end
end
if isempty(best)
    result.reason = 'No configured backup relay and breaker can clear the fault.';
    return;
end

result.backupRelayOperatingTime_s = best.relay.operatingTime_s;
result.backupBreakerOpeningDelay_s = best.breaker.openingDelay_s;
result.backupClearingTime_s = calculateBreakerClearingTime( ...
    best.relay.operatingTime_s, best.breaker.openingDelay_s).totalClearingTime_s;
result.backupOperates = true;
result.directionalStatus = best.direction;
result.relayCTI_s = best.relay.operatingTime_s - ...
    result.primaryRelayOperatingTime_s;
result.clearingTimeMargin_s = best.relay.operatingTime_s - ...
    result.primaryClearingTime_s;
result.overallStatus = 'CLEARED_BY_BACKUP_PROTECTION';
result.reason = 'Primary breaker failed; configured backup protection cleared the fault.';
end

function validateInput(fault, zones, relays, breakers, scenario)
if ~isstruct(fault) || ~isscalar(fault) || ...
        ~isfield(fault, 'relayResults') || ~isfield(fault, 'faultedBus')
    error('evaluateBreakerFailureScenario:InvalidFaultStudyResult', ...
        'faultStudyResult must be one integrated study result.');
end
if isempty(zones) || ~isstruct(zones)
    error('evaluateBreakerFailureScenario:InvalidZones', ...
        'At least one protection zone is required.');
end
if ~isstruct(relays) || isempty(relays) || ~isstruct(breakers) || isempty(breakers)
    error('evaluateBreakerFailureScenario:InvalidProtection', ...
        'Relays and breakers must be configured.');
end
if ~isstruct(scenario) || ~isscalar(scenario) || ~isfield(scenario, 'id')
    error('evaluateBreakerFailureScenario:InvalidFailureScenario', ...
        'failureScenario must contain an id.');
end
validateBreakerStates(breakers);
end

function validateBreakerStates(breakers)
valid = {'closed', 'opened', 'failedToOpen', 'notCommanded'};
for index = 1:numel(breakers)
    if isfield(breakers, 'state') && ~isempty(breakers(index).state) && ...
            ~any(strcmp(valid, breakers(index).state))
        error('evaluateBreakerFailureScenario:InvalidBreakerState', ...
            'Breaker %s has an invalid state.', breakers(index).id);
    end
end
end

function zones = applicableZones(allZones, fault)
zones = allZones([]);
for index = 1:numel(allZones)
    zone = allZones(index);
    if isfield(zone, 'applicableFaultedBuses')
        ids = normalizeIds(zone.applicableFaultedBuses);
        if any(strcmp(ids, fault.faultedBus))
            zones(end + 1) = zone; %#ok<AGROW>
        end
    end
end
end

function value = zoneStatus(zones)
if isempty(zones)
    value = 'missing';
elseif numel(zones) == 1
    value = 'covered';
else
    value = 'overlap';
end
end

function relay = findRelayResult(results, relayId)
relay = results(strcmp({results.relayId}, relayId));
if numel(relay) > 1
    relay = relay(1);
end
end

function breaker = breakerForRelay(breakers, relayId)
breaker = breakers(strcmp({breakers.relayId}, relayId));
if numel(breaker) > 1
    breaker = breaker(1);
end
end

function id = breakerIdForRelay(breakers, relayId)
breaker = breakerForRelay(breakers, relayId);
if isempty(breaker)
    id = '';
else
    id = char(breaker.id);
end
end

function ids = normalizeIds(value)
if ischar(value)
    ids = {value};
elseif isstring(value)
    ids = cellstr(value(:));
elseif iscell(value)
    ids = value;
else
    ids = {};
end
end

function value = getOption(value, name, default)
if isfield(value, name)
    value = value.(name);
else
    value = default;
end
end

function value = isDisabled(scenario, relayId)
value = false;
if isfield(scenario, 'disabledRelayIds')
    value = any(strcmp(normalizeIds(scenario.disabledRelayIds), relayId));
end
end

function value = directionalStatus(scenario, relayId)
value = 'notApplicable';
if isfield(scenario, 'directionalResults') && ...
        isstruct(scenario.directionalResults) && ...
        isfield(scenario.directionalResults, relayId)
    entry = scenario.directionalResults.(relayId);
    if isstruct(entry) && isfield(entry, 'status')
        value = char(entry.status);
    else
        value = char(entry);
    end
end
end

function value = breakerFailed(scenario, breakerId)
failedIds = {};
if isfield(scenario, 'failedBreakerId') && ~isempty(scenario.failedBreakerId)
    failedIds = [failedIds, normalizeIds(scenario.failedBreakerId)];
end
if isfield(scenario, 'failedBreakerIds')
    failedIds = [failedIds, normalizeIds(scenario.failedBreakerIds)];
end
value = any(strcmp(failedIds, breakerId));
end

function value = breakerCanClear(breaker)
value = true;
if isfield(breaker, 'state') && ~isempty(breaker.state)
    value = strcmp(breaker.state, 'closed');
end
end
