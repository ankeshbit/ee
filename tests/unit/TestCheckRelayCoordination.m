classdef TestCheckRelayCoordination < matlab.unittest.TestCase

    methods (Test)

        function testCoordinatedRelayPair(testCase)
            primary = relay(2.5, 1, 'Very Inverse', 400, 5);
            backup = relay(2.5, 2, 'Very Inverse', 800, 5);

            result = checkRelayCoordination(800, primary, backup, 5);

            testCase.verifyEqual(result.primarySecondaryCurrent_A, 10);
            testCase.verifyEqual(result.backupSecondaryCurrent_A, 5);
            testCase.verifyEqual(result.primaryOperatingTime_s, 4.5, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(result.backupOperatingTime_s, 27, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(result.coordinationInterval_s, 22.5, ...
                'AbsTol', 1e-12);
            testCase.verifyTrue(result.primaryOperates);
            testCase.verifyTrue(result.backupOperates);
            testCase.verifyTrue(result.isCoordinated);
        end

        function testCoordinationIntervalViolation(testCase)
            primary = relay(2.5, 1, 'Very Inverse', 400, 5);
            backup = relay(2.5, 2, 'Very Inverse', 800, 5);

            result = checkRelayCoordination(800, primary, backup, 22.5001);

            testCase.verifyFalse(result.isCoordinated);
            testCase.verifyEqual(result.coordinationInterval_s, 22.5, ...
                'AbsTol', 1e-12);
        end

        function testPrimaryOperatesBackupDoesNot(testCase)
            primary = relay(2.5, 1, 'Very Inverse', 400, 5);
            backup = relay(10, 1, 'Very Inverse', 800, 5);

            result = checkRelayCoordination(800, primary, backup, 0);

            testCase.verifyTrue(result.primaryOperates);
            testCase.verifyFalse(result.backupOperates);
            testCase.verifyEqual(result.coordinationInterval_s, Inf);
            testCase.verifyFalse(result.isCoordinated);
        end

        function testBackupOperatesPrimaryDoesNot(testCase)
            primary = relay(20, 1, 'Very Inverse', 400, 5);
            backup = relay(2.5, 1/3, 'Very Inverse', 800, 5);

            result = checkRelayCoordination(800, primary, backup, 0);

            testCase.verifyFalse(result.primaryOperates);
            testCase.verifyTrue(result.backupOperates);
            testCase.verifyEqual(result.coordinationInterval_s, Inf);
            testCase.verifyFalse(result.isCoordinated);
        end

        function testNeitherRelayOperates(testCase)
            primary = relay(20, 1, 'Very Inverse', 400, 5);
            backup = relay(10, 1, 'Very Inverse', 800, 5);

            result = checkRelayCoordination(800, primary, backup, 0);

            testCase.verifyFalse(result.primaryOperates);
            testCase.verifyFalse(result.backupOperates);
            testCase.verifyEqual(result.coordinationInterval_s, Inf);
            testCase.verifyFalse(result.isCoordinated);
        end

        function testEqualOperatingTimesGiveZeroCTI(testCase)
            primary = relay(2.5, 1, 'Very Inverse', 400, 5);
            backup = relay(2.5, 1/3, 'Very Inverse', 800, 5);

            result = checkRelayCoordination(800, primary, backup, 0);

            testCase.verifyEqual(result.coordinationInterval_s, 0, ...
                'AbsTol', 1e-12);
            testCase.verifyTrue(result.isCoordinated);
        end

        function testZeroMinimumCTI(testCase)
            primary = relay(2.5, 1, 'Very Inverse', 400, 5);
            backup = relay(2.5, 1.1, 'Very Inverse', 800, 5);

            result = checkRelayCoordination(800, primary, backup, 0);

            testCase.verifyTrue(result.isCoordinated);
        end

        function testIndependentCTRatios(testCase)
            primary = relay(1, 1, 'Very Inverse', 400, 5);
            backup = relay(2, 1, 'Very Inverse', 800, 1);

            result = checkRelayCoordination(400, primary, backup, 0);

            testCase.verifyEqual(result.primarySecondaryCurrent_A, 5);
            testCase.verifyEqual(result.backupSecondaryCurrent_A, 0.5);
            testCase.verifyTrue(result.primaryOperates);
            testCase.verifyFalse(result.backupOperates);
        end

        function testInvalidFaultCurrent(testCase)
            primary = relay(1, 1, 'VI', 400, 5);
            backup = primary;
            invalidCurrents = {-1, NaN, Inf, 1 + 1i, [1 2], '100'};

            for inputIndex = 1:numel(invalidCurrents)
                testCase.verifyError( ...
                    @() checkRelayCoordination(invalidCurrents{inputIndex}, ...
                    primary, backup, 0), ...
                    'checkRelayCoordination:InvalidFaultCurrent');
            end
        end

        function testInvalidRelayConfiguration(testCase)
            valid = relay(1, 1, 'VI', 400, 5);

            testCase.verifyError( ...
                @() checkRelayCoordination(400, [], valid, 0), ...
                'checkRelayCoordination:InvalidRelayConfiguration');

            missingField = rmfield(valid, 'TMS');
            testCase.verifyError( ...
                @() checkRelayCoordination(400, missingField, valid, 0), ...
                'checkRelayCoordination:MissingRelayField');
        end

        function testInvalidRelaySettings(testCase)
            valid = relay(1, 1, 'VI', 400, 5);

            invalidRelays = { ...
                setfield(valid, 'CTprimary_A', 0), ... %#ok<SFLD>
                setfield(valid, 'pickupCurrent_A', 0), ... %#ok<SFLD>
                setfield(valid, 'TMS', 0), ... %#ok<SFLD>
                setfield(valid, 'curveType', 'unsupported')}; %#ok<SFLD>

            expectedIdentifiers = { ...
                'convertPrimaryToSecondaryCurrent:InvalidCTRating', ...
                'calculateRelayOperatingTime:InvalidPickupCurrent', ...
                'calculateRelayOperatingTime:InvalidTMS', ...
                'calculateRelayOperatingTime:UnsupportedCurve'};

            for inputIndex = 1:numel(invalidRelays)
                testCase.verifyError( ...
                    @() checkRelayCoordination(400, ...
                    invalidRelays{inputIndex}, valid, 0), ...
                    expectedIdentifiers{inputIndex});
            end
        end

        function testInvalidMinimumCTI(testCase)
            valid = relay(1, 1, 'VI', 400, 5);

            testCase.verifyError( ...
                @() checkRelayCoordination(400, valid, valid, -1), ...
                'checkRelayCoordination:InvalidMinimumCTI');
            testCase.verifyError( ...
                @() checkRelayCoordination(400, valid, valid, NaN), ...
                'checkRelayCoordination:InvalidMinimumCTI');
        end

    end
end

function relayConfiguration = relay(pickupCurrent_A, TMS, curveType, ...
    CTprimary_A, CTsecondary_A)
relayConfiguration = struct( ...
    'pickupCurrent_A', pickupCurrent_A, ...
    'TMS', TMS, ...
    'curveType', curveType, ...
    'CTprimary_A', CTprimary_A, ...
    'CTsecondary_A', CTsecondary_A);
end
