classdef TestBranchedRadialFaultStudy < matlab.unittest.TestCase

    methods (Test)

        function testBranchedNetworkValidates(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            testCase.verifyWarningFree(@() validateRadialNetwork(network));
        end

        function testFaultDownstreamOfOneBranchDoesNotEnergizeSibling(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            relays = relaySet();
            scenario = struct('id', 'fault_b', 'faultedBus', 'BUS_B', ...
                'faultType', 'three phase', 'Zf_pu', 0);

            result = runIntegratedFaultStudy(network, scenario, relays, []);
            branchB = result.relayResults(strcmp( ...
                {result.relayResults.relayId}, 'R_B'));
            branchC = result.relayResults(strcmp( ...
                {result.relayResults.relayId}, 'R_C'));

            testCase.verifyTrue(branchB.isOnFaultPath);
            testCase.verifyGreaterThan(branchB.faultCurrentPrimary_A, 0);
            testCase.verifyFalse(branchC.isOnFaultPath);
            testCase.verifyEqual(branchC.faultCurrentPrimary_A, 0);
        end

        function testTransformerSideRelaysUseDifferentCurrentBases(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            relays = relaySet();
            scenario = struct('id', 'fault_b', 'faultedBus', 'BUS_B', ...
                'faultType', 'three phase', 'Zf_pu', 0);

            result = runIntegratedFaultStudy(network, scenario, relays, []);
            high = result.relayResults(strcmp( ...
                {result.relayResults.relayId}, 'R_HV'));
            low = result.relayResults(strcmp( ...
                {result.relayResults.relayId}, 'R_LV'));
            fault_pu = result.faultCurrent_pu;

            testCase.verifyEqual(high.faultCurrentPrimary_A, ...
                fault_pu * 10e6/(sqrt(3)*33e3), 'AbsTol', 1e-9);
            testCase.verifyEqual(low.faultCurrentPrimary_A, ...
                fault_pu * 10e6/(sqrt(3)*11e3), 'AbsTol', 1e-9);
            testCase.verifyNotEqual(high.faultCurrentPrimary_A, ...
                low.faultCurrentPrimary_A);
        end

        function testFaultUpstreamOfSplitUsesCommonUpstreamPath(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            relays = relaySet();
            scenario = struct('id', 'fault_a', 'faultedBus', 'BUS_A', ...
                'faultType', 'three phase', 'Zf_pu', 0);

            result = runIntegratedFaultStudy(network, scenario, relays, []);
            branchB = result.relayResults(strcmp( ...
                {result.relayResults.relayId}, 'R_B'));
            branchC = result.relayResults(strcmp( ...
                {result.relayResults.relayId}, 'R_C'));
            branch1 = result.relayResults(strcmp( ...
                {result.relayResults.relayId}, 'R_1'));

            testCase.verifyTrue(branch1.isOnFaultPath);
            testCase.verifyFalse(branchB.isOnFaultPath);
            testCase.verifyFalse(branchC.isOnFaultPath);
        end

        function testInvalidDisconnectedNetwork(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            network.buses(end + 1) = struct('id', 'ISOLATED', 'VbaseV', 11e3);

            testCase.verifyError(@() validateRadialNetwork(network), ...
                'validateRadialNetwork:DisconnectedNetwork');
        end

        function testInvalidCycleIsRejected(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            network.branches(3).toBus = 'BUS_11KV';

            testCase.verifyError(@() validateRadialNetwork(network), ...
                'validateRadialNetwork:NonRadialTopology');
        end

        function testInvalidExplicitRelayLocation(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            relays = relaySet();
            relays(1).measurementElementId = 'UNKNOWN';
            scenario = struct('id', 'fault_b', 'faultedBus', 'BUS_B', ...
                'faultType', 'three phase', 'Zf_pu', 0);

            testCase.verifyError( ...
                @() runIntegratedFaultStudy(network, scenario, relays, []), ...
                'runIntegratedFaultStudy:InvalidRelayLocation');
        end

        function testCoordinationUsesRelaySpecificCurrents(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            relays = relaySet();
            scenario = struct('id', 'fault_b', 'faultedBus', 'BUS_B', ...
                'faultType', 'three phase', 'Zf_pu', 0);
            pair = struct('primaryRelayId', 'R_B', ...
                'backupRelayId', 'R_1', 'minimumCTI_s', 0);

            result = runIntegratedFaultStudy(network, scenario, relays, pair);
            testCase.verifyEqual( ...
                result.coordinationResults.primaryOperatingTime_s, ...
                result.relayResults( ...
                strcmp({result.relayResults.relayId}, 'R_B')).operatingTime_s, ...
                'AbsTol', 1e-12);
            testCase.verifyTrue(result.coordinationResults.isCoordinated);
        end
    end
end

function values = relaySet()
values = struct( ...
    'id', {'R_HV', 'R_LV', 'R_1', 'R_B', 'R_C'}, ...
    'measurementElementType', ...
    {'transformer', 'transformer', 'branch', 'branch', 'branch'}, ...
    'measurementElementId', {'T1', 'T1', 'BR_1', 'BR_2', 'BR_3'}, ...
    'measurementSide', {'high', 'low', 'from', 'from', 'from'}, ...
    'pickupCurrent_A', {2, 2, 2, 2, 2}, ...
    'TMS', {2, 2, 1, 1, 1}, ...
    'curveType', {'Very Inverse', 'Very Inverse', 'Very Inverse', ...
    'Very Inverse', 'Very Inverse'}, ...
    'CTprimary_A', {400, 800, 800, 400, 400}, ...
    'CTsecondary_A', {5, 5, 5, 5, 5});
end
