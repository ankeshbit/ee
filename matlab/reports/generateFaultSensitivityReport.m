function report = generateFaultSensitivityReport(study)
% generateFaultSensitivityReport Create report tables without plotting.

if ~isstruct(study) || ~isfield(study, 'relayTable') || ...
        ~isfield(study, 'coordinationTable')
    error('generateFaultSensitivityReport:InvalidStudy', ...
        'study must be returned by runFaultSensitivityStudy.');
end
report.scenarioSummary = scenarioSummary(study.scenarioResults);
report.relayOperatingTimes = study.relayTable;
report.coordination = study.coordinationTable;
if isfield(study, 'selectivityMatrix')
    report.selectivityMatrix = study.selectivityMatrix;
else
    report.selectivityMatrix = table();
end
if isfield(study, 'phasorResults') && ~isempty(study.phasorResults)
    report.phasorResults = study.phasorResults;
else
    report.phasorResults = struct([]);
end
if isfield(study, 'breakerFailureTable')
    report.breakerFailure = study.breakerFailureTable;
else
    report.breakerFailure = table();
end
if isempty(study.coordinationTable)
    report.failedCoordination = study.coordinationTable;
else
    report.failedCoordination = study.coordinationTable( ...
        ~study.coordinationTable.isCoordinated, :);
end
if isempty(study.relayTable)
    report.nonOperatingRelays = study.relayTable;
    report.ctScreeningWarnings = study.relayTable;
    report.directionalUnsupported = study.relayTable;
else
    report.nonOperatingRelays = study.relayTable( ...
        isinf(study.relayTable.relayOperatingTime_s), :);
    report.ctScreeningWarnings = study.relayTable( ...
        ~strcmp(study.relayTable.ctScreeningStatus, ...
        'withinConfiguredLimits'), :);
    report.directionalUnsupported = study.relayTable( ...
        ~strcmp(study.relayTable.directionalStatus, 'forward') & ...
        ~strcmp(study.relayTable.directionalStatus, 'reverse'), :);
end
if isempty(report.breakerFailure)
    report.backupClearingOutcomes = report.breakerFailure;
    report.unclearedFaults = report.breakerFailure;
    report.zoneConfigurationIssues = report.breakerFailure;
else
    report.backupClearingOutcomes = report.breakerFailure( ...
        strcmp(report.breakerFailure.overallStatus, ...
        'CLEARED_BY_BACKUP_PROTECTION'), :);
    report.unclearedFaults = report.breakerFailure( ...
        strcmp(report.breakerFailure.overallStatus, ...
        'NOT_CLEARED_BY_MODELED_PROTECTION'), :);
    report.zoneConfigurationIssues = report.breakerFailure( ...
        strcmp(report.breakerFailure.zoneStatus, 'missingOrAmbiguous') | ...
        strcmp(report.breakerFailure.zoneStatus, 'overlap'), :);
end
end

function tableOutput = scenarioSummary(results)
if isempty(results)
    tableOutput = table();
    return;
end
ids = {results.scenarioId}';
buses = {results.faultedBus}';
types = {results.faultType}';
currentPu = [results.faultCurrentMagnitude_pu]';
currentA = [results.faultCurrentMagnitude_A]';
tableOutput = table(ids, buses, types, currentPu, currentA, ...
    'VariableNames', {'scenarioId', 'faultedBus', 'faultType', ...
    'faultCurrent_pu', 'faultCurrent_A'});
end
