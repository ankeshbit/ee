classdef TestSimulationMeasurementProcessing < matlab.unittest.TestCase
% TestSimulationMeasurementProcessing Unit tests for window validation, RMS, and phasor calculations.

    methods (Test)

        function testValidateMeasurementWindowValid(testCase)
            f0 = 50; % Hz
            dt = 1e-4; % fs = 10000 Hz, 200 samples/cycle
            t = (0:dt:0.25)';
            t_fault = 0.05;

            window = validateMeasurementWindow(t, t_fault, f0);

            testCase.verifyTrue(window.isValid);
            testCase.verifyGreaterThanOrEqual(window.numCycles, 1);
            testCase.verifyEqual(window.nominalFrequency_Hz, 50);
            testCase.verifyEqual(window.period_s, 0.02, 'AbsTol', 1e-6);
            testCase.verifyNotEmpty(window.steadyStateIndices);
            testCase.verifyNotEmpty(window.prefaultIndices);
        end

        function testValidateMeasurementWindowInsufficientSampleRate(testCase)
            f0 = 50;
            dt = 2e-3; % fs = 500 Hz, 10 samples/cycle (< 16 required)
            t = (0:dt:0.25)';

            window = validateMeasurementWindow(t, 0.05, f0);
            testCase.verifyFalse(window.isValid);
            testCase.verifyTrue(contains(window.warningMessage, 'Insufficient sampling rate'));
        end

        function testValidateMeasurementWindowNonMonotonicTime(testCase)
            t = [0; 0.01; 0.005; 0.02; 0.03]; % Non-monotonic
            window = validateMeasurementWindow(t, 0.01, 50);
            testCase.verifyFalse(window.isValid);
            testCase.verifyTrue(contains(window.warningMessage, 'not strictly monotonically increasing'));
        end

        function testValidateMeasurementWindowTooShort(testCase)
            t = (0:1e-4:0.04)'; % Stops before 0.05 s fault
            window = validateMeasurementWindow(t, 0.05, 50);
            testCase.verifyFalse(window.isValid);
        end

        function testExtractSimulationRMSKnownSinusoid(testCase)
            f0 = 50;
            dt = 1e-4;
            t = (0:dt:0.25)';
            t_fault = 0.05;

            window = validateMeasurementWindow(t, t_fault, f0);

            % Synthetic current: prefault 10 A RMS, fault 100 A RMS (peak = 100*sqrt(2))
            prefaultSig = 10 * sqrt(2) * sin(2*pi*f0*t);
            faultSig = 100 * sqrt(2) * sin(2*pi*f0*t);

            sig = prefaultSig;
            sig(t >= t_fault) = faultSig(t >= t_fault);

            rmsResult = extractSimulationRMS(t, sig, window);

            testCase.verifyTrue(rmsResult.isValid);
            testCase.verifyEqual(rmsResult.steadyStateRMS, 100.0, 'RelTol', 0.01);
            testCase.verifyEqual(rmsResult.peakTransient, 100 * sqrt(2), 'RelTol', 0.01);
            testCase.verifyEqual(rmsResult.prefaultRMS, 10.0, 'RelTol', 0.01);
        end

        function testExtractSimulationRMSThreePhase(testCase)
            f0 = 50;
            dt = 1e-4;
            t = (0:dt:0.25)';
            window = validateMeasurementWindow(t, 0.05, f0);

            % 3-phase currents: 50, 100, 150 A RMS
            ia = 50 * sqrt(2) * sin(2*pi*f0*t);
            ib = 100 * sqrt(2) * sin(2*pi*f0*t - 2*pi/3);
            ic = 150 * sqrt(2) * sin(2*pi*f0*t + 2*pi/3);

            threePhaseSig = [ia, ib, ic];

            rmsResult = extractSimulationRMS(t, threePhaseSig, window);
            testCase.verifyTrue(rmsResult.isValid);
            testCase.verifyEqual(rmsResult.steadyStateRMS(1), 50.0, 'RelTol', 0.01);
            testCase.verifyEqual(rmsResult.steadyStateRMS(2), 100.0, 'RelTol', 0.01);
            testCase.verifyEqual(rmsResult.steadyStateRMS(3), 150.0, 'RelTol', 0.01);
        end

        function testEstimateFundamentalPhasorKnownValues(testCase)
            f0 = 50;
            dt = 1e-4;
            t = (0:dt:0.25)';
            window = validateMeasurementWindow(t, 0.05, f0);

            % Cosine reference: Ia = 100*sqrt(2)*cos(wt) -> 100 A RMS at 0 degrees
            % Ib = 100*sqrt(2)*cos(wt - 120 deg) -> 100 A RMS at -120 degrees
            % Ic = 100*sqrt(2)*cos(wt + 120 deg) -> 100 A RMS at +120 degrees
            wt = 2 * pi * f0 * t;
            ia = 100 * sqrt(2) * cos(wt);
            ib = 100 * sqrt(2) * cos(wt - 2*pi/3);
            ic = 100 * sqrt(2) * cos(wt + 2*pi/3);

            phasorResult = estimateFundamentalPhasor(t, [ia, ib, ic], window);

            testCase.verifyTrue(phasorResult.isValid);
            testCase.verifyEqual(phasorResult.magnitudeRMS, [100, 100, 100], 'RelTol', 0.01);
            testCase.verifyEqual(phasorResult.angle_deg(1), 0.0, 'AbsTol', 1.0);
            testCase.verifyEqual(phasorResult.angle_deg(2), -120.0, 'AbsTol', 1.0);
            testCase.verifyEqual(phasorResult.angle_deg(3), 120.0, 'AbsTol', 1.0);

            % Verify sequence decomposition: balanced positive sequence -> I1 = 100, I2 = 0, I0 = 0
            testCase.verifyEqual(abs(phasorResult.sequencePhasors.V1), 100.0, 'RelTol', 0.01);
            testCase.verifyEqual(abs(phasorResult.sequencePhasors.V2), 0.0, 'AbsTol', 1.0);
            testCase.verifyEqual(abs(phasorResult.sequencePhasors.V0), 0.0, 'AbsTol', 1.0);
        end

    end

end
