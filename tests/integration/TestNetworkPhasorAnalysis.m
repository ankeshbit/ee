classdef TestNetworkPhasorAnalysis < matlab.unittest.TestCase

    methods (Test)

        function testBalancedPositiveSequenceReconstruction(testCase)
            V1 = 1.2 + 0.3i;
            Vseq = [0; V1; 0];
            Vphase = sequenceToPhase(Vseq);
            seq = calculateSequenceComponents(Vphase);
            testCase.verifyEqual(seq.V0, 0, 'AbsTol', 1e-12);
            testCase.verifyEqual(seq.V1, V1, 'AbsTol', 1e-12);
            testCase.verifyEqual(seq.V2, 0, 'AbsTol', 1e-12);
        end

        function testThreePhaseFaultBusVoltage(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            scenario = caseScenario('B3', 'BUS_B', 'three phase', 0);
            result = calculateNetworkPhasors(network, scenario, relaySet());
            Z1 = 0.1 + 0.08 + 0.04 + 0.03;
            expectedI = 1/Z1;
            expectedV1 = 1 - Z1 * expectedI;
            testCase.verifyEqual(result.sequenceCurrents_pu(2), ...
                expectedI, 'AbsTol', 1e-12);
            testCase.verifyEqual(result.faultedBusSequenceVoltages_pu(2), ...
                expectedV1, 'AbsTol', 1e-12);
        end

        function testFaultTypesProduceSequenceAndPhasePhasors(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            types = {'three phase', 'SLG', 'LL', 'DLG'};
            for index = 1:numel(types)
                scenario = caseScenario(['case' num2str(index)], ...
                    'BUS_B', types{index}, 0);
                result = calculateNetworkPhasors(network, scenario, relaySet());
                testCase.verifyEqual(numel(result.sequenceCurrents_pu), 3);
                testCase.verifyEqual(numel(result.faultedBusPhaseVoltages_pu), 3);
            end
        end

        function testTransformerRelayBasesAndMeasurementPhasors(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            scenario = caseScenario('B3', 'BUS_B', 'three phase', 0);
            relays = relaySet();
            result = calculateNetworkPhasors(network, scenario, relays);
            hv = result.relayMeasurements(strcmp( ...
                {result.relayMeasurements.relayId}, 'R_HV'));
            lv = result.relayMeasurements(strcmp( ...
                {result.relayMeasurements.relayId}, 'R_LV'));
            testCase.verifyEqual(hv.voltageBaseV, 33e3);
            testCase.verifyEqual(lv.voltageBaseV, 11e3);
            testCase.verifyEqual(hv.currentBaseA, 10e6/(sqrt(3)*33e3), ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(lv.currentBaseA, 10e6/(sqrt(3)*11e3), ...
                'AbsTol', 1e-12);
            testCase.verifyNotEqual(hv.phaseCurrents_A(1), ...
                lv.phaseCurrents_A(1));
        end

        function testOffPathRelayIsExplicitlyUnsupported(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            scenario = caseScenario('B3', 'BUS_B', 'three phase', 0);
            result = calculateNetworkPhasors(network, scenario, relaySet());
            relay = result.relayMeasurements(strcmp( ...
                {result.relayMeasurements.relayId}, 'R_C'));
            testCase.verifyEqual(relay.supportStatus, 'unsupportedOffFaultPath');
            testCase.verifyEqual(relay.directionalResult.status, 'unsupported');
        end

        function testBlockedZeroSequenceIsRejected(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            network.transformers.windingConnection = 'delta-grounded-wye';
            network.transformers.grounding = 'low neutral grounded';
            scenario = caseScenario('B_SLG', 'BUS_B', 'SLG', 0);
            testCase.verifyError(@() calculateNetworkPhasors( ...
                network, scenario, relaySet()), ...
                'calculateNetworkPhasors:BlockedZeroSequence');
        end

        function testDirectionalResultUsesCalculatedPhasors(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            scenario = caseScenario('B3', 'BUS_B', 'three phase', 0);
            relays = relaySet();
            relays(1).directionalSettings = struct('enabled', true, ...
                'characteristicAngle_deg', 0);
            result = calculateNetworkPhasors(network, scenario, relays);
            testCase.verifyTrue(any(strcmp( ...
                {'forward', 'reverse', 'indeterminate'}, ...
                result.relayMeasurements(1).directionalResult.status)));
        end

        function testSourceImpedanceIncludedInBusAndRelayVoltages(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            faultTypes = {'three phase', 'SLG', 'LL', 'DLG'};
            zfValues = [0, 0.05];

            relays = relaySet();
            relays(end + 1) = struct( ...
                'id', 'R_FAULTED', ...
                'measurementElementType', 'branch', ...
                'measurementElementId', 'BR_2', ...
                'measurementSide', 'to', ...
                'pickupCurrent_A', 1, 'TMS', 1, ...
                'curveType', 'Very Inverse', ...
                'CTprimary_A', 400, 'CTsecondary_A', 5);

            for ftIdx = 1:numel(faultTypes)
                for zfIdx = 1:numel(zfValues)
                    scenario = caseScenario( ...
                        sprintf('test_%s_zf%d', faultTypes{ftIdx}, zfIdx), ...
                        'BUS_B', faultTypes{ftIdx}, zfValues(zfIdx));
                    result = calculateNetworkPhasors(network, scenario, relays);

                    testCase.verifyEqual( ...
                        result.busResults(end).phaseVoltages_pu, ...
                        result.faultedBusPhaseVoltages_pu, ...
                        'AbsTol', 1e-12, ...
                        sprintf('Bus voltage mismatch at faulted bus for %s (Zf=%g)', ...
                            faultTypes{ftIdx}, zfValues(zfIdx)));

                    Vth = network.source.Vth_pu;
                    Zs1 = network.source.Z1_pu;
                    I1 = result.sequenceCurrents_pu(2);
                    expectedSourceV1 = Vth - Zs1 * I1;
                    testCase.verifyEqual( ...
                        result.busResults(1).sequenceVoltages_pu(2), ...
                        expectedSourceV1, ...
                        'AbsTol', 1e-12, ...
                        sprintf('Source bus V1 mismatch for %s (Zf=%g)', ...
                            faultTypes{ftIdx}, zfValues(zfIdx)));

                    rFaulted = result.relayMeasurements(strcmp( ...
                        {result.relayMeasurements.relayId}, 'R_FAULTED'));
                    testCase.verifyEqual( ...
                        rFaulted.sequenceVoltages_pu, ...
                        result.faultedBusSequenceVoltages_pu, ...
                        'AbsTol', 1e-12, ...
                        sprintf('Relay sequence voltage mismatch for %s (Zf=%g)', ...
                            faultTypes{ftIdx}, zfValues(zfIdx)));
                end
            end
        end

        function testEmptyRelaysSucceedsAndProducesEmptyMeasurements(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            scenario = caseScenario('B3_no_relays', 'BUS_B', 'three phase', 0);
            result = calculateNetworkPhasors(network, scenario, []);
            testCase.verifyTrue(isstruct(result.relayMeasurements));
            testCase.verifyEmpty(result.relayMeasurements);
        end
    end
end

function values = relaySet()
values = struct( ...
    'id', {'R_HV', 'R_LV', 'R_B', 'R_C'}, ...
    'measurementElementType', ...
    {'transformer', 'transformer', 'branch', 'branch'}, ...
    'measurementElementId', {'T1', 'T1', 'BR_2', 'BR_3'}, ...
    'measurementSide', {'high', 'low', 'from', 'from'}, ...
    'pickupCurrent_A', {1, 1, 1, 1}, 'TMS', {1, 1, 1, 1}, ...
    'curveType', {'Very Inverse', 'Very Inverse', ...
    'Very Inverse', 'Very Inverse'}, ...
    'CTprimary_A', {400, 800, 400, 400}, ...
    'CTsecondary_A', {5, 5, 5, 5});
end

function value = caseScenario(id, bus, type, Zf)
value = struct('id', id, 'faultedBus', bus, ...
    'faultType', type, 'Zf_pu', Zf);
end

function phases = sequenceToPhase(sequence)
a = exp(1i * 2*pi/3);
phases = [1, 1, 1; 1, a^2, a; 1, a, a^2] * sequence;
end
