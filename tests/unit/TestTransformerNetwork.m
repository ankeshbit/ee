classdef TestTransformerNetwork < matlab.unittest.TestCase

    methods (Test)

        function testBaseQuantitiesAtBothVoltageLevels(testCase)
            high = calculateBaseValues(10e6, 33e3);
            low = calculateBaseValues(10e6, 11e3);

            testCase.verifyEqual(high.IbaseA, 10e6/(sqrt(3)*33e3), ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(low.IbaseA, 10e6/(sqrt(3)*11e3), ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(high.ZbaseOhm, 33e3^2/10e6, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(low.ZbaseOhm, 11e3^2/10e6, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(high.SbaseVA, low.SbaseVA);
        end

        function testImpedanceIdentityAndChangedMVA(testCase)
            testCase.verifyEqual( ...
                convertPuImpedanceBase(0.1, 10e6, 33e3, 10e6, 33e3), ...
                0.1, 'AbsTol', 1e-12);
            testCase.verifyEqual( ...
                convertPuImpedanceBase(0.1, 10e6, 33e3, 20e6, 33e3), ...
                0.2, 'AbsTol', 1e-12);
        end

        function testImpedanceChangedVoltageBase(testCase)
            actual = convertPuImpedanceBase(0.1, 10e6, 33e3, 10e6, 11e3);

            testCase.verifyEqual(actual, 0.9, 'AbsTol', 1e-12);
        end

        function testInvalidBase(testCase)
            testCase.verifyError( ...
                @() convertPuImpedanceBase(0.1, 0, 33e3, 10e6, 11e3), ...
                'MATLAB:expectedPositive');
        end

        function testSupportedTransformer(testCase)
            network = createIllustrativeTransformerRadialNetwork();

            validateRadialNetwork(network);
            validateTransformerConfiguration( ...
                network.transformers, {network.buses.id});
            testCase.verifyEqual(network.buses(2).VbaseV, 11e3);
        end

        function testInvalidTransformerTerminal(testCase)
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.highVoltageBus = 'UNKNOWN';

            testCase.verifyError( ...
                @() validateRadialNetwork(network), ...
                'validateTransformerConfiguration:InvalidTerminal');
        end

        function testUnsupportedWindingConnection(testCase)
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.windingConnection = 'delta-delta';

            testCase.verifyError( ...
                @() validateRadialNetwork(network), ...
                'validateTransformerConfiguration:UnsupportedWindingConnection');
        end

        function testUngroundedWyeIsRejected(testCase)
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.grounding = 'high side only';

            testCase.verifyError( ...
                @() validateRadialNetwork(network), ...
                'validateTransformerConfiguration:UnsupportedGrounding');
        end

        function testUngroundedZeroSequencePathIsExplicitlyRejected(testCase)
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.windingConnection = 'delta-grounded-wye';
            network.transformers.grounding = 'ungrounded';
            scenario = struct('id', 'low_slg', 'faultedBus', 'BUS_11KV', ...
                'faultType', 'SLG', 'Zf_pu', 0);

            testCase.verifyError( ...
                @() runIntegratedFaultStudy(network, scenario, ...
                relaySet(), []), ...
                'runIntegratedFaultStudy:NoGroundedNeutral');
        end

        function testHighAndLowSideFaultBases(testCase)
            network = createIllustrativeTransformerRadialNetwork();
            scenarios = [ ...
                struct('id', 'high', 'faultedBus', 'SOURCE_33KV', ...
                'faultType', 'three phase', 'Zf_pu', 0), ...
                struct('id', 'low', 'faultedBus', 'BUS_11KV_END', ...
                'faultType', 'three phase', 'Zf_pu', 0)];

            results = runIntegratedFaultStudy( ...
                network, scenarios, relaySet(), []);

            testCase.verifyEqual(results(1).faultCurrent_A, ...
                results(1).faultCurrent_pu * 10e6/(sqrt(3)*33e3), ...
                'AbsTol', 1e-9);
            testCase.verifyEqual(results(2).faultCurrent_A, ...
                results(2).faultCurrent_pu * 10e6/(sqrt(3)*11e3), ...
                'AbsTol', 1e-9);
        end


        function testDeltaWyeSLGLvCurrentAndImpedanceSensitivity(testCase)
            % Acceptance test (a): SLG on LV side
            % Ia_LV = 3*Vth / (Z1 + Z2 + Z0), where Z1 and Z2 include source
            % and Z0 = Zt0 + downstream only. Verify result does NOT change
            % when source.Z0_pu is changed, and does change with transformer Z0.
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.windingConnection = 'delta-grounded-wye';
            network.transformers.grounding = 'low neutral grounded';
            scenario = struct('id', 'slg_lv', 'faultedBus', 'BUS_11KV', ...
                'faultType', 'SLG', 'Zf_pu', 0);

            res1 = runIntegratedFaultStudy(network, scenario, relaySet(), []);

            % Change source Z0_pu: result must NOT change
            netSourceZ0 = network;
            netSourceZ0.source.Z0_pu = netSourceZ0.source.Z0_pu * 5 + 0.123;
            res2 = runIntegratedFaultStudy(netSourceZ0, scenario, relaySet(), []);
            testCase.verifyEqual(res1.faultCurrentMagnitude_A, res2.faultCurrentMagnitude_A, ...
                'AbsTol', 1e-9, 'SLG on LV side of Delta-Yg must be invariant to source Z0');

            % Change transformer Z0_pu: result MUST change
            netXfmrZ0 = network;
            netXfmrZ0.transformers.Z0_pu = netXfmrZ0.transformers.Z0_pu * 2;
            res3 = runIntegratedFaultStudy(netXfmrZ0, scenario, relaySet(), []);
            testCase.verifyNotEqual(res1.faultCurrentMagnitude_A, res3.faultCurrentMagnitude_A, ...
                'SLG on LV side of Delta-Yg must depend on transformer Z0');

            % Check exact theoretical formula: Ia_LV = 3*Vth / (Z1 + Z2 + Z0)
            Vth = network.source.Vth_pu;
            expectedZ1 = network.source.Z1_pu + network.transformers.Z1_pu;
            expectedZ2 = network.source.Z2_pu + network.transformers.Z2_pu;
            expectedZ0 = network.transformers.Z0_pu; % source excluded!
            expectedIa_pu = 3 * Vth / (expectedZ1 + expectedZ2 + expectedZ0);
            testCase.verifyEqual(res1.phaseCurrents_pu(1), expectedIa_pu, 'AbsTol', 1e-9);
        end

        function testDeltaWyeSLGHvLineCurrents(testCase)
            % Acceptance test (b): SLG on LV side
            % HV line currents have exactly one phase at ~0 and the other two
            % equal in magnitude, opposite in sign, with magnitude |Ia_LV|/sqrt(3).
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.windingConnection = 'delta-grounded-wye';
            network.transformers.grounding = 'low neutral grounded';
            scenario = struct('id', 'slg_lv', 'faultedBus', 'BUS_11KV', ...
                'faultType', 'SLG', 'Zf_pu', 0);
            relays = struct( ...
                'id', 'R_HV', ...
                'protectedBranch', 'T1', ...
                'measurementElementType', 'transformer', ...
                'measurementElementId', 'T1', ...
                'measurementSide', 'high', ...
                'pickupCurrent_A', 1, ...
                'TMS', 1, ...
                'curveType', 'Standard Inverse', ...
                'CTprimary_A', 200, ...
                'CTsecondary_A', 5);

            res = runIntegratedFaultStudy(network, scenario, relays, []);
            Ia_LV_pu = res.phaseCurrents_pu(1);
            expectedHvMag = abs(Ia_LV_pu) / sqrt(3);

            % Calculate phasors to inspect all three HV phase currents
            phasors = calculateNetworkPhasors(network, scenario, relays);
            hvRelay = phasors.relayMeasurements(strcmp({phasors.relayMeasurements.relayId}, 'R_HV'));
            hvPhases = hvRelay.phaseCurrents_pu;

            zeroPhaseIdx = find(abs(hvPhases) < 1e-6);
            nonZeroPhaseIdx = find(abs(hvPhases) >= 1e-6);
            testCase.verifyEqual(numel(zeroPhaseIdx), 1, 'Exactly one HV phase must be ~0');
            testCase.verifyEqual(numel(nonZeroPhaseIdx), 2, 'Exactly two HV phases must carry current');
            testCase.verifyEqual(abs(hvPhases(nonZeroPhaseIdx(1))), expectedHvMag, 'AbsTol', 1e-6);
            testCase.verifyEqual(abs(hvPhases(nonZeroPhaseIdx(2))), expectedHvMag, 'AbsTol', 1e-6);
            testCase.verifyEqual(hvPhases(nonZeroPhaseIdx(1)) + hvPhases(nonZeroPhaseIdx(2)), 0, ...
                'AbsTol', 1e-6, 'The two non-zero HV phases must be opposite in sign');
        end

        function testDeltaWyeLLCurrentRatios(testCase)
            % Acceptance test (c): LL on LV side
            % LV peak line current = sqrt(3)*I1, HV peak line current = 2*I1,
            % where I1 = Vth / (Z1 + Z2 + Zf).
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.windingConnection = 'delta-grounded-wye';
            network.transformers.grounding = 'low neutral grounded';
            scenario = struct('id', 'll_lv', 'faultedBus', 'BUS_11KV', ...
                'faultType', 'LL', 'Zf_pu', 0);
            relays = struct( ...
                'id', 'R_HV', ...
                'protectedBranch', 'T1', ...
                'measurementElementType', 'transformer', ...
                'measurementElementId', 'T1', ...
                'measurementSide', 'high', ...
                'pickupCurrent_A', 1, ...
                'TMS', 1, ...
                'curveType', 'Standard Inverse', ...
                'CTprimary_A', 200, ...
                'CTsecondary_A', 5);

            res = runIntegratedFaultStudy(network, scenario, relays, []);
            Vth = network.source.Vth_pu;
            Z1 = network.source.Z1_pu + network.transformers.Z1_pu;
            Z2 = network.source.Z2_pu + network.transformers.Z2_pu;
            I1 = Vth / (Z1 + Z2);

            lvPeak_pu = max(abs(res.phaseCurrents_pu));
            testCase.verifyEqual(lvPeak_pu, sqrt(3) * abs(I1), 'AbsTol', 1e-9);

            phasors = calculateNetworkPhasors(network, scenario, relays);
            hvRelay = phasors.relayMeasurements(strcmp({phasors.relayMeasurements.relayId}, 'R_HV'));
            hvPeak_pu = max(abs(hvRelay.phaseCurrents_pu));
            testCase.verifyEqual(hvPeak_pu, 2 * abs(I1), 'AbsTol', 1e-9);
        end

        function testDeltaWyeThreePhaseUnchanged(testCase)
            % Acceptance test (d): Three-phase results are unchanged
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.windingConnection = 'delta-grounded-wye';
            network.transformers.grounding = 'low neutral grounded';
            scenario = struct('id', '3ph_lv', 'faultedBus', 'BUS_11KV', ...
                'faultType', '3PH', 'Zf_pu', 0);
            res = runIntegratedFaultStudy(network, scenario, relaySet(), []);
            Z1 = network.source.Z1_pu + network.transformers.Z1_pu;
            expectedI = network.source.Vth_pu / Z1;
            testCase.verifyEqual(res.faultCurrent_pu, expectedI, 'AbsTol', 1e-9);
        end

        function testFaultOnHvBusUnchanged(testCase)
            % Acceptance test (f): Faults on HV bus are unchanged
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.windingConnection = 'delta-grounded-wye';
            network.transformers.grounding = 'low neutral grounded';
            scenario = struct('id', 'hv_fault', 'faultedBus', 'SOURCE_33KV', ...
                'faultType', 'SLG', 'Zf_pu', 0);
            res = runIntegratedFaultStudy(network, scenario, relaySet(), []);
            Z1 = network.source.Z1_pu;
            Z2 = network.source.Z2_pu;
            Z0 = network.source.Z0_pu;
            expectedI = 3 * network.source.Vth_pu / (Z1 + Z2 + Z0);
            testCase.verifyEqual(res.phaseCurrents_pu(1), expectedI, 'AbsTol', 1e-9);
        end

        function testDeltaRelaysZeroSequenceCurrent(testCase)
            % Acceptance test (g): Relays on delta side never report zero sequence
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.windingConnection = 'delta-grounded-wye';
            network.transformers.grounding = 'low neutral grounded';
            scenario = struct('id', 'slg_lv', 'faultedBus', 'BUS_11KV', ...
                'faultType', 'SLG', 'Zf_pu', 0);
            relays = struct( ...
                'id', {'R_HV', 'R_LV'}, ...
                'protectedBranch', {'T1', 'T1'}, ...
                'measurementElementType', {'transformer', 'transformer'}, ...
                'measurementElementId', {'T1', 'T1'}, ...
                'measurementSide', {'high', 'low'}, ...
                'pickupCurrent_A', {1, 1}, ...
                'TMS', {1, 1}, ...
                'curveType', {'Standard Inverse', 'Standard Inverse'}, ...
                'CTprimary_A', {200, 600}, ...
                'CTsecondary_A', {5, 5});

            phasors = calculateNetworkPhasors(network, scenario, relays);
            hvRelay = phasors.relayMeasurements(strcmp({phasors.relayMeasurements.relayId}, 'R_HV'));
            lvRelay = phasors.relayMeasurements(strcmp({phasors.relayMeasurements.relayId}, 'R_LV'));

            testCase.verifyEqual(hvRelay.sequenceCurrents_pu(1), 0, 'AbsTol', 1e-12, ...
                'Relays on delta side must report zero I0');
            testCase.verifyGreaterThan(abs(lvRelay.sequenceCurrents_pu(1)), 0, ...
                'Relays on grounded wye side must report non-zero I0');
        end

        function testNonStructTransformerThrowsInvalidTransformer(testCase)
            testCase.verifyError( ...
                @() validateTransformerConfiguration(123, {'BUS_A', 'BUS_B'}), ...
                'validateTransformerConfiguration:InvalidTransformer');
            testCase.verifyError( ...
                @() validateTransformerConfiguration([struct(), struct()], {'BUS_A', 'BUS_B'}), ...
                'validateTransformerConfiguration:InvalidTransformer');
        end

    end
end

function values = relaySet()
values = struct( ...
    'id', {'R_T', 'R_L'}, ...
    'protectedBranch', {'BR_11KV', 'BR_11KV'}, ...
    'pickupCurrent_A', {1, 1}, ...
    'TMS', {1, 1}, ...
    'curveType', {'Very Inverse', 'Very Inverse'}, ...
    'CTprimary_A', {1000, 400}, ...
    'CTsecondary_A', {5, 5});
end
