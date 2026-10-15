classdef TestProtectionIndependentValidation < matlab.unittest.TestCase
    % TestProtectionIndependentValidation Independent recomputations of protection logic.
    %
    % Covers:
    % 1. IEC Standard Inverse curve recomputed independently:
    %    t = TMS * 0.14 / ((I / Is)^0.02 - 1)
    % 2. CTI evaluation with passing and failing cases.
    % 3. Breaker failure backup timing with passing and failing cases.
    % 4. CT saturation screening with passing and failing cases.
    % 5. Directional supervision with passing and failing cases.

    properties
        cfg
    end

    methods (TestMethodSetup)
        function loadConfig(testCase)
            testCase.cfg = getSystemMasterConfiguration();
        end
    end

    methods (Test)

        %% 1. IEC Standard Inverse Independent Recomputation
        function testIECStandardInverseRecomputation(testCase)
            % Test grid of currents and settings
            testCurrents_A = [100, 250, 500, 1000, 2000, 5000];
            testPickups_A  = [1.0, 2.5, 5.0];
            testTMS        = [0.05, 0.10, 0.25, 0.50];

            for I = testCurrents_A
                for Is = testPickups_A
                    for tms = testTMS
                        if I <= Is
                            expected_t = Inf;
                        else
                            % Pure independent formula (IEC 60255-151 standard inverse)
                            M = I / Is;
                            expected_t = tms * 0.14 / (M^0.02 - 1);
                        end

                        actual_t = calculateRelayOperatingTime(I, Is, tms, 'standard inverse');

                        if isinf(expected_t)
                            testCase.verifyTrue(isinf(actual_t));
                        else
                            testCase.verifyEqual(actual_t, expected_t, 'RelTol', 1e-12);
                        end
                    end
                end
            end
        end

        function testScenarioRelayTimingParity(testCase)
            % Compare calculateRelayOperatingTime against independent formulas for Phase F scenarios
            relayB = testCase.cfg.relays(strcmp({testCase.cfg.relays.id}, 'RELAY_BUS_B'));
            CTratio = relayB.CTprimary_A.value / relayB.CTsecondary_A.value; % 400/5 = 80
            Is_sec = relayB.pickupCurrent_A.value; % 1.0 A
            TMS = relayB.TMS.value; % 0.10

            % Scenario currents from validated Phase F runs:
            scenarios = {
                struct('name', 'PF_3PH', 'I_pri', 1886.2, 'simTripRel_s', 0.2125);
                struct('name', 'PF_SLG', 'I_pri', 1947.1, 'simTripRel_s', 0.2114);
                struct('name', 'PF_LL',  'I_pri', 1647.2, 'simTripRel_s', 0.2290);
                struct('name', 'PF_DLG', 'I_pri', 1927.6, 'simTripRel_s', 0.2150)
            };

            for i = 1:numel(scenarios)
                sc = scenarios{i};
                I_sec = sc.I_pri / CTratio;
                M = I_sec / Is_sec;

                % Independent formula calculation:
                t_hand = TMS * 0.14 / (M^0.02 - 1);

                % Code calculation:
                t_calc = calculateRelayOperatingTime(I_sec, Is_sec, TMS, 'standard inverse');

                testCase.verifyEqual(t_calc, t_hand, 'RelTol', 1e-10);

                % Simulated trip time must be within 10 ms (0.010 s) of analytical value:
                testCase.verifyLessThan(abs(sc.simTripRel_s - t_calc), 0.010);
            end
        end

        %% 2. Coordination Time Interval (CTI) Passing and Failing Cases
        function testCTIPassingAndFailingCases(testCase)
            faultCurrent_A = 1886.2; % Primary fault current
            relayB = struct('id', 'RELAY_BUS_B', 'CTprimary_A', 400, 'CTsecondary_A', 5, ...
                'pickupCurrent_A', 1.0, 'TMS', 0.10, 'curveType', 'standard inverse');
            relayA = struct('id', 'RELAY_BUS_A', 'CTprimary_A', 600, 'CTsecondary_A', 5, ...
                'pickupCurrent_A', 1.0, 'TMS', 0.25, 'curveType', 'standard inverse');

            % Case 2A: Passing CTI (configured settings with minCTI = 0.25 s)
            minCTI = 0.25;
            resPass = checkRelayCoordination(faultCurrent_A, relayB, relayA, minCTI);

            testCase.verifyTrue(resPass.isCoordinated);
            testCase.verifyGreaterThan(resPass.coordinationInterval_s, minCTI);
            testCase.verifyEqual(resPass.coordinationInterval_s, ...
                resPass.backupOperatingTime_s - resPass.primaryOperatingTime_s, 'RelTol', 1e-10);

            % Case 2B: Failing CTI (tightened TMS on backup relay so CTI is violated)
            relayA_tight = relayA;
            relayA_tight.TMS = 0.11; % Backup trips too quickly!
            resFail = checkRelayCoordination(faultCurrent_A, relayB, relayA_tight, minCTI);

            testCase.verifyFalse(resFail.isCoordinated);
            testCase.verifyLessThan(resFail.coordinationInterval_s, minCTI);
        end

        %% 3. Breaker Failure Backup Timing Passing and Failing Cases
        function testBreakerFailurePassingAndFailingCases(testCase)
            net = createIllustrativeRadialNetwork();
            scenarios = struct('id', 'SCN_3PH', 'faultedBus', 'BUS_B', ...
                'faultType', '3PH', 'Zf_pu', 0.0);
            relays = [ ...
                struct('id', 'RELAY_BUS_B', 'pickupCurrent_A', 1.0, 'TMS', 0.10, ...
                    'curveType', 'standard inverse', 'CTprimary_A', 400, 'CTsecondary_A', 5, ...
                    'protectedBranch', 'BR_B'), ...
                struct('id', 'RELAY_BUS_A', 'pickupCurrent_A', 1.0, 'TMS', 0.25, ...
                    'curveType', 'standard inverse', 'CTprimary_A', 600, 'CTsecondary_A', 5, ...
                    'protectedBranch', 'BR_A') ...
            ];

            pairs = struct('primaryRelayId', 'RELAY_BUS_B', 'backupRelayId', 'RELAY_BUS_A', ...
                'minimumCTI_s', 0.25);
            studyRes = runIntegratedFaultStudy(net, scenarios, relays, pairs);

            zones = struct('id', 'ZONE_B', 'applicableFaultedBuses', {{'BUS_B'}}, ...
                'primaryRelayId', 'RELAY_BUS_B', 'backupRelayIds', {{'RELAY_BUS_A'}}, ...
                'minimumCTI_s', 0.25);

            breakers = [ ...
                struct('id', 'CB_BUS_B', 'relayId', 'RELAY_BUS_B', 'openingDelay_s', 0.05, ...
                    'canClear', true), ...
                struct('id', 'CB_BUS_A', 'relayId', 'RELAY_BUS_A', 'openingDelay_s', 0.06, ...
                    'canClear', true) ...
            ];

            % Case 3A: Passing Breaker Failure (CB_BUS_B fails, CB_BUS_A clears)
            failScenPass = struct('id', 'CBF_PASS', 'failedBreakerIds', {{'CB_BUS_B'}}, ...
                'disabledRelayIds', {{}});
            resPass = evaluateBreakerFailureScenario(studyRes, zones, relays, breakers, failScenPass);

            testCase.verifyEqual(resPass.overallStatus, 'CLEARED_BY_BACKUP_PROTECTION');
            testCase.verifyFalse(resPass.primaryBreakerClears);
            testCase.verifyTrue(resPass.backupOperates);
            expectedBackupClearing = resPass.backupRelayOperatingTime_s + 0.06;
            testCase.verifyEqual(resPass.backupClearingTime_s, expectedBackupClearing, 'RelTol', 1e-10);

            % Case 3B: Failing Breaker Failure (both primary and backup breakers fail)
            failScenFail = struct('id', 'CBF_FAIL', 'failedBreakerIds', {{'CB_BUS_B', 'CB_BUS_A'}}, ...
                'disabledRelayIds', {{}});
            resFail = evaluateBreakerFailureScenario(studyRes, zones, relays, breakers, failScenFail);


            testCase.verifyEqual(resFail.overallStatus, 'NOT_CLEARED_BY_MODELED_PROTECTION');
            testCase.verifyFalse(resFail.primaryBreakerClears);
            testCase.verifyFalse(resFail.backupOperates);
        end

        %% 4. CT Saturation Screening Passing and Failing Cases
        function testCTSaturationScreeningPassingAndFailing(testCase)
            relay = struct('CTprimary_A', 400, 'CTsecondary_A', 5);
            threshold_A = 100.0; % Max 20x nominal secondary current (20 * 5 = 100 A)

            % Case 4A: Passing case (fault current 4000 A -> 50 A secondary <= 100 A)
            resPass = screenCTSaturation(4000, relay, threshold_A);
            testCase.verifyEqual(resPass.status, 'withinConfiguredLimits');
            testCase.verifyEqual(resPass.secondaryCurrent_A, 50.0, 'AbsTol', 1e-10);

            % Case 4B: Failing case (fault current 10,000 A -> 125 A secondary > 100 A)
            resFail = screenCTSaturation(10000, relay, threshold_A);
            testCase.verifyEqual(resFail.status, 'exceedsConfiguredThreshold');
            testCase.verifyEqual(resFail.secondaryCurrent_A, 125.0, 'AbsTol', 1e-10);
        end

        %% 5. Directional Supervision Passing and Failing Cases
        function testDirectionalSupervisionPassingAndFailing(testCase)
            settings = struct('enabled', true, 'characteristicAngle_deg', 45);

            % Forward fault: V = 1.0 (0 deg), I lags by 60 deg (I = exp(-1i * pi/3))
            % torque = real(I * conj(V) * exp(-1i * 45 deg))
            % torque = cos(-60 - 45 deg) = cos(-105 deg) is negative, so let's choose
            % angle of I = -45 deg:
            % torque = real(exp(-1i*pi/4) * 1.0 * exp(-1i*pi/4)) = real(exp(-1i*pi/2)) = 0 (boundary)
            % Let I lag by 30 deg: angle = -30 deg.
            % torque = cos(-30 - 45 deg) = cos(-75 deg) = +0.2588 > 0 -> FORWARD
            fDataFwd = struct('polarizingVoltagePhasor', 1.0 + 0i, ...
                'currentPhasor', cosd(-30) + 1i*sind(-30));
            resFwd = evaluateDirectionalSupervision(settings, fDataFwd);
            testCase.verifyEqual(resFwd.status, 'forward');

            % Reverse fault: I flow in reverse direction (180 deg shifted)
            % Let I angle = 150 deg:
            % torque = cos(150 - 45 deg) = cos(105 deg) = -0.2588 < 0 -> REVERSE
            fDataRev = struct('polarizingVoltagePhasor', 1.0 + 0i, ...
                'currentPhasor', cosd(150) + 1i*sind(150));
            resRev = evaluateDirectionalSupervision(settings, fDataRev);
            testCase.verifyEqual(resRev.status, 'reverse');
        end

    end
end
