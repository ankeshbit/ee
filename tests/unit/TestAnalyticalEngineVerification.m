classdef TestAnalyticalEngineVerification < matlab.unittest.TestCase

    methods (Test)

        function testBaseQuantitiesUseThreePhaseLLDefinitions(testCase)
            bases = calculateBaseValues(10e6, 11e3);
            testCase.verifyEqual(bases.IbaseA, 10e6/(sqrt(3)*11e3), ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(bases.ZbaseOhm, 11e3^2/10e6, ...
                'AbsTol', 1e-12);
        end

        function testPuConversionHandCalculation(testCase)
            actual = convertPuImpedanceBase(0.08, 10e6, 33e3, ...
                5e6, 33e3);
            testCase.verifyEqual(actual, 0.04, 'AbsTol', 1e-12);
            identity = convertPuImpedanceBase(0.08, 10e6, 33e3, ...
                10e6, 33e3);
            testCase.verifyEqual(identity, 0.08, 'AbsTol', 1e-12);
        end

        function testFaultSolversAgainstIndependentReferenceCases(testCase)
            testCase.verifyEqual(calculateThreePhaseFault(1, 0.2, 0.1), ...
                10/3, 'AbsTol', 1e-12);
            slg = calculateSLGFault(1, 0.1, 0.2, 0.3, 0.1);
            testCase.verifyEqual(slg.I0_pu, 1/0.9, 'AbsTol', 1e-12);
            testCase.verifyEqual(slg.Ia_pu, 10/3, 'AbsTol', 1e-12);
            ll = calculateLLFault(1, 0.1, 0.2, 0.1);
            testCase.verifyEqual(abs(ll.I1_pu), 1/0.4, 'AbsTol', 1e-12);
            testCase.verifyEqual(abs(ll.Ib_pu), sqrt(3)/0.4, ...
                'AbsTol', 1e-12);
            dlg = calculateDLGFault(1, 0.1, 0.2, 0.3, 0);
            testCase.verifyEqual(dlg.I1_pu, 1/0.22, 'AbsTol', 1e-12);
            testCase.verifyEqual(dlg.I0_pu, -dlg.I1_pu * 0.2/0.5, ...
                'AbsTol', 1e-12);
        end

        function testSequenceTransformRoundTrip(testCase)
            phase = [1.1 + 0.2i; -0.4 + 0.7i; 0.2 - 0.1i];
            sequence = calculateSequenceComponents(phase);
            a = exp(1i*2*pi/3);
            reconstructed = [1, 1, 1; 1, a^2, a; 1, a, a^2] * ...
                [sequence.V0; sequence.V1; sequence.V2];
            testCase.verifyEqual(reconstructed, phase, 'AbsTol', 1e-12);
        end

        function testRelayPickupBoundaryAndBreakerMargin(testCase)
            testCase.verifyEqual(calculateRelayOperatingTime(5, 5, 1, ...
                'Very Inverse'), Inf);
            relayTime = calculateRelayOperatingTime(10, 5, 1, ...
                'Very Inverse');
            expected = 13.5/(2 - 1);
            testCase.verifyEqual(relayTime, expected, 'AbsTol', 1e-12);
            clearing = calculateBreakerClearingTime(relayTime, 0.08);
            testCase.verifyEqual(clearing.totalClearingTime_s, ...
                expected + 0.08, 'AbsTol', 1e-12);
        end

        function testCoordinationUsesRelayCTIOnly(testCase)
            primary = relay(400, 5);
            backup = relay(800, 5);
            result = checkRelayCoordination(1600, primary, backup, 1);
            expectedPrimary = 13.5/(20 - 1);
            expectedBackup = 13.5/(10 - 1);
            testCase.verifyEqual(result.primaryOperatingTime_s, ...
                expectedPrimary, 'AbsTol', 1e-12);
            testCase.verifyEqual(result.backupOperatingTime_s, ...
                expectedBackup, 'AbsTol', 1e-12);
            testCase.verifyEqual(result.coordinationInterval_s, ...
                expectedBackup - expectedPrimary, 'AbsTol', 1e-12);
        end

        function testInvalidAndSingularAnalyticalInputs(testCase)
            testCase.verifyError(@() calculateThreePhaseFault(1, 0, 0), ...
                'calculateThreePhaseFault:ZeroImpedance');
            testCase.verifyError(@() calculateLLFault(1, 0, 0, 0), ...
                'calculateLLFault:ZeroImpedance');
            testCase.verifyError(@() calculateBaseValues(-1, 11e3), ...
                'MATLAB:expectedPositive');
            testCase.verifyError(@() convertPuImpedanceBase(1, 0, 1, 1, 1), ...
                'MATLAB:expectedPositive');
        end

        function testTransformerPhaseDisplacementIsExplicitlyUnsupported(testCase)
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.phaseShift_deg = 30;
            testCase.verifyError(@() validateRadialNetwork(network), ...
                'validateTransformerConfiguration:UnsupportedPhaseShift');
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.vectorGroup = 'YNd1';
            testCase.verifyError(@() validateRadialNetwork(network), ...
                'validateTransformerConfiguration:UnsupportedPhaseShift');
        end

        function testTransformerCommonBaseAndElementIdValidation(testCase)
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.ratedSbaseVA = 5e6;
            testCase.verifyError(@() validateRadialNetwork(network), ...
                'validateRadialNetwork:InconsistentSbase');
            network = createIllustrativeTransformerRadialNetwork();
            network.transformers.id = network.branches.id;
            testCase.verifyError(@() validateRadialNetwork(network), ...
                'validateRadialNetwork:DuplicateElementId');
        end

        function testDirectionalMissingPhasorsIsUnsupported(testCase)
            result = evaluateDirectionalSupervision( ...
                struct('enabled', true, 'characteristicAngle_deg', 30), ...
                struct('currentPhasor', 1));
            testCase.verifyEqual(result.status, 'unsupported');
        end
    end
end

function value = relay(ctPrimary, ctSecondary)
value = struct('pickupCurrent_A', 1, 'TMS', 1, ...
    'curveType', 'Very Inverse', 'CTprimary_A', ctPrimary, ...
    'CTsecondary_A', ctSecondary);
end
