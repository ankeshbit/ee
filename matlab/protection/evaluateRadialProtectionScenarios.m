function studyResult = evaluateRadialProtectionScenarios(simulationResults, config, options)
% evaluateRadialProtectionScenarios Evaluate relay protection and coordination
% for all power system fault types (3PH, SLG, LL, DLG) and healthy operation.
%
% Inputs:
%   simulationResults - (Optional) Struct containing simulation results from
%                       runRadialFaultSimulation for keys: F_3PH, F_SLG, F_LL,
%                       F_DLG, F_HEALTHY. If empty, simulation results are
%                       executed or analytically predicted based on options.
%   config            - (Optional) Relay configuration struct from
%                       createRadialRelayStudyConfiguration().
%   options           - (Optional) Options struct:
%                         useSimulatedCurrents : boolean (default: true)
%                         currentBasis         : 'fundamental' (default) or 'phaseMax'
%                         directionalPhasors   : struct of phasor data for directional tests
%                         quiet                : boolean (default: false)
%
% Output:
%   studyResult - Comprehensive protection study struct containing:
%                 scenarios            : Per-scenario relay response and coordination
%                 relayTable           : Summary table of all relay operations
%                 coordinationTable    : Summary table of primary/backup coordination
%                 breakerFailureTable  : Summary table of breaker failure clearing
%                 zoneValidation       : Result of validateProtectionZones
%                 provenance           : Timestamp and release information

    if nargin < 2 || isempty(config)
        config = createRadialRelayStudyConfiguration();
    end
    if nargin < 3 || isempty(options)
        options = struct();
    end
    if ~isfield(options, 'useSimulatedCurrents')
        options.useSimulatedCurrents = true;
    end
    if ~isfield(options, 'currentBasis')
        options.currentBasis = 'fundamental';
    end
    if ~isfield(options, 'quiet')
        options.quiet = false;
    end

    % Validate protection zones against network configuration
    validateProtectionZones(config.zones, config.network, config.relays, config.breakers);
    studyResult.zoneValidation = struct('status', 'VALID', 'message', 'Protection zones validated successfully.');

    % Define standard study scenario list
    scenarioDefs = {
        struct('id', '3PH',     'faultType', '3PH',     'faultedBus', 'BUS_B', 'isFault', true);
        struct('id', 'SLG',     'faultType', 'SLG',     'faultedBus', 'BUS_B', 'isFault', true);
        struct('id', 'LL',      'faultType', 'LL',      'faultedBus', 'BUS_B', 'isFault', true);
        struct('id', 'DLG',     'faultType', 'DLG',     'faultedBus', 'BUS_B', 'isFault', true);
        struct('id', 'HEALTHY', 'faultType', 'HEALTHY', 'faultedBus', 'BUS_B', 'isFault', false)
    };

    allRelayRows = struct([]);
    allCoordRows = struct([]);
    allFailureRows = struct([]);
    scenarioResults = struct();

    for sIdx = 1:numel(scenarioDefs)
        sDef = scenarioDefs{sIdx};
        sKey = ['F_', sDef.id];

        % 1. Determine primary current at Bus B
        isSimulated = false;
        if nargin >= 1 && ~isempty(simulationResults) && isfield(simulationResults, sKey)
            simRes = simulationResults.(sKey);
            isSimulated = isfield(simRes, 'isSimulated') && simRes.isSimulated;
            if strcmp(options.currentBasis, 'phaseMax') && isfield(simRes, 'rms') && isfield(simRes.rms, 'I_RMS_phase')
                IBusB_primary_A = max(simRes.rms.I_RMS_phase);
            elseif isfield(simRes, 'phasors') && isfield(simRes.phasors, 'I1_magnitude_A')
                IBusB_primary_A = simRes.phasors.I1_magnitude_A;
            elseif isfield(simRes, 'faultCurrent_A')
                IBusB_primary_A = abs(simRes.faultCurrent_A);
            else
                masterCfg = getSystemMasterConfiguration();
                IBusB_primary_A = masterCfg.load.power_W.value / (sqrt(3) * masterCfg.load.voltage_V.value);
            end
        else
            % Analytical baseline derived dynamically from network configuration
            if strcmp(sDef.faultType, 'HEALTHY')
                masterCfg = getSystemMasterConfiguration();
                IBusB_primary_A = masterCfg.load.power_W.value / (sqrt(3) * masterCfg.load.voltage_V.value);
            else
                anaScn = struct('id', ['ANA_', sDef.id], 'faultedBus', sDef.faultedBus, ...
                    'faultType', sDef.faultType, 'Zf_pu', 0.0);
                anaRes = runIntegratedFaultStudy(config.network, anaScn, config.relays, config.coordinationPairs);
                IBusB_primary_A = anaRes.faultCurrentMagnitude_A;
            end
        end

        % In radial feeder: Bus A through-current equals Bus B current
        IBusA_primary_A = IBusB_primary_A;
        % 33 kV HV through-current equals 11 kV current transformed by (11 kV / 33 kV)
        I33kV_primary_A = IBusB_primary_A / 3.0;

        % 2. Evaluate Each Relay
        numRelays = numel(config.relays);
        relayEvals = repmat(struct(), 1, numRelays);

        for rIdx = 1:numRelays
            relay = config.relays(rIdx);
            breaker = config.breakers(strcmp({config.breakers.id}, relay.breakerId));

            % Measurement mapping respecting network topology
            switch relay.locationBus
                case 'BUS_B'
                    I_pri = IBusB_primary_A;
                    role = ternary(sDef.isFault, 'PRIMARY', 'NOT_APPLICABLE');
                case 'BUS_A'
                    I_pri = IBusA_primary_A;
                    role = ternary(sDef.isFault, 'BACKUP', 'NOT_APPLICABLE');
                case 'SOURCE_33KV'
                    I_pri = I33kV_primary_A;
                    role = ternary(sDef.isFault, 'REMOTE_BACKUP', 'NOT_APPLICABLE');
                otherwise
                    I_pri = 0;
                    role = 'UNASSIGNED';
            end

            % Secondary Current Conversion
            I_sec = convertPrimaryToSecondaryCurrent( ...
                I_pri, relay.CTprimary_A, relay.CTsecondary_A);

            % Multiple of Pickup
            M = I_sec / relay.pickupCurrent_A;

            % Directional Supervision Check
            dirStatus = 'notEnabled';
            isBlockedByDirection = false;
            if isfield(relay, 'directionalSettings') && relay.directionalSettings.enabled
                if isfield(options, 'directionalPhasors') && isfield(options.directionalPhasors, relay.id)
                    fData = options.directionalPhasors.(relay.id);
                    dirRes = evaluateDirectionalSupervision(relay.directionalSettings, fData);
                    dirStatus = dirRes.status;
                    if strcmp(dirStatus, 'reverse') || strcmp(dirStatus, 'blocked')
                        isBlockedByDirection = true;
                    end
                else
                    dirRes = evaluateDirectionalSupervision(relay.directionalSettings, struct());
                    dirStatus = dirRes.status;
                end
            end

            % Operating Time via IEC curve
            if isBlockedByDirection
                t_op = Inf;
                tripStatus = 'BLOCKED_DIRECTIONAL';
            elseif I_sec <= relay.pickupCurrent_A
                t_op = Inf;
                tripStatus = 'BELOW_PICKUP';
            else
                t_op = calculateRelayOperatingTime( ...
                    I_sec, relay.pickupCurrent_A, relay.TMS, relay.curveType);
                tripStatus = 'TRIPPED';
            end

            % Breaker Clearing Time Estimate
            brkClearing = calculateBreakerClearingTime(t_op, breaker.openingDelay_s);
            t_clear = brkClearing.totalClearingTime_s;

            relayEvals(rIdx).relayId = relay.id;
            relayEvals(rIdx).name = relay.name;
            relayEvals(rIdx).locationBus = relay.locationBus;
            relayEvals(rIdx).CT_ratio = sprintf('%d/%d A', relay.CTprimary_A, relay.CTsecondary_A);
            relayEvals(rIdx).I_primary_A = I_pri;
            relayEvals(rIdx).I_secondary_A = I_sec;
            relayEvals(rIdx).pickupCurrentSec_A = relay.pickupCurrent_A;
            relayEvals(rIdx).pickupMultiple_M = M;
            relayEvals(rIdx).curveType = relay.curveType;
            relayEvals(rIdx).TMS = relay.TMS;
            relayEvals(rIdx).operatingTime_s = t_op;
            relayEvals(rIdx).breakerDelay_s = breaker.openingDelay_s;
            relayEvals(rIdx).totalClearingTime_s = t_clear;
            relayEvals(rIdx).directionalStatus = dirStatus;
            relayEvals(rIdx).role = role;
            relayEvals(rIdx).tripStatus = tripStatus;
            relayEvals(rIdx).isSimulatedCurrent = isSimulated;

            % Build table row
            rRow = struct( ...
                'scenarioId', sDef.id, ...
                'faultType', sDef.faultType, ...
                'isSimulated', isSimulated, ...
                'relayId', relay.id, ...
                'locationBus', relay.locationBus, ...
                'I_primary_A', I_pri, ...
                'I_secondary_A', I_sec, ...
                'pickupSec_A', relay.pickupCurrent_A, ...
                'multiple_M', M, ...
                'curveType', relay.curveType, ...
                'TMS', relay.TMS, ...
                'operatingTime_s', t_op, ...
                'totalClearingTime_s', t_clear, ...
                'directionalStatus', dirStatus, ...
                'role', role, ...
                'tripStatus', tripStatus);
            allRelayRows = appendStruct(allRelayRows, rRow);
        end

        % 3. Evaluate Coordination Pairs
        numPairs = numel(config.coordinationPairs);
        coordEvals = repmat(struct(), 1, numPairs);

        for pIdx = 1:numPairs
            pair = config.coordinationPairs(pIdx);
            priRelayEval = findEval(relayEvals, pair.primaryRelayId);
            bkuRelayEval = findEval(relayEvals, pair.backupRelayId);

            t_pri = priRelayEval.operatingTime_s;
            t_bku = bkuRelayEval.operatingTime_s;
            t_pri_clr = priRelayEval.totalClearingTime_s;

            % Distinct definitions:
            % CTI = backup operating time - primary operating time
            % Margin = backup operating time - primary total clearing time
            if isfield(pair, 'applicableFaultedBuses') && ~isempty(pair.applicableFaultedBuses) && ...
                    isfield(sDef, 'faultedBus') && ~any(strcmp(cellstr(pair.applicableFaultedBuses), sDef.faultedBus))
                t_pri = Inf;
                t_bku = Inf;
                t_pri_clr = Inf;
                CTI_s = Inf;
                margin_s = Inf;
                isCoordinated = false;
                coordStatus = 'Not applicable to this fault location';
            elseif isfinite(t_pri) && isfinite(t_bku)
                CTI_s = t_bku - t_pri;
                margin_s = t_bku - t_pri_clr;
                isCoordinated = (CTI_s >= pair.minimumCTI_s);
                coordStatus = ternary(isCoordinated, 'COORDINATED', 'CTI_VIOLATION');
            elseif ~isfinite(t_pri) && ~isfinite(t_bku)
                CTI_s = Inf;
                margin_s = Inf;
                isCoordinated = false;
                coordStatus = 'NEITHER_OPERATES';
            elseif ~isfinite(t_pri)
                CTI_s = Inf;
                margin_s = Inf;
                isCoordinated = false;
                coordStatus = 'PRIMARY_DOES_NOT_OPERATE';
            else
                CTI_s = Inf;
                margin_s = Inf;
                isCoordinated = false;
                coordStatus = 'BACKUP_DOES_NOT_OPERATE';
            end

            coordEvals(pIdx).pairId = pair.pairId;
            coordEvals(pIdx).primaryRelayId = pair.primaryRelayId;
            coordEvals(pIdx).backupRelayId = pair.backupRelayId;
            coordEvals(pIdx).primaryOperatingTime_s = t_pri;
            coordEvals(pIdx).backupOperatingTime_s = t_bku;
            coordEvals(pIdx).primaryTotalClearingTime_s = t_pri_clr;
            coordEvals(pIdx).CTI_s = CTI_s;
            coordEvals(pIdx).minimumCTI_s = pair.minimumCTI_s;
            coordEvals(pIdx).clearingTimeMargin_s = margin_s;
            coordEvals(pIdx).minimumMargin_s = pair.minimumMargin_s;
            coordEvals(pIdx).isCoordinated = isCoordinated;
            coordEvals(pIdx).coordinationStatus = coordStatus;

            cRow = struct( ...
                'scenarioId', sDef.id, ...
                'pairId', pair.pairId, ...
                'primaryRelayId', pair.primaryRelayId, ...
                'backupRelayId', pair.backupRelayId, ...
                't_primary_s', t_pri, ...
                't_backup_s', t_bku, ...
                't_primary_clearing_s', t_pri_clr, ...
                'CTI_s', CTI_s, ...
                'minimumCTI_s', pair.minimumCTI_s, ...
                'margin_s', margin_s, ...
                'isCoordinated', isCoordinated, ...
                'status', coordStatus);
            allCoordRows = appendStruct(allCoordRows, cRow);
        end

        % 4. Breaker-Failure Evaluation
        % Standard failure scenario: CB_BUS_B fails to open during fault
        bfResult = evaluateBreakerFailureForScenario(sDef, relayEvals, config);
        allFailureRows = appendStruct(allFailureRows, bfResult);

        validId = matlab.lang.makeValidName(['SCN_', sDef.id]);
        scenarioResults.(validId) = struct( ...
            'definition', sDef, ...
            'relays', relayEvals, ...
            'coordination', coordEvals, ...
            'breakerFailure', bfResult);
    end

    studyResult.scenarios = scenarioResults;
    studyResult.relayTable = struct2table(allRelayRows);
    studyResult.coordinationTable = struct2table(allCoordRows);
    studyResult.breakerFailureTable = struct2table(allFailureRows);
    studyResult.provenance = struct( ...
        'matlabRelease', ['R', version('-release')], ...
        'timestamp', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>

    if ~options.quiet
        printProtectionSummary(studyResult);
    end
end

function bfResult = evaluateBreakerFailureForScenario(sDef, relayEvals, config)
    priEval = findEval(relayEvals, 'RELAY_BUS_B');
    bkuEval = findEval(relayEvals, 'RELAY_BUS_A');

    if ~sDef.isFault
        bfResult = struct( ...
            'scenarioId', sDef.id, ...
            'primaryRelayId', 'RELAY_BUS_B', ...
            'primaryBreakerState', 'closed', ...
            'backupRelayId', 'RELAY_BUS_A', ...
            'primaryOperatingTime_s', priEval.operatingTime_s, ...
            'backupOperatingTime_s', bkuEval.operatingTime_s, ...
            'CTI_s', Inf, ...
            'clearingTimeMargin_s', Inf, ...
            'overallStatus', 'HEALTHY_INACTIVE', ...
            'clearingMechanism', 'NO_ACTION_REQUIRED');
        return;
    end

    % Normal Clearing: Primary breaker opens successfully
    if priEval.operatingTime_s < Inf
        normalClearingTime_s = priEval.totalClearingTime_s;
    else
        normalClearingTime_s = Inf;
    end

    % Breaker Failure Mode: Primary breaker fails to open
    % Backup clears after backup relay time + backup breaker delay
    if bkuEval.operatingTime_s < Inf
        backupClearingTime_s = bkuEval.totalClearingTime_s;
        bfStatus = 'CLEARED_BY_BACKUP_PROTECTION';
        cti = bkuEval.operatingTime_s - priEval.operatingTime_s;
        margin = bkuEval.operatingTime_s - priEval.totalClearingTime_s;
    else
        backupClearingTime_s = Inf;
        bfStatus = 'NOT_CLEARED_BY_MODELED_PROTECTION';
        cti = Inf;
        margin = Inf;
    end

    bfResult = struct( ...
        'scenarioId', sDef.id, ...
        'primaryRelayId', 'RELAY_BUS_B', ...
        'primaryBreakerState', 'failedToOpen', ...
        'backupRelayId', 'RELAY_BUS_A', ...
        'primaryOperatingTime_s', priEval.operatingTime_s, ...
        'backupOperatingTime_s', bkuEval.operatingTime_s, ...
        'CTI_s', cti, ...
        'clearingTimeMargin_s', margin, ...
        'overallStatus', bfStatus, ...
        'clearingMechanism', sprintf('Backup cleared in %.4f s', backupClearingTime_s));
end

function target = findEval(evalArray, targetId)
    idx = find(strcmp({evalArray.relayId}, targetId), 1);
    if isempty(idx)
        target = struct('operatingTime_s', Inf, 'totalClearingTime_s', Inf);
    else
        target = evalArray(idx);
    end
end

function val = ternary(cond, a, b)
    if cond, val = a; else, val = b; end
end

function arr = appendStruct(arr, s)
    if isempty(arr)
        arr = s;
    else
        arr(end + 1) = s;
    end
end

function printProtectionSummary(study)
    fprintf('\n========================================================================================\n');
    fprintf('  PHASE E: RELAY PROTECTION & COORDINATION SUMMARY REPORT\n');
    fprintf('========================================================================================\n\n');

    fprintf('--- RELAY OPERATION MATRIX ---\n');
    disp(study.relayTable(:, {'scenarioId', 'relayId', 'I_primary_A', 'multiple_M', 'operatingTime_s', 'totalClearingTime_s', 'tripStatus'}));

    fprintf('\n--- PRIMARY/BACKUP COORDINATION MATRIX ---\n');
    disp(study.coordinationTable(:, {'scenarioId', 'pairId', 't_primary_s', 't_backup_s', 'CTI_s', 'minimumCTI_s', 'margin_s', 'status'}));

    fprintf('\n--- BREAKER-FAILURE ANALYSIS (PRIMARY BREAKER FAILED TO OPEN) ---\n');
    disp(study.breakerFailureTable(:, {'scenarioId', 'primaryRelayId', 'backupRelayId', 'primaryBreakerState', 'overallStatus', 'clearingMechanism'}));
    fprintf('========================================================================================\n\n');
end
