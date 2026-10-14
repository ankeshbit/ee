%% run_complete_fault_study.m
% Phase G — Unified Automated Fault Study Entry Point
%
% Executes all supported scenarios (healthy, 3PH, SLG, LL, DLG, breaker-
% failure) through both the analytical engine and the native Simscape
% Electrical physical simulation. Collects structured results, generates
% plots, and produces a consolidated multi-format report.
%
% Usage:
%   study = run_complete_fault_study()
%   study = run_complete_fault_study(options)
%
% Options (struct, all fields optional):
%   outputDir       : Results directory  (default: <projRoot>/results)
%   skipSimulation  : Skip physical simulations (default: false)
%   quiet           : Suppress per-scenario console output (default: false)
%   forceRebuild    : Force Simulink model rebuild (default: false)
%   generatePlots   : Save figures to results/plots/ (default: true)
%   generateReports : Write reports to results/reports/ (default: true)
%
% Output study struct fields:
%   .runTimestamp .matlabVersion .modelFile .config
%   .analyticalResults .simulationResults
%   .comparisonTable .relayTimingTable .protectionCoord
%   .testOutcomes .overallPass
%   .reportPaths .plotPaths

function study = run_complete_fault_study(options)

%% 0. Defaults
if nargin < 1 || isempty(options), options = struct(); end
if ~isfield(options,'skipSimulation'),  options.skipSimulation  = false; end
if ~isfield(options,'quiet'),           options.quiet           = false; end
if ~isfield(options,'forceRebuild'),    options.forceRebuild    = false; end
if ~isfield(options,'generatePlots'),   options.generatePlots   = true;  end
if ~isfield(options,'generateReports'), options.generateReports = true;  end

thisFile = mfilename('fullpath');
projRoot = fileparts(fileparts(thisFile));

addpath(genpath(fullfile(projRoot,'matlab')));
addpath(genpath(fullfile(projRoot,'scripts')));

if ~isfield(options,'outputDir')
    options.outputDir = fullfile(projRoot,'results');
end
plotDir   = fullfile(options.outputDir,'plots');
reportDir = fullfile(options.outputDir,'reports');
for d = {plotDir, reportDir}
    if ~exist(d{1},'dir'), mkdir(d{1}); end
end

study = p_initStudy();
study.runTimestamp  = datestr(now,'yyyy-mm-ddTHH:MM:SS'); %#ok<TNOW1,DATST>
study.matlabVersion = version;
study.projRoot      = projRoot;

pLog(options,'\n================================================================\n');
pLog(options,' PHASE G — Complete Fault Study\n');
pLog(options,' Power System Fault Analysis & Protection Coordination Simulator\n');
pLog(options,' MATLAB R%s   %s\n',version('-release'),study.runTimestamp);
pLog(options,'================================================================\n\n');

%% 1. Dependencies
pLog(options,'[1/8] Checking environment and dependencies...\n');
requiredFuncs = {'checkSimulationCapabilities','runIntegratedFaultStudy', ...
    'runDynamicBreakerSwitchingSimulation','createRadialRelayStudyConfiguration', ...
    'calculateRelayOperatingTime','collectFaultStudyResults', ...
    'generateFaultStudyReport'};
for i = 1:numel(requiredFuncs)
    if ~exist(requiredFuncs{i},'file') && ~exist(requiredFuncs{i},'builtin')
        error('run_complete_fault_study:MissingDependency', ...
            'Required function not found on path: %s', requiredFuncs{i});
    end
end
diagOpts = struct('quiet',true,'allowPowerSystemBlocks',true);
diag = checkSimulationCapabilities(diagOpts);
study.environment = diag;
simAvailable = strcmp(diag.status,'READY');
pLog(options,'     Environment : %s  |  Simscape: %s\n', ...
    diag.status, mat2str(diag.simscapeElectricalLicensed));
if options.skipSimulation
    pLog(options,'     [INFO] skipSimulation=true — Simscape runs skipped.\n');
end

%% 2. Configuration
pLog(options,'\n[2/8] Loading relay configuration...\n');
cfg = createRadialRelayStudyConfiguration();
study.config = cfg;
pLog(options,'     Relays: %d  Breakers: %d  Pairs: %d\n', ...
    numel(cfg.relays),numel(cfg.breakers),numel(cfg.coordinationPairs));

%% 3. Analytical study
pLog(options,'\n[3/8] Running analytical fault study...\n');
network     = cfg.network;
relays      = cfg.relays;
coordPairs  = cfg.coordinationPairs;
anaScenarios = p_buildAnalyticalScenarios();
anaResults   = runIntegratedFaultStudy(network, anaScenarios, relays, coordPairs);
study.analyticalResults = anaResults;
for i = 1:numel(anaResults)
    r = anaResults(i);
    pLog(options,'     %-22s  %-5s  Ifault=%7.1f A\n', ...
        r.scenarioId, r.faultType, r.faultCurrentMagnitude_A);
end

%% 4. Physical Simscape simulations
pLog(options,'\n[4/8] Running Phase F physical simulations...\n');
FAULT_START  = 0.05;
SIM_STOP     = 0.60;
SIM_STOP_CBF = 0.85;
pfDefs = { ...
    'PF_HEALTHY', 'HEALTHY', false, false, SIM_STOP    ; ...
    'PF_3PH',     '3PH',     false, false, SIM_STOP    ; ...
    'PF_SLG',     'SLG',     false, false, SIM_STOP    ; ...
    'PF_LL',      'LL',      false, false, SIM_STOP    ; ...
    'PF_DLG',     'DLG',     false, false, SIM_STOP    ; ...
    'PF_3PH_CBF', '3PH',     true,  false, SIM_STOP_CBF};
simResults = cell(size(pfDefs,1),1);
simOpts = struct('quiet',true,'forceRebuild',options.forceRebuild);
for i = 1:size(pfDefs,1)
    scn.scenarioId          = pfDefs{i,1};
    scn.faultType           = pfDefs{i,2};
    scn.failCB_B            = pfDefs{i,3};
    scn.failCB_A            = pfDefs{i,4};
    scn.faultInsertionTime_s = FAULT_START;
    scn.simulationStopTime_s = pfDefs{i,5};
    scn.Zf_Ohm              = 0.001;
    scn.Zg_Ohm              = 0.001;
    if ~simAvailable || options.skipSimulation
        simResults{i} = p_blockedResult(scn, ~simAvailable);
        pLog(options,'     %-15s  [SKIPPED]\n', scn.scenarioId);
    else
        pLog(options,'     Running %-15s (%s)... ', scn.scenarioId, scn.faultType);
        simResults{i} = runDynamicBreakerSwitchingSimulation(scn, simOpts);
        pLog(options,'[%s]\n', simResults{i}.status);
    end
end
study.simulationResults = simResults;
study.modelFile = fullfile(projRoot,'simulink','models','radial_fault_study_network.slx');

%% 5. Comparison and timing tables
pLog(options,'\n[5/8] Computing comparison and timing tables...\n');
[study.comparisonTable, study.relayTimingTable] = ...
    collectFaultStudyResults(anaResults, simResults, cfg, FAULT_START);
study.protectionCoord = p_coordinationSummary(cfg, anaResults);

%% 6. Acceptance checks
pLog(options,'\n[6/8] Running acceptance-criteria checks...\n');
[study.testOutcomes, study.overallPass] = ...
    p_evaluateAcceptance(simResults, study.relayTimingTable);
if ~isempty(study.testOutcomes) && isfield(study.testOutcomes(1),'pass')
    nPassed = sum([study.testOutcomes.pass]);
    nTotal  = numel(study.testOutcomes);
else
    nPassed = 0;
    nTotal  = 0;
end
pLog(options,'     Checks: %d / %d passed\n', nPassed, nTotal);

%% 7. Plots
study.plotPaths = struct();
if options.generatePlots
    pLog(options,'\n[7/8] Generating plots...\n');
    study.plotPaths = p_generatePlots(simResults, study, plotDir, options);
else
    pLog(options,'\n[7/8] Plots skipped.\n');
end

%% 8. Reports
study.reportPaths = struct();
if options.generateReports
    pLog(options,'\n[8/8] Generating reports...\n');
    study.reportPaths = generateFaultStudyReport(study, reportDir);
    fields = fieldnames(study.reportPaths);
    for i = 1:numel(fields)
        pLog(options,'     %-6s: %s\n', upper(fields{i}), study.reportPaths.(fields{i}));
    end
else
    pLog(options,'\n[8/8] Reports skipped.\n');
end

pLog(options,'\n================================================================\n');
pLog(options,' PHASE G COMPLETE  |  Overall: %s  |  Checks: %d/%d passed\n', ...
    ternary(study.overallPass,'PASS','FAIL'), nPassed, nTotal);
pLog(options,'================================================================\n\n');
end

%% ═══════════════════════════════ Helpers ══════════════════════════════════

function s = p_initStudy()
s = struct('runTimestamp','','matlabVersion','','projRoot','','modelFile','', ...
    'config',struct(),'environment',struct(), ...
    'analyticalResults',struct([]),'simulationResults',{{}},...
    'comparisonTable',struct([]),'relayTimingTable',struct([]), ...
    'protectionCoord',struct(),'testOutcomes',struct([]), ...
    'overallPass',false,'reportPaths',struct(),'plotPaths',struct());
end

function network = p_buildNetwork()
cfg = createRadialRelayStudyConfiguration();
network = cfg.network;
end

function scenarios = p_buildAnalyticalScenarios()
% Per-unit fault impedance: 0.001 Ohm at 11 kV base (11e3^2/10e6 = 12.1 Ohm)
Zf_pu = 0.001 / (11e3^2 / 10e6);
fts = {'3PH','SLG','LL','DLG'};
scenarios = repmat(struct('id','','faultedBus','','faultType','','Zf_pu',0),1,4);
for i = 1:4
    scenarios(i).id         = sprintf('ANA_%s_BUS_B', fts{i});
    scenarios(i).faultedBus = 'BUS_B';
    scenarios(i).faultType  = fts{i};
    scenarios(i).Zf_pu      = Zf_pu;
end
end

function coord = p_coordinationSummary(cfg, anaResults)
coord.pairs        = cfg.coordinationPairs;
coord.scenarioBasis = '3PH fault at BUS_B (maximum current basis)';
coord.relayTimes   = struct([]);
coord.criteria     = cfg.criteria;
hit = find(strcmp({anaResults.faultType},'3PH'),1);
if isempty(hit), return; end
rr = anaResults(hit).relayResults;
rows = [];
for i = 1:numel(rr)
    relIdx = strcmp({cfg.relays.id}, rr(i).relayId);
    bkrId = '';
    if any(relIdx), bkrId = cfg.relays(relIdx).breakerId; end
    bkrIdx = strcmp({cfg.breakers.id}, bkrId);
    bkrDelay = ternary(any(bkrIdx), cfg.breakers(bkrIdx).openingDelay_s, NaN);
    row = struct();
    row.relayId         = rr(i).relayId;
    row.operatingTime_s = rr(i).operatingTime_s;
    row.breakerDelay_s  = bkrDelay;
    row.clearingTime_s  = rr(i).operatingTime_s + bkrDelay;
    if isempty(rows)
        rows = row;
    else
        rows(end+1) = row; %#ok<AGROW>
    end
end
if ~isempty(rows)
    coord.relayTimes = rows;
end
end

function [outcomes, overallPass] = p_evaluateAcceptance(simResults, rtTable)
RELAY_TOL_S = 0.020;
EXTINCT_A   = 0.01;
MAX_CLEAR_S = 0.300;
outcomes = [];
for i = 1:numel(simResults)
    r = simResults{i};
    if isempty(r) || ~isfield(r,'status') || ~strcmp(r.status,'COMPLETED'), continue; end
    isHealthy = strcmp(r.faultType,'HEALTHY');
    isCBF     = contains(r.scenarioId,'CBF');
    if ~isHealthy && ~isCBF && isfield(r.relay,'B') && isfield(r.relay.B,'breakerOpenTime_s')
        delay = r.relay.B.breakerOpenTime_s - r.faultInception_s;
        row = struct('criterion','PrimaryBreakWithinLimit', ...
            'scenarioId',r.scenarioId,'pass',delay < MAX_CLEAR_S, ...
            'value',sprintf('%.3f s',delay),'limit',sprintf('< %.3f s',MAX_CLEAR_S));
        if isempty(outcomes), outcomes = row; else, outcomes(end+1) = row; end %#ok<AGROW>
        cv = r.clearingVerification;
        row = struct('criterion','FaultCurrentExtinction', ...
            'scenarioId',r.scenarioId, ...
            'pass',cv.faultCleared && cv.postClearingCurrentPeak_A < EXTINCT_A, ...
            'value',sprintf('%.4f A',cv.postClearingCurrentPeak_A), ...
            'limit',sprintf('< %.4f A',EXTINCT_A));
        outcomes(end+1) = row; %#ok<AGROW>
    end
    if isHealthy
        bTripped = isfield(r.relay,'B') && strcmp(r.relay.B.tripStatus,'TRIPPED');
        row = struct('criterion','NoSpuriousTrip', ...
            'scenarioId',r.scenarioId,'pass',~bTripped, ...
            'value',ternary(bTripped,'TRIPPED','NO_TRIP'),'limit','NO_TRIP');
        if isempty(outcomes), outcomes = row; else, outcomes(end+1) = row; end %#ok<AGROW>
    end
    if isCBF
        aTripped = isfield(r.relay,'A') && strcmp(r.relay.A.tripStatus,'TRIPPED');
        row = struct('criterion','BackupRelayOpOnCBF', ...
            'scenarioId',r.scenarioId, ...
            'pass',aTripped && r.clearingVerification.faultCleared, ...
            'value',ternary(aTripped,'TRIPPED','NO_TRIP'),'limit','TRIPPED+CLEARED');
        if isempty(outcomes), outcomes = row; else, outcomes(end+1) = row; end %#ok<AGROW>
    end
end
if ~isempty(rtTable) && isstruct(rtTable(1)) && isfield(rtTable(1),'timingErrorMs')
    for i = 1:numel(rtTable)
        if isnan(rtTable(i).timingErrorMs), continue; end
        row = struct('criterion','RelayTimingError', ...
            'scenarioId',rtTable(i).scenarioId, ...
            'pass',abs(rtTable(i).timingErrorMs) <= RELAY_TOL_S*1e3, ...
            'value',sprintf('%+.1f ms',rtTable(i).timingErrorMs), ...
            'limit',sprintf('|err|<=%.0f ms',RELAY_TOL_S*1e3));
        if isempty(outcomes), outcomes = row; else, outcomes(end+1) = row; end %#ok<AGROW>
    end
end
if isempty(outcomes)
    outcomes = struct([]);
    overallPass = true;
else
    overallPass = all([outcomes.pass]);
end
end

function plotPaths = p_generatePlots(simResults, study, plotDir, options)
plotPaths = struct();
for i = 1:numel(simResults)
    r = simResults{i};
    if isempty(r) || ~isfield(r,'status') || ~strcmp(r.status,'COMPLETED'), continue; end
    if ~isfield(r,'measurements') || ~isfield(r.measurements,'I_BusB'), continue; end
    sid = r.scenarioId;
    try
        f1 = fullfile(plotDir, sprintf('waveform_current_%s.png',sid));
        g1 = fullfile(plotDir, sprintf('waveform_current_%s.fig',sid));
        plotPhaseCurrentWaveforms(r, f1, g1, true);
        plotPaths.(sprintf('current_%s',sid)) = f1;
    catch ME
        pLog(options,'     [WARN] Current waveform %s: %s\n',sid,ME.message);
    end
    if isfield(r.measurements,'V_BusB') && isfield(r.measurements,'V_BusA')
        try
            f2 = fullfile(plotDir, sprintf('waveform_voltage_%s.png',sid));
            g2 = fullfile(plotDir, sprintf('waveform_voltage_%s.fig',sid));
            plotVoltageWaveforms(r, f2, g2, true);
            plotPaths.(sprintf('voltage_%s',sid)) = f2;
        catch ME
            pLog(options,'     [WARN] Voltage waveform %s: %s\n',sid,ME.message);
        end
    end
    if isfield(r,'waveforms') && isfield(r.waveforms,'sigmaB')
        try
            f3 = fullfile(plotDir, sprintf('relay_operation_%s.png',sid));
            g3 = fullfile(plotDir, sprintf('relay_operation_%s.fig',sid));
            plotRmsAndRelayOperation(r, f3, g3, true);
            plotPaths.(sprintf('relay_%s',sid)) = f3;
        catch ME
            pLog(options,'     [WARN] Relay op plot %s: %s\n',sid,ME.message);
        end
    end
end
if ~isempty(study.comparisonTable) && isstruct(study.comparisonTable(1))
    try
        fc = fullfile(plotDir,'fault_current_comparison.png');
        gc = fullfile(plotDir,'fault_current_comparison.fig');
        plotFaultCurrentComparison(study.comparisonTable, fc, gc, true);
        plotPaths.currentComparison = fc;
    catch ME
        pLog(options,'     [WARN] Current comparison: %s\n',ME.message);
    end
end
if ~isempty(study.relayTimingTable) && isstruct(study.relayTimingTable(1))
    try
        fr = fullfile(plotDir,'relay_timing_comparison.png');
        gr = fullfile(plotDir,'relay_timing_comparison.fig');
        plotRelayTimingComparison(study.relayTimingTable, fr, gr, true);
        plotPaths.relayTiming = fr;
    catch ME
        pLog(options,'     [WARN] Relay timing: %s\n',ME.message);
    end
end
end

function r = p_blockedResult(scn, notReady)
r.status    = ternary(notReady,'BLOCKED','SKIPPED');
r.scenarioId = scn.scenarioId;
r.faultType  = scn.faultType;
r.faultInception_s = scn.faultInsertionTime_s;
r.measurements = struct();
r.waveforms    = struct();
r.relay = struct('B',struct('tripStatus','UNKNOWN','tripTime_s',NaN,'breakerOpenTime_s',NaN), ...
                 'A',struct('tripStatus','UNKNOWN','tripTime_s',NaN,'breakerOpenTime_s',NaN));
r.clearingVerification = struct('faultCleared',false,'extinctionTime_s',NaN, ...
    'postClearingCurrentPeak_A',NaN,'extinctionThreshold_A',0.01);
r.rms = struct();
r.analyticalPredictions = struct();
r.errors   = {sprintf('Simulation %s — not executed',r.status)};
r.warnings = {};
end

function pLog(options, fmt, varargin)
if ~isfield(options,'quiet') || ~options.quiet
    fprintf(fmt, varargin{:});
end
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
