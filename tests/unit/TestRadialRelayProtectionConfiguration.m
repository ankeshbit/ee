classdef TestRadialRelayProtectionConfiguration < matlab.unittest.TestCase
% TestRadialRelayProtectionConfiguration Unit tests for Phase E relay configuration,
% IEC curves, pickup boundaries, directional blocking, and protection zone validation.

    properties
        config
        repoRoot
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.repoRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            addpath(genpath(fullfile(testCase.repoRoot, 'matlab')));
            addpath(genpath(fullfile(testCase.repoRoot, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function setupConfig(testCase)
            testCase.config = createRadialRelayStudyConfiguration();
        end
    end

    methods (Test)

        function testConfigurationIntegrity(testCase)
            % Verify relay configuration contains all required fields and valid types
            cfg = testCase.config;
            testCase.verifyNotEmpty(cfg.relays);
            testCase.verifyEqual(numel(cfg.relays), 3);
            testCase.verifyEqual(numel(cfg.breakers), 3);
            testCase.verifyEqual(numel(cfg.coordinationPairs), 2);
            testCase.verifyEqual(numel(cfg.zones), 2);

            for idx = 1:numel(cfg.relays)
                r = cfg.relays(idx);
                testCase.verifyGreaterThan(r.CTprimary_A, 0);
                testCase.verifyGreaterThan(r.CTsecondary_A, 0);
                testCase.verifyGreaterThan(r.pickupCurrent_A, 0);
                testCase.verifyGreaterThan(r.TMS, 0);
                testCase.verifyTrue(ismember(lower(r.curveType), {'standard inverse', 'very inverse', 'extremely inverse'}));
            end
        end

        function testBusAFaultNotAssignedToRelayBusA(testCase)
            % RELAY_BUS_A measures FEEDER_BRB (outgoing from Bus A to Bus B).
            % Bus A faults must not be assigned to RELAY_BUS_A as primary protection.
            cfg = testCase.config;
            zoneT1 = cfg.zones(strcmp({cfg.zones.id}, 'ZONE_TRANSFORMER_T1'));
            testCase.verifyFalse(any(strcmp(zoneT1.applicableFaultedBuses, 'BUS_A')) && ...
                strcmp(zoneT1.primaryRelayId, 'RELAY_BUS_A'), ...
                'Bus A faults must not be assigned to RELAY_BUS_A as primary');
        end

        function testCTRatioConversion(testCase)
            % Test CT ratio conversion consistency
            pri_A = 1872.22;
            % 400/5 A CT
            sec400 = convertPrimaryToSecondaryCurrent(pri_A, 400, 5);
            testCase.verifyEqual(sec400, pri_A * 5 / 400, 'AbsTol', 1e-9);

            % 600/5 A CT
            sec600 = convertPrimaryToSecondaryCurrent(pri_A, 600, 5);
            testCase.verifyEqual(sec600, pri_A * 5 / 600, 'AbsTol', 1e-9);

            % Zero current
            testCase.verifyEqual(convertPrimaryToSecondaryCurrent(0, 400, 5), 0);
        end

        function testIECCurvesAndPickupBoundaries(testCase)
            % Test Standard Inverse, Very Inverse, and Extremely Inverse at known multiples
            % SI: t = TMS * 0.14 / (M^0.02 - 1)
            % At M = 2, TMS = 1: t = 0.14 / (2^0.02 - 1) = 0.14 / 0.013959 = 10.029 s
            t_SI = calculateRelayOperatingTime(2.0, 1.0, 1.0, 'Standard Inverse');
            testCase.verifyEqual(t_SI, 0.14 / (2^0.02 - 1), 'RelTol', 1e-6);

            % VI: t = TMS * 13.5 / (M^1 - 1)
            % At M = 2, TMS = 1: t = 13.5 / (2 - 1) = 13.5 s
            t_VI = calculateRelayOperatingTime(2.0, 1.0, 1.0, 'Very Inverse');
            testCase.verifyEqual(t_VI, 13.5, 'RelTol', 1e-9);

            % EI: t = TMS * 80 / (M^2 - 1)
            % At M = 2, TMS = 1: t = 80 / (4 - 1) = 26.6667 s
            t_EI = calculateRelayOperatingTime(2.0, 1.0, 1.0, 'Extremely Inverse');
            testCase.verifyEqual(t_EI, 80/3, 'RelTol', 1e-9);

            % Boundary test: exactly at pickup (M = 1) -> Inf
            testCase.verifyTrue(isinf(calculateRelayOperatingTime(1.0, 1.0, 0.1, 'SI')));
            % Below pickup (M < 1) -> Inf
            testCase.verifyTrue(isinf(calculateRelayOperatingTime(0.99, 1.0, 0.1, 'SI')));
            % Just above pickup (M = 1.01) -> finite positive
            t_just_above = calculateRelayOperatingTime(1.01, 1.0, 0.1, 'SI');
            testCase.verifyTrue(isfinite(t_just_above) && t_just_above > 0);
        end

        function testSeparateClearingTimeMarginAndCTISign(testCase)
            % Primary relay op time = 0.20 s, Breaker delay = 0.05 s -> Primary clearing = 0.25 s
            % Backup relay op time = 0.60 s, Breaker delay = 0.06 s
            % CTI = t_backup - t_primary = 0.60 - 0.20 = +0.40 s
            % Margin = t_backup - t_primary_clearing = 0.60 - 0.25 = +0.35 s
            t_pri = 0.20;
            t_bku = 0.60;
            delay_pri = 0.05;

            clr_pri = calculateBreakerClearingTime(t_pri, delay_pri);
            testCase.verifyEqual(clr_pri.totalClearingTime_s, 0.25);

            CTI = t_bku - t_pri;
            margin = t_bku - clr_pri.totalClearingTime_s;

            testCase.verifyEqual(CTI, 0.40, 'AbsTol', 1e-12);
            testCase.verifyEqual(margin, 0.35, 'AbsTol', 1e-12);
            testCase.verifyGreaterThan(CTI, margin, 'CTI must strictly exceed clearing-time margin by breaker delay.');
            testCase.verifyEqual(CTI - margin, delay_pri, 'AbsTol', 1e-12);

            % Test reverse/inverted CTI when backup trips faster than primary (miscoordination)
            t_miscoordinated_bku = 0.15;
            CTI_negative = t_miscoordinated_bku - t_pri;
            testCase.verifyTrue(CTI_negative < 0, 'Miscoordinated pair produces negative CTI.');
        end

        function testDirectionalSupervisionStates(testCase)
            % Test forward, reverse, and indeterminate states
            settings = struct('enabled', true, 'characteristicAngle_deg', 45);

            % Forward: angle between I and V matches characteristic forward direction
            I_fwd = 10 * exp(1i * deg2rad(45));
            V_ref = 100 * exp(1i * deg2rad(0));
            resFwd = evaluateDirectionalSupervision(settings, struct( ...
                'currentPhasor', I_fwd, 'polarizingVoltagePhasor', V_ref));
            testCase.verifyEqual(resFwd.status, 'forward');

            % Reverse: 180 degrees opposite
            I_rev = 10 * exp(1i * deg2rad(45 + 180));
            resRev = evaluateDirectionalSupervision(settings, struct( ...
                'currentPhasor', I_rev, 'polarizingVoltagePhasor', V_ref));
            testCase.verifyEqual(resRev.status, 'reverse');

            % Indeterminate: zero polarizing voltage
            resInd = evaluateDirectionalSupervision(settings, struct( ...
                'currentPhasor', I_fwd, 'polarizingVoltagePhasor', 0));
            testCase.verifyEqual(resInd.status, 'indeterminate');

            % Incomplete data: missing polarizing phasor
            resInc = evaluateDirectionalSupervision(settings, struct('currentPhasor', I_fwd));
            testCase.verifyEqual(resInc.status, 'unsupported');
        end

        function testProtectionZoneValidationAndAmbiguity(testCase)
            % Test valid zone configuration passes
            cfg = testCase.config;
            testCase.verifyWarningFree(@() validateProtectionZones( ...
                cfg.zones, cfg.network, cfg.relays, cfg.breakers));

            % Duplicate Zone ID throws error
            badZones = cfg.zones;
            badZones(2).id = badZones(1).id;
            testCase.verifyError(@() validateProtectionZones( ...
                badZones, cfg.network, cfg.relays, cfg.breakers), ...
                'validateProtectionZones:DuplicateZoneId');

            % Unknown protected element throws error
            badElemZones = cfg.zones;
            badElemZones(1).protectedElementId = 'NONEXISTENT_BRANCH';
            testCase.verifyError(@() validateProtectionZones( ...
                badElemZones, cfg.network, cfg.relays, cfg.breakers), ...
                'validateProtectionZones:InvalidElement');

            % Unknown primary relay throws error
            badRelayZones = cfg.zones;
            badRelayZones(1).primaryRelayId = 'UNKNOWN_RELAY';
            testCase.verifyError(@() validateProtectionZones( ...
                badRelayZones, cfg.network, cfg.relays, cfg.breakers), ...
                'validateProtectionZones:InvalidRelayReference');
        end

        function testMissingOrInvalidRelayConfigurationHandling(testCase)
            % checkRelayCoordination throws on missing required struct fields
            faultI = 1000;
            valid = testCase.config.relays(1);
            invalidRelay = rmfield(valid, 'TMS');
            testCase.verifyError( ...
                @() checkRelayCoordination(faultI, invalidRelay, valid, 0.25), ...
                'checkRelayCoordination:MissingRelayField');

            % Negative minimum CTI
            testCase.verifyError( ...
                @() checkRelayCoordination(faultI, valid, valid, -0.1), ...
                'checkRelayCoordination:InvalidMinimumCTI');
        end

    end

end
