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

        function testFloatingPointCycleCountSweep(testCase)
            f0 = 50;
            T = 1 / f0;
            dt = 1e-4;
            faultTimes = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30];

            % 1. Default case explicitly: fault 0.05, stop 0.15, dt 1e-4
            tDefault = (0:dt:0.15)';
            wDefault = validateMeasurementWindow(tDefault, 0.05, f0);
            testCase.verifyTrue(wDefault.isValid, 'Default case must be valid');
            testCase.verifyEqual(wDefault.numCycles, 4, 'Default case must have exactly 4 full cycles');

            % 2. Sweep across fault times and full cycles
            for ft = faultTimes
                for nc = 1:10
                    stopTime = ft + (1 + nc) * T;
                    tSweep = (0:dt:stopTime)';
                    wSweep = validateMeasurementWindow(tSweep, ft, f0);
                    testCase.verifyTrue(wSweep.isValid, ...
                        sprintf('Window must be valid for faultTime=%.2f, nc=%d', ft, nc));
                    testCase.verifyEqual(wSweep.numCycles, nc, ...
                        sprintf('Cycle count mismatch for faultTime=%.2f, nc=%d', ft, nc));
                end
            end
        end

        function testVerifyFaultClearingSlidingRMS(testCase)
            f0 = 50;
            dt = 1e-4;
            t = (0:dt:0.5)';
            tFault = 0.05;
            openTimeB = 0.10;
            thresh = 0.01;

            % 1. Uncleared 1000 A single-phase sinusoid (phase A active, B and C zero)
            iUncleared = [1000 * sqrt(2) * sin(2*pi*f0*t), zeros(numel(t), 2)];
            cvUncleared = verifyFaultClearing(t, iUncleared, tFault, openTimeB, NaN, thresh);
            testCase.verifyFalse(cvUncleared.faultCleared, ...
                'Uncleared 1000 A single-phase sinusoid must not be detected as cleared');

            % 2. Current that actually goes to zero after breaker opens
            iCleared = iUncleared;
            iCleared(t >= openTimeB + 0.01, :) = 0;
            cvCleared = verifyFaultClearing(t, iCleared, tFault, openTimeB, NaN, thresh);
            testCase.verifyTrue(cvCleared.faultCleared, ...
                'Current that actually goes to zero must be detected as cleared');
            testCase.verifyFalse(isnan(cvCleared.extinctionTime_s));
        end

        function testVerifyFaultClearingWindowStart(testCase)
            f0 = 50;
            dt = 1e-4;
            t = (0:dt:0.5)';
            tFault = 0.05;
            openTimeB = 0.10;
            thresh = 0.01;
            tQuiet = 0.11; % Current goes to zero at 0.11 s

            iSig = [1000 * sqrt(2) * sin(2*pi*f0*t), zeros(numel(t), 2)];
            iSig(t >= tQuiet, :) = 0;
            cv = verifyFaultClearing(t, iSig, tFault, openTimeB, NaN, thresh, f0);

            testCase.verifyTrue(cv.faultCleared);
            testCase.verifyEqual(cv.extinctionTime_s, tQuiet, 'AbsTol', 1e-3, ...
                'extinctionTime_s must be the start of the quiet window where current actually extinguished.');
        end

    end

end

