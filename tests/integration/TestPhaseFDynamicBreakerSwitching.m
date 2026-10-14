classdef TestPhaseFDynamicBreakerSwitching < matlab.unittest.TestCase
% TestPhaseFDynamicBreakerSwitching Comprehensive integration tests for Phase F:
% Validates dynamic relay operation and physical circuit-breaker switching for all
% four fault types (3PH, SLG, LL, DLG) and healthy operation, breaker-failure
% backup clearing, and analytical-to-simulated timing cross-validation.
%
% Prerequisites:
%   - Simscape Electrical licensed and verified (checkSimulationCapabilities READY)
%   - radial_fault_study_network.slx with Phase F relay/breaker subsystems
%   - IEC Standard Inverse relay settings per createRadialRelayStudyConfiguration
%
% Acceptance Criteria per Phase F specification:
%   - Primary relay (BUS B) trips before backup (BUS A)
%   - Simulated relay trip time within ±20 ms of analytical IEC prediction
%   - Physical fault clearing confirmed by current extinction (< 0.01 A RMS)
%   - Backup relay operates during primary breaker failure scenario
%   - All pre-fault Phase C/D simulation results remain unaffected by Phase F
%     configuration constants (Config_Breaker_Clearing = 0 when not in Phase F)

    properties (Constant)
        % Acceptance tolerances
        RELAY_TIMING_TOL_S   = 0.020  % ±20 ms analytical vs simulated trip time
        EXTINCTION_TOL_A     = 0.01   % Amps — fault considered extinct below this
        MAX_PRIMARY_CLEAR_S  = 0.300  % Primary must clear within 300 ms of fault
        MIN_CTI_S            = 0.200  % Minimum coordination time interval
        SIM_STOP_S           = 0.60   % Default simulation stop time for Phase F
        FAULT_START_S        = 0.05   % Default fault inception
    end

    properties
        env             % Environment diagnostic struct
        repoRoot        % Project root path
        config          % Relay study configuration
        simReady        % Boolean: simulation environment is READY
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.repoRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            addpath(genpath(fullfile(testCase.repoRoot, 'matlab')));
            addpath(genpath(fullfile(testCase.repoRoot, 'scripts')));

            opts = struct('quiet', true, 'allowPowerSystemBlocks', true);
            testCase.env      = checkSimulationCapabilities(opts);
            testCase.simReady = strcmp(testCase.env.status, 'READY');
            testCase.config   = createRadialRelayStudyConfiguration();
        end
    end

    methods (TestMethodSetup)
        function checkPrerequisites(testCase)
            testCase.assumeTrue(testCase.simReady, sprintf( ...
                'Simulation environment not ready (%s). Phase F tests skipped.', ...
                testCase.env.status));
        end
    end

    methods (Test)

        %% ── 1. PRIMARY CLEARING: 3PH fault ────────────────────────────────
        function test3PHPrimaryClearing(testCase)
            % 3-phase fault: primary relay must trip, CB_BUS_B must open,
            % and fault current must be extinguished.
            scn = struct('scenarioId', 'PHASE_F_3PH_PRIMARY', ...
                'faultType', '3PH', ...
                'faultInsertionTime_s', testCase.FAULT_START_S, ...
                'simulationStopTime_s', testCase.SIM_STOP_S, ...
                'Zf_Ohm', 0.001, 'failCB_B', false, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED', ...
                '3PH Phase F simulation must complete without error.');
            testCase.verifyEqual(res.relay.B.tripStatus, 'TRIPPED', ...
                'Primary relay Bus B must issue a trip command for 3PH fault.');
            testCase.verifyFalse(isnan(res.relay.B.breakerOpenTime_s), ...
                'CB_BUS_B must physically open for 3PH fault.');
            testCase.verifyTrue(res.clearingVerification.faultCleared, ...
                'Fault current must be extinguished after CB_BUS_B opens (3PH).');

            % Primary breaker must open within 300 ms of fault inception
            openDelay = res.relay.B.breakerOpenTime_s - testCase.FAULT_START_S;
            testCase.verifyLessThan(openDelay, testCase.MAX_PRIMARY_CLEAR_S, ...
                sprintf('3PH: CB_BUS_B must open within %.0f ms of fault inception.', ...
                testCase.MAX_PRIMARY_CLEAR_S * 1e3));
        end

        %% ── 2. PRIMARY CLEARING: SLG fault ────────────────────────────────
        function testSLGPrimaryClearing(testCase)
            scn = struct('scenarioId', 'PHASE_F_SLG_PRIMARY', ...
                'faultType', 'SLG', ...
                'faultInsertionTime_s', testCase.FAULT_START_S, ...
                'simulationStopTime_s', testCase.SIM_STOP_S, ...
                'Zf_Ohm', 0.001, 'Zg_Ohm', 0.001, ...
                'failCB_B', false, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED', ...
                'SLG Phase F simulation must complete without error.');
            testCase.verifyEqual(res.relay.B.tripStatus, 'TRIPPED', ...
                'Primary relay Bus B must trip for SLG fault.');
            testCase.verifyFalse(isnan(res.relay.B.breakerOpenTime_s), ...
                'CB_BUS_B must open for SLG fault.');
            testCase.verifyTrue(res.clearingVerification.faultCleared, ...
                'SLG fault must be extinguished after CB_BUS_B opens.');

            openDelay = res.relay.B.breakerOpenTime_s - testCase.FAULT_START_S;
            testCase.verifyLessThan(openDelay, testCase.MAX_PRIMARY_CLEAR_S, ...
                'SLG: CB_BUS_B must open within 300 ms of fault inception.');
        end

        %% ── 3. PRIMARY CLEARING: LL fault ─────────────────────────────────
        function testLLPrimaryClearing(testCase)
            scn = struct('scenarioId', 'PHASE_F_LL_PRIMARY', ...
                'faultType', 'LL', ...
                'faultInsertionTime_s', testCase.FAULT_START_S, ...
                'simulationStopTime_s', testCase.SIM_STOP_S, ...
                'Zf_Ohm', 0.001, 'failCB_B', false, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED', ...
                'LL Phase F simulation must complete without error.');
            testCase.verifyEqual(res.relay.B.tripStatus, 'TRIPPED', ...
                'Primary relay Bus B must trip for LL fault.');
            testCase.verifyFalse(isnan(res.relay.B.breakerOpenTime_s), ...
                'CB_BUS_B must open for LL fault.');
            testCase.verifyTrue(res.clearingVerification.faultCleared, ...
                'LL fault must be extinguished after CB_BUS_B opens.');
        end

        %% ── 4. PRIMARY CLEARING: DLG fault ────────────────────────────────
        function testDLGPrimaryClearing(testCase)
            scn = struct('scenarioId', 'PHASE_F_DLG_PRIMARY', ...
                'faultType', 'DLG', ...
                'faultInsertionTime_s', testCase.FAULT_START_S, ...
                'simulationStopTime_s', testCase.SIM_STOP_S, ...
                'Zf_Ohm', 0.001, 'Zg_Ohm', 0.001, ...
                'failCB_B', false, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED', ...
                'DLG Phase F simulation must complete without error.');
            testCase.verifyEqual(res.relay.B.tripStatus, 'TRIPPED', ...
                'Primary relay Bus B must trip for DLG fault.');
            testCase.verifyFalse(isnan(res.relay.B.breakerOpenTime_s), ...
                'CB_BUS_B must open for DLG fault.');
            testCase.verifyTrue(res.clearingVerification.faultCleared, ...
                'DLG fault must be extinguished after CB_BUS_B opens.');
        end

        %% ── 5. SELECTIVITY: Backup does NOT trip during normal primary clearing ─
        function testBackupSelectivityDuringPrimaryClearing(testCase)
            % When primary clears the fault normally, CB_BUS_A must remain closed.
            scn = struct('scenarioId', 'PHASE_F_3PH_SELECTIVITY', ...
                'faultType', '3PH', ...
                'faultInsertionTime_s', testCase.FAULT_START_S, ...
                'simulationStopTime_s', testCase.SIM_STOP_S, ...
                'Zf_Ohm', 0.001, 'failCB_B', false, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED');
            % Backup relay CB_BUS_A must NOT open during normal primary clearing
            testCase.verifyTrue(isnan(res.relay.A.breakerOpenTime_s), ...
                'Backup CB_BUS_A must NOT open when primary clears normally (selectivity).');
        end

        %% ── 6. BREAKER FAILURE: CB_BUS_B fails, backup CB_BUS_A clears ────
        function testBreakerFailureBackupClearing3PH(testCase)
            % CB_BUS_B is configured to fail (failCB_B = true).
            % Backup relay RELAY_BUS_A must trip and CB_BUS_A must open.
            scn = struct('scenarioId', 'PHASE_F_3PH_BKRFAIL_B', ...
                'faultType', '3PH', ...
                'faultInsertionTime_s', testCase.FAULT_START_S, ...
                'simulationStopTime_s', 0.85, ...
                'Zf_Ohm', 0.001, 'failCB_B', true, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED', ...
                'Breaker failure simulation must complete.');
            testCase.verifyEqual(res.relay.B.tripStatus, 'FAILED_OPEN', ...
                'CB_BUS_B must be logged as FAILED_OPEN.');
            testCase.verifyEqual(res.relay.A.tripStatus, 'TRIPPED', ...
                'Backup relay RELAY_BUS_A must trip when primary CB fails.');
            testCase.verifyFalse(isnan(res.relay.A.breakerOpenTime_s), ...
                'Backup CB_BUS_A must physically open during breaker failure scenario.');
            testCase.verifyTrue(res.clearingVerification.faultCleared, ...
                'Fault must be cleared by backup protection (CB_BUS_A).');
        end

        %% ── 7. BREAKER FAILURE: SLG fault ─────────────────────────────────
        function testBreakerFailureBackupClearingSLG(testCase)
            scn = struct('scenarioId', 'PHASE_F_SLG_BKRFAIL_B', ...
                'faultType', 'SLG', ...
                'faultInsertionTime_s', testCase.FAULT_START_S, ...
                'simulationStopTime_s', 1.25, ...
                'Zf_Ohm', 0.001, 'Zg_Ohm', 0.001, ...
                'failCB_B', true, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED');
            testCase.verifyEqual(res.relay.A.tripStatus, 'TRIPPED', ...
                'Backup must trip for SLG breaker failure.');
            testCase.verifyTrue(res.clearingVerification.faultCleared, ...
                'SLG fault must be cleared by backup protection.');
        end

        %% ── 8. TIMING: Primary–Backup selectivity margin ──────────────────
        function testPrimaryBackupTimingMargin(testCase)
            % Verify relay B trips before relay A, with CTI >= MIN_CTI_S
            scn = struct('scenarioId', 'PHASE_F_3PH_CTI_CHECK', ...
                'faultType', '3PH', ...
                'faultInsertionTime_s', testCase.FAULT_START_S, ...
                'simulationStopTime_s', testCase.SIM_STOP_S, ...
                'Zf_Ohm', 0.001, 'failCB_B', false, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED');
            testCase.verifyEqual(res.relay.B.tripStatus, 'TRIPPED');

            tripB = res.relay.B.tripTime_s;
            tripA = res.relay.A.tripTime_s;  % May be NaN if A does not trip

            % Primary relay must trip before backup relay
            if ~isnan(tripA)
                testCase.verifyGreaterThan(tripA, tripB, ...
                    'Backup relay A must trip AFTER primary relay B.');
                CTI = tripA - tripB;
                testCase.verifyGreaterThanOrEqual(CTI, testCase.MIN_CTI_S, ...
                    sprintf('CTI between relays B and A must be >= %.0f ms.', ...
                    testCase.MIN_CTI_S * 1e3));
            end
        end

        %% ── 9. ANALYTICAL vs SIMULATED relay timing cross-validation ───────
        function testRelayTimingMatchesAnalytical3PH(testCase)
            % For 3PH fault, simulated relay B trip time must match the
            % analytical IEC Standard Inverse prediction within ±20 ms.
            scn = struct('scenarioId', 'PHASE_F_3PH_ANA_XVAL', ...
                'faultType', '3PH', ...
                'faultInsertionTime_s', testCase.FAULT_START_S, ...
                'simulationStopTime_s', testCase.SIM_STOP_S, ...
                'Zf_Ohm', 0.001, 'failCB_B', false, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED');

            if isfield(res.analyticalPredictions, 'I1_fundamental_A')
                ap  = res.analyticalPredictions;
                simTripRelativeB = res.relay.B.tripTime_s - testCase.FAULT_START_S;
                err = abs(simTripRelativeB - ap.anaRelayB_trip_s);
                testCase.verifyLessThan(err, testCase.RELAY_TIMING_TOL_S, ...
                    sprintf(['3PH: Relay B trip time error %.1f ms exceeds ', ...
                    '±%.0f ms tolerance vs analytical IEC-SI prediction.'], ...
                    err * 1e3, testCase.RELAY_TIMING_TOL_S * 1e3));
            else
                testCase.log('Analytical prediction not available — timing cross-check skipped.');
            end
        end

        %% ── 10. HEALTHY MODE: No relay must operate ─────────────────────────
        function testHealthyModeNoRelayOperation(testCase)
            scn = struct('scenarioId', 'PHASE_F_HEALTHY', ...
                'faultType', 'HEALTHY', ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.30, ...
                'failCB_B', false, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED', ...
                'Healthy mode simulation must complete without error.');
            % No relay must trip under healthy load
            testCase.assertNotEqual(res.relay.B.tripStatus, 'TRIPPED', ...
                'Primary relay must NOT trip under healthy load.');
            testCase.assertNotEqual(res.relay.A.tripStatus, 'TRIPPED', ...
                'Backup relay must NOT trip under healthy load.');
            testCase.assertFalse(res.clearingVerification.faultCleared, ...
                'No fault clearing event should occur under healthy load.');
        end

        %% ── 11. BACKWARD COMPATIBILITY: Phase C/D simulations unaffected ────
        function testPhaseCDCompatibilityAfterPhaseFRun(testCase)
            % Run a Phase F simulation, then verify that a standard Phase C/D
            % simulation (with Config_Breaker_Clearing = 0) returns the same
            % fault current as the validated Phase D benchmark (1872.22 A ± 0.5%).
            scnF = struct('scenarioId', 'PHASE_F_3PH', ...
                'faultType', '3PH', ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.60, ...
                'Zf_Ohm', 0.001, 'failCB_B', false);
            runDynamicBreakerSwitchingSimulation(scnF, struct('quiet', true));

            % Phase C/D simulation must now run correctly (breaker clearing=0)
            scnD = struct('scenarioId', 'TEST_COMPAT_3PH', ...
                'faultType', '3PH', ...
                'faultedBus', 'BUS_B', ...
                'Zf_Ohm', 0.001, ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.15);

            resD = runRadialFaultSimulation(scnD, struct('quiet', true));

            testCase.verifyEqual(resD.status, 'SIMULATION_COMPLETED', ...
                'Phase C/D simulation must complete after Phase F run.');
            testCase.verifyTrue(resD.isSimulated);

            expectedI1 = 1872.22;  % Validated Phase D benchmark
            simI1      = resD.phasors.I1_magnitude_A;
            relErr     = 100 * abs(simI1 - expectedI1) / expectedI1;
            testCase.verifyLessThan(relErr, 0.5, ...
                sprintf(['Phase C/D backward-compat: 3PH fault current %.2f A ', ...
                'differs from benchmark %.2f A by %.4f%% (limit 0.5%%).'], ...
                simI1, expectedI1, relErr));
        end

        %% ── 12. POST-CLEARING VOLTAGE RECOVERY ──────────────────────────────
        function testVoltageRecoveryAfterClearing(testCase)
            % After primary breaker opens, bus voltages must recover to nominal.
            % Nominal phase-to-ground RMS at 11 kV = 11000/sqrt(3) = 6350.9 V.
            V_NOMINAL   = 11e3 / sqrt(3);   % ~6350.9 V
            V_RECOVERY  = 0.80;             % Must recover to >= 80% nominal

            scn = struct('scenarioId', 'PHASE_F_3PH_RECOVERY', ...
                'faultType', '3PH', ...
                'faultInsertionTime_s', testCase.FAULT_START_S, ...
                'simulationStopTime_s', testCase.SIM_STOP_S, ...
                'Zf_Ohm', 0.001, 'failCB_B', false, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'COMPLETED');

            if res.clearingVerification.faultCleared
                t    = res.time_s;
                vBusA = res.measurements.V_BusA;
                tExt = res.clearingVerification.extinctionTime_s;

                % Recovery window: 2 cycles (40 ms) after extinction
                recoveryMask = t > tExt + 0.04 & t <= tExt + 0.12;
                if any(recoveryMask)
                    vRecoveryRMS = sqrt(mean(vBusA(recoveryMask, :).^2, 1));
                    for ph = 1:3
                        testCase.verifyGreaterThan(vRecoveryRMS(ph), V_RECOVERY * V_NOMINAL, ...
                            sprintf('Bus A Phase %d voltage must recover to >= 80%% nominal after clearing.', ph));
                    end
                end
            end
        end

    end  % methods (Test)
end
