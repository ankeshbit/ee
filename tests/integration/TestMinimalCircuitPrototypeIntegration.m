classdef TestMinimalCircuitPrototypeIntegration < matlab.unittest.TestCase
% TestMinimalCircuitPrototypeIntegration Integration test for minimal Simscape circuit prototype.

    properties
        diagnostic
    end

    methods (TestClassSetup)
        function checkEnvironment(testCase)
            options = struct('quiet', true, 'allowPowerSystemBlocks', true);
            testCase.diagnostic = checkSimulationCapabilities(options);
        end
    end

    methods (Test)

        function testMinimalCircuitSimulationExecution(testCase)
            % Ensure prerequisites are met
            isReady = strcmp(testCase.diagnostic.status, 'READY');
            testCase.assumeTrue(isReady, sprintf( ...
                'Minimal circuit prototype simulation unavailable: status=%s.', ...
                testCase.diagnostic.status));

            % Run minimal circuit prototype
            options = struct('quiet', true, 'stopTime_s', 0.04);
            simResult = runMinimalCircuitPrototype(options);

            % Verify solver completion and result integrity
            testCase.verifyEqual(simResult.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(simResult.isSimulated);
            testCase.verifyNotEmpty(simResult.time_s);
            testCase.verifyGreaterThan(numel(simResult.time_s), 100);
            testCase.verifyEqual(simResult.time_s(end), 0.04, 'AbsTol', 1e-4);

            % Verify time-vector monotonicity
            testCase.verifyTrue(all(diff(simResult.time_s) > 0), 'Time vector must be strictly monotonically increasing.');

            % Verify finite output measurements
            vData = simResult.measurements.V_abc;
            iData = simResult.measurements.I_abc;
            testCase.verifyEqual(size(vData, 2), 3);
            testCase.verifyEqual(size(iData, 2), 3);
            testCase.verifyEqual(size(vData, 1), numel(simResult.time_s));
            testCase.verifyEqual(size(iData, 1), numel(simResult.time_s));
            testCase.verifyTrue(all(isfinite(vData(:))));
            testCase.verifyTrue(all(isfinite(iData(:))));

            % Verify RMS values and analytical agreement
            testCase.verifyTrue(simResult.isValidMeasurementWindow);
            vRms = simResult.rms.V_RMS_phase;
            iRms = simResult.rms.I_RMS_phase;

            % Analytical expectations:
            % V_line = 11,000 V -> V_phase = 11000 / sqrt(3) = 6350.85 V RMS
            % Z_phase = sqrt(10^2 + (2*pi*50*0.01)^2) = 10.4819 Ohm
            % I_phase = 6350.85 / 10.4819 = 605.89 A RMS
            vExpectedRms = 11000 / sqrt(3);
            zExpected = sqrt(10^2 + (2 * pi * 50 * 0.01)^2);
            iExpectedRms = vExpectedRms / zExpected;

            % Verify phase voltages agree with analytical expectation within 0.5%
            for ph = 1:3
                vRelErr = abs(vRms(ph) - vExpectedRms) / vExpectedRms;
                testCase.verifyLessThan(vRelErr, 0.005, sprintf('Phase %d voltage RMS relative error %.4f exceeds 0.5%%.', ph, vRelErr));
            end

            % Verify phase currents agree with analytical expectation within 0.5%
            for ph = 1:3
                iRelErr = abs(iRms(ph) - iExpectedRms) / iExpectedRms;
                testCase.verifyLessThan(iRelErr, 0.005, sprintf('Phase %d current RMS relative error %.4f exceeds 0.5%%.', ph, iRelErr));
            end

            % Verify peak values
            vExpectedPeak = sqrt(2) * vExpectedRms;
            testCase.verifyEqual(simResult.rms.V_peak, vExpectedPeak, 'RelTol', 1e-3);
            testCase.verifyEqual(simResult.rms.I_peak, sqrt(2) * iExpectedRms, 'RelTol', 2e-3);
        end

    end

end
