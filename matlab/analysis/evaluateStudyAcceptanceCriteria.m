function [outcomes, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(simResults, rtTable, expectedScenarios)
% evaluateStudyAcceptanceCriteria Comprehensive acceptance criteria evaluation
% for fault study and protection coordination verification.
%
% Syntax:
%   [outcomes, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(simResults)
%   [outcomes, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(simResults, rtTable)
%   [outcomes, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(simResults, rtTable, expectedScenarios)
%
% Inputs:
%   simResults        - Cell array of simulation result structures from
%                       runDynamicBreakerSwitchingSimulation.
%   rtTable           - (optional) Relay timing comparison table.
%   expectedScenarios - (optional) Cell array of mandatory scenario IDs.
%                       Defaults to: {'PF_HEALTHY', 'PF_3PH', 'PF_SLG', 'PF_LL', 'PF_DLG', 'PF_3PH_CBF'}
%
% Outputs:
%   outcomes          - Struct array of evaluated criteria with fields:
%                       criterion, scenarioId, pass (bool), status ('PASS'|'FAIL'|'BLOCKED'|'INCOMPLETE'),
%                       value, limit.
%   overallPass       - Boolean. True ONLY if all mandatory scenarios and criteria PASS.
%                       NEVER true on empty or missing results.
%   overallStatus     - Char: 'PASS', 'FAIL', 'BLOCKED', or 'INCOMPLETE'.

    if nargin < 2
        rtTable = [];
    end
    if nargin < 3 || isempty(expectedScenarios)
        expectedScenarios = {'PF_HEALTHY', 'PF_3PH', 'PF_SLG', 'PF_LL', 'PF_DLG', 'PF_3PH_CBF'};
    end

    RELAY_TOL_S = 0.020; % ±20 ms timing tolerance band
    EXTINCT_A   = 0.01;  % 10 mA extinction threshold
    MAX_CLEAR_S = 0.300; % 300 ms maximum primary clearing delay

    outcomes = struct('criterion', {}, 'scenarioId', {}, 'pass', {}, ...
                      'status', {}, 'value', {}, 'limit', {});

    % 1. Handle empty simResults array
    if isempty(simResults)
        overallPass = false;
        overallStatus = 'INCOMPLETE';
        for sIdx = 1:numel(expectedScenarios)
            row = struct('criterion', 'MandatoryScenarioExecuted', ...
                'scenarioId', expectedScenarios{sIdx}, ...
                'pass', false, ...
                'status', 'INCOMPLETE', ...
                'value', 'MISSING', ...
                'limit', 'COMPLETED');
            outcomes(end+1) = row; %#ok<AGROW>
        end
        return;
    end

    % 2. Index simulation results by scenarioId
    simMap = containers.Map();
    for i = 1:numel(simResults)
        r = simResults{i};
        if isempty(r) || ~isstruct(r), continue; end
        sId = '';
        if isfield(r, 'scenarioId') && ~isempty(r.scenarioId)
            sId = char(r.scenarioId);
        elseif isfield(r, 'id') && ~isempty(r.id)
            sId = char(r.id);
        end
        if ~isempty(sId)
            simMap(sId) = r;
        end
    end

    % 3. Evaluate each mandatory scenario
    hasBlocked = false;
    hasFailed = false;
    hasIncomplete = false;

    for sIdx = 1:numel(expectedScenarios)
        reqId = expectedScenarios{sIdx};
        if ~isKey(simMap, reqId)
            hasIncomplete = true;
            row = struct('criterion', 'MandatoryScenarioExecuted', ...
                'scenarioId', reqId, ...
                'pass', false, ...
                'status', 'INCOMPLETE', ...
                'value', 'MISSING', ...
                'limit', 'COMPLETED');
            outcomes(end+1) = row; %#ok<AGROW>
            continue;
        end

        r = simMap(reqId);
        simStatus = 'UNKNOWN';
        if isfield(r, 'status') && ~isempty(r.status)
            simStatus = upper(strtrim(char(r.status)));
        end

        switch simStatus
            case 'BLOCKED'
                hasBlocked = true;
                row = struct('criterion', 'ScenarioExecutionStatus', ...
                    'scenarioId', reqId, ...
                    'pass', false, ...
                    'status', 'BLOCKED', ...
                    'value', 'BLOCKED', ...
                    'limit', 'COMPLETED');
                outcomes(end+1) = row; %#ok<AGROW>
                continue;

            case {'BUILD_FAILED', 'SIMULATION_FAILED', 'FAILED', 'MEASUREMENTS_INVALID'}
                hasFailed = true;
                row = struct('criterion', 'ScenarioExecutionStatus', ...
                    'scenarioId', reqId, ...
                    'pass', false, ...
                    'status', 'FAIL', ...
                    'value', simStatus, ...
                    'limit', 'COMPLETED');
                outcomes(end+1) = row; %#ok<AGROW>
                continue;

            case {'NOT_RUN', 'SKIPPED', 'INCOMPLETE'}
                hasIncomplete = true;
                row = struct('criterion', 'ScenarioExecutionStatus', ...
                    'scenarioId', reqId, ...
                    'pass', false, ...
                    'status', 'INCOMPLETE', ...
                    'value', simStatus, ...
                    'limit', 'COMPLETED');
                outcomes(end+1) = row; %#ok<AGROW>
                continue;

            case 'COMPLETED'
                % Proceed to physical criteria evaluation below
            otherwise
                hasFailed = true;
                row = struct('criterion', 'ScenarioExecutionStatus', ...
                    'scenarioId', reqId, ...
                    'pass', false, ...
                    'status', 'FAIL', ...
                    'value', sprintf('UNEXPECTED_STATUS_%s', simStatus), ...
                    'limit', 'COMPLETED');
                outcomes(end+1) = row; %#ok<AGROW>
                continue;
        end

        % Detailed physical criteria checks for COMPLETED simulation
        isHealthy = strcmp(r.faultType, 'HEALTHY');
        isCBF     = contains(reqId, 'CBF');

        if ~isHealthy && ~isCBF
            % Primary relay & breaker operation
            if isfield(r, 'relay') && isfield(r.relay, 'B') && isfield(r.relay.B, 'breakerOpenTime_s') && isfinite(r.relay.B.breakerOpenTime_s)
                delay = r.relay.B.breakerOpenTime_s - r.faultInception_s;
                passDelay = (delay < MAX_CLEAR_S) && (delay >= 0);
                row = struct('criterion', 'PrimaryBreakWithinLimit', ...
                    'scenarioId', reqId, ...
                    'pass', passDelay, ...
                    'status', p_passToStatus(passDelay), ...
                    'value', sprintf('%.3f s', delay), ...
                    'limit', sprintf('< %.3f s', MAX_CLEAR_S));
                outcomes(end+1) = row; %#ok<AGROW>
            else
                hasFailed = true;
                row = struct('criterion', 'PrimaryBreakWithinLimit', ...
                    'scenarioId', reqId, ...
                    'pass', false, ...
                    'status', 'FAIL', ...
                    'value', 'NO_BREAKER_OPEN_TIME', ...
                    'limit', sprintf('< %.3f s', MAX_CLEAR_S));
                outcomes(end+1) = row; %#ok<AGROW>
            end

            % Current extinction check
            if isfield(r, 'clearingVerification') && isstruct(r.clearingVerification)
                cv = r.clearingVerification;
                passExt = isfield(cv, 'faultCleared') && cv.faultCleared && ...
                          isfield(cv, 'postClearingCurrentPeak_A') && (cv.postClearingCurrentPeak_A < EXTINCT_A);
                peakVal = NaN;
                if isfield(cv, 'postClearingCurrentPeak_A'), peakVal = cv.postClearingCurrentPeak_A; end
                row = struct('criterion', 'FaultCurrentExtinction', ...
                    'scenarioId', reqId, ...
                    'pass', passExt, ...
                    'status', p_passToStatus(passExt), ...
                    'value', sprintf('%.4f A', peakVal), ...
                    'limit', sprintf('< %.4f A', EXTINCT_A));
                outcomes(end+1) = row; %#ok<AGROW>
            else
                hasFailed = true;
                row = struct('criterion', 'FaultCurrentExtinction', ...
                    'scenarioId', reqId, ...
                    'pass', false, ...
                    'status', 'FAIL', ...
                    'value', 'NO_CLEARING_VERIFICATION', ...
                    'limit', sprintf('< %.4f A', EXTINCT_A));
                outcomes(end+1) = row; %#ok<AGROW>
            end
        end

        if isHealthy
            bTripped = isfield(r, 'relay') && isfield(r.relay, 'B') && ...
                       strcmp(r.relay.B.tripStatus, 'TRIPPED');
            passNoTrip = ~bTripped;
            row = struct('criterion', 'NoSpuriousTrip', ...
                'scenarioId', reqId, ...
                'pass', passNoTrip, ...
                'status', p_passToStatus(passNoTrip), ...
                'value', p_ternary(bTripped, 'TRIPPED', 'NO_TRIP'), ...
                'limit', 'NO_TRIP');
            outcomes(end+1) = row; %#ok<AGROW>
        end

        if isCBF
            aTripped = isfield(r, 'relay') && isfield(r.relay, 'A') && ...
                       strcmp(r.relay.A.tripStatus, 'TRIPPED');
            cCleared = isfield(r, 'clearingVerification') && isfield(r.clearingVerification, 'faultCleared') && ...
                       r.clearingVerification.faultCleared;
            passCBF = aTripped && cCleared;
            row = struct('criterion', 'BackupRelayOpOnCBF', ...
                'scenarioId', reqId, ...
                'pass', passCBF, ...
                'status', p_passToStatus(passCBF), ...
                'value', sprintf('RelayA=%s, Cleared=%s', p_ternary(aTripped, 'TRIPPED', 'NO_TRIP'), mat2str(cCleared)), ...
                'limit', 'TRIPPED+CLEARED');
            outcomes(end+1) = row; %#ok<AGROW>
        end
    end

    % 4. Timing Error Checks from rtTable
    if ~isempty(rtTable) && isstruct(rtTable(1)) && isfield(rtTable(1), 'timingErrorMs')
        for i = 1:numel(rtTable)
            rowScenario = '';
            if isfield(rtTable(i), 'scenarioId'), rowScenario = rtTable(i).scenarioId; end
            if isnan(rtTable(i).timingErrorMs)
                hasIncomplete = true;
                row = struct('criterion', 'RelayTimingError', ...
                    'scenarioId', rowScenario, ...
                    'pass', false, ...
                    'status', 'INCOMPLETE', ...
                    'value', 'NaN ms', ...
                    'limit', sprintf('|err|<=%.0f ms', RELAY_TOL_S*1e3));
                outcomes(end+1) = row; %#ok<AGROW>
                continue;
            end
            errMs = rtTable(i).timingErrorMs;
            passErr = (abs(errMs) <= RELAY_TOL_S * 1e3);
            row = struct('criterion', 'RelayTimingError', ...
                'scenarioId', rowScenario, ...
                'pass', passErr, ...
                'status', p_passToStatus(passErr), ...
                'value', sprintf('%+.1f ms', errMs), ...
                'limit', sprintf('|err|<=%.0f ms', RELAY_TOL_S*1e3));
            outcomes(end+1) = row; %#ok<AGROW>
        end
    end

    % 5. Overall verdict resolution
    if isempty(outcomes)
        overallPass = false;
        overallStatus = 'INCOMPLETE';
        return;
    end

    allPass = all([outcomes.pass]);

    if allPass
        overallPass = true;
        overallStatus = 'PASS';
    elseif any(strcmp({outcomes.status}, 'FAIL')) || hasFailed
        overallPass = false;
        overallStatus = 'FAIL';
    elseif any(strcmp({outcomes.status}, 'BLOCKED')) || hasBlocked
        overallPass = false;
        overallStatus = 'BLOCKED';
    elseif any(strcmp({outcomes.status}, 'INCOMPLETE')) || hasIncomplete
        overallPass = false;
        overallStatus = 'INCOMPLETE';
    else
        overallPass = false;
        overallStatus = 'FAIL';
    end
end

function s = p_passToStatus(passVal)
    if passVal
        s = 'PASS';
    else
        s = 'FAIL';
    end
end

function v = p_ternary(cond, tVal, fVal)
    if cond, v = tVal; else, v = fVal; end
end

