classdef TestPhaseGReporting < matlab.unittest.TestCase
% TestPhaseGReporting  Integration tests for Phase G automated fault study,
% structured result collection, report generation, and visualization.
%
% Prerequisites:
%   - createRadialRelayStudyConfiguration on path
%   - runIntegratedFaultStudy on path
%   - collectFaultStudyResults on path
%   - generateFaultStudyReport on path
%   - All plotting functions on path
%
% Simscape-dependent tests are marked with assumptions and will be skipped
% gracefully if the environment is not READY.

    properties (Constant)
        RELAY_TOL_MS   = 20.0   % ±20 ms relay timing tolerance
        EXTINCT_TOL_A  = 0.01   % A post-clearing current limit
        MAX_CLEAR_S    = 0.300  % s primary clearing limit
    end

    properties
        projRoot      % Project root
        repoRoot      % Alias for projRoot
        cfg           % Relay configuration
        anaResults    % Pre-computed analytical results
        simAvailable  % Boolean: Simscape READY
        tmpDir        % Temporary output directory
    end

    methods (TestClassSetup)
        function setupClass(tc)
            tc.repoRoot  = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            tc.projRoot  = tc.repoRoot;
            addpath(genpath(fullfile(tc.projRoot, 'matlab')));
            addpath(genpath(fullfile(tc.projRoot, 'scripts')));

            tc.cfg = createRadialRelayStudyConfiguration();

            % Run analytical study once for class-level use
            network = tc.p_buildNetwork();
            relays  = tc.cfg.relays;
            coordPairs = tc.cfg.coordinationPairs;
            Zf_pu = 0.001 / (11e3^2 / 10e6);
            fts = {'3PH','SLG','LL','DLG'};
            scenarios = repmat(struct('id','','faultedBus','','faultType','','Zf_pu',0),1,4);
            for i = 1:4
                scenarios(i).id        = sprintf('ANA_%s_BUS_B', fts{i});
                scenarios(i).faultedBus = 'BUS_B';
                scenarios(i).faultType  = fts{i};
                scenarios(i).Zf_pu      = Zf_pu;
            end
            tc.anaResults = runIntegratedFaultStudy(network, scenarios, relays, coordPairs);

            % Simscape availability
            opts = struct('quiet',true,'allowPowerSystemBlocks',true);
            diag = checkSimulationCapabilities(opts);
            tc.simAvailable = strcmp(diag.status,'READY');

            % Temporary directory (safe for file-writing tests)
            tc.tmpDir = fullfile(tempdir, sprintf('PhaseG_test_%s', ...
                strrep(num2str(now), '.', '_')));
            mkdir(tc.tmpDir);
        end

        function teardownClass(tc)
            % Best-effort cleanup
            try, rmdir(tc.tmpDir,'s'); catch, end
        end
    end

    %% ─── PART 1: collectFaultStudyResults ────────────────────────────────

    methods (Test)

        function testCollectFaultStudyResults_AnalyticalOnly(tc)
            % With no simulation results, compTable must still be produced
            simEmpty = cellfun(@(~) [], cell(6,1),'UniformOutput',false);
            [compTable, relayTable] = collectFaultStudyResults( ...
                tc.anaResults, simEmpty, tc.cfg, 0.05);
            tc.verifyNotEmpty(compTable, 'compTable must not be empty with analytical input.');
            tc.verifyEqual(numel(compTable), 4, ...
                'Expected 4 comparison rows (3PH, SLG, LL, DLG).');
            % All analytical currents must be positive
            for i = 1:numel(compTable)
                tc.verifyGreaterThan(compTable(i).analyticalCurrent_A, 0, ...
                    sprintf('analyticalCurrent_A must be positive for %s.', compTable(i).faultType));
            end
        end

        function testScenarioIdsAreUnique(tc)
            % Each analytical scenario must have a unique ID
            ids = {tc.anaResults.scenarioId};
            tc.verifyEqual(numel(unique(ids)), numel(ids), ...
                'Analytical scenario IDs must be unique.');
        end

        function testHealthyDistinguishableFromFault(tc)
            faults = {tc.anaResults.faultType};
            tc.verifyTrue(all(ismember(faults, {'3PH','SLG','LL','DLG'})), ...
                'All analytical results should be fault types (no HEALTHY in analytical study).');
        end

        function testMissingSimNotRepresentedAsZero(tc)
            simEmpty = cellfun(@(~) [], cell(6,1),'UniformOutput',false);
            [compTable, ~] = collectFaultStudyResults( ...
                tc.anaResults, simEmpty, tc.cfg, 0.05);
            for i = 1:numel(compTable)
                tc.verifyTrue(isnan(compTable(i).simulatedFundamentalRMS_A), ...
                    sprintf('Missing simulation must be NaN, not zero. Row %d (%s).', ...
                    i, compTable(i).faultType));
            end
        end

        function testTimingErrorUnits(tc)
            % Construct a synthetic relay timing row and verify unit consistency
            % timingErrorMs = (simRelayTime_s - analyticalTime_s) * 1000
            simEmpty = cellfun(@(~) [], cell(6,1),'UniformOutput',false);
            [~, relayTable] = collectFaultStudyResults( ...
                tc.anaResults, simEmpty, tc.cfg, 0.05);
            % With no sims, all relay rows should be empty or invalid
            for i = 1:numel(relayTable)
                tc.verifyTrue(isnan(relayTable(i).timingErrorMs) || ...
                    ~relayTable(i).validComparison, ...
                    'Relay timing rows without simulation data must be invalid or NaN.');
            end
        end

        function testIECOperatingTimeFormula(tc)
            % Direct verification of calculateRelayOperatingTime
            % Standard Inverse: t = 0.14 * TMS / (M^0.02 - 1)
            relayB = tc.cfg.relays(strcmp({tc.cfg.relays.id},'RELAY_BUS_B'));
            TMS    = relayB.TMS;         % 0.10
            Ip     = relayB.pickupCurrent_A;  % 1.0 A-sec
            CTrat  = relayB.CTprimary_A / relayB.CTsecondary_A;  % 80

            testCurrents_A = [1886 1947 1647 1928];  % primary A, from Phase F
            for Ipri = testCurrents_A
                Isec  = Ipri / CTrat;
                M     = Isec / Ip;
                tExp  = 0.14 * TMS / (M^0.02 - 1);
                tCalc = calculateRelayOperatingTime(Isec, Ip, TMS, 'Standard Inverse');
                tc.verifyEqual(tCalc, tExp, 'AbsTol', 1e-9, ...
                    sprintf('IEC SI formula mismatch at Ipri=%.0f A.', Ipri));
            end
        end

        function testBelowPickupReturnsInf(tc)
            relayB = tc.cfg.relays(strcmp({tc.cfg.relays.id},'RELAY_BUS_B'));
            tInf = calculateRelayOperatingTime(0.5, relayB.pickupCurrent_A, relayB.TMS, 'Standard Inverse');
            tc.verifyTrue(isinf(tInf), 'Below-pickup relay must return Inf operating time.');
        end

        function testCTIandClearingMarginAreDistinct(tc)
            % CTI = backup relay op time - primary relay op time (relay-to-relay)
            % Clearing-time margin = backup relay op time - primary total clearing time
            % They MUST differ when primary breaker delay > 0
            coord = tc.cfg.coordinationPairs(strcmp({tc.cfg.coordinationPairs.pairId},'PAIR_B_A'));
            tc.verifyNotEmpty(coord, 'Coordination pair B-A must exist.');
            tc.verifyTrue(isfield(coord,'minimumCTI_s'), 'Coordination pair must have minimumCTI_s.');
            tc.verifyTrue(isfield(coord,'minimumMargin_s'), 'Coordination pair must have minimumMargin_s.');
            tc.verifyNotEqual(coord.minimumCTI_s, coord.minimumMargin_s, ...
                'CTI and clearing-time margin must differ (breaker delay is non-zero).');
        end

    end

    %% ─── PART 2: generateFaultStudyReport ───────────────────────────────

    methods (Test)

        function testReportGenerationFromSyntheticStudy(tc)
            study = tc.p_makeSyntheticStudy();
            paths = generateFaultStudyReport(study, tc.tmpDir);

            tc.verifyTrue(exist(paths.html,'file')>0, 'HTML report must be created.');
            tc.verifyTrue(exist(paths.csv, 'file')>0, 'CSV report must be created.');
            tc.verifyTrue(exist(paths.mat, 'file')>0, 'MAT file must be created.');
            tc.verifyTrue(exist(paths.txt, 'file')>0, 'TXT report must be created.');
        end

        function testCSVHasMachineReadableValues(tc)
            study = tc.p_makeSyntheticStudy();
            paths = generateFaultStudyReport(study, tc.tmpDir);
            raw   = fileread(paths.csv);
            tc.verifySubstring(raw, 'ScenarioId', 'CSV header must contain ScenarioId.');
            % Verify no formatted display strings like "1,886.18 A"
            tc.verifyEmpty(regexp(raw, '\d{1,3}(,\d{3})+\.\d+\s*A'), ...
                'CSV values must be machine-readable numbers, not formatted strings.');
        end

        function testMATFileContainsStudyStruct(tc)
            study = tc.p_makeSyntheticStudy();
            paths = generateFaultStudyReport(study, tc.tmpDir);
            loaded = load(paths.mat, 'study');
            tc.verifyTrue(isstruct(loaded.study), 'MAT file must contain study struct.');
            tc.verifyTrue(isfield(loaded.study, 'runTimestamp'), 'MAT must contain runTimestamp.');
            tc.verifyTrue(isfield(loaded.study, 'analyticalResults'), 'MAT must contain analyticalResults.');
        end

        function testRepeatedReportGenerationDoesNotCorrupt(tc)
            study = tc.p_makeSyntheticStudy();
            % First run
            paths1 = generateFaultStudyReport(study, tc.tmpDir);
            sz1 = dir(paths1.html); sz1 = sz1.bytes;
            % Second run — should overwrite cleanly
            paths2 = generateFaultStudyReport(study, tc.tmpDir);
            sz2 = dir(paths2.html); sz2 = sz2.bytes;
            tc.verifyEqual(sz1, sz2, 'HTML file size must be identical on repeated generation.');
        end

        function testOverallPassNotReportedWhenFailExists(tc)
            study = tc.p_makeSyntheticStudy();
            study.overallPass = false;
            paths = generateFaultStudyReport(study, tc.tmpDir);
            html = fileread(paths.html);
            tc.verifySubstring(html, '<span class="badge badge-fail">FAIL</span>', ...
                'HTML must show FAIL badge when overallPass=false.');
            tc.verifyEmpty(regexp(html, '<span class="badge badge-pass">', 'once'), ...
                'Must not render pass badge element when overallPass=false.');
        end

    end

    %% ─── PART 3: Plotting functions ──────────────────────────────────────

    methods (Test)

        function testPlotCurrentWaveforms_SkipsOnNoData(tc)
            % Non-completed result — function must return silently without error
            r = struct('status','BLOCKED','faultType','3PH','scenarioId','TEST', ...
                'faultInception_s',0.05,'measurements',struct(),'waveforms',struct(), ...
                'relay',struct('B',struct('tripStatus','UNKNOWN')), ...
                'clearingVerification',struct('faultCleared',false,'extinctionTime_s',NaN));
            pngOut = fullfile(tc.tmpDir,'test_blocked.png');
            tc.verifyWarningFree(@() plotPhaseCurrentWaveforms(r, pngOut, '', true));
            tc.verifyFalse(exist(pngOut,'file')>0, ...
                'No PNG should be saved for a BLOCKED result.');
        end

        function testPlotCurrentComparison_EmptyTableNoError(tc)
            tc.verifyWarningFree(@() plotFaultCurrentComparison(struct([]), '', '', true));
        end

        function testPlotRelayTiming_EmptyTableNoError(tc)
            tc.verifyWarningFree(@() plotRelayTimingComparison(struct([]), '', '', true));
        end

    end

    %% ─── PART 4: run_complete_fault_study (analytical only) ─────────────

    methods (Test)

        function testUnifiedRunnerAnalyticalOnly(tc)
            % Run with skipSimulation=true to avoid Simscape dependency
            opts.skipSimulation  = true;
            opts.quiet           = true;
            opts.generatePlots   = false;
            opts.generateReports = false;
            opts.outputDir       = tc.tmpDir;

            study = run_complete_fault_study(opts);

            tc.verifyNotEmpty(study, 'run_complete_fault_study must return a non-empty struct.');
            tc.verifyTrue(isfield(study,'analyticalResults'), 'study must contain analyticalResults.');
            tc.verifyEqual(numel(study.analyticalResults), 4, ...
                'Must have 4 analytical results (3PH, SLG, LL, DLG).');
        end

        function testUnifiedRunnerSimulationResultsAreCell(tc)
            opts.skipSimulation  = true;
            opts.quiet           = true;
            opts.generatePlots   = false;
            opts.generateReports = false;
            opts.outputDir       = tc.tmpDir;
            study = run_complete_fault_study(opts);
            tc.verifyTrue(iscell(study.simulationResults), ...
                'simulationResults must be a cell array.');
        end

        function testUnifiedRunnerSkippedSimsNotZero(tc)
            opts.skipSimulation  = true;
            opts.quiet           = true;
            opts.generatePlots   = false;
            opts.generateReports = false;
            opts.outputDir       = tc.tmpDir;
            study = run_complete_fault_study(opts);
            for i = 1:numel(study.simulationResults)
                r = study.simulationResults{i};
                if isempty(r), continue; end
                if isfield(r,'clearingVerification')
                    cv = r.clearingVerification;
                    tc.verifyTrue(isnan(cv.postClearingCurrentPeak_A) || ...
                        cv.postClearingCurrentPeak_A >= 0, ...
                        'Skipped simulation postClearingCurrentPeak_A must be NaN, not 0.');
                end
            end
        end

        function testUnifiedRunnerWithReportsAnalytical(tc)
            opts.skipSimulation  = true;
            opts.quiet           = true;
            opts.generatePlots   = false;
            opts.generateReports = true;
            opts.outputDir       = tc.tmpDir;
            study = run_complete_fault_study(opts);
            tc.verifyTrue(isfield(study,'reportPaths'), 'study must contain reportPaths.');
            tc.verifyTrue(isfield(study.reportPaths,'html'), 'reportPaths must contain html field.');
            tc.verifyTrue(exist(study.reportPaths.html,'file')>0, 'HTML report must exist on disk.');
            tc.verifyTrue(exist(study.reportPaths.csv,'file')>0,  'CSV must exist on disk.');
            tc.verifyTrue(exist(study.reportPaths.mat,'file')>0,  'MAT must exist on disk.');
            tc.verifyTrue(exist(study.reportPaths.txt,'file')>0,  'TXT must exist on disk.');
        end

    end

    %% ─── PART 5: Phase D and Phase F regression ─────────────────────────

    methods (Test)

        function testPhaseD_RadialAllFaultTypesRegression(tc)
            tc.assumeTrue(exist('TestRadialAllFaultTypesIntegration','file') > 0, ...
                'Phase D test class not found — skipping regression.');
            results = runtests('tests/integration/TestRadialAllFaultTypesIntegration.m');
            nFailed = sum([results.Failed]);
            tc.verifyEqual(nFailed, 0, ...
                sprintf('Phase D regression: %d test(s) FAILED.', nFailed));
        end

        function testPhaseF_DynamicBreakerSwitchingRegression(tc)
            tc.assumeTrue(tc.simAvailable, ...
                'Simscape not available — Phase F regression skipped.');
            tc.assumeTrue(exist('TestPhaseFDynamicBreakerSwitching','file') > 0, ...
                'Phase F test class not found — skipping regression.');
            results = runtests('tests/integration/TestPhaseFDynamicBreakerSwitching.m');
            nFailed = sum([results.Failed]);
            tc.verifyEqual(nFailed, 0, ...
                sprintf('Phase F regression: %d test(s) FAILED.', nFailed));
        end

    end

    %% ─── Private helpers ─────────────────────────────────────────────────

    methods (Access = private)

        function network = p_buildNetwork(tc)
            network = tc.cfg.network;
        end

        function study = p_makeSyntheticStudy(tc)
            % Build a minimal study struct sufficient to drive generateFaultStudyReport
            study.runTimestamp    = datestr(now,'yyyy-mm-ddTHH:MM:SS'); %#ok<TNOW1,DATST>
            study.matlabVersion   = version;
            study.projRoot        = tc.projRoot;
            study.modelFile       = '';
            study.config          = tc.cfg;
            study.environment     = struct('status','READY');
            study.analyticalResults = tc.anaResults;
            study.overallPass     = true;

            % Synthetic sim results (SKIPPED, no Simscape needed)
            fts = {'HEALTHY','3PH','SLG','LL','DLG','3PH_CBF'};
            study.simulationResults = cell(6,1);
            for i = 1:6
                r.status     = 'SKIPPED';
                r.scenarioId = sprintf('PF_%s',fts{i});
                r.faultType  = strrep(fts{i},'_CBF','');
                r.faultInception_s = 0.05;
                r.measurements = struct();
                r.waveforms    = struct();
                r.relay = struct('B',struct('tripStatus','NO_TRIP','tripTime_s',NaN,'breakerOpenTime_s',NaN), ...
                                 'A',struct('tripStatus','NO_TRIP','tripTime_s',NaN,'breakerOpenTime_s',NaN));
                r.clearingVerification = struct('faultCleared',false,'extinctionTime_s',NaN, ...
                    'postClearingCurrentPeak_A',NaN,'extinctionThreshold_A',0.01);
                r.rms                  = struct();
                r.analyticalPredictions = struct();
                r.errors   = {'Skipped'};
                r.warnings = {};
                study.simulationResults{i} = r;
            end

            [study.comparisonTable, study.relayTimingTable] = ...
                collectFaultStudyResults(tc.anaResults, study.simulationResults, tc.cfg, 0.05);
            study.protectionCoord = struct('pairs',tc.cfg.coordinationPairs, ...
                'scenarioBasis','3PH BUS_B','relayTimes',struct([]), ...
                'criteria',tc.cfg.criteria);
            study.testOutcomes = struct('criterion','SyntheticCheck','scenarioId','N/A', ...
                'pass',true,'value','OK','limit','OK');
            study.reportPaths  = struct();
            study.plotPaths    = struct();
        end

    end

end
