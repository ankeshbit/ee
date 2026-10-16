function matrix = buildProtectionSelectivityMatrix(phasorStudy, ...
    sensitivityStudy)
% buildProtectionSelectivityMatrix Combine calculated phasors and protection.
% Electrical quantities are consumed from the supplied result objects; this
% function does not solve faults or recompute relay operating times.

if ~isstruct(phasorStudy) || ~isfield(phasorStudy, 'relayMeasurements')
    error('buildProtectionSelectivityMatrix:InvalidPhasorStudy', ...
        'phasorStudy must contain relayMeasurements.');
end
if nargin < 2 || isempty(sensitivityStudy)
    sensitivityStudy = struct();
end
relayTable = getTable(sensitivityStudy, 'relayTable');
failureTable = getTable(sensitivityStudy, 'breakerFailureTable');
rows = struct([]);
for index = 1:numel(phasorStudy.relayMeasurements)
    measurement = phasorStudy.relayMeasurements(index);
    row = struct( ...
        'scenarioId', phasorStudy.scenarioId, ...
        'faultedBus', phasorStudy.faultedBus, ...
        'faultType', phasorStudy.faultType, ...
        'faultImpedance_pu', phasorStudy.faultStudyResult.faultImpedance_pu, ...
        'relayId', measurement.relayId, ...
        'measurementElementType', measurement.measurementElementType, ...
        'measurementElementId', measurement.measurementElementId, ...
        'measurementSide', measurement.measurementSide, ...
        'phaseCurrentMagnitude_A', scalarMagnitude(measurement.phaseCurrents_A), ...
        'sequenceCurrentMagnitude_A', abs(measurement.sequenceCurrents_A), ...
        'sequenceVoltage_pu', measurement.sequenceVoltages_pu, ...
        'directionalStatus', measurement.directionalResult.status, ...
        'primaryBackupRole', 'notAssigned', ...
        'relayOperatingTime_s', Inf, ...
        'breakerOpeningDelay_s', NaN, ...
        'totalClearingTime_s', Inf, ...
        'relayCTI_s', NaN, ...
        'clearingTimeMargin_s', NaN, ...
        'breakerFailureStatus', 'notConfigured', ...
        'eligibleToClear', false, ...
        'selectivityStatus', measurement.supportStatus, ...
        'reason', measurement.directionalResult.reason);
    if ~isempty(relayTable)
        match = strcmp(relayTable.scenarioId, row.scenarioId) & ...
            strcmp(relayTable.relayId, row.relayId);
        if any(match)
            source = relayTable(find(match, 1), :);
            row.relayOperatingTime_s = source.relayOperatingTime_s;
            row.breakerOpeningDelay_s = source.breakerOpeningDelay_s;
            row.totalClearingTime_s = source.totalClearingTime_s;
            row.eligibleToClear = isfinite(row.totalClearingTime_s) && ...
                strcmp(measurement.supportStatus, 'supportedOnFaultPath');
        end
    end
    if ~isempty(failureTable)
        isPrimary = strcmp(failureTable.primaryRelayId, row.relayId);
        isBackup = false(height(failureTable), 1);
        if ismember('backupRelayIds', failureTable.Properties.VariableNames)
            backupCol = failureTable.backupRelayIds;
            for bIdx = 1:height(failureTable)
                if iscell(backupCol)
                    entry = backupCol{bIdx};
                else
                    entry = backupCol(bIdx);
                end
                isBackup(bIdx) = matchesRelayId(entry, row.relayId);
            end
        end
        match = strcmp(failureTable.scenarioId, row.scenarioId) & ...
            (isPrimary | isBackup);
        if any(match)
            source = failureTable(find(match, 1), :);
            row.breakerFailureStatus = source.overallStatus;
            row.relayCTI_s = source.relayCTI_s;
            row.clearingTimeMargin_s = source.clearingTimeMargin_s;
            row.selectivityStatus = source.zoneStatus;
        end
    end
    rows = appendRow(rows, row);
end
if isempty(rows)
    matrix = table();
else
    matrix = struct2table(rows);
end
end

function value = getTable(study, name)
value = table();
if isfield(study, name) && ~isempty(study.(name))
    value = study.(name);
end
end

function rows = appendRow(rows, row)
if isempty(rows)
    rows = row;
else
    rows(end + 1) = row;
end
end

function value = scalarMagnitude(values)
if isempty(values)
    value = NaN;
else
    value = max(abs(values(:)));
end
end

function tf = matchesRelayId(ids, targetRelayId)
if isempty(ids)
    tf = false;
    return;
end
if iscell(ids) && isscalar(ids) && (iscell(ids{1}) || isstring(ids{1}))
    ids = ids{1};
end
if ischar(ids)
    tf = strcmp(ids, targetRelayId);
elseif iscell(ids) || isstring(ids)
    tf = any(strcmp(ids, targetRelayId));
else
    tf = false;
end
end
