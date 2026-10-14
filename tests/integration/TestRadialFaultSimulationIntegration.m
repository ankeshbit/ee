classdef TestRadialFaultSimulationIntegration < matlab.unittest.TestCase
% TestRadialFaultSimulationIntegration End-to-end integration tests for 33/11 kV Simscape fault simulation.

    properties
        diagnostic
    end

    methods (TestClassSetup)
        function checkEnvironment(testCase)
            options = struct('quiet', true, 'allowPowerSystemBlocks', true);
            testCase.diagnostic = checkSimulationCapabilities(options);

            % Ensure scripts and models are on path
            repoRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            scriptsDir = fullfile(repoRoot, 'scripts');
            if exist(scriptsDir, 'dir')
                addpath(scriptsDir);
            end
        end
    end

    methods (Test)

        function testHealthyRadialNetworkSimulation(testCase)
            % Ensure prerequisites are met
            isReady = strcmp(testCase.diagnostic.status, 'READY');
            testCase.assumeTrue(isReady, sprintf( ...
                'Radial fault simulation unavailable: status=%s.', testCase.diagnostic.status));

            scnHealthy = struct( ...
                'scenarioId', 'TEST_HEALTHY', ...
                'faultType', 'HEALTHY', ...
                'faultedBus', 'BUS_B', ...
                'simulationStopTime_s', 0.08);

            simResult = runRadialFaultSimulation(scnHealthy, struct('quiet', true));

            % 1. Result schema and simulation completion
            testCase.verifyEqual(simResult.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(simResult.isSimulated);
            testCase.verifyNotEmpty(simResult.time_s);
            testCase.verifyTrue(all(diff(simResult.time_s) > 0), 'Time vector must be monotonic.');

            % 2. Signal dimensions and finite values
            vBusB = simResult.measurements.V_BusB;
            iBusB = simResult.measurements.I_BusB;
            testCase.verifyEqual(size(vBusB, 2), 3);
            testCase.verifyEqual(size(iBusB, 2), 3);
            testCase.verifyEqual(size(vBusB, 1), numel(simResult.time_s));
            testCase.verifyTrue(all(isfinite(vBusB(:))));
            testCase.verifyTrue(all(isfinite(iBusB(:))));

            % 3. Voltage and current steady-state values
            testCase.verifyTrue(simResult.isValidMeasurementWindow);
            vExpectedRms = 11000 / sqrt(3); % 6350.85 V
            for ph = 1:3
                vRelErr = abs(simResult.rms.V_RMS_phase(ph) - vExpectedRms) / vExpectedRms;
                testCase.verifyLessThan(vRelErr, 0.01, ...
                    sprintf('Phase %d voltage RMS relative error exceeds 1.0%%.', ph));
            end

            % Prefault load current is ~53 A (121 Ohm load at 11 kV)
            for ph = 1:3
                testCase.verifyGreaterThan(simResult.rms.I_RMS_phase(ph), 45.0);
                testCase.verifyLessThan(simResult.rms.I_RMS_phase(ph), 60.0);
            end
        end

        function testThreePhaseFaultSimulationAndAnalyticalAgreement(testCase)
            % Ensure prerequisites are met
            isReady = strcmp(testCase.diagnostic.status, 'READY');
            testCase.assumeTrue(isReady, sprintf( ...
                'Radial fault simulation unavailable: status=%s.', testCase.diagnostic.status));

            scn3PH = struct( ...
                'scenarioId', 'TEST_3PH_BUS_B', ...
                'faultType', '3PH', ...
                'faultedBus', 'BUS_B', ...
                'Zf_Ohm', 0.001, ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.15);

            simResult = runRadialFaultSimulation(scn3PH, struct('quiet', true));

            % 1. Solver completion
            testCase.verifyEqual(simResult.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(simResult.isSimulated);
            testCase.verifyTrue(simResult.isValidMeasurementWindow);

            % 2. Bus B voltage collapses under bolted 3-phase fault
            testCase.verifyLessThan(max(simResult.rms.V_RMS_phase), 20.0, ...
                'Faulted bus voltage must collapse under bolted 3-phase fault.');

            % 3. Bus A voltage is an intermediate voltage divider
            testCase.verifyGreaterThan(min(simResult.rms.V_RMS_BusA), 1000.0);
            testCase.verifyLessThan(max(simResult.rms.V_RMS_BusA), 1300.0);

            % 4. Analytical fault current comparison
            % Sbase = 10 MVA, Vbase = 11 kV -> Ibase = 524.8638 A
            % Ztotal = 0.10 + 0.08 + 0.05 + 0.05 = 0.28 pu
            % If_analytical = 524.8638 / 0.28 = 1874.5136 A
            analyticalIf_A = 10e6 / (sqrt(3) * 11e3 * 0.28);
            simulatedI1_A = simResult.phasors.I1_magnitude_A;

            absError_A = abs(simulatedI1_A - analyticalIf_A);
            relError_pct = 100 * absError_A / analyticalIf_A;

            % Strict tolerance: agreement must be within 0.5%
            testCase.verifyLessThan(relError_pct, 0.5, ...
                sprintf('Relative error %.4f%% exceeds 0.5%% acceptance limit.', relError_pct));

            % 5. Symmetrical fault balance: zero- and negative-sequence currents are near zero
            testCase.verifyLessThan(simResult.phasors.I0_magnitude_A, 1.0, ...
                'Zero-sequence current must be near zero for balanced 3-phase fault.');
            testCase.verifyLessThan(simResult.phasors.I2_magnitude_A, 50.0, ...
                'Negative-sequence current must be minimal for balanced 3-phase fault.');

            % 6. Peak transient current exceeds steady-state RMS due to DC offset
            testCase.verifyGreaterThan(simResult.rms.I_peak, sqrt(2) * simulatedI1_A);
        end

    end

end
