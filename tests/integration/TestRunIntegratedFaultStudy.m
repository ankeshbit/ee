classdef TestRunIntegratedFaultStudy < matlab.unittest.TestCase

    methods (Test)

        function testIllustrativeThreePhaseStudy(testCase)
            network = createIllustrativeRadialNetwork();
            scenarios = scenario('BUS_A', 'three phase', 0);
            relays = relaySet();
            pairs = pair('R_A', 'R_B', 0);

            result = runIntegratedFaultStudy( ...
                network, scenarios, relays, pairs);

            expectedCurrent_pu = 1 / (0.1 + 0.05);
            expectedBaseCurrent_A = 10e6 / (sqrt(3) * 11e3);
            testCase.verifyEqual(result.faultCurrent_pu, expectedCurrent_pu, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(result.faultCurrent_A, ...
                expectedCurrent_pu * expectedBaseCurrent_A, ...
                'AbsTol', 1e-9);
            testCase.verifyEqual( ...
                result.relayResults(1).relayCurrentSecondary_A, ...
                result.faultCurrent_A * 5 / 400, 'AbsTol', 1e-9);
            testCase.verifyTrue(result.relayResults(1).operates);
            testCase.verifyFalse(result.relayResults(2).operates);
            testCase.verifyFalse(result.coordinationResults.isCoordinated);
        end

        function testAllFaultTypes(testCase)
            network = createIllustrativeRadialNetwork();
            scenarios = [ ...
                scenario('BUS_A', 'three phase', 0), ...
                scenario('BUS_A', 'SLG', 0), ...
                scenario('BUS_A', 'LL', 0), ...
                scenario('BUS_A', 'DLG', 0)];
            relays = relaySet();

            results = runIntegratedFaultStudy(network, scenarios, relays, []);

            testCase.verifyNumElements(results, 4);
            for index = 1:numel(results)
                testCase.verifyGreaterThan(abs(results(index).faultCurrent_pu), 0);
                testCase.verifyEqual(numel(results(index).phaseCurrents_pu), 3);
                testCase.verifyEqual(numel(results(index).sequenceCurrents_pu), 3);
            end
        end

        function testMultipleFaultedBusesUseDifferentTheveninImpedance(testCase)
            network = createIllustrativeRadialNetwork();
            scenarios = [ ...
                scenario('BUS_A', 'three phase', 0), ...
                scenario('BUS_B', 'three phase', 0)];

            results = runIntegratedFaultStudy( ...
                network, scenarios, relaySet(), []);

            testCase.verifyGreaterThan( ...
                results(1).faultCurrentMagnitude_A, ...
                results(2).faultCurrentMagnitude_A);
        end

        function testNonzeroFaultImpedanceReducesCurrent(testCase)
            network = createIllustrativeRadialNetwork();
            scenarios = [ ...
                scenario('BUS_A', 'three phase', 0), ...
                scenario('BUS_A', 'three phase', 0.1)];

            results = runIntegratedFaultStudy( ...
                network, scenarios, relaySet(), []);

            testCase.verifyLessThan( ...
                results(2).faultCurrentMagnitude_A, ...
                results(1).faultCurrentMagnitude_A);
        end

        function testBothPathRelaysCoordinateUsingTheirCalculatedTimes(testCase)
            network = createIllustrativeRadialNetwork();
            relays = relaySet();
            scenarios = scenario('BUS_B', 'three phase', 0);
            pairs = pair('R_A', 'R_B', 0);

            result = runIntegratedFaultStudy( ...
                network, scenarios, relays, pairs);

            testCase.verifyTrue(result.relayResults(1).operates);
            testCase.verifyTrue(result.relayResults(2).operates);
            testCase.verifyEqual( ...
                result.coordinationResults.coordinationInterval_s, ...
                result.relayResults(2).operatingTime_s - ...
                result.relayResults(1).operatingTime_s, ...
                'AbsTol', 1e-12);
        end

        function testInvalidNetworkConfiguration(testCase)
            network = createIllustrativeRadialNetwork();
            network.buses(2).id = network.buses(1).id;

            testCase.verifyError( ...
                @() validateRadialNetwork(network), ...
                'validateRadialNetwork:DuplicateBusId');
        end

        function testInvalidBranchEndpoint(testCase)
            network = createIllustrativeRadialNetwork();
            network.branches(1).toBus = 'UNKNOWN';

            testCase.verifyError( ...
                @() validateRadialNetwork(network), ...
                'validateRadialNetwork:InvalidBranchEndpoint');
        end

        function testInconsistentVoltageBase(testCase)
            network = createIllustrativeRadialNetwork();
            network.buses(3).VbaseV = 33e3;

            testCase.verifyError( ...
                @() validateRadialNetwork(network), ...
                'validateRadialNetwork:InconsistentVoltageBase');
        end

        function testInvalidScenario(testCase)
            network = createIllustrativeRadialNetwork();
            invalidScenario = scenario('UNKNOWN', 'three phase', 0);

            testCase.verifyError( ...
                @() runIntegratedFaultStudy( ...
                network, invalidScenario, relaySet(), []), ...
                'runIntegratedFaultStudy:InvalidScenario');
        end

        function testInvalidRelayConfiguration(testCase)
            network = createIllustrativeRadialNetwork();
            invalidRelays = rmfield(relaySet(), 'TMS');
            validScenario = scenario('BUS_A', 'three phase', 0);

            testCase.verifyError( ...
                @() runIntegratedFaultStudy( ...
                network, validScenario, invalidRelays, []), ...
                'runIntegratedFaultStudy:MissingField');
        end

        function testInvalidCoordinationPair(testCase)
            network = createIllustrativeRadialNetwork();
            invalidPair = pair('R_UNKNOWN', 'R_B', 0);

            testCase.verifyError( ...
                @() runIntegratedFaultStudy( ...
                network, scenario('BUS_A', 'three phase', 0), ...
                relaySet(), invalidPair), ...
                'runIntegratedFaultStudy:UnknownRelayInPair');
        end

    end
end

function value = scenario(bus, faultType, Zf_pu)
value = struct('id', [bus '_' faultType], ...
    'faultedBus', bus, 'faultType', faultType, 'Zf_pu', Zf_pu);
end

function values = relaySet()
values = struct( ...
    'id', {'R_A', 'R_B'}, ...
    'protectedBranch', {'BR_A', 'BR_B'}, ...
    'pickupCurrent_A', {5, 2}, ...
    'TMS', {1, 2}, ...
    'curveType', {'Very Inverse', 'Very Inverse'}, ...
    'CTprimary_A', {400, 800}, ...
    'CTsecondary_A', {5, 5});
end

function value = pair(primaryRelayId, backupRelayId, minimumCTI_s)
value = struct('primaryRelayId', primaryRelayId, ...
    'backupRelayId', backupRelayId, 'minimumCTI_s', minimumCTI_s);
end
