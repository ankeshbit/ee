classdef TestRadialRelayProtectionConfiguration < matlab.unittest.TestCase
% TestRadialRelayProtectionConfiguration Unit tests for Phase E relay configuration,
% IEC curves, pickup boundaries, directional blocking, and protection zone validation.

    properties
        config
        repoRoot
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.repoRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            addpath(genpath(fullfile(testCase.repoRoot, 'matlab')));
            addpath(genpath(fullfile(testCase.repoRoot, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function setupConfig(testCase)
            testCase.config = createRadialRelayStudyConfiguration();
        end
    end

    methods (Test)

        function testConfigurationIntegrity(testCase)
            % Verify relay configuration contains all required fields and valid types
            cfg = testCase.config;
            testCase.verifyNotEmpty(cfg.relays);
            testCase.verifyEqual(numel(cfg.relays), 3);
            testCase.verifyEqual(numel(cfg.breakers), 3);
            testCase.verifyEqual(numel(cfg.coordinationPairs), 2);
            testCase.verifyEqual(numel(cfg.zones), 3);

            for idx = 1:numel(cfg.relays)
                r = cfg.relays(idx);
                testCase.verifyGreaterThan(r.CTprimary_A, 0);
                testCase.verifyGreaterThan(r.CTsecondary_A, 0);
                testCase.verifyGreaterThan(r.pickupCurrent_A, 0);
                testCase.verifyGreaterThan(r.TMS, 0);
                testCase.verifyTrue(ismember(lower(r.curveType), {'standard inverse', 'very inverse', 'extremely inverse'}));
            end
        end

        function testEveryFaultableBusHasActivePrimaryRelayCoveringZone(testCase)
            % SOURCE_33KV is the infinite grid boundary/source bus and excluded.
            % All legitimate faultable buses in the study must have complete zone coverage.
            cfg = testCase.config;
            faultableBuses = {'BUS_11KV', 'BUS_A', 'BUS_B'};
            faultTypes = {'three phase', 'SLG', 'LL', 'DLG'};

            for bi = 1:numel(faultableBuses)
                busId = faultableBuses{bi};
                matchingZones = cfg.zones(cellfun(@(afb) any(strcmp(afb, busId)), ...
                    {cfg.zones.applicableFaultedBuses}));
                testCase.verifyNotEmpty(matchingZones, ...
                    sprintf('Bus %s must be listed in applicableFaultedBuses of at least one zone.', busId));

                for fi = 1:numel(faultTypes)
                    fType = faultTypes{fi};
                    scn = struct('id', sprintf('F_%s_%s', busId, matlab.lang.makeValidName(fType)), ...
                        'faultedBus', busId, 'faultType', fType, 'Zf_pu', 0);
                    res = runIntegratedFaultStudy(cfg.network, scn, cfg.relays, cfg.coordinationPairs);

                    % (i) Check zone coverage
                    testCase.verifyNotEmpty(matchingZones);

                    % (ii) Check primary relay of that zone is on fault path and operates
                    primaryRelayId = matchingZones(1).primaryRelayId;
                    pRelayRes = res.relayResults(strcmp({res.relayResults.relayId}, primaryRelayId));
                    testCase.verifyNotEmpty(pRelayRes, ...
                        sprintf('Primary relay %s result must exist for %s %s', primaryRelayId, busId, fType));
                    testCase.verifyTrue(pRelayRes.isOnFaultPath, ...
                        sprintf('Primary relay %s must be on fault path for %s %s', primaryRelayId, busId, fType));
                    testCase.verifyTrue(pRelayRes.operates, ...
                        sprintf('Primary relay %s must operate for %s %s', primaryRelayId, busId, fType));
                end
            end
        end

        function testCoordinationPairsApplicableFaultedBusesScoping(testCase)
            cfg = testCase.config;
            % For a fault at BUS_A, pairs scoped to BUS_B must report status 'Not applicable to this fault location'
            scnA = struct('id', 'F_BUS_A_3PH', 'faultedBus', 'BUS_A', 'faultType', 'three phase', 'Zf_pu', 0);
            resA = runIntegratedFaultStudy(cfg.network, scnA, cfg.relays, cfg.coordinationPairs);

            pBA = resA.coordinationResults(strcmp({resA.coordinationResults.primaryRelayId}, 'RELAY_BUS_B'));
            testCase.verifyEqual(pBA.coordinationStatus, 'Not applicable to this fault location');

            pA33 = resA.coordinationResults(strcmp({resA.coordinationResults.primaryRelayId}, 'RELAY_BUS_A'));
            testCase.verifyEqual(pA33.coordinationStatus, 'Not applicable to this fault location');
        end

        function testNonApplicablePairExcludedFromCoordinationSummary(testCase)
            cfg = testCase.config;
            % Add a failing pair applicable to BUS_A, alongside a non-applicable pair scoped to BUS_B
            failingPair = cfg.coordinationPairs(1);
            failingPair.pairId = 'PAIR_FAIL';
            failingPair.primaryRelayId = 'RELAY_33KV';
            failingPair.backupRelayId = 'RELAY_33KV';
            failingPair.applicableFaultedBuses = {'BUS_A'};
            failingPair.minimumCTI_s = 0.5; % minimumCTI > 0 with identical relay times will fail
            testPairs = [cfg.coordinationPairs(1), failingPair]; % pair 1 is scoped to BUS_B (non-applicable for BUS_A)

            scnA = struct('id', 'F_A', 'faultedBus', 'BUS_A', 'faultType', 'three phase', 'Zf_pu', 0);
            resA = runIntegratedFaultStudy(cfg.network, scnA, cfg.relays, testPairs);

            pNonApp = resA.coordinationResults(1);
            pFail = resA.coordinationResults(2);

            testCase.verifyFalse(pNonApp.isApplicable);
            testCase.verifyTrue(isnan(pNonApp.isCoordinated));

            testCase.verifyTrue(pFail.isApplicable);
            testCase.verifyFalse(pFail.isCoordinated);

            % Overall coordination across applicable pairs only must be false
            appResults = resA.coordinationResults([resA.coordinationResults.isApplicable]);
            isAllCoordinated = ~isempty(appResults) && all([appResults.isCoordinated] == 1);
            testCase.verifyFalse(isAllCoordinated, 'Overall coordination must be false when an applicable pair fails');
        end

        function testOverallCoordinationStatusOnlyNonApplicable(testCase)
            % (i) only non-applicable pairs -> overall status is explicit 'NOT_APPLICABLE', not 'COORDINATED'
            pairs = [ ...
                struct('pairId', 'P1', 'isApplicable', false, 'isCoordinated', NaN), ...
                struct('pairId', 'P2', 'isApplicable', false, 'isCoordinated', NaN) ...
            ];
            status = computeOverallCoordinationStatus(pairs);
            testCase.verifyEqual(status, 'NOT_APPLICABLE', ...
                'Only non-applicable pairs must produce overall status NOT_APPLICABLE');
        end

        function testOverallCoordinationStatusOneApplicablePassOneNonApplicable(testCase)
            % (ii) one applicable pass + one non-applicable -> COORDINATED
            pairs = [ ...
                struct('pairId', 'P1', 'isApplicable', true,  'isCoordinated', true), ...
                struct('pairId', 'P2', 'isApplicable', false, 'isCoordinated', NaN) ...
            ];
            status = computeOverallCoordinationStatus(pairs);
            testCase.verifyEqual(status, 'COORDINATED', ...
                'One applicable pass + one non-applicable must produce overall status COORDINATED');
        end

        function testCoordinationTableAndCSVExportWithNaN(testCase)
            % (iii) table and CSV export do not error when isCoordinated contains NaN
            pairs = [ ...
                struct('pairId', 'P1', 'isApplicable', true,  'isCoordinated', true,  'CTI_s', 0.4), ...
                struct('pairId', 'P2', 'isApplicable', false, 'isCoordinated', NaN,   'CTI_s', NaN) ...
            ];
            t = struct2table(pairs);
            testCase.verifyTrue(istable(t));
            tmpCsv = [tempname, '.csv'];
            c = onCleanup(@() cleanupFile(tmpCsv));
            writetable(t, tmpCsv);
            testCase.verifyTrue(exist(tmpCsv, 'file') > 0);
            csvText = fileread(tmpCsv);
            testCase.verifyTrue(contains(csvText, 'NaN'));
        end

        function testCTRatioConversion(testCase)
            % Test CT ratio conversion consistency
            pri_A = 1872.22;
            % 400/5 A CT
            sec400 = convertPrimaryToSecondaryCurrent(pri_A, 400, 5);
            testCase.verifyEqual(sec400, pri_A * 5 / 400, 'AbsTol', 1e-9);

            % 600/5 A CT
            sec600 = convertPrimaryToSecondaryCurrent(pri_A, 600, 5);
            testCase.verifyEqual(sec600, pri_A * 5 / 600, 'AbsTol', 1e-9);

            % Zero current
            testCase.verifyEqual(convertPrimaryToSecondaryCurrent(0, 400, 5), 0);
        end

        function testIECCurvesAndPickupBoundaries(testCase)
            % Test Standard Inverse, Very Inverse, and Extremely Inverse at known multiples
            % SI: t = TMS * 0.14 / (M^0.02 - 1)
            % At M = 2, TMS = 1: t = 0.14 / (2^0.02 - 1) = 0.14 / 0.013959 = 10.029 s
            t_SI = calculateRelayOperatingTime(2.0, 1.0, 1.0, 'Standard Inverse');
            testCase.verifyEqual(t_SI, 0.14 / (2^0.02 - 1), 'RelTol', 1e-6);

            % VI: t = TMS * 13.5 / (M^1 - 1)
            % At M = 2, TMS = 1: t = 13.5 / (2 - 1) = 13.5 s
            t_VI = calculateRelayOperatingTime(2.0, 1.0, 1.0, 'Very Inverse');
            testCase.verifyEqual(t_VI, 13.5, 'RelTol', 1e-9);

            % EI: t = TMS * 80 / (M^2 - 1)
            % At M = 2, TMS = 1: t = 80 / (4 - 1) = 26.6667 s
            t_EI = calculateRelayOperatingTime(2.0, 1.0, 1.0, 'Extremely Inverse');
            testCase.verifyEqual(t_EI, 80/3, 'RelTol', 1e-9);

            % Boundary test: exactly at pickup (M = 1) -> Inf
            testCase.verifyTrue(isinf(calculateRelayOperatingTime(1.0, 1.0, 0.1, 'SI')));
            % Below pickup (M < 1) -> Inf
            testCase.verifyTrue(isinf(calculateRelayOperatingTime(0.99, 1.0, 0.1, 'SI')));
            % Just above pickup (M = 1.01) -> finite positive
            t_just_above = calculateRelayOperatingTime(1.01, 1.0, 0.1, 'SI');
            testCase.verifyTrue(isfinite(t_just_above) && t_just_above > 0);
        end

        function testSeparateClearingTimeMarginAndCTISign(testCase)
            % Primary relay op time = 0.20 s, Breaker delay = 0.05 s -> Primary clearing = 0.25 s
            % Backup relay op time = 0.60 s, Breaker delay = 0.06 s
            % CTI = t_backup - t_primary = 0.60 - 0.20 = +0.40 s
            % Margin = t_backup - t_primary_clearing = 0.60 - 0.25 = +0.35 s
            t_pri = 0.20;
            t_bku = 0.60;
            delay_pri = 0.05;

            clr_pri = calculateBreakerClearingTime(t_pri, delay_pri);
            testCase.verifyEqual(clr_pri.totalClearingTime_s, 0.25);

            CTI = t_bku - t_pri;
            margin = t_bku - clr_pri.totalClearingTime_s;

            testCase.verifyEqual(CTI, 0.40, 'AbsTol', 1e-12);
            testCase.verifyEqual(margin, 0.35, 'AbsTol', 1e-12);
            testCase.verifyGreaterThan(CTI, margin, 'CTI must strictly exceed clearing-time margin by breaker delay.');
            testCase.verifyEqual(CTI - margin, delay_pri, 'AbsTol', 1e-12);

            % Test reverse/inverted CTI when backup trips faster than primary (miscoordination)
            t_miscoordinated_bku = 0.15;
            CTI_negative = t_miscoordinated_bku - t_pri;
            testCase.verifyTrue(CTI_negative < 0, 'Miscoordinated pair produces negative CTI.');
        end

        function testDirectionalSupervisionStates(testCase)
            % Test forward, reverse, and indeterminate states
            settings = struct('enabled', true, 'characteristicAngle_deg', 45);

            % Forward: angle between I and V matches characteristic forward direction
            I_fwd = 10 * exp(1i * deg2rad(45));
            V_ref = 100 * exp(1i * deg2rad(0));
            resFwd = evaluateDirectionalSupervision(settings, struct( ...
                'currentPhasor', I_fwd, 'polarizingVoltagePhasor', V_ref));
            testCase.verifyEqual(resFwd.status, 'forward');

            % Reverse: 180 degrees opposite
            I_rev = 10 * exp(1i * deg2rad(45 + 180));
            resRev = evaluateDirectionalSupervision(settings, struct( ...
                'currentPhasor', I_rev, 'polarizingVoltagePhasor', V_ref));
            testCase.verifyEqual(resRev.status, 'reverse');

            % Indeterminate: zero polarizing voltage
            resInd = evaluateDirectionalSupervision(settings, struct( ...
                'currentPhasor', I_fwd, 'polarizingVoltagePhasor', 0));
            testCase.verifyEqual(resInd.status, 'indeterminate');

            % Incomplete data: missing polarizing phasor
            resInc = evaluateDirectionalSupervision(settings, struct('currentPhasor', I_fwd));
            testCase.verifyEqual(resInc.status, 'unsupported');
        end

        function testProtectionZoneValidationAndAmbiguity(testCase)
            % Test valid zone configuration passes
            cfg = testCase.config;
            testCase.verifyWarningFree(@() validateProtectionZones( ...
                cfg.zones, cfg.network, cfg.relays, cfg.breakers));

            % Duplicate Zone ID throws error
            badZones = cfg.zones;
            badZones(2).id = badZones(1).id;
            testCase.verifyError(@() validateProtectionZones( ...
                badZones, cfg.network, cfg.relays, cfg.breakers), ...
                'validateProtectionZones:DuplicateZoneId');

            % Unknown protected element throws error
            badElemZones = cfg.zones;
            badElemZones(1).protectedElementId = 'NONEXISTENT_BRANCH';
            testCase.verifyError(@() validateProtectionZones( ...
                badElemZones, cfg.network, cfg.relays, cfg.breakers), ...
                'validateProtectionZones:InvalidElement');

            % Unknown primary relay throws error
            badRelayZones = cfg.zones;
            badRelayZones(1).primaryRelayId = 'UNKNOWN_RELAY';
            testCase.verifyError(@() validateProtectionZones( ...
                badRelayZones, cfg.network, cfg.relays, cfg.breakers), ...
                'validateProtectionZones:InvalidRelayReference');
        end

        function testMissingOrInvalidRelayConfigurationHandling(testCase)
            % checkRelayCoordination throws on missing required struct fields
            faultI = 1000;
            valid = testCase.config.relays(1);
            invalidRelay = rmfield(valid, 'TMS');
            testCase.verifyError( ...
                @() checkRelayCoordination(faultI, invalidRelay, valid, 0.25), ...
                'checkRelayCoordination:MissingRelayField');

            % Negative minimum CTI
            testCase.verifyError( ...
                @() checkRelayCoordination(faultI, valid, valid, -0.1), ...
                'checkRelayCoordination:InvalidMinimumCTI');
        end

    end

end

function cleanupFile(filePath)
    if exist(filePath, 'file')
        delete(filePath);
    end
end
