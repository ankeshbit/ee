classdef TestAnsiProtectionElements < matlab.unittest.TestCase
% TestAnsiProtectionElements Unit tests for Phase 4:
% Verifies ANSI 50 (Instantaneous Overcurrent), ANSI 50N/51N (Earth-Fault),
% and ANSI 46 (Negative-Sequence Unbalance) protection elements.

    methods (Test)

        %% 1. ANSI 50 Instantaneous Overcurrent Tests
        function testInstantaneousOvercurrentOperates(testCase)
            settings = struct('pickupCurrent_A', 1000.0, 'operatingDelay_s', 0.02);
            res = evaluateInstantaneousOvercurrent(1500.0, settings);

            testCase.verifyTrue(res.operates);
            testCase.verifyEqual(res.tripStatus, 'TRIPPED');
            testCase.verifyEqual(res.operatingTime_s, 0.02);
            testCase.verifyEqual(res.pickupRatio, 1.5);
        end

        function testInstantaneousOvercurrentRestrains(testCase)
            settings = struct('pickupCurrent_A', 1000.0);
            res = evaluateInstantaneousOvercurrent(800.0, settings);

            testCase.verifyFalse(res.operates);
            testCase.verifyEqual(res.tripStatus, 'NO_TRIP');
            testCase.verifyEqual(res.operatingTime_s, Inf);
        end

        function testInstantaneousOvercurrentDisabled(testCase)
            settings = struct('enabled', false, 'pickupCurrent_A', 1000.0);
            res = evaluateInstantaneousOvercurrent(1500.0, settings);
            testCase.verifyFalse(res.operates);
            testCase.verifyEqual(res.tripStatus, 'NO_TRIP');
        end

        %% 2. ANSI 50N / 51N Earth-Fault Overcurrent Tests
        function testEarthFaultBalancedNoTrip(testCase)
            % Balanced 3-phase currents: Ia + Ib + Ic = 0
            Ia = 500 * exp(1j * 0);
            Ib = 500 * exp(-1j * 2*pi/3);
            Ic = 500 * exp(1j * 2*pi/3);

            settings = struct('pickupCurrent_A', 100.0, 'curveType', 'standard inverse', 'TMS', 0.10);
            res = evaluateEarthFaultProtection([Ia, Ib, Ic], settings);

            testCase.verifyFalse(res.operates);
            testCase.verifyEqual(res.tripStatus, 'NO_TRIP');
            testCase.verifyLessThan(res.residualCurrent_A, 1e-6);
        end

        function testEarthFaultInverseTimeTripsOnSLG(testCase)
            % Single phase to ground: Ia = 1000 A, Ib = 0, Ic = 0 -> In = 1000 A
            settings = struct('pickupCurrent_A', 100.0, 'curveType', 'standard inverse', 'TMS', 0.10);
            res = evaluateEarthFaultProtection([1000, 0, 0], settings);

            testCase.verifyTrue(res.operates);
            testCase.verifyEqual(res.tripStatus, 'TRIPPED');
            testCase.verifyEqual(res.operatingElement, '51N_TIME_OVERCURRENT');
            testCase.verifyGreaterThan(res.operatingTime_s, 0);
            testCase.verifyLessThan(res.operatingTime_s, 1.0);
        end

        function testEarthFaultInstantaneous50NTrips(testCase)
            % Heavy ground fault exceeding instPickup_A
            settings = struct('pickupCurrent_A', 100.0, 'instPickup_A', 1000.0, 'TMS', 0.10);
            res = evaluateEarthFaultProtection([2000, 0, 0], settings);

            testCase.verifyTrue(res.operates);
            testCase.verifyEqual(res.operatingElement, '50N_INSTANTANEOUS');
            testCase.verifyEqual(res.operatingTime_s, 0.020);
        end

        %% 3. ANSI 46 Negative-Sequence Overcurrent Tests
        function testNegativeSequenceZeroOnBalancedCurrents(testCase)
            Ia = 500 * exp(1j * 0);
            Ib = 500 * exp(-1j * 2*pi/3);
            Ic = 500 * exp(1j * 2*pi/3);

            settings = struct('pickupCurrent_A', 50.0);
            res = evaluateNegativeSequenceProtection([Ia, Ib, Ic], settings);

            testCase.verifyFalse(res.operates);
            testCase.verifyEqual(res.tripStatus, 'NO_TRIP');
            testCase.verifyLessThan(res.I2_magnitude_A, 1e-4);
            testCase.verifyLessThan(res.unbalanceRatio_pct, 1e-4);
        end

        function testNegativeSequenceTripsOnUnbalancedFault(testCase)
            % Unbalanced LL fault (Phase B and Phase C equal and opposite)
            Ia = 0;
            Ib = -1000;
            Ic = 1000;

            settings = struct('pickupCurrent_A', 100.0, 'mode', 'definite', 'definiteDelay_s', 0.50);
            res = evaluateNegativeSequenceProtection([Ia, Ib, Ic], settings);

            testCase.verifyTrue(res.operates);
            testCase.verifyEqual(res.tripStatus, 'TRIPPED');
            testCase.verifyEqual(res.operatingTime_s, 0.50);
            testCase.verifyGreaterThan(res.I2_magnitude_A, 500.0);
        end

        function testNegativeSequenceThermalCurve(testCase)
            Ia = 0;
            Ib = -1000;
            Ic = 1000;

            settings = struct('pickupCurrent_A', 100.0, 'mode', 'thermal', 'thermalK', 10.0);
            res = evaluateNegativeSequenceProtection([Ia, Ib, Ic], settings);

            testCase.verifyTrue(res.operates);
            testCase.verifyEqual(res.tripStatus, 'TRIPPED');
            testCase.verifyGreaterThan(res.operatingTime_s, 0);
        end

    end

end

