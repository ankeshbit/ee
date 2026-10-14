classdef TestRadialRelayProtectionIntegration < matlab.unittest.TestCase
% TestRadialRelayProtectionIntegration Comprehensive integration tests for Phase E:
% Validates relay protection and coordination across all four fault types (3PH, SLG,
% LL, DLG) and healthy operation, verifying CTI, clearing margins, directional blocking,
% and breaker-failure backup clearance on the 33/11 kV radial study network.

    properties
        config
        simResults
        repoRoot
    end

    methods (TestClassSetup)
        function setupData(testCase)
            testCase.repoRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            addpath(genpath(fullfile(testCase.repoRoot, 'matlab')));
            addpath(genpath(fullfile(testCase.repoRoot, 'scripts')));

            testCase.config = createRadialRelayStudyConfiguration();

            % Standard simulated fundamental currents validated in Phase D:
            % 3PH: 1872.22 A, SLG: 655.37 A, LL: 938.13 A, DLG: 1275.83 A, HEALTHY: 53.02 A
            sims = struct();
            sims.F_3PH = struct('isSimulated', true, 'phasors', struct('I1_magnitude_A', 1872.22));
            sims.F_SLG = struct('isSimulated', true, 'phasors', struct('I1_magnitude_A', 655.37));
            sims.F_LL  = struct('isSimulated', true, 'phasors', struct('I1_magnitude_A', 938.13));
            sims.F_DLG = struct('isSimulated', true, 'phasors', struct('I1_magnitude_A', 1275.83));
            sims.F_HEALTHY = struct('isSimulated', true, 'phasors', struct('I1_magnitude_A', 53.02));
            testCase.simResults = sims;
        end
    end

    methods (Test)

        function testAllFaultTypesAndHealthyEvaluation(testCase)
            % Execute evaluation with simulated currents
            study = evaluateRadialProtectionScenarios(testCase.simResults, testCase.config, struct('quiet', true));

            testCase.verifyNotEmpty(study.scenarios);
            testCase.verifyEqual(height(study.relayTable), 15); % 5 scenarios * 3 relays
            testCase.verifyEqual(height(study.coordinationTable), 10); % 5 scenarios * 2 pairs

            % Verify 3PH response
            s3PH = study.scenarios.SCN_3PH;
            rB_3PH = s3PH.relays(strcmp({s3PH.relays.relayId}, 'RELAY_BUS_B'));
            rA_3PH = s3PH.relays(strcmp({s3PH.relays.relayId}, 'RELAY_BUS_A'));
            testCase.verifyEqual(rB_3PH.tripStatus, 'TRIPPED');
            testCase.verifyEqual(rA_3PH.tripStatus, 'TRIPPED');
            testCase.verifyLessThan(rB_3PH.operatingTime_s, 0.25);
            testCase.verifyLessThan(rA_3PH.operatingTime_s, 0.65);
            testCase.verifyGreaterThan(rA_3PH.operatingTime_s, rB_3PH.operatingTime_s);

            % Verify SLG response
            sSLG = study.scenarios.SCN_SLG;
            rB_SLG = sSLG.relays(strcmp({sSLG.relays.relayId}, 'RELAY_BUS_B'));
            rA_SLG = sSLG.relays(strcmp({sSLG.relays.relayId}, 'RELAY_BUS_A'));
            testCase.verifyEqual(rB_SLG.tripStatus, 'TRIPPED');
            testCase.verifyEqual(rA_SLG.tripStatus, 'TRIPPED');
            testCase.verifyLessThan(rB_SLG.operatingTime_s, 0.35);

            % Verify LL response
            sLL = study.scenarios.SCN_LL;
            rB_LL = sLL.relays(strcmp({sLL.relays.relayId}, 'RELAY_BUS_B'));
            rA_LL = sLL.relays(strcmp({sLL.relays.relayId}, 'RELAY_BUS_A'));
            testCase.verifyEqual(rB_LL.tripStatus, 'TRIPPED');
            testCase.verifyEqual(rA_LL.tripStatus, 'TRIPPED');

            % Verify DLG response
            sDLG = study.scenarios.SCN_DLG;
            rB_DLG = sDLG.relays(strcmp({sDLG.relays.relayId}, 'RELAY_BUS_B'));
            rA_DLG = sDLG.relays(strcmp({sDLG.relays.relayId}, 'RELAY_BUS_A'));
            testCase.verifyEqual(rB_DLG.tripStatus, 'TRIPPED');
            testCase.verifyEqual(rA_DLG.tripStatus, 'TRIPPED');
        end

        function testHealthyModeInactivity(testCase)
            % Under healthy load, all relays must remain below pickup (Inf operating time)
            study = evaluateRadialProtectionScenarios(testCase.simResults, testCase.config, struct('quiet', true));
            sHlt = study.scenarios.SCN_HEALTHY;

            for rIdx = 1:numel(sHlt.relays)
                r = sHlt.relays(rIdx);
                testCase.verifyEqual(r.tripStatus, 'BELOW_PICKUP', ...
                    sprintf('%s must not trip under healthy load.', r.relayId));
                testCase.verifyTrue(isinf(r.operatingTime_s));
                testCase.verifyTrue(isinf(r.totalClearingTime_s));
                testCase.verifyLessThan(r.pickupMultiple_M, 1.0);
            end

            % Healthy coordination must show NEITHER_OPERATES
            for pIdx = 1:numel(sHlt.coordination)
                p = sHlt.coordination(pIdx);
                testCase.verifyEqual(p.coordinationStatus, 'NEITHER_OPERATES');
                testCase.verifyFalse(p.isCoordinated);
                testCase.verifyTrue(isinf(p.CTI_s));
                testCase.verifyTrue(isinf(p.clearingTimeMargin_s));
            end
        end

        function testCoordinationIntervalsAndClearingMargins(testCase)
            % For all fault types, CTI >= minCTI and Margin > 0
            study = evaluateRadialProtectionScenarios(testCase.simResults, testCase.config, struct('quiet', true));
            faultNames = {'SCN_3PH', 'SCN_SLG', 'SCN_LL', 'SCN_DLG'};

            for fIdx = 1:numel(faultNames)
                fn = faultNames{fIdx};
                scn = study.scenarios.(fn);

                % Pair 1: Bus B (Primary) and Bus A (Backup)
                pBA = scn.coordination(strcmp({scn.coordination.pairId}, 'PAIR_B_A'));
                testCase.verifyTrue(pBA.isCoordinated, sprintf('%s PAIR_B_A must be coordinated.', fn));
                testCase.verifyGreaterThanOrEqual(pBA.CTI_s, 0.250);
                testCase.verifyGreaterThan(pBA.clearingTimeMargin_s, 0.200);

                % Verify separation: CTI - Margin == primary breaker opening delay (50 ms)
                testCase.verifyEqual(pBA.CTI_s - pBA.clearingTimeMargin_s, 0.050, 'AbsTol', 1e-9);

                % Pair 2: Bus A (Primary) and 33 kV (Backup)
                pA33 = scn.coordination(strcmp({scn.coordination.pairId}, 'PAIR_A_33KV'));
                testCase.verifyTrue(pA33.isCoordinated, sprintf('%s PAIR_A_33KV must be coordinated.', fn));
                testCase.verifyGreaterThanOrEqual(pA33.CTI_s, 0.300);
                testCase.verifyGreaterThan(pA33.clearingTimeMargin_s, 0.200);

                % Verify separation: CTI - Margin == Bus A breaker opening delay (60 ms)
                testCase.verifyEqual(pA33.CTI_s - pA33.clearingTimeMargin_s, 0.060, 'AbsTol', 1e-9);
            end
        end

        function testBreakerFailureBackupClearance(testCase)
            % When primary breaker fails to open, backup relay clears
            study = evaluateRadialProtectionScenarios(testCase.simResults, testCase.config, struct('quiet', true));
            faultNames = {'SCN_3PH', 'SCN_SLG', 'SCN_LL', 'SCN_DLG'};

            for fIdx = 1:numel(faultNames)
                fn = faultNames{fIdx};
                bf = study.scenarios.(fn).breakerFailure;
                testCase.verifyEqual(bf.primaryBreakerState, 'failedToOpen');
                testCase.verifyEqual(bf.overallStatus, 'CLEARED_BY_BACKUP_PROTECTION');
                testCase.verifyTrue(contains(bf.clearingMechanism, 'Backup cleared in'));
                testCase.verifyTrue(isfinite(bf.backupOperatingTime_s));
            end
        end

        function testBreakerFailureWithoutBackup(testCase)
            % When primary breaker fails and backup is unavailable, fault is not cleared
            customCfg = testCase.config;
            % Disable backup relay by setting extremely high pickup
            customCfg.relays(2).pickupCurrent_A = 99999;
            study = evaluateRadialProtectionScenarios(testCase.simResults, customCfg, struct('quiet', true));

            bf = study.scenarios.SCN_3PH.breakerFailure;
            testCase.verifyEqual(bf.overallStatus, 'NOT_CLEARED_BY_MODELED_PROTECTION');
        end

        function testDirectionalSupervisionBlocking(testCase)
            % Test that reverse current blocks relay operation when directional is enabled
            customCfg = testCase.config;
            customCfg.relays(1).directionalSettings.enabled = true;
            customCfg.relays(1).directionalSettings.characteristicAngle_deg = 45;

            % Provide reverse phasor data for RELAY_BUS_B
            opts = struct('quiet', true);
            opts.directionalPhasors.RELAY_BUS_B = struct( ...
                'currentPhasor', 10 * exp(1i * deg2rad(45 + 180)), ... % Reverse
                'polarizingVoltagePhasor', 100);

            study = evaluateRadialProtectionScenarios(testCase.simResults, customCfg, opts);
            rB = study.scenarios.SCN_3PH.relays(strcmp({study.scenarios.SCN_3PH.relays.relayId}, 'RELAY_BUS_B'));

            testCase.verifyEqual(rB.directionalStatus, 'reverse');
            testCase.verifyEqual(rB.tripStatus, 'BLOCKED_DIRECTIONAL');
            testCase.verifyTrue(isinf(rB.operatingTime_s));
        end

        function testCoordinationFailureWithMiscoordinatedTMS(testCase)
            % Deliberately set backup TMS too fast so backup trips before primary (CTI < 0)
            customCfg = testCase.config;
            customCfg.relays(2).TMS = 0.05; % Faster than primary
            study = evaluateRadialProtectionScenarios(testCase.simResults, customCfg, struct('quiet', true));

            pBA = study.scenarios.SCN_3PH.coordination(strcmp({study.scenarios.SCN_3PH.coordination.pairId}, 'PAIR_B_A'));
            testCase.verifyFalse(pBA.isCoordinated);
            testCase.verifyEqual(pBA.coordinationStatus, 'CTI_VIOLATION');
            testCase.verifyLessThan(pBA.CTI_s, customCfg.coordinationPairs(1).minimumCTI_s);
        end

        function testReproducibilityAcrossMultipleRuns(testCase)
            % Ensure consecutive evaluations produce identical numerical outputs
            study1 = evaluateRadialProtectionScenarios(testCase.simResults, testCase.config, struct('quiet', true));
            study2 = evaluateRadialProtectionScenarios(testCase.simResults, testCase.config, struct('quiet', true));

            testCase.verifyEqual(study1.relayTable.operatingTime_s, study2.relayTable.operatingTime_s);
            testCase.verifyEqual(study1.coordinationTable.CTI_s, study2.coordinationTable.CTI_s);
            testCase.verifyEqual(study1.coordinationTable.margin_s, study2.coordinationTable.margin_s);
        end

    end

end
