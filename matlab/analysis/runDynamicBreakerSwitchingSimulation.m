function result = runDynamicBreakerSwitchingSimulation(scenario, options)
% runDynamicBreakerSwitchingSimulation Execute Phase F time-domain simulation with
% dynamic protective relay operation and physical circuit-breaker switching.
%
% This function extends the Phase C/D radial network simulation by enabling
% Config_Breaker_Clearing = 1 inside radial_fault_study_network.slx, activating
% the relay-protection and physical-breaker-switching subsystems.
%
% Syntax:
%   result = runDynamicBreakerSwitchingSimulation()
%   result = runDynamicBreakerSwitchingSimulation(scenario)
%   result = runDynamicBreakerSwitchingSimulation(scenario, options)
%
% Inputs:
%   scenario - struct with optional fields:
%     faultType            : '3PH','SLG','LL','DLG','HEALTHY' (default: '3PH')
%     scenarioId           : identifier string (default: 'PHASE_F_SIM')
%     faultInsertionTime_s : fault inception time in s (default: 0.05)
%     simulationStopTime_s : simulation end time in s (default: 0.60)
%     Zf_Ohm               : fault resistance in Ohm (default: 0.001)
%     Zg_Ohm               : ground resistance in Ohm (default: = Zf_Ohm)
%     failCB_B             : logical, simulate CB_BUS_B failure (default: false)
%     failCB_A             : logical, simulate CB_BUS_A failure (default: false)
%
%   options  - struct with optional fields:
%     quiet        : suppress console output (default: false)
%     forceRebuild : force model rebuild (default: false)
%     overrides    : diagnostic capability overrides
%
% Outputs:
%   result - struct containing:
%     .status                      : 'COMPLETED','FAILED', or 'BLOCKED'
%     .scenarioId                  : scenario identifier
%     .faultType                   : canonical fault type
%     .faultInception_s            : configured fault inception time
%     .time_s                      : simulation time vector
%     .measurements                : V_BusA, I_BusA, V_BusB, I_BusB
%     .waveforms                   : relay/breaker signal waveforms
%     .relay.B / .relay.A          : trip time, breaker open time, status
%     .clearingVerification        : extinction time, faultCleared flag
%     .rms                         : fault-window RMS values
%     .analyticalPredictions       : analytical relay timing cross-check
%     .errors / .warnings          : diagnostic messages

    %% 1. Input defaults
    if nargin < 1 || isempty(scenario), scenario = struct(); end
    if nargin < 2 || isempty(options),  options  = struct(); end

    if ~isfield(options, 'quiet'),        options.quiet        = false; end
    if ~isfield(options, 'forceRebuild'), options.forceRebuild = false; end

    if ~isfield(scenario, 'scenarioId') || isempty(scenario.scenarioId)
        scenario.scenarioId = 'PHASE_F_SIM';
    end
    if ~isfield(scenario, 'faultType')            || isempty(scenario.faultType)
        scenario.faultType = '3PH';
    end
    if ~isfield(scenario, 'faultInsertionTime_s'),  scenario.faultInsertionTime_s = 0.05; end
    if ~isfield(scenario, 'simulationStopTime_s'),  scenario.simulationStopTime_s = 0.60; end
    if ~isfield(scenario, 'Zf_Ohm'),                scenario.Zf_Ohm = 0.001; end
    if ~isfield(scenario, 'Zg_Ohm'),                scenario.Zg_Ohm = scenario.Zf_Ohm; end
    if ~isfield(scenario, 'failCB_B'),              scenario.failCB_B = false; end
    if ~isfield(scenario, 'failCB_A'),              scenario.failCB_A = false; end

    %% 2. Fault type mapping
    rawFT = upper(strtrim(char(scenario.faultType)));
    switch rawFT
        case {'3PH','ABC','3P','THREE_PHASE'}
            canonFT = '3PH'; faultOpt = 'ee.enum.fault_type_option.abc'; isHealthy = false;
        case {'SLG','AG','LG','SINGLE_LINE_TO_GROUND'}
            canonFT = 'SLG'; faultOpt = 'ee.enum.fault_type_option.ag';  isHealthy = false;
        case {'LL','BC','LINE_TO_LINE'}
            canonFT = 'LL';  faultOpt = 'ee.enum.fault_type_option.bc';  isHealthy = false;
        case {'DLG','BCG','LLG','DOUBLE_LINE_TO_GROUND'}
            canonFT = 'DLG'; faultOpt = 'ee.enum.fault_type_option.bcg'; isHealthy = false;
        case {'HEALTHY','NONE','NO_FAULT'}
            canonFT = 'HEALTHY'; faultOpt = 'ee.enum.fault_type_option.abc'; isHealthy = true;
        otherwise
            error('runDynamicBreakerSwitchingSimulation:UnsupportedFaultType', ...
                'Unsupported fault type: "%s"', rawFT);
    end
    scenario.faultType = canonFT;

    %% 3. Environment capability check
    diagOpts = struct('quiet', true, 'allowPowerSystemBlocks', true);
    if isfield(options, 'overrides'), diagOpts.overrides = options.overrides; end
    diag = checkSimulationCapabilities(diagOpts);
    if ~strcmp(diag.status, 'READY')
        result = p_makeResult('BLOCKED', scenario, canonFT);
        result.errors{end+1} = sprintf('Simulation environment not ready: %s — %s', ...
            diag.status, diag.message);
        return;
    end

    %% 4. Locate / build model
    modelName = 'radial_fault_study_network';
    thisDir   = fileparts(mfilename('fullpath'));
    projRoot  = fullfile(thisDir, '..', '..');
    modelFile = fullfile(projRoot, 'simulink', 'models', [modelName, '.slx']);

    try
        if ~exist(modelFile, 'file') || options.forceRebuild
            addpath(genpath(fullfile(projRoot, 'scripts')));
            modelFile = build_radial_fault_model(fullfile(projRoot, 'simulink', 'models'));
        end
        if ~bdIsLoaded(modelName)
            load_system(modelFile);
        end
    catch ME
        result = p_makeResult('FAILED', scenario, canonFT);
        result.errors{end+1} = sprintf('Model load/build failed: %s', ME.message);
        return;
    end

    %% 5. Configure scenario parameters
    faultBlock = [modelName, '/Fault_BusB'];
    try
        if isHealthy
            set_param(faultBlock, ...
                'enable_temporal_fault', 'ee.enum.enable.yes', ...
                'fault_type_option',     'ee.enum.fault_type_option.abc', ...
                'fault_start_time',      '999.0');
        else
            rPn = max(1e-4, scenario.Zf_Ohm);
            rNg = max(1e-4, scenario.Zg_Ohm);
            dur = scenario.simulationStopTime_s - scenario.faultInsertionTime_s + 0.10;
            set_param(faultBlock, ...
                'enable_temporal_fault', 'ee.enum.enable.yes', ...
                'fault_type_option',     faultOpt, ...
                'fault_start_time',      num2str(scenario.faultInsertionTime_s), ...
                'fault_duration',        num2str(dur), ...
                'R_pn_fault',            num2str(rPn), ...
                'R_ng_fault',            num2str(rNg));
        end

        % Enable Phase F relay + breaker switching
        set_param([modelName, '/Config_Breaker_Clearing'], 'Value', '1');
        set_param([modelName, '/Config_Fail_CB_B'], 'Value', num2str(double(scenario.failCB_B)));
        set_param([modelName, '/Config_Fail_CB_A'], 'Value', num2str(double(scenario.failCB_A)));
        set_param(modelName, 'StopTime', num2str(scenario.simulationStopTime_s));

        %% 6. Run simulation
        simOut = sim(modelName);

        % Restore defaults immediately after simulation completes
        p_safeRestoreDefaults(modelName);

    catch ME
        p_safeRestoreDefaults(modelName);
        if bdIsLoaded(modelName), close_system(modelName, 0); end
        result = p_makeResult('FAILED', scenario, canonFT);
        result.errors{end+1} = sprintf('Simulation failed: %s (%s)', ME.message, ME.identifier);
        if ~options.quiet
            fprintf('[PHASE F] FAILED — %s (%s)\n  %s\n', ...
                scenario.scenarioId, canonFT, ME.message);
        end
        return;
    end

    %% 7. Extract output signals (10 ports)
    try
        y = simOut.yout;
        if isprop(simOut, 'tout') && ~isempty(simOut.tout)
            t = simOut.tout(:);
        else
            t = y{1}.Values.Time(:);
        end
        nT = numel(t);

        % Ports 1-4: physical measurements [T x 3]
        vBusA = squeeze(y{1}.Values.Data).';
        iBusA = squeeze(y{2}.Values.Data).';
        vBusB = squeeze(y{3}.Values.Data).';
        iBusB = squeeze(y{4}.Values.Data).';

        % Ports 5-10: relay / breaker scalars
        tripCmdB  = p_extractPort(y,  5, nT);
        brkStateB = p_extractPort(y,  6, nT);
        tripCmdA  = p_extractPort(y,  7, nT);
        brkStateA = p_extractPort(y,  8, nT);
        sigmaB    = p_extractPort(y,  9, nT);
        sigmaA    = p_extractPort(y, 10, nT);

    catch ME
        p_safeRestoreDefaults(modelName);
        if bdIsLoaded(modelName), close_system(modelName, 0); end
        result = p_makeResult('FAILED', scenario, canonFT);
        result.errors{end+1} = sprintf('Output extraction failed: %s', ME.message);
        return;
    end

    if bdIsLoaded(modelName), close_system(modelName, 0); end

    %% 8. Build result
    result = p_makeResult('COMPLETED', scenario, canonFT);
    result.faultInception_s = scenario.faultInsertionTime_s;
    result.time_s           = t;
    result.measurements     = struct('V_BusA', vBusA, 'I_BusA', iBusA, ...
                                     'V_BusB', vBusB, 'I_BusB', iBusB);
    result.waveforms        = struct('tripCmdB',  tripCmdB,  'breakerStateB', brkStateB, ...
                                     'tripCmdA',  tripCmdA,  'breakerStateA', brkStateA, ...
                                     'sigmaB',    sigmaB,    'sigmaA',        sigmaA);

    %% 9. Relay / breaker timing analysis
    TRIP_THR    = 0.5;   % Logical threshold (0 = open, 1 = trip/open)
    EXTINCT_THR = 0.01;  % A — instantaneous RMS proxy threshold for extinction

    [tripTime_B, openTime_B, statusB] = p_detectRelay( ...
        t, tripCmdB, brkStateB, TRIP_THR, scenario.failCB_B);
    [tripTime_A, openTime_A, statusA] = p_detectRelay( ...
        t, tripCmdA, brkStateA, TRIP_THR, scenario.failCB_A);

    result.relay = struct( ...
        'B', struct('tripTime_s', tripTime_B, 'breakerOpenTime_s', openTime_B, ...
                    'tripStatus', statusB, 'sigmaFinal', sigmaB(end)), ...
        'A', struct('tripTime_s', tripTime_A, 'breakerOpenTime_s', openTime_A, ...
                    'tripStatus', statusA, 'sigmaFinal', sigmaA(end)));

    %% 10. Current extinction / clearing verification
    tFault = scenario.faultInsertionTime_s;
    result.clearingVerification = p_verifyClearing( ...
        t, iBusB, tFault, openTime_B, openTime_A, EXTINCT_THR);

    %% 11. RMS extraction (fault steady-state window, strictly pre-clearing)
    if ~isnan(openTime_B) && openTime_B > tFault + 0.03
        tPreClearIdx = (t <= openTime_B - 0.002);
    elseif ~isnan(openTime_A) && openTime_A > tFault + 0.03
        tPreClearIdx = (t <= openTime_A - 0.002);
    else
        tPreClearIdx = true(size(t));
    end
    tPre = t(tPreClearIdx);
    iBusBPre = iBusB(tPreClearIdx, :);
    vBusBPre = vBusB(tPreClearIdx, :);
    vBusAPre = vBusA(tPreClearIdx, :);

    window = validateMeasurementWindow(tPre, tFault, 50.0);
    if window.isValid
        rmsVB = extractSimulationRMS(tPre, vBusBPre, window);
        rmsIB = extractSimulationRMS(tPre, iBusBPre, window);
        rmsVA = extractSimulationRMS(tPre, vBusAPre, window);
        result.rms = struct('V_RMS_BusB', rmsVB.steadyStateRMS, ...
                            'I_RMS_BusB', rmsIB.steadyStateRMS, ...
                            'V_RMS_BusA', rmsVA.steadyStateRMS);
    end

    %% 12. Analytical relay timing (best-effort cross-validation)
    result.analyticalPredictions = p_analyticalPredictions(tPre, iBusBPre, window, isHealthy);

    %% 13. Console summary
    if ~options.quiet
        p_printSummary(result, scenario, isHealthy);
    end
end

%% ── Local helpers ──────────────────────────────────────────────────────────

function result = p_makeResult(status, scenario, canonFT)
    result.status                = status;
    result.scenarioId            = scenario.scenarioId;
    result.faultType             = canonFT;
    result.faultInception_s      = scenario.faultInsertionTime_s;
    result.time_s                = [];
    result.measurements          = struct();
    result.waveforms             = struct();
    result.relay                 = struct('B', struct('tripStatus','UNKNOWN'), ...
                                          'A', struct('tripStatus','UNKNOWN'));
    result.clearingVerification  = struct('faultCleared', false, 'extinctionTime_s', NaN, ...
                                          'postClearingCurrentPeak_A', 0, ...
                                          'extinctionThreshold_A', 0.01);
    result.rms                   = struct();
    result.analyticalPredictions = struct();
    result.errors                = {};
    result.warnings              = {};
end

function p_safeRestoreDefaults(modelName)
    try
        if bdIsLoaded(modelName)
            set_param([modelName, '/Config_Breaker_Clearing'], 'Value', '0');
            set_param([modelName, '/Config_Fail_CB_B'],        'Value', '0');
            set_param([modelName, '/Config_Fail_CB_A'],        'Value', '0');
        end
    catch
        % Best effort — never throw from a cleanup path
    end
end

function sig = p_extractPort(y, portIdx, nT)
    % Return zeros for missing ports; resample if length mismatch
    if y.numElements >= portIdx
        raw = double(squeeze(y{portIdx}.Values.Data));
        raw = raw(:);
        if numel(raw) == nT
            sig = raw;
        elseif numel(raw) > 1
            sig = interp1(linspace(0,1,numel(raw)), raw, linspace(0,1,nT), 'linear')';
        else
            sig = repmat(raw(1), nT, 1);
        end
    else
        sig = zeros(nT, 1);
    end
end

function [tripTime, openTime, statusStr] = p_detectRelay(t, tripCmd, brkState, thresh, simFailure)
    tripIdx = find(tripCmd >= thresh, 1, 'first');
    openIdx = find(brkState >= thresh, 1, 'first');

    if ~isempty(tripIdx)
        tripTime  = t(tripIdx);
        statusStr = 'TRIPPED';
    else
        tripTime  = NaN;
        statusStr = 'NO_TRIP';
    end

    if ~isempty(openIdx)
        openTime = t(openIdx);
    else
        openTime = NaN;
    end

    % If breaker failure was configured, override status
    if simFailure && strcmp(statusStr, 'TRIPPED')
        statusStr = 'FAILED_OPEN';
    end
end

function cv = p_verifyClearing(t, iBusB, tFault, openTimeB, openTimeA, thresh)
    cv = verifyFaultClearing(t, iBusB, tFault, openTimeB, openTimeA, thresh);
end

function ap = p_analyticalPredictions(t, iBusB, window, isHealthy)
    ap = struct('note', 'Analytical prediction unavailable.');
    if isHealthy || ~window.isValid, return; end
    try
        cfg    = createRadialRelayStudyConfiguration();
        relayB = cfg.relays(strcmp({cfg.relays.id}, 'RELAY_BUS_B'));
        relayA = cfg.relays(strcmp({cfg.relays.id}, 'RELAY_BUS_A'));
        bkrB   = cfg.breakers(strcmp({cfg.breakers.id}, 'CB_BUS_B'));
        bkrA   = cfg.breakers(strcmp({cfg.breakers.id}, 'CB_BUS_A'));

        phasorI = estimateFundamentalPhasor(t, iBusB, window);
        I1_A    = abs(phasorI.sequencePhasors.V1);
        I_act   = max(phasorI.magnitudeRMS);

        % Symmetrical component basis (positive sequence I1, used in Phase E)
        IsecB_I1 = convertPrimaryToSecondaryCurrent(I1_A, relayB.CTprimary_A, relayB.CTsecondary_A);
        IsecA_I1 = convertPrimaryToSecondaryCurrent(I1_A, relayA.CTprimary_A, relayA.CTsecondary_A);
        topB_I1  = calculateRelayOperatingTime(IsecB_I1, relayB.pickupCurrent_A, relayB.TMS, relayB.curveType);
        topA_I1  = calculateRelayOperatingTime(IsecA_I1, relayA.pickupCurrent_A, relayA.TMS, relayA.curveType);

        % Physical phase element basis (maximum phase RMS, sensed by physical CTs)
        IsecB_max = convertPrimaryToSecondaryCurrent(I_act, relayB.CTprimary_A, relayB.CTsecondary_A);
        IsecA_max = convertPrimaryToSecondaryCurrent(I_act, relayA.CTprimary_A, relayA.CTsecondary_A);
        topB_max  = calculateRelayOperatingTime(IsecB_max, relayB.pickupCurrent_A, relayB.TMS, relayB.curveType);
        topA_max  = calculateRelayOperatingTime(IsecA_max, relayA.pickupCurrent_A, relayA.TMS, relayA.curveType);

        ap = struct( ...
            'I1_fundamental_A',       I1_A, ...
            'I_fault_effective_A',    I_act, ...
            'I_phaseMax_A',           I_act, ...
            'IsecB_I1',               IsecB_I1, ...
            'multiple_M_I1',          IsecB_I1 / relayB.pickupCurrent_A, ...
            'anaRelayB_trip_I1_s',    topB_I1, ...
            'anaRelayA_trip_I1_s',    topA_I1, ...
            'IsecB_max',              IsecB_max, ...
            'multiple_M_max',         IsecB_max / relayB.pickupCurrent_A, ...
            'anaRelayB_trip_Imax_s',  topB_max, ...
            'anaRelayA_trip_Imax_s',  topA_max, ...
            'anaRelayB_trip_s',       topB_max, ...
            'anaRelayA_trip_s',       topA_max, ...
            'anaBreaker_B_open_s',    topB_max + bkrB.openingDelay_s, ...
            'anaBreaker_A_open_s',    topA_max + bkrA.openingDelay_s, ...
            'anaTotalClearingTime_s', topB_max + bkrB.openingDelay_s);
    catch ME
        ap = struct('note', sprintf('Analytical prediction failed: %s', ME.message));
    end
end

function p_printSummary(res, scn, isHealthy)
    fprintf('\n================================================================\n');
    fprintf(' PHASE F — DYNAMIC RELAY & PHYSICAL BREAKER SWITCHING\n');
    fprintf('================================================================\n');
    fprintf('  Scenario  : %s\n', res.scenarioId);
    fprintf('  Status    : [%s]\n', res.status);
    fprintf('  Fault     : %s @ t = %.3f s\n', res.faultType, res.faultInception_s);

    if ~isHealthy && strcmp(res.status, 'COMPLETED')
        b = res.relay.B; a = res.relay.A;
        fprintf('----------------------------------------------------------------\n');
        fprintf('  Primary Relay (BUS B)  |  Backup Relay (BUS A)\n');
        fprintf('  Trip : %8.4f s         |  Trip : %8.4f s\n', b.tripTime_s, a.tripTime_s);
        fprintf('  Open : %8.4f s         |  Open : %8.4f s\n', b.breakerOpenTime_s, a.breakerOpenTime_s);
        fprintf('  CB_B delay from fault  : %.4f s\n', b.breakerOpenTime_s - res.faultInception_s);
        cv = res.clearingVerification;
        fprintf('----------------------------------------------------------------\n');
        fprintf('  Fault Cleared : %s\n', mat2str(cv.faultCleared));
        if cv.faultCleared
            fprintf('  Extinction    : %.4f s  |  Post-clear peak: %.4f A\n', ...
                cv.extinctionTime_s, cv.postClearingCurrentPeak_A);
        end
        if isfield(res.analyticalPredictions, 'I1_fundamental_A')
            ap = res.analyticalPredictions;
            simTripB = b.tripTime_s - res.faultInception_s;
            simOpenB = b.breakerOpenTime_s - res.faultInception_s;
            fprintf('----------------------------------------------------------------\n');
            fprintf('  I1 = %.1f A | Ana relay-B: %.4f s  Sim: %.4f s  Err: %+.4f s\n', ...
                ap.I1_fundamental_A, ap.anaRelayB_trip_s, simTripB, simTripB - ap.anaRelayB_trip_s);
            fprintf('             | Ana CB_B:     %.4f s  Sim: %.4f s  Err: %+.4f s\n', ...
                ap.anaBreaker_B_open_s, simOpenB, simOpenB - ap.anaBreaker_B_open_s);
        end
    elseif ~isempty(res.errors)
        fprintf('  Error: %s\n', res.errors{1});
    end
    fprintf('================================================================\n\n');
end
