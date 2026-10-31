classdef TestMeasurementWindowValidationRegression < matlab.unittest.TestCase
% TestMeasurementWindowValidationRegression Regression tests for Bug 2.2:
% Ensures transient exclusion fallback never silently contaminates steady-state window,
% validates frequencies (50/60 Hz), sampling density, duration bounds, and irregular time.

    methods (Test)

        function testShortDurationMustNotFallbackToTransient(testCase)
            % Fault at 0.05 s, stop at 0.065 s.
            % Skipping 1 cycle at 50 Hz requires 0.05 + 0.02 = 0.07 s.
            % With 0.065 s, skipping the transient is impossible.
            % Bug 2.2 used to fallback to steadyStart_t = 0.05 s and claim valid!
            t = (0:1e-4:0.065)';
            w = validateMeasurementWindow(t, 0.05, 50);
            testCase.verifyFalse(w.isValid, ...
                'Short simulation duration cannot skip transient; window must be marked INVALID.');
            testCase.verifyTrue(contains(w.warningMessage, 'insufficient to skip post-fault transient'));
        end

        function testValidWindowAt50Hz(testCase)
            % Fault at 0.05 s, stop at 0.15 s (spans 5 cycles after fault: 1 transient + 4 steady)
            t = (0:1e-4:0.15)';
            w = validateMeasurementWindow(t, 0.05, 50);
            testCase.verifyTrue(w.isValid);
            testCase.verifyEqual(w.nominalFrequency_Hz, 50);
            testCase.verifyEqual(w.numCycles, 4);
            testCase.verifyEqual(w.t_start_s, 0.07, 'AbsTol', 1e-6);
            testCase.verifyEqual(w.t_end_s, 0.15, 'AbsTol', 1e-6);
        end

        function testValidWindowAt60Hz(testCase)
            % 60 Hz: period = 1/60 = 0.01667 s
            % Fault at 0.05 s, stop at 0.15 s (spans 6 cycles: 1 transient + 5 steady)
            f0 = 60.0;
            T = 1.0 / f0;
            t = (0:1e-4:0.15)';
            w = validateMeasurementWindow(t, 0.05, f0);
            testCase.verifyTrue(w.isValid);
            testCase.verifyEqual(w.nominalFrequency_Hz, 60);
            testCase.verifyEqual(w.t_start_s, 0.05 + T, 'AbsTol', 1e-6);
            testCase.verifyGreaterThanOrEqual(w.numCycles, 4);
        end

        function testFaultNearSimulationEndpoint(testCase)
            % Fault at 0.14 s, simulation ends at 0.15 s (only 0.01 s after fault, less than 1 cycle)
            t = (0:1e-4:0.15)';
            w = validateMeasurementWindow(t, 0.14, 50);
            testCase.verifyFalse(w.isValid);
            testCase.verifyTrue(contains(w.warningMessage, 'insufficient to skip post-fault transient'));
        end

        function testFaultAfterSimulationEndpoint(testCase)
            % Fault at 0.20 s, simulation ends at 0.15 s
            t = (0:1e-4:0.15)';
            w = validateMeasurementWindow(t, 0.20, 50);
            testCase.verifyFalse(w.isValid);
            testCase.verifyTrue(contains(w.warningMessage, 'Simulation stopped'));
        end

        function testInsufficientSamplesPerCycleRejected(testCase)
            % 50 Hz, dt = 2.5 ms -> fs = 400 Hz -> 8 samples/cycle (< 16 required)
            t = (0:2.5e-3:0.25)';
            w = validateMeasurementWindow(t, 0.05, 50);
            testCase.verifyFalse(w.isValid);
            testCase.verifyTrue(contains(w.warningMessage, 'Insufficient sampling rate'));
        end

        function testNonMonotonicTimeVectorRejected(testCase)
            t = [0; 0.01; 0.02; 0.015; 0.03; 0.04; 0.05];
            w = validateMeasurementWindow(t, 0.02, 50);
            testCase.verifyFalse(w.isValid);
            testCase.verifyTrue(contains(w.warningMessage, 'not strictly monotonically increasing'));
        end

        function testNonFiniteTimeVectorRejected(testCase)
            t = [0; 0.01; NaN; 0.03; 0.04];
            w = validateMeasurementWindow(t, 0.01, 50);
            testCase.verifyFalse(w.isValid);
            testCase.verifyTrue(contains(w.warningMessage, 'non-finite'));
        end

        function testInvalidOptionsRejected(testCase)
            t = (0:1e-4:0.25)';
            % Negative minSamplesPerCycle
            w = validateMeasurementWindow(t, 0.05, 50, struct('minSamplesPerCycle', -5));
            testCase.verifyFalse(w.isValid);

            % Negative frequency
            w2 = validateMeasurementWindow(t, 0.05, -50);
            testCase.verifyFalse(w2.isValid);
        end

        function testCustomTransientCyclesOption(testCase)
            % Skip 2 transient cycles instead of 1: 0.05 + 2*0.02 = 0.09 s
            t = (0:1e-4:0.20)';
            opts = struct('cyclesToSkipTransient', 2.0, 'minCyclesForWindow', 2.0);
            w = validateMeasurementWindow(t, 0.05, 50, opts);
            testCase.verifyTrue(w.isValid);
            testCase.verifyEqual(w.t_start_s, 0.09, 'AbsTol', 1e-6);
            testCase.verifyEqual(w.numCycles, 5); % (0.20 - 0.09)/0.02 = 5.5 -> 5 full cycles
        end

    end

end

