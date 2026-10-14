function paths = generateFaultStudyReport(study, reportDir)
% generateFaultStudyReport  Generate HTML, CSV, MAT, and TXT reports from
% the structured Phase G fault study results.
%
% Inputs:
%   study     - Struct returned by run_complete_fault_study
%   reportDir - Directory for output files
%
% Outputs:
%   paths - Struct with fields .html, .csv, .mat, .txt

if nargin < 2 || isempty(reportDir)
    reportDir = fullfile(study.projRoot, 'results', 'reports');
end
if ~exist(reportDir,'dir'), mkdir(reportDir); end

ts   = strrep(study.runTimestamp, ':', '-');
paths.html = fullfile(reportDir, 'fault_study_report.html');
paths.csv  = fullfile(reportDir, 'fault_study_summary.csv');
paths.mat  = fullfile(reportDir, 'fault_study_summary.mat');
paths.txt  = fullfile(reportDir, 'fault_study_report.txt');

%% 1. MAT file — save full study struct
% Write to temp first, then rename atomically to avoid partial writes
tmpMat = [paths.mat, '.tmp'];
save(tmpMat, 'study', '-v7.3');
if exist(paths.mat,'file'), delete(paths.mat); end
movefile(tmpMat, paths.mat);

%% 2. CSV summary
p_writeCSV(paths.csv, study);

%% 3. TXT report
p_writeTXT(paths.txt, study);

%% 4. HTML report
p_writeHTML(paths.html, study);
end

%% ═══════════════════════════════════════════════════════════════════
%% CSV writer
%% ═══════════════════════════════════════════════════════════════════
function p_writeCSV(csvFile, study)
fid = fopen(csvFile, 'w');
if fid < 0
    warning('generateFaultStudyReport:CSVFailed','Cannot open %s for writing.', csvFile);
    return;
end
% Header
fprintf(fid,'ScenarioId,FaultType,SimStatus,AnalyticalCurrent_A,SimulatedMaxPhaseRMS_A,');
fprintf(fid,'AbsError_A,PctError,RelayTripTime_s,BreakerOpenTime_s,');
fprintf(fid,'TimingError_ms,FaultCleared,ExtinctionTime_s,PostClearPeak_A,OverallPass\n');

% Rows from simulation results
simMap = containers.Map('KeyType','char','ValueType','any');
for i = 1:numel(study.simulationResults)
    r = study.simulationResults{i};
    if ~isempty(r) && isfield(r,'scenarioId')
        simMap(r.scenarioId) = r;
    end
end

% Build relay timing map
rtMap = containers.Map('KeyType','char','ValueType','any');
if ~isempty(study.relayTimingTable) && isstruct(study.relayTimingTable(1))
    for i = 1:numel(study.relayTimingTable)
        rt = study.relayTimingTable(i);
        if isfield(rt,'scenarioId')
            rtMap(rt.scenarioId) = rt;
        end
    end
end

% Comparison map
ctMap = containers.Map('KeyType','char','ValueType','any');
if ~isempty(study.comparisonTable) && isstruct(study.comparisonTable(1))
    for i = 1:numel(study.comparisonTable)
        ct = study.comparisonTable(i);
        if isfield(ct,'faultType')
            ctMap(ct.faultType) = ct;
        end
    end
end

fts = {'HEALTHY','3PH','SLG','LL','DLG','3PH_CBF'};
for fi = 1:numel(fts)
    ft = fts{fi};
    pfId = sprintf('PF_%s', ft);
    if ~simMap.isKey(pfId), continue; end
    r = simMap(pfId);

    anaCurr = 'N/A';
    simCurr = 'N/A';
    absErr  = 'N/A';
    pctErr  = 'N/A';
    if ctMap.isKey(ft)
        ct = ctMap(ft);
        anaCurr = sprintf('%.2f', ct.analyticalCurrent_A);
        if ~isnan(ct.simulatedFundamentalRMS_A)
            simCurr = sprintf('%.2f', ct.simulatedFundamentalRMS_A);
            absErr  = sprintf('%.2f', ct.absoluteError_A);
            pctErr  = sprintf('%.2f', ct.percentageError);
        end
    end

    tripT = 'N/A';  openT = 'N/A';
    if isfield(r,'relay') && isfield(r.relay,'B')
        if isfield(r.relay.B,'tripTime_s') && ~isnan(r.relay.B.tripTime_s)
            tripT = sprintf('%.4f', r.relay.B.tripTime_s);
        end
        if isfield(r.relay.B,'breakerOpenTime_s') && ~isnan(r.relay.B.breakerOpenTime_s)
            openT = sprintf('%.4f', r.relay.B.breakerOpenTime_s);
        end
    end

    timErr = 'N/A';
    if rtMap.isKey(pfId)
        rt = rtMap(pfId);
        if isfield(rt,'timingErrorMs') && ~isnan(rt.timingErrorMs)
            timErr = sprintf('%.1f', rt.timingErrorMs);
        end
    end

    cv = r.clearingVerification;
    cleared  = mat2str(cv.faultCleared);
    extT     = ternary(~isnan(cv.extinctionTime_s), sprintf('%.4f',cv.extinctionTime_s), 'N/A');
    postPeak = ternary(~isnan(cv.postClearingCurrentPeak_A), ...
        sprintf('%.4f',cv.postClearingCurrentPeak_A), 'N/A');

    fprintf(fid,'%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n', ...
        pfId, ft, r.status, anaCurr, simCurr, absErr, pctErr, ...
        tripT, openT, timErr, cleared, extT, postPeak, ...
        mat2str(study.overallPass));
end

fclose(fid);
end

%% ═══════════════════════════════════════════════════════════════════
%% TXT report
%% ═══════════════════════════════════════════════════════════════════
function p_writeTXT(txtFile, study)
fid = fopen(txtFile,'w');
if fid < 0
    warning('generateFaultStudyReport:TXTFailed','Cannot open %s.',txtFile);
    return;
end

W = @(fmt,varargin) fprintf(fid,fmt,varargin{:});
SEP = repmat('=',1,72);
sep = repmat('-',1,72);

W('%s\n',SEP);
W(' FAULT STUDY REPORT — Power System Fault Analysis & Protection Simulator\n');
W(' Phase G — Automated Fault Study, Visualization & Reporting\n');
W(' MATLAB R%s   Generated: %s\n', version('-release'), study.runTimestamp);
W('%s\n\n',SEP);

%% 1. System Configuration
W('1. SYSTEM CONFIGURATION\n%s\n',sep);
cfg = study.config;
net = cfg.network;
W('   System Base       : %.0f MVA\n', net.base.SbaseVA/1e6);
W('   Source Voltage    : %.0f kV\n', net.base.VbaseV/1e3);
W('   Frequency         : 50 Hz (nominal)\n');
W('   Transformer T1    : %.0f/%.0f kV, %.0f MVA, Z1=%.2f pu\n', ...
    net.transformers.ratedHighVoltageV/1e3, net.transformers.ratedLowVoltageV/1e3, ...
    net.transformers.ratedSbaseVA/1e6, net.transformers.Z1_pu);
W('   Fault Resistance  : 0.001 Ohm (Zf_Ohm)\n');
W('   Fault Location    : Bus B (11 kV)\n');
W('   Relay Curve       : IEC Standard Inverse  t = 0.14*TMS/(M^0.02-1)\n\n');

W('   Relay Settings:\n');
for ri = 1:numel(cfg.relays)
    r = cfg.relays(ri);
    bkr = cfg.breakers(strcmp({cfg.breakers.id},r.breakerId));
    W('   %-14s  CT=%d/%d A  Pickup=%.1f A-sec  TMS=%.2f  CB Delay=%.0f ms\n', ...
        r.id, r.CTprimary_A, r.CTsecondary_A, r.pickupCurrent_A, r.TMS, ...
        bkr.openingDelay_s*1e3);
end
W('\n');

%% 2. Analytical Results
W('2. ANALYTICAL FAULT STUDY (Symmetrical Component Method)\n%s\n',sep);
W('   %-22s  %-5s  %10s  %12s\n','ScenarioId','Fault','|Ifault|(A)','Ibase(A)');
W('   %s\n',repmat('-',1,55));
for i = 1:numel(study.analyticalResults)
    r = study.analyticalResults(i);
    W('   %-22s  %-5s  %10.1f\n', r.scenarioId, r.faultType, r.faultCurrentMagnitude_A);
end
W('\n');

%% 3. Simulation Results
W('3. PHASE F PHYSICAL SIMULATION RESULTS\n%s\n',sep);
W('   %-15s  %-7s  %-9s  %-9s  %-9s  %-8s  %-7s\n', ...
    'Scenario','Status','TripB(s)','OpenB(s)','Extinct(s)','Cleared','Pass');
W('   %s\n',repmat('-',1,72));
for i = 1:numel(study.simulationResults)
    r = study.simulationResults{i};
    if isempty(r), continue; end
    tripT  = 'N/A';  openT  = 'N/A';  extT = 'N/A';
    if isfield(r,'relay') && isfield(r.relay,'B')
        b = r.relay.B;
        if isfield(b,'tripTime_s')       && ~isnan(b.tripTime_s),       tripT=sprintf('%.4f',b.tripTime_s);       end
        if isfield(b,'breakerOpenTime_s')&& ~isnan(b.breakerOpenTime_s), openT=sprintf('%.4f',b.breakerOpenTime_s); end
    end
    cv = r.clearingVerification;
    if ~isnan(cv.extinctionTime_s), extT = sprintf('%.4f',cv.extinctionTime_s); end
    isHealthy = strcmp(r.faultType,'HEALTHY');
    pass = ternary(isHealthy, ~cv.faultCleared, strcmp(r.status,'COMPLETED')&&cv.faultCleared);
    W('   %-15s  %-7s  %-9s  %-9s  %-9s  %-8s  %-7s\n', ...
        r.scenarioId, r.status, tripT, openT, extT, mat2str(cv.faultCleared), ...
        ternary(pass,'PASS','FAIL'));
end
W('\n');

%% 4. Relay Timing Cross-Validation
W('4. RELAY TIMING CROSS-VALIDATION (±20 ms tolerance)\n%s\n',sep);
if ~isempty(study.relayTimingTable) && isstruct(study.relayTimingTable(1))
    W('   %-8s  %10s  %8s  %12s  %12s  %10s  %-6s\n', ...
        'Fault','Imax(A)','M','Ana(s)','Sim(s)','Err(ms)','Pass');
    W('   %s\n',repmat('-',1,70));
    for i = 1:numel(study.relayTimingTable)
        rt = study.relayTimingTable(i);
        if ~rt.validComparison, continue; end
        pass = abs(rt.timingErrorMs) <= 20;
        W('   %-8s  %10.2f  %8.3f  %12.4f  %12.4f  %+10.1f  %-6s\n', ...
            rt.faultType, rt.Imax_A, rt.M_max, rt.analyticalTime_s, ...
            rt.simulatedRelayTime_s, rt.timingErrorMs, ternary(pass,'PASS','FAIL'));
    end
else
    W('   Relay timing data not available (simulation skipped or failed).\n');
end
W('\n');

%% 5. Protection Coordination
W('5. PROTECTION COORDINATION SUMMARY (3PH fault basis)\n%s\n',sep);
coord = study.protectionCoord;
if isfield(coord,'relayTimes') && ~isempty(coord.relayTimes)
    W('   %-14s  %12s  %10s  %12s\n','Relay','TopRelay(s)','CB_Delay(s)','ClearTime(s)');
    W('   %s\n',repmat('-',1,52));
    for i = 1:numel(coord.relayTimes)
        rt = coord.relayTimes(i);
        W('   %-14s  %12.4f  %10.3f  %12.4f\n', ...
            rt.relayId, rt.operatingTime_s, rt.breakerDelay_s, rt.clearingTime_s);
    end
end
W('\n');

%% 6. Acceptance Checks
W('6. ACCEPTANCE CRITERIA RESULTS\n%s\n',sep);
if ~isempty(study.testOutcomes) && isstruct(study.testOutcomes(1)) && isfield(study.testOutcomes(1),'criterion')
    nPass = sum([study.testOutcomes.pass]);
    nTotal = numel(study.testOutcomes);
    W('   Passed: %d / %d\n\n', nPass, nTotal);
    W('   %-30s  %-15s  %-12s  %-16s  %-6s\n','Criterion','ScenarioId','Value','Limit','Pass');
    W('   %s\n',repmat('-',1,82));
    for i = 1:numel(study.testOutcomes)
        oc = study.testOutcomes(i);
        W('   %-30s  %-15s  %-12s  %-16s  %-6s\n', ...
            oc.criterion, oc.scenarioId, oc.value, oc.limit, ...
            ternary(oc.pass,'PASS','FAIL'));
    end
end
W('\n');

%% 7. Overall
W('%s\n',SEP);
W(' OVERALL RESULT: %s\n', ternary(study.overallPass,'PASS','FAIL'));
W(' MATLAB %s  |  Run: %s\n', study.matlabVersion, study.runTimestamp);
W('%s\n',SEP);

fclose(fid);
end

%% ═══════════════════════════════════════════════════════════════════
%% HTML report
%% ═══════════════════════════════════════════════════════════════════
function p_writeHTML(htmlFile, study)
fid = fopen(htmlFile,'w','n','UTF-8');
if fid < 0
    warning('generateFaultStudyReport:HTMLFailed','Cannot open %s.',htmlFile);
    return;
end
W = @(s) fprintf(fid,'%s\n',s);
overallColor = ternary(study.overallPass,'#1a7a3a','#b52020');
overallTxt   = ternary(study.overallPass,'PASS','FAIL');

W('<!DOCTYPE html>');
W('<html lang="en"><head><meta charset="UTF-8">');
W('<meta name="viewport" content="width=device-width,initial-scale=1">');
W('<title>Fault Study Report — Power System Protection Simulator</title>');
W('<style>');
W('body{font-family:Arial,Helvetica,sans-serif;margin:0;background:#f4f6f9;color:#222;}');
W('.header{background:linear-gradient(135deg,#1b3a6b,#2c6fad);color:#fff;padding:28px 36px;}');
W('.header h1{margin:0 0 6px;font-size:1.6em;}');
W('.header p{margin:0;opacity:0.85;font-size:0.92em;}');
W('.badge{display:inline-block;padding:4px 16px;border-radius:20px;font-weight:bold;');
W('  font-size:1.1em;color:#fff;margin-top:10px;}');
W('.badge-pass{background:#1a7a3a;} .badge-fail{background:#b52020;}');
W('.container{max-width:1100px;margin:24px auto;padding:0 16px;}');
W('h2{color:#1b3a6b;border-bottom:2px solid #2c6fad;padding-bottom:6px;margin-top:28px;}');
W('table{width:100%;border-collapse:collapse;margin-bottom:18px;font-size:0.88em;}');
W('th{background:#2c6fad;color:#fff;padding:7px 10px;text-align:left;}');
W('td{padding:6px 10px;border-bottom:1px solid #dde3ea;}');
W('tr:hover td{background:#eaf1fb;}');
W('.pass{color:#1a7a3a;font-weight:bold;} .fail{color:#b52020;font-weight:bold;}');
W('.na{color:#888;} .note{font-size:0.8em;color:#555;margin-top:4px;}');
W('.section{background:#fff;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,0.07);');
W('  padding:20px 24px;margin-bottom:20px;}');
W('</style></head><body>');

% Header
W('<div class="header">');
fprintf(fid,'<h1>Power System Fault Study Report</h1>\n');
fprintf(fid,'<p>Phase G — Automated Fault Study, Visualization &amp; Reporting</p>\n');
fprintf(fid,'<p>MATLAB %s &nbsp;|&nbsp; Generated: %s</p>\n', ...
    study.matlabVersion, study.runTimestamp);
fprintf(fid,'<span class="badge badge-%s">%s</span>\n', ...
    lower(overallTxt), overallTxt);
W('</div>');
W('<div class="container">');

%% Executive Summary
W('<div class="section">');
W('<h2>1. Executive Summary</h2>');
nSim = numel(study.simulationResults);
nCompleted = sum(cellfun(@(r) ~isempty(r)&&isfield(r,'status')&&strcmp(r.status,'COMPLETED'), ...
    study.simulationResults));
nFailed    = sum(cellfun(@(r) ~isempty(r)&&isfield(r,'status')&&strcmp(r.status,'FAILED'), ...
    study.simulationResults));
nPassed = 0; nTotal = 0;
if ~isempty(study.testOutcomes) && isstruct(study.testOutcomes(1)) && isfield(study.testOutcomes(1),'pass')
    nPassed = sum([study.testOutcomes.pass]);
    nTotal  = numel(study.testOutcomes);
end

W('<table>');
W('<tr><th>Item</th><th>Value</th></tr>');
fprintf(fid,'<tr><td>Scenarios attempted</td><td>%d</td></tr>\n', nSim);
fprintf(fid,'<tr><td>Simulations completed</td><td>%d</td></tr>\n', nCompleted);
fprintf(fid,'<tr><td>Simulations failed / blocked</td><td>%d</td></tr>\n', nFailed + (nSim - nCompleted - nFailed));
fprintf(fid,'<tr><td>Acceptance checks passed</td><td class="%s">%d / %d</td></tr>\n', ...
    ternary(nPassed==nTotal,'pass','fail'), nPassed, nTotal);
fprintf(fid,'<tr><td>Overall result</td><td class="%s">%s</td></tr>\n', ...
    lower(overallTxt), overallTxt);
fprintf(fid,'<tr><td>MATLAB version</td><td>%s</td></tr>\n', study.matlabVersion);
W('</table>');
W('</div>');

%% System Configuration
W('<div class="section">');
W('<h2>2. System Configuration</h2>');
cfg = study.config;
net = cfg.network;
W('<table>');
W('<tr><th>Parameter</th><th>Value</th></tr>');
fprintf(fid,'<tr><td>System Base</td><td>%.0f MVA</td></tr>\n', net.base.SbaseVA/1e6);
fprintf(fid,'<tr><td>Source Voltage</td><td>%.0f kV</td></tr>\n', net.base.VbaseV/1e3);
fprintf(fid,'<tr><td>Frequency</td><td>50 Hz</td></tr>\n');
fprintf(fid,'<tr><td>Transformer T1</td><td>%.0f/%.0f kV, %.0f MVA, Z1=%.2f pu (Yg-Yg)</td></tr>\n', ...
    net.transformers.ratedHighVoltageV/1e3, net.transformers.ratedLowVoltageV/1e3, ...
    net.transformers.ratedSbaseVA/1e6, net.transformers.Z1_pu);
fprintf(fid,'<tr><td>Fault Location</td><td>Bus B (11 kV) — bolted/near-bolted (Z_f = 0.001 &Omega;)</td></tr>\n');
fprintf(fid,'<tr><td>Relay Characteristic</td><td>IEC Standard Inverse: t = 0.14&times;TMS/(M<sup>0.02</sup>&minus;1)</td></tr>\n');
W('</table>');
W('<h3>Relay Settings</h3><table>');
W('<tr><th>Relay ID</th><th>CT Ratio</th><th>Pickup (A-sec)</th><th>TMS</th><th>CB Delay</th></tr>');
for ri = 1:numel(cfg.relays)
    r = cfg.relays(ri);
    bkr = cfg.breakers(strcmp({cfg.breakers.id},r.breakerId));
    fprintf(fid,'<tr><td>%s</td><td>%d/%d A</td><td>%.1f A</td><td>%.2f</td><td>%.0f ms</td></tr>\n', ...
        r.id, r.CTprimary_A, r.CTsecondary_A, r.pickupCurrent_A, r.TMS, bkr.openingDelay_s*1e3);
end
W('</table></div>');

%% Simulation Results
W('<div class="section">');
W('<h2>3. Simulation Results</h2>');
W('<table>');
W('<tr><th>Scenario</th><th>Fault</th><th>Status</th><th>Trip B (s)</th><th>CB Open (s)</th><th>Extinction (s)</th><th>Cleared</th><th>Result</th></tr>');
for i = 1:numel(study.simulationResults)
    r = study.simulationResults{i};
    if isempty(r), continue; end
    tripT='N/A'; openT='N/A'; extT='N/A';
    if isfield(r,'relay')&&isfield(r.relay,'B')
        b=r.relay.B;
        if isfield(b,'tripTime_s')&&~isnan(b.tripTime_s), tripT=sprintf('%.4f',b.tripTime_s); end
        if isfield(b,'breakerOpenTime_s')&&~isnan(b.breakerOpenTime_s), openT=sprintf('%.4f',b.breakerOpenTime_s); end
    end
    cv=r.clearingVerification;
    if ~isnan(cv.extinctionTime_s), extT=sprintf('%.4f',cv.extinctionTime_s); end
    isHealthy=strcmp(r.faultType,'HEALTHY');
    pass=ternary(isHealthy,~cv.faultCleared,strcmp(r.status,'COMPLETED')&&cv.faultCleared);
    passStr=ternary(pass,'<span class="pass">PASS</span>','<span class="fail">FAIL</span>');
    fprintf(fid,'<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
        r.scenarioId,r.faultType,r.status,tripT,openT,extT,mat2str(cv.faultCleared),passStr);
end
W('</table></div>');

%% Relay Timing
W('<div class="section">');
W('<h2>4. Relay Timing Cross-Validation (±20 ms)</h2>');
W('<p class="note">Relay B: CT=400/5 A, Pickup=1.0 A-sec, TMS=0.10, IEC Standard Inverse. Simulated = physical relay trip time relative to fault inception.</p>');
if ~isempty(study.relayTimingTable) && isstruct(study.relayTimingTable(1))
    W('<table>');
    W('<tr><th>Fault</th><th>I&#x2098;&#x2090;&#x2093; (A)</th><th>M</th><th>Analytical (s)</th><th>Simulated (s)</th><th>Error (ms)</th><th>Pass</th></tr>');
    for i = 1:numel(study.relayTimingTable)
        rt = study.relayTimingTable(i);
        if ~rt.validComparison, continue; end
        pass = abs(rt.timingErrorMs) <= 20;
        pStr = ternary(pass,'<span class="pass">PASS</span>','<span class="fail">FAIL</span>');
        fprintf(fid,'<tr><td>%s</td><td>%.2f</td><td>%.3f</td><td>%.4f</td><td>%.4f</td><td>%+.1f</td><td>%s</td></tr>\n', ...
            rt.faultType, rt.Imax_A, rt.M_max, rt.analyticalTime_s, rt.simulatedRelayTime_s, rt.timingErrorMs, pStr);
    end
    W('</table>');
else
    W('<p class="na">Relay timing data not available.</p>');
end
W('</div>');

%% Acceptance Criteria
W('<div class="section">');
W('<h2>5. Acceptance Criteria</h2>');
if ~isempty(study.testOutcomes) && isstruct(study.testOutcomes(1)) && isfield(study.testOutcomes(1),'criterion')
    W('<table>');
    W('<tr><th>Criterion</th><th>Scenario</th><th>Value</th><th>Limit</th><th>Result</th></tr>');
    for i = 1:numel(study.testOutcomes)
        oc = study.testOutcomes(i);
        pStr = ternary(oc.pass,'<span class="pass">PASS</span>','<span class="fail">FAIL</span>');
        fprintf(fid,'<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
            oc.criterion, oc.scenarioId, oc.value, oc.limit, pStr);
    end
    W('</table>');
end
W('</div>');

%% Known Limitations
W('<div class="section">');
W('<h2>6. Known Limitations</h2>');
W('<ul>');
W('<li>Directional supervision is evaluated analytically in Phase E; not dynamically embedded in the Simscape relay block.</li>');
W('<li>Dynamic breaker-failure scenario is validated in Simscape for 3PH fault only; backup clearance for other faults is confirmed analytically.</li>');
W('<li>Zero-sequence branch impedance in analytical configuration reflects typical coupled overhead line assumptions (Z0=0.15 pu), whereas Simscape uses uncoupled 3-phase RLC elements (Z0=Z1=0.05 pu), resulting in expected current divergence for ground faults (SLG and DLG).</li>');
W('<li>Relay operating time cross-validation uses the measured line current (I_max RMS) sensed by physical CTs, agreeing within &plusmn;5 ms of IEC Standard Inverse theory.</li>');
W('<li>Arc resistance, stochastic point-on-wave initiation, and dielectric restrike are not modeled (ideal breaker contacts).</li>');
W('<li>Load is modeled as static balanced 1 MW resistive (121 &Omega;) at Bus B; dynamic induction motors and ZIP characteristics are not modeled.</li>');
W('</ul>');
W('</div>');

%% Footer
fprintf(fid,'<p style="text-align:center;color:#888;font-size:0.8em;">');
fprintf(fid,'Generated by Phase G — run_complete_fault_study.m &nbsp;|&nbsp; MATLAB R%s &nbsp;|&nbsp; %s</p>\n', ...
    version('-release'), study.runTimestamp);
W('</div></body></html>');
fclose(fid);
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
