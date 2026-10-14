classdef TestRadialAllFaultTypesIntegration < matlab.unittest.TestCase
% TestRadialAllFaultTypesIntegration Comprehensive validation suite for Phase D:
% Tests all four power system fault types (3PH, SLG, LL, DLG) and healthy mode
% on the physical 33/11 kV Simscape Electrical radial study network.

    properties
        diagnostic
        repoRoot
        Ibase_A
        Sbase_VA = 10e6
        Vbase_V = 11e3
        Z1_pu = 0.28i
        Z2_pu = 0.28i
        Z0_pu = 0.248i
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            options = struct('quiet', true, 'allowPowerSystemBlocks', true);
            testCase.diagnostic = checkSimulationCapabilities(options);

            testCase.repoRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            addpath(genpath(fullfile(testCase.repoRoot, 'matlab')));
            addpath(genpath(fullfile(testCase.repoRoot, 'scripts')));

            testCase.Ibase_A = testCase.Sbase_VA / (sqrt(3) * testCase.Vbase_V); % 524.8638 A
        end
    end

    methods (TestMethodSetup)
        function checkPrerequisites(testCase)
            isReady = strcmp(testCase.diagnostic.status, 'READY');
            testCase.assumeTrue(isReady, sprintf( ...
                'Simulation environment not ready: status=%s.', testCase.diagnostic.status));
        end
    end

    methods (Test)

        function testHealthyOperation(testCase)
            % Test healthy baseline without an active fault
            scn = struct( ...
                'scenarioId', 'TEST_HEALTHY_STEADY', ...
                'faultType', 'HEALTHY', ...
                'faultedBus', 'BUS_B', ...
                'simulationStopTime_s', 0.08);

            res = runRadialFaultSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(res.isSimulated);
            testCase.verifyNotEmpty(res.time_s);
            testCase.verifyTrue(all(diff(res.time_s) > 0), 'Time vector must be strictly monotonic.');
            testCase.verifyTrue(all(isfinite(res.measurements.V_BusB(:))), 'Bus B voltages must be finite.');
            testCase.verifyTrue(all(isfinite(res.measurements.I_BusB(:))), 'Bus B currents must be finite.');

            % Nominal voltage check (~6351 V RMS line-to-ground)
            vNominal = testCase.Vbase_V / sqrt(3);
            for ph = 1:3
                vErr = abs(res.rms.V_RMS_phase(ph) - vNominal) / vNominal;
                testCase.verifyLessThan(vErr, 0.015, 'Healthy voltage RMS within 1.5% of nominal.');
                testCase.verifyGreaterThan(res.rms.I_RMS_phase(ph), 48.0, 'Healthy load current > 48 A.');
                testCase.verifyLessThan(res.rms.I_RMS_phase(ph), 58.0, 'Healthy load current < 58 A.');
            end

            % Positive sequence current matches ~52.5 A, zero and negative are near zero
            testCase.verifyLessThan(abs(res.phasors.I1_magnitude_A - 52.49), 2.0);
            testCase.verifyLessThan(res.phasors.I0_magnitude_A, 0.5);
            testCase.verifyLessThan(res.phasors.I2_magnitude_A, 0.5);
        end

        function testThreePhaseFault(testCase)
            % Test 3PH bolted fault
            scn = struct( ...
                'scenarioId', 'TEST_3PH_BOLTED', ...
                'faultType', '3PH', ...
                'faultedBus', 'BUS_B', ...
                'Zf_Ohm', 0.001, ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.15);

            res = runRadialFaultSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(res.isSimulated);
            testCase.verifyTrue(res.isValidMeasurementWindow);

            % Voltage collapse across all three phases
            testCase.verifyLessThan(max(res.rms.V_RMS_phase), 20.0, ...
                'All three phase voltages must collapse under 3PH fault.');

            % Intermediate divider at Bus A (~1000 - 1300 V RMS)
            testCase.verifyGreaterThan(min(res.rms.V_RMS_BusA), 1000.0);
            testCase.verifyLessThan(max(res.rms.V_RMS_BusA), 1300.0);

            % Fundamental current comparison
            ana3PH = calculateThreePhaseFault(1.0, testCase.Z1_pu, 0);
            expectedI1 = abs(ana3PH) * testCase.Ibase_A; % 1874.51 A
            simI1 = res.phasors.I1_magnitude_A;

            relErrPct = 100 * abs(simI1 - expectedI1) / expectedI1;
            testCase.verifyLessThan(relErrPct, 0.5, ...
                sprintf('3PH fundamental current relative error %.4f%% exceeds 0.5%%.', relErrPct));

            % Sequence symmetry: I0 and I2 are minimal
            testCase.verifyLessThan(res.phasors.I0_magnitude_A, 1.0);
            testCase.verifyLessThan(res.phasors.I2_magnitude_A, 50.0);

            % Peak current includes transient DC offset
            testCase.verifyGreaterThan(res.rms.I_peak, sqrt(2) * simI1);
        end

        function testSingleLineToGroundFault(testCase)
            % Test SLG (Phase A to Ground) fault
            scn = struct( ...
                'scenarioId', 'TEST_SLG_BOLTED', ...
                'faultType', 'SLG', ...
                'faultedBus', 'BUS_B', ...
                'Zf_Ohm', 0.001, ...
                'Zg_Ohm', 0.001, ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.15);

            res = runRadialFaultSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(res.isSimulated);
            testCase.verifyTrue(res.isValidMeasurementWindow);

            % Physical behavior: Phase A collapses; Phases B and C remain energized
            testCase.verifyLessThan(res.rms.V_RMS_phase(1), 20.0, ...
                'Faulted Phase A voltage must collapse to near zero.');
            testCase.verifyGreaterThan(res.rms.V_RMS_phase(2), 5500.0, ...
                'Unfaulted Phase B must remain energized.');
            testCase.verifyGreaterThan(res.rms.V_RMS_phase(3), 5500.0, ...
                'Unfaulted Phase C must remain energized.');

            % Faulted phase A carries large current; unfaulted phases carry load current
            testCase.verifyGreaterThan(res.rms.I_RMS_phase(1), 1800.0, ...
                'Phase A current must be large fault current (> 1800 A).');
            testCase.verifyLessThan(res.rms.I_RMS_phase(2), 70.0, ...
                'Phase B current must remain near load current (< 70 A).');
            testCase.verifyLessThan(res.rms.I_RMS_phase(3), 70.0, ...
                'Phase C current must remain near load current (< 70 A).');

            % Sequence component characteristics for SLG: I0, I1, I2 are all significant and comparable
            i0 = res.phasors.I0_magnitude_A;
            i1 = res.phasors.I1_magnitude_A;
            i2 = res.phasors.I2_magnitude_A;

            testCase.verifyGreaterThan(i0, 500.0, 'SLG I0 must be large.');
            testCase.verifyGreaterThan(i1, 500.0, 'SLG I1 must be large.');
            testCase.verifyGreaterThan(i2, 500.0, 'SLG I2 must be large.');

            % Relative error against sequence calculation with load superposition
            anaSLG = calculateSLGFault(1.0, testCase.Z1_pu, testCase.Z2_pu, testCase.Z0_pu, 0);
            expectedI1 = abs(anaSLG.I1_pu) * testCase.Ibase_A; % ~650 A
            relErrPct = 100 * abs(i1 - expectedI1) / expectedI1;
            testCase.verifyLessThan(relErrPct, 3.0, ...
                sprintf('SLG fundamental current relative error %.4f%% exceeds 3.0%%.', relErrPct));
        end

        function testLineToLineFault(testCase)
            % Test LL (Phases B to C) fault
            scn = struct( ...
                'scenarioId', 'TEST_LL_BOLTED', ...
                'faultType', 'LL', ...
                'faultedBus', 'BUS_B', ...
                'Zf_Ohm', 0.001, ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.15);

            res = runRadialFaultSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(res.isSimulated);
            testCase.verifyTrue(res.isValidMeasurementWindow);

            % Physical behavior: Unfaulted Phase A carries minimal/load current
            testCase.verifyLessThan(res.rms.I_RMS_phase(1), 70.0, ...
                'Unfaulted Phase A must carry only load current (< 70 A).');
            testCase.verifyGreaterThan(res.rms.I_RMS_phase(2), 1500.0, ...
                'Faulted Phase B current must be large (> 1500 A).');
            testCase.verifyGreaterThan(res.rms.I_RMS_phase(3), 1500.0, ...
                'Faulted Phase C current must be large (> 1500 A).');

            % LL sequence properties: I0 must be zero; I1 and I2 must be equal
            testCase.verifyLessThan(res.phasors.I0_magnitude_A, 1.0, ...
                'Zero-sequence current must be zero for ungrounded LL fault.');
            i1 = res.phasors.I1_magnitude_A;
            i2 = res.phasors.I2_magnitude_A;
            testCase.verifyLessThan(abs(i1 - i2), 20.0, ...
                'Positive- and negative-sequence currents must be approximately equal for LL fault.');

            % Analytical comparison: If = sqrt(3)/2 * If_3PH = 1623.38 A
            anaLL = calculateLLFault(1.0, testCase.Z1_pu, testCase.Z2_pu, 0);
            expectedI1 = abs(anaLL.I1_pu) * testCase.Ibase_A; % 937.26 A
            relErrPct = 100 * abs(i1 - expectedI1) / expectedI1;
            testCase.verifyLessThan(relErrPct, 0.5, ...
                sprintf('LL fundamental current relative error %.4f%% exceeds 0.5%%.', relErrPct));
        end

        function testDoubleLineToGroundFault(testCase)
            % Test DLG (Phases B and C to Ground) fault
            scn = struct( ...
                'scenarioId', 'TEST_DLG_BOLTED', ...
                'faultType', 'DLG', ...
                'faultedBus', 'BUS_B', ...
                'Zf_Ohm', 0.001, ...
                'Zg_Ohm', 0.001, ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.15);

            res = runRadialFaultSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(res.isSimulated);
            testCase.verifyTrue(res.isValidMeasurementWindow);

            % Physical behavior: Unfaulted Phase A carries minimal/load current
            testCase.verifyLessThan(res.rms.I_RMS_phase(1), 70.0, ...
                'Unfaulted Phase A must carry only load current (< 70 A).');
            testCase.verifyGreaterThan(res.rms.I_RMS_phase(2), 1700.0, ...
                'Faulted Phase B current must be large (> 1700 A).');
            testCase.verifyGreaterThan(res.rms.I_RMS_phase(3), 1700.0, ...
                'Faulted Phase C current must be large (> 1700 A).');

            % DLG sequence properties: I0, I1, I2 are all non-zero
            testCase.verifyGreaterThan(res.phasors.I0_magnitude_A, 400.0);
            testCase.verifyGreaterThan(res.phasors.I1_magnitude_A, 1000.0);
            testCase.verifyGreaterThan(res.phasors.I2_magnitude_A, 400.0);

            % Analytical comparison
            anaDLG = calculateDLGFault(1.0, testCase.Z1_pu, testCase.Z2_pu, testCase.Z0_pu, 0);
            expectedI1 = abs(anaDLG.I1_pu) * testCase.Ibase_A; % ~1276 A
            simI1 = res.phasors.I1_magnitude_A;
            relErrPct = 100 * abs(simI1 - expectedI1) / expectedI1;
            testCase.verifyLessThan(relErrPct, 2.5, ...
                sprintf('DLG fundamental current relative error %.4f%% exceeds 2.5%%.', relErrPct));
        end

        function testNonzeroFaultResistance(testCase)
            % Test 3PH fault with nonzero fault resistance (Rf = 2.0 Ohm)
            scn = struct( ...
                'scenarioId', 'TEST_3PH_RESISTIVE', ...
                'faultType', '3PH', ...
                'faultedBus', 'BUS_B', ...
                'Zf_Ohm', 2.0, ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.15);

            res = runRadialFaultSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(res.isSimulated);

            % Fault current with Rf = 2.0 Ohm must be significantly lower than bolted fault
            % Bolted: ~1872 A. With Rf = 2.0 Ohm (pu ~ 2.0 / 12.10 = 0.165 pu):
            % Ztotal = sqrt(0.165^2 + 0.28^2) = 0.325 pu -> If ~ 524.86 / 0.325 ~ 1614 A
            testCase.verifyLessThan(res.phasors.I1_magnitude_A, 1750.0);
            testCase.verifyGreaterThan(res.phasors.I1_magnitude_A, 1400.0);

            % Faulted bus voltage is not zero due to fault resistance drop
            testCase.verifyGreaterThan(min(res.rms.V_RMS_phase), 2000.0);
        end

        function testFaultTimingActivation(testCase)
            % Verify fault is inactive before inception (t < 0.06 s) and active after
            scn = struct( ...
                'scenarioId', 'TEST_TIMING', ...
                'faultType', '3PH', ...
                'faultedBus', 'BUS_B', ...
                'faultInsertionTime_s', 0.06, ...
                'simulationStopTime_s', 0.14);

            res = runRadialFaultSimulation(scn, struct('quiet', true));

            testCase.verifyEqual(res.status, 'SIMULATION_COMPLETED');
            t = res.time_s;
            iB = res.measurements.I_BusB;

            % Prefault window (t = 0.02 to 0.05 s): max current must be healthy load (< 100 A)
            prefaultIdx = (t >= 0.02 & t <= 0.05);
            maxPrefaultI = max(abs(iB(prefaultIdx, :)), [], 'all');
            testCase.verifyLessThan(maxPrefaultI, 100.0, ...
                'Prefault current must be bounded by load current prior to inception.');

            % Fault window (t > 0.07 s): max current must exceed 1000 A
            faultIdx = (t >= 0.07);
            maxFaultI = max(abs(iB(faultIdx, :)), [], 'all');
            testCase.verifyGreaterThan(maxFaultI, 1500.0, ...
                'Fault current must rise above 1500 A following inception.');
        end

        function testInvalidInputHandling(testCase)
            % Invalid fault type must throw explicit error
            testCase.verifyError(@() runRadialFaultSimulation(struct('faultType', 'UNKNOWN_TYPE')), ...
                'runRadialFaultSimulation:UnsupportedFaultType');

            % Invalid faulted bus must throw explicit error
            testCase.verifyError(@() runRadialFaultSimulation(struct('faultedBus', 'BUS_C')), ...
                'runRadialFaultSimulation:UnsupportedBus');

            % Negative fault resistance must throw error
            testCase.verifyError(@() runRadialFaultSimulation(struct('Zf_Ohm', -5.0)), ...
                'MATLAB:runRadialFaultSimulation:expectedNonnegative');

            % Inconsistent timing (stop time <= insertion time)
            testCase.verifyError(@() runRadialFaultSimulation(struct( ...
                'faultType', '3PH', 'faultInsertionTime_s', 0.10, 'simulationStopTime_s', 0.05)), ...
                'runRadialFaultSimulation:InvalidTiming');
        end

        function testRepeatedRunsParameterIsolation(testCase)
            % Ensure no parameter leakage occurs between runs
            scn1 = struct('scenarioId', 'RUN1_HEALTHY', 'faultType', 'HEALTHY', 'simulationStopTime_s', 0.08);
            scn2 = struct('scenarioId', 'RUN2_3PH', 'faultType', '3PH', 'simulationStopTime_s', 0.12);
            scn3 = struct('scenarioId', 'RUN3_HEALTHY', 'faultType', 'HEALTHY', 'simulationStopTime_s', 0.08);

            r1 = runRadialFaultSimulation(scn1, struct('quiet', true));
            r2 = runRadialFaultSimulation(scn2, struct('quiet', true));
            r3 = runRadialFaultSimulation(scn3, struct('quiet', true));

            testCase.verifyEqual(r1.status, 'SIMULATION_COMPLETED');
            testCase.verifyEqual(r2.status, 'SIMULATION_COMPLETED');
            testCase.verifyEqual(r3.status, 'SIMULATION_COMPLETED');

            % Run 1 and Run 3 must produce identical healthy current
            testCase.verifyLessThan(abs(r1.phasors.I1_magnitude_A - r3.phasors.I1_magnitude_A), 0.1, ...
                'Repeated healthy runs must produce identical results without state leakage.');
            testCase.verifyGreaterThan(r2.phasors.I1_magnitude_A, 1800.0, ...
                'Interleaved 3PH fault must simulate correctly.');
        end

    end

end
