classdef TestVerifyFaultClearingRegression < matlab.unittest.TestCase
% TestVerifyFaultClearingRegression Regression tests for Bug 2.4:
% Verifies fault clearing, persistence detection, dimension checks, non-monotonic time,
% insufficient data handling, and explicit status categorization (CLEARED, NOT_CLEARED,
% INSUFFICIENT_DATA, INVALID_INPUT).

    methods (Test)

        function testValidFaultClearingAndExtinction(testCase)
            f0 = 50.0;
            dt = 1e-4;
            t = (0:dt:0.35)';
            tFault = 0.05;
            tOpen = 0.15;

            % 3-phase currents: 1000 A fault from 0.05 to 0.15 s, then 0.001 A residual
            nT = numel(t);
            iBus = zeros(nT, 3);
            for ph = 1:3
                phi = (ph - 1) * 2 * pi / 3;
                iBus(:, ph) = 1000 * sqrt(2) * sin(2*pi*f0*t - phi);
                % Clear after tOpen (decay to zero)
                afterOpen = (t >= tOpen + 0.01);
                iBus(afterOpen, ph) = 0.002 * sin(2*pi*f0*t(afterOpen));
            end

            cv = verifyFaultClearing(t, iBus, tFault, tOpen, [], 0.01, f0);
            testCase.verifyTrue(cv.faultCleared);
            testCase.verifyEqual(cv.status, 'CLEARED');
            testCase.verifyNotEmpty(cv.extinctionTime_s);
            testCase.verifyLessThan(cv.postClearingCurrentPeak_A, 0.01);
        end

        function testFaultNotClearedWhenCurrentPersists(testCase)
            f0 = 50.0;
            dt = 1e-4;
            t = (0:dt:0.30)';
            tFault = 0.05;
            tOpen = 0.15;

            % Fault current sustained throughout simulation (breaker fails to clear)
            nT = numel(t);
            iBus = 1000 * sqrt(2) * sin(2*pi*f0*t) * [1, 1, 1];

            cv = verifyFaultClearing(t, iBus, tFault, tOpen, [], 0.01, f0);
            testCase.verifyFalse(cv.faultCleared);
            testCase.verifyEqual(cv.status, 'NOT_CLEARED');
            testCase.verifyTrue(isnan(cv.extinctionTime_s));
        end

        function testInsufficientDataWhenSimulationStopsImmediatelyAfterExtinction(testCase)
            f0 = 50.0;
            dt = 1e-4;
            % Simulation ends at 0.155 s, breaker opens at 0.150 s.
            % Only 5 ms after opening; 1 full cycle (20 ms) of persistence cannot be evaluated.
            t = (0:dt:0.155)';
            tFault = 0.05;
            tOpen = 0.15;

            nT = numel(t);
            iBus = zeros(nT, 3);
            iBus(t < tOpen, :) = 1000.0;

            cv = verifyFaultClearing(t, iBus, tFault, tOpen, [], 0.01, f0);
            testCase.verifyFalse(cv.faultCleared);
            testCase.verifyEqual(cv.status, 'INSUFFICIENT_DATA');
            testCase.verifyTrue(contains(cv.explanation, 'ended before'));
        end

        function testInvalidTimeVectorRejected(testCase)
            % Non-monotonic time
            t = [0; 0.01; 0.005; 0.02; 0.03];
            iBus = ones(5, 3);
            cv = verifyFaultClearing(t, iBus, 0.01, 0.02, [], 0.01, 50);
            testCase.verifyFalse(cv.faultCleared);
            testCase.verifyEqual(cv.status, 'INVALID_INPUT');
        end

        function testDimensionMismatchRejected(testCase)
            t = (0:1e-4:0.10)'; % 1001 samples
            iBus = ones(500, 3); % mismatch!
            cv = verifyFaultClearing(t, iBus, 0.05, 0.08, [], 0.01, 50);
            testCase.verifyFalse(cv.faultCleared);
            testCase.verifyEqual(cv.status, 'INVALID_INPUT');
        end

        function testNonFiniteWaveformRejected(testCase)
            t = (0:1e-4:0.10)';
            iBus = ones(numel(t), 3);
            iBus(50, 1) = NaN;
            cv = verifyFaultClearing(t, iBus, 0.05, 0.08, [], 0.01, 50);
            testCase.verifyFalse(cv.faultCleared);
            testCase.verifyEqual(cv.status, 'INVALID_INPUT');
        end

        function testNaNBreakerOpeningTime(testCase)
            t = (0:1e-4:0.20)';
            iBus = 100 * ones(numel(t), 3);
            % Breaker opening time is NaN (no breaker opened)
            cv = verifyFaultClearing(t, iBus, 0.05, NaN, NaN, 0.01, 50);
            testCase.verifyFalse(cv.faultCleared);
            testCase.verifyEqual(cv.status, 'NOT_CLEARED');
        end

    end

end

