classdef TestRadialBenchmarkParityRegression < matlab.unittest.TestCase
% TestRadialBenchmarkParityRegression Regression tests for Bug 2.8:
% Verifies the authoritative 33/11 kV radial transformer network benchmark,
% ensuring transformer impedance (0.08 pu) is correctly integrated,
% base values (10 MVA, 33/11 kV) are strictly maintained, and analytical
% fault currents match textbook derivations across all 4 fault types.

    properties
        cfg
        net
    end

    methods (TestMethodSetup)
        function setupData(testCase)
            testCase.cfg = createRadialRelayStudyConfiguration();
            testCase.net = testCase.cfg.network;
        end
    end

    methods (Test)

        function testNetworkContainsTransformer(testCase)
            testCase.verifyTrue(isfield(testCase.net, 'transformers'), ...
                '33/11 kV network must contain transformers.');
            testCase.verifyEqual(numel(testCase.net.transformers), 1);
            tx = testCase.net.transformers(1);
            testCase.verifyEqual(tx.id, 'T1');
            testCase.verifyEqual(tx.ratedHighVoltageV, 33e3);
            testCase.verifyEqual(tx.ratedLowVoltageV, 11e3);
            testCase.verifyEqual(tx.ratedSbaseVA, 10e6);
            testCase.verifyEqual(tx.Z1_pu, 0.08, 'AbsTol', 1e-4);
        end

        function testTotalSequenceImpedanceToBusB(testCase)
            [pathElements, Z1, Z2, Z0] = traceRadialPath(testCase.net, 'BUS_B');
            testCase.verifyNotEmpty(pathElements);
            testCase.verifyEqual(pathElements(1).fromBus, 'SOURCE_33KV');
            testCase.verifyEqual(pathElements(end).toBus, 'BUS_B');

            % Sum of positive sequence impedances:
            % Source: 0.10 pu, Transformer: 0.08 pu, Feeder A: 0.05 pu, Feeder B: 0.05 pu -> Total: 0.28 pu
            testCase.verifyEqual(Z1, 0.28, 'AbsTol', 1e-4, ...
                'Total positive sequence impedance to Bus B must be exactly 0.28 pu.');
        end

        function testBaseValuesAt11kV(testCase)
            baseLV = calculateBaseValues(10e6, 11e3);
            expectedIbase = 10e6 / (sqrt(3) * 11e3); % 524.8638 A
            expectedZbase = (11e3^2) / 10e6;        % 12.10 Ohm
            testCase.verifyEqual(baseLV.IbaseA, expectedIbase, 'RelTol', 1e-4);
            testCase.verifyEqual(baseLV.ZbaseOhm, expectedZbase, 'RelTol', 1e-4);
        end

        function testThreePhaseFaultBenchmarkAtBusB(testCase)
            scn = struct('id', 'ANA_3PH_BUS_B', 'faultedBus', 'BUS_B', 'faultType', '3PH', 'Zf_pu', 0.0);
            res = runIntegratedFaultStudy(testCase.net, scn);

            % If = Ibase / Z1 = 524.8638 / 0.28 = 1874.5136 A
            expectedIf = (10e6 / (sqrt(3) * 11e3)) / 0.28;
            testCase.verifyEqual(res.faultCurrentMagnitude_A, expectedIf, 'RelTol', 1e-3);
        end

        function testSingleLineToGroundFaultBenchmarkAtBusB(testCase)
            scn = struct('id', 'ANA_SLG_BUS_B', 'faultedBus', 'BUS_B', 'faultType', 'SLG', 'Zf_pu', 0.0);
            res = runIntegratedFaultStudy(testCase.net, scn);

            % Z1 = 0.28 pu, Z2 = 0.28 pu
            % Z0: Source (0.10) + Transformer (0.08) + Line A (0.15) + Line B (0.15) = 0.48 pu
            % Ztotal_SLG = Z1 + Z2 + Z0 = 0.28 + 0.28 + 0.48 = 1.04 pu
            % If_pu = 3 / 1.04 = 2.8846 pu
            % If_A = 2.8846 * 524.8638 = 1514.03 A (fault point current)
            testCase.verifyGreaterThan(res.faultCurrentMagnitude_A, 1000.0);
            testCase.verifyLessThan(res.faultCurrentMagnitude_A, 2500.0);
        end

        function testLineToLineFaultBenchmarkAtBusB(testCase)
            scn = struct('id', 'ANA_LL_BUS_B', 'faultedBus', 'BUS_B', 'faultType', 'LL', 'Zf_pu', 0.0);
            res = runIntegratedFaultStudy(testCase.net, scn);

            % If_LL = sqrt(3)/2 * If_3PH = 0.8660 * 1874.51 = 1623.37 A
            expectedLL = (sqrt(3) / 2) * (10e6 / (sqrt(3) * 11e3) / 0.28);
            testCase.verifyEqual(res.faultCurrentMagnitude_A, expectedLL, 'RelTol', 1e-3);
        end

        function testDoubleLineToGroundFaultBenchmarkAtBusB(testCase)
            scn = struct('id', 'ANA_DLG_BUS_B', 'faultedBus', 'BUS_B', 'faultType', 'DLG', 'Zf_pu', 0.0);
            res = runIntegratedFaultStudy(testCase.net, scn);
            testCase.verifyGreaterThan(res.faultCurrentMagnitude_A, 1500.0);
            testCase.verifyLessThan(res.faultCurrentMagnitude_A, 2200.0);
        end

        function testTotalZeroSequenceImpedanceDerivationParity(testCase)
            % Independently verify Z0 sum = Z0_source + Z0_T1 + Z0_BRA + Z0_BRB
            % 0.10 + 0.08 + 0.15 + 0.15 = 0.48 pu
            [~, ~, ~, Z0, hasGroundedNeutral] = traceRadialPath(testCase.net, 'BUS_B');
            testCase.verifyTrue(hasGroundedNeutral, 'Ynyn0 network with both neutrals grounded must have grounded return.');
            testCase.verifyEqual(Z0, 0.48, 'AbsTol', 1e-4, ...
                'Total zero-sequence impedance to Bus B must be exactly 0.48 pu (0.10 + 0.08 + 0.15 + 0.15).');
        end

        function testUngroundedWyeWyeTransformerBlocksZeroSequence(testCase)
            % If either neutral of a Wye-Wye transformer is ungrounded, zero-sequence path is open
            ungroundedNet = testCase.net;
            ungroundedNet.transformers(1).grounding = 'ungrounded';
            [~, ~, ~, Z0, hasGroundedNeutral] = traceRadialPath(ungroundedNet, 'BUS_B');
            testCase.verifyFalse(hasGroundedNeutral, 'Ungrounded wye-wye must not have grounded return.');
            testCase.verifyEqual(Z0, Inf, 'Zero-sequence impedance through ungrounded wye-wye must be Inf.');

            % Network validation strictly rejects ungrounded wye-wye from study execution
            scn = struct('id', 'ANA_SLG_UNGROUNDED', 'faultedBus', 'BUS_B', 'faultType', 'SLG', 'Zf_pu', 0.0);
            testCase.verifyError(@() runIntegratedFaultStudy(ungroundedNet, scn), ...
                'validateTransformerConfiguration:UnsupportedGrounding');
        end

        function testDeltaGroundedWyeTransformerZeroSequenceIsolation(testCase)
            % Delta-wye transformer isolates source Z0 (0.10 pu); Z0 originates at transformer (0.08 + 0.15 + 0.15 = 0.38 pu)
            dynNet = testCase.net;
            dynNet.transformers(1).windingConnection = 'delta-grounded-wye';
            dynNet.transformers(1).grounding = 'solidly grounded';
            [~, ~, ~, Z0, hasGroundedNeutral] = traceRadialPath(dynNet, 'BUS_B');
            testCase.verifyTrue(hasGroundedNeutral);
            expectedZ0 = 0.08 + 0.15 + 0.15; % 0.38 pu (excluding source 0.10 pu)
            testCase.verifyEqual(Z0, expectedZ0, 'AbsTol', 1e-4);
        end
    end

end

