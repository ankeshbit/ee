%% phase_f_validation_report.m
% Phase F Validation Script — Dynamic Relay and Physical Breaker Switching
%
% Executes all four fault types (3PH, SLG, LL, DLG) plus healthy mode and
% one breaker-failure scenario through the Phase F simulation runner, then
% produces a consolidated text report.
%
% Usage: Run directly from MATLAB command window or via:
%   matlab -batch "cd('C:/Users/ankes/OneDrive/Desktop/ee'); run('scripts/phase_f_validation_report.m')"
%
% Output: results/phase_f_validation_report.txt

clear; clc;

%% ── 0. Setup ─────────────────────────────────────────────────────────────
thisFile  = mfilename('fullpath');
scriptDir = fileparts(thisFile);
projRoot  = fileparts(scriptDir);

addpath(genpath(fullfile(projRoot, 'matlab')));
addpath(genpath(fullfile(projRoot, 'scripts')));

resultsDir = fullfile(projRoot, 'results');
if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end

reportFile = fullfile(resultsDir, 'phase_f_validation_report.txt');
fid = fopen(reportFile, 'w');
if fid < 0
    warning('Could not open report file: %s — writing to console only.', reportFile);
    fid = 1;
end

pLog = @(fmt, varargin) fprintf(fid, fmt, varargin{:});
pCon = @(fmt, varargin) fprintf(fmt, varargin{:});  % Always to console too

logBoth = @(fmt, varargin) deal(fprintf(fmt, varargin{:}), ...
    fid ~= 1 && fprintf(fid, fmt, varargin{:}));

pLog('=================================================================\n');
pLog(' PHASE F VALIDATION REPORT — Dynamic Relay & Breaker Switching\n');
pLog(' Power System Fault Analysis & Protection Coordination Simulator\n');
pLog(' MATLAB Release: R%s    Date: %s\n', version('-release'), datestr(now, 'yyyy-mm-dd HH:MM')); %#ok<TNOW1,DATST>
pLog('=================================================================\n\n');
fprintf('=================================================================\n');
fprintf(' PHASE F VALIDATION REPORT\n');
fprintf(' MATLAB R%s — %s\n', version('-release'), datestr(now, 'yyyy-mm-dd HH:MM')); %#ok<TNOW1,DATST>
fprintf('=================================================================\n\n');

%% ── 1. Environment check ─────────────────────────────────────────────────
pLog('1. ENVIRONMENT CHECK\n   ─────────────────\n');
fprintf('1. ENVIRONMENT CHECK\n');
diagOpts = struct('quiet', true, 'allowPowerSystemBlocks', true);
diag = checkSimulationCapabilities(diagOpts);
pLog('   Status               : %s\n', diag.status);
pLog('   Power System Blocks  : %s\n', mat2str(diag.powerSystemBlocksLicensed));
pLog('   Simscape Electrical  : %s\n\n', mat2str(diag.simscapeElectricalLicensed));
fprintf('   Status: %s\n\n', diag.status);

if ~strcmp(diag.status, 'READY')
    pLog('   [BLOCKED] Environment not ready: %s\n', diag.message);
    if fid ~= 1, fclose(fid); end
    error('Phase F validation blocked: %s', diag.status);
end

%% ── 2. Force model rebuild with updated solver settings ──────────────────
% The model .slx on disk may have been built before ConsistencyChecking=off
% was added.  Delete and rebuild unconditionally so the new settings apply.
fprintf('2. MODEL REBUILD (ensures ConsistencyChecking=off is active)\n');
pLog('2. MODEL REBUILD\n   ─────────────────\n');
modelFile = fullfile(projRoot, 'simulink', 'models', 'radial_fault_study_network.slx');
if exist(modelFile, 'file')
    if bdIsLoaded('radial_fault_study_network')
        close_system('radial_fault_study_network', 0);
    end
    delete(modelFile);
    pLog('   Old model deleted — rebuilding with updated solver settings.\n');
    fprintf('   Old model deleted — rebuilding...\n');
else
    pLog('   No existing model found — building fresh.\n');
    fprintf('   No existing model found — building fresh.\n');
end
newModelFile = build_radial_fault_model(fullfile(projRoot, 'simulink', 'models'));
pLog('   Model built: %s\n\n', newModelFile);
fprintf('   Model built: %s\n\n', newModelFile);

%% ── 3. Relay configuration summary ──────────────────────────────────────
cfg = createRadialRelayStudyConfiguration();
pLog('3. RELAY CONFIGURATION\n   ───────────────────\n');
for r = cfg.relays
    bkr = cfg.breakers(strcmp({cfg.breakers.id}, r.breakerId));
    pLog('   %s: CT=%d/%d A, Pickup=%.1f A-sec, TMS=%.2f, %s, CB=%s (%.0f ms)\n', ...
        r.id, r.CTprimary_A, r.CTsecondary_A, r.pickupCurrent_A, r.TMS, ...
        r.curveType, r.breakerId, bkr.openingDelay_s * 1e3);
end
pLog('\n');

%% ── 4. Run all Phase F scenarios ─────────────────────────────────────────
FAULT_START = 0.05;
SIM_STOP    = 0.60;
RELAY_TOL   = 0.020;    % ±20 ms analytical vs sim trip time
EXTINCT_LIM = 0.01;     % A — post-clearing peak current limit

faultScenarios = { ...
    struct('scenarioId','PF_3PH',     'faultType','3PH',     'Zf_Ohm',0.001,'Zg_Ohm',0.001,'failCB_B',false,'failCB_A',false); ...
    struct('scenarioId','PF_SLG',     'faultType','SLG',     'Zf_Ohm',0.001,'Zg_Ohm',0.001,'failCB_B',false,'failCB_A',false); ...
    struct('scenarioId','PF_LL',      'faultType','LL',      'Zf_Ohm',0.001,'Zg_Ohm',0.001,'failCB_B',false,'failCB_A',false); ...
    struct('scenarioId','PF_DLG',     'faultType','DLG',     'Zf_Ohm',0.001,'Zg_Ohm',0.001,'failCB_B',false,'failCB_A',false); ...
    struct('scenarioId','PF_HEALTHY', 'faultType','HEALTHY', 'Zf_Ohm',0.001,'Zg_Ohm',0.001,'failCB_B',false,'failCB_A',false); ...
    struct('scenarioId','PF_3PH_CBF', 'faultType','3PH',     'Zf_Ohm',0.001,'Zg_Ohm',0.001,'failCB_B',true, 'failCB_A',false)};

results = cell(numel(faultScenarios), 1);
overallPass = true;

pLog('4. SCENARIO RESULTS\n');
pLog('   %-15s %-8s %-10s %-10s %-10s %-10s %-8s %-6s\n', ...
    'Scenario','FaultType','TripB(s)','OpenB(s)','TripA(s)','OpenA(s)','Cleared','PASS');
pLog('   %s\n', repmat('-',1,80));
fprintf('\n4. SCENARIO RESULTS\n');
fprintf('   %-15s %-8s %-10s %-10s %-10s %-10s %-8s %-6s\n', ...
    'Scenario','FaultType','TripB(s)','OpenB(s)','TripA(s)','OpenA(s)','Cleared','PASS');
fprintf('   %s\n', repmat('-',1,80));

for sIdx = 1:numel(faultScenarios)
    scn = faultScenarios{sIdx};
    scn.faultInsertionTime_s  = FAULT_START;
    if scn.failCB_B
        scn.simulationStopTime_s = 0.85;
    else
        scn.simulationStopTime_s = SIM_STOP;
    end

    fprintf('   Running %-15s (%s)... ', scn.scenarioId, scn.faultType);
    res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true, 'forceRebuild', false));
    results{sIdx} = res;

    % Safe field extraction (guard for FAILED/BLOCKED results)
    [tripB, openB, tripA, openA, clr] = extractTimings(res);
    isHealthy = strcmp(res.faultType, 'HEALTHY');
    isCBFail  = scn.failCB_B;
    passed    = evaluatePass(res, isHealthy, isCBFail, clr);
    if ~isHealthy && ~passed, overallPass = false; end

    pLog('   %-15s %-8s %-10s %-10s %-10s %-10s %-8s %-6s\n', ...
        scn.scenarioId, res.faultType, ...
        fmtTime(tripB), fmtTime(openB), fmtTime(tripA), fmtTime(openA), ...
        mat2str(clr), ternary(passed,'PASS','FAIL'));
    fprintf(' [%s]\n', ternary(passed,'PASS','FAIL'));

    if strcmp(res.status, 'FAILED') && ~isempty(res.errors)
        pLog('     ERROR: %s\n', res.errors{1});
        fprintf('     ERROR: %s\n', res.errors{1});
    end
end

pLog('   %s\n\n', repmat('-',1,80));
fprintf('   %s\n\n', repmat('-',1,80));

%% ── 5. Analytical cross-validation ──────────────────────────────────────
pLog('5. ANALYTICAL vs SIMULATED TIMING CROSS-VALIDATION (±%.0f ms tolerance)\n', RELAY_TOL*1e3);
pLog('   %-8s  %-12s  %-12s  %-12s  %-10s  %-10s  %-6s\n', ...
    'Fault','I1-sim(A)','Ana-B(s)','Sim-B(s)','ErrB(ms)','OpenB(s)','PASS');
pLog('   %s\n', repmat('-',1,78));
fprintf('\n5. ANALYTICAL vs SIMULATED TIMING CROSS-VALIDATION\n');

for sIdx = 1:4   % 3PH, SLG, LL, DLG
    res = results{sIdx};
    if ~strcmp(res.status, 'COMPLETED')
        pLog('   %-8s  [Simulation %s — cross-check skipped]\n', res.faultType, res.status);
        fprintf('   %-8s  Skipped (%s)\n', res.faultType, res.status);
        overallPass = false;
        continue;
    end
    if ~isfield(res.analyticalPredictions, 'I1_fundamental_A')
        pLog('   %-8s  Analytical prediction unavailable — cross-check skipped.\n', res.faultType);
        fprintf('   %-8s  Analytical prediction unavailable.\n', res.faultType);
        continue;
    end
    ap  = res.analyticalPredictions;
    [tripB, openB, ~, ~, ~] = extractTimings(res);
    if isnan(tripB)
        pLog('   %-8s  No trip detected — FAIL\n', res.faultType);
        overallPass = false;
        continue;
    end
    simRel  = tripB - FAULT_START;
    errMs   = (simRel - ap.anaRelayB_trip_s) * 1e3;
    passXv  = abs(simRel - ap.anaRelayB_trip_s) <= RELAY_TOL;
    if ~passXv, overallPass = false; end

    pLog('   %-8s  %-12.2f  %-12.4f  %-12.4f  %+10.1f  %-10.4f  %-6s\n', ...
        res.faultType, ap.I1_fundamental_A, ap.anaRelayB_trip_s, simRel, ...
        errMs, openB - FAULT_START, ternary(passXv,'PASS','FAIL'));
    fprintf('   %-8s  I1=%.1f A  AnaB=%.4f s  SimB=%.4f s  Err=%+.1f ms  [%s]\n', ...
        res.faultType, ap.I1_fundamental_A, ap.anaRelayB_trip_s, simRel, errMs, ternary(passXv,'PASS','FAIL'));
end
pLog('   %s\n\n', repmat('-',1,78));

%% ── 6. Current extinction summary ────────────────────────────────────────
pLog('6. FAULT CLEARING AND CURRENT EXTINCTION\n');
pLog('   %-15s  %-8s  %-14s  %-18s  %-6s\n', ...
    'Scenario','Cleared','Extinction(s)','PostPeak(A)','PASS');
pLog('   %s\n', repmat('-',1,65));
fprintf('\n6. CURRENT EXTINCTION VERIFICATION\n');

for sIdx = 1:numel(results)
    res = results{sIdx};
    cv  = res.clearingVerification;
    isHealthy = strcmp(res.faultType, 'HEALTHY');
    if isHealthy
        passExt = ~cv.faultCleared;
    else
        passExt = strcmp(res.status,'COMPLETED') && cv.faultCleared && ...
                  cv.postClearingCurrentPeak_A < EXTINCT_LIM;
    end
    if ~isHealthy && ~passExt, overallPass = false; end
    pLog('   %-15s  %-8s  %-14s  %-18.4f  %-6s\n', ...
        res.scenarioId, mat2str(cv.faultCleared), ...
        ternary(cv.faultCleared, sprintf('%.4f', cv.extinctionTime_s), 'N/A'), ...
        cv.postClearingCurrentPeak_A, ternary(isHealthy || passExt, 'PASS', 'FAIL'));
    fprintf('   %-15s  Cleared=%-5s  ExtinctT=%-8s  Peak=%.4f A  [%s]\n', ...
        res.scenarioId, mat2str(cv.faultCleared), ...
        ternary(cv.faultCleared, sprintf('%.4f s', cv.extinctionTime_s), 'N/A'), ...
        cv.postClearingCurrentPeak_A, ternary(isHealthy || passExt, 'PASS', 'FAIL'));
end
pLog('   %s\n\n', repmat('-',1,65));

%% ── 7. Overall verdict ───────────────────────────────────────────────────
pLog('7. OVERALL PHASE F VALIDATION RESULT\n');
pLog('   ────────────────────────────────────\n');
if overallPass
    verdict = 'PASS — All Phase F acceptance criteria met.';
else
    verdict = 'FAIL — One or more Phase F acceptance criteria not met. See FAIL rows above.';
end
pLog('   RESULT: %s\n', verdict);
pLog('   Report: %s\n', reportFile);
pLog('=================================================================\n');

fprintf('\n7. OVERALL RESULT: %s\n', verdict);
fprintf('   Report saved: %s\n', reportFile);
fprintf('=================================================================\n\n');

if fid ~= 1, fclose(fid); end

%% ──────────────────────────────── Local helpers ──────────────────────────

function [tripB, openB, tripA, openA, cleared] = extractTimings(res)
    % Safely extract timing fields from result struct (handles FAILED results)
    tripB   = NaN; openB = NaN; tripA = NaN; openA = NaN;
    cleared = false;
    if isfield(res, 'clearingVerification') && isfield(res.clearingVerification, 'faultCleared')
        cleared = res.clearingVerification.faultCleared;
    end
    if isfield(res, 'relay') && isfield(res.relay, 'B')
        if isfield(res.relay.B, 'tripTime_s'),       tripB = res.relay.B.tripTime_s; end
        if isfield(res.relay.B, 'breakerOpenTime_s'), openB = res.relay.B.breakerOpenTime_s; end
    end
    if isfield(res, 'relay') && isfield(res.relay, 'A')
        if isfield(res.relay.A, 'tripTime_s'),       tripA = res.relay.A.tripTime_s; end
        if isfield(res.relay.A, 'breakerOpenTime_s'), openA = res.relay.A.breakerOpenTime_s; end
    end
end

function passed = evaluatePass(res, isHealthy, isCBFail, clr)
    if ~strcmp(res.status, 'COMPLETED'), passed = false; return; end
    bStatus = '';
    aStatus = '';
    if isfield(res.relay,'B') && isfield(res.relay.B,'tripStatus'), bStatus = res.relay.B.tripStatus; end
    if isfield(res.relay,'A') && isfield(res.relay.A,'tripStatus'), aStatus = res.relay.A.tripStatus; end
    [~, openB, ~, ~, ~] = extractTimings(res);
    if isHealthy
        passed = ~strcmp(bStatus,'TRIPPED') && ~strcmp(aStatus,'TRIPPED');
    elseif isCBFail
        passed = strcmp(aStatus,'TRIPPED') && clr;
    else
        passed = strcmp(bStatus,'TRIPPED') && ~isnan(openB) && clr;
    end
end

function s = fmtTime(t)
    if isnan(t), s = 'N/A'; else, s = sprintf('%.4f', t); end
end

function out = ternary(cond, trueVal, falseVal)
    if cond, out = trueVal; else, out = falseVal; end
end
