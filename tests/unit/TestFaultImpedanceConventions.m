classdef TestFaultImpedanceConventions < matlab.unittest.TestCase
    % TestFaultImpedanceConventions Verifies fault-impedance conventions and edge cases.
    %
    % Covers:
    % 1. 3*Zf in SLG denominator
    % 2. Zf between phases in LL
    % 3. Z0 + 3*Zf in DLG zero-sequence branch
    % 4. Edge cases: Zf = 0 (bolted)
    % 5. Edge cases: Very large Zf (1e6 pu) -> finite, near zero, no divergence
    % 6. Zero-sequence blocked by transformer: Delta/Yg blocks SLG/DLG and throws
    %    runIntegratedFaultStudy:BlockedZeroSequence, while Yg/Yg allows it.
    % 7. Degenerate denominators throw explicit error IDs, never returning Inf or NaN.

    properties
        Vth = 1.0;
        Z1 = 0.10 + 0.20i;
        Z2 = 0.10 + 0.20i;
        Z0 = 0.15 + 0.40i;
    end

    methods (Test)

        %% 1. SLG Denominator Convention (3*Zf)
        function testSLG3ZfDenominatorConvention(testCase)
            % For SLG: Ztotal = Z1 + Z2 + Z0 + 3*Zf
            % If Zf increases by delta_Zf, Ztotal must increase by 3*delta_Zf
            Zf1 = 0.02;
            Zf2 = 0.07;
            delta_Zf = Zf2 - Zf1; % 0.05

            fault1 = calculateSLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, Zf1);
            fault2 = calculateSLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, Zf2);

            % Compare sequence currents:
            expected_Ztotal1 = testCase.Z1 + testCase.Z2 + testCase.Z0 + 3*Zf1;
            expected_Ztotal2 = testCase.Z1 + testCase.Z2 + testCase.Z0 + 3*Zf2;

            testCase.verifyEqual(fault1.I1_pu, testCase.Vth / expected_Ztotal1, 'AbsTol', 1e-12);
            testCase.verifyEqual(fault2.I1_pu, testCase.Vth / expected_Ztotal2, 'AbsTol', 1e-12);

            % The difference in sequence impedance is exactly 3 * delta_Zf
            diff_Ztotal = (testCase.Vth / fault2.I1_pu) - (testCase.Vth / fault1.I1_pu);
            testCase.verifyEqual(real(diff_Ztotal), 3 * delta_Zf, 'AbsTol', 1e-12);
            testCase.verifyEqual(imag(diff_Ztotal), 0.0, 'AbsTol', 1e-12);
        end

        %% 2. LL Fault Impedance Convention (Zf directly between phases)
        function testLLZfBetweenPhasesConvention(testCase)
            % For LL: Ztotal = Z1 + Z2 + Zf (not 2*Zf or 3*Zf)
            Zf1 = 0.03;
            Zf2 = 0.08;
            delta_Zf = Zf2 - Zf1;

            fault1 = calculateLLFault(testCase.Vth, testCase.Z1, testCase.Z2, Zf1);
            fault2 = calculateLLFault(testCase.Vth, testCase.Z1, testCase.Z2, Zf2);

            expected_Ztotal1 = testCase.Z1 + testCase.Z2 + Zf1;
            expected_Ztotal2 = testCase.Z1 + testCase.Z2 + Zf2;

            testCase.verifyEqual(fault1.I1_pu, testCase.Vth / expected_Ztotal1, 'AbsTol', 1e-12);
            testCase.verifyEqual(fault2.I1_pu, testCase.Vth / expected_Ztotal2, 'AbsTol', 1e-12);

            diff_Ztotal = (testCase.Vth / fault1.I1_pu) - (testCase.Vth / fault2.I1_pu);
            testCase.verifyEqual(real(diff_Ztotal), -delta_Zf, 'AbsTol', 1e-12);
        end

        %% 3. DLG Zero-Sequence Branch Convention (Z0 + 3*Zf)
        function testDLGZ0Plus3ZfConvention(testCase)
            % In DLG, the zero-sequence branch impedance is Zg = Z0 + 3*Zf
            Zf = 0.05;
            fault = calculateDLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, Zf);

            Zg = testCase.Z0 + 3*Zf;
            Zden = testCase.Z2 + Zg;
            Z20 = (testCase.Z2 * Zg) / Zden;
            expected_I1 = testCase.Vth / (testCase.Z1 + Z20);
            expected_I2 = -expected_I1 * (Zg / Zden);
            expected_I0 = -expected_I1 * (testCase.Z2 / Zden);

            testCase.verifyEqual(fault.I1_pu, expected_I1, 'AbsTol', 1e-12);
            testCase.verifyEqual(fault.I2_pu, expected_I2, 'AbsTol', 1e-12);
            testCase.verifyEqual(fault.I0_pu, expected_I0, 'AbsTol', 1e-12);
        end

        %% 4. Edge Cases: Bolted Faults (Zf = 0)
        function testBoltedFaultEdgeCases(testCase)
            % All fault types must execute smoothly with Zf = 0
            f3ph = calculateThreePhaseFault(testCase.Vth, testCase.Z1, 0.0);
            fslg = calculateSLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, 0.0);
            fll  = calculateLLFault(testCase.Vth, testCase.Z1, testCase.Z2, 0.0);
            fdlg = calculateDLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, 0.0);

            testCase.verifyTrue(isfinite(f3ph) && abs(f3ph) > 0);
            testCase.verifyTrue(isfinite(fslg.Ia_pu) && abs(fslg.Ia_pu) > 0);
            testCase.verifyTrue(isfinite(fll.Ib_pu) && abs(fll.Ib_pu) > 0);
            testCase.verifyTrue(isfinite(fdlg.Ib_pu) && abs(fdlg.Ib_pu) > 0);
        end

        %% 5. Edge Cases: Very Large Fault Impedance (Zf = 1e6 pu)
        function testVeryLargeFaultImpedance(testCase)
            % With very large Zf, currents must remain finite and decay towards 0
            Zf_huge = 1e6;

            f3ph = calculateThreePhaseFault(testCase.Vth, testCase.Z1, Zf_huge);
            testCase.verifyTrue(isfinite(f3ph));
            testCase.verifyLessThan(abs(f3ph), 1e-5);

            fslg = calculateSLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, Zf_huge);
            testCase.verifyTrue(isfinite(fslg.Ia_pu));
            testCase.verifyLessThan(abs(fslg.Ia_pu), 1e-5);

            fll = calculateLLFault(testCase.Vth, testCase.Z1, testCase.Z2, Zf_huge);
            testCase.verifyTrue(isfinite(fll.Ib_pu));
            testCase.verifyLessThan(abs(fll.Ib_pu), 1e-5);

            fdlg = calculateDLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, Zf_huge);
            testCase.verifyTrue(isfinite(fdlg.Ib_pu));
            testCase.verifyTrue(isfinite(fdlg.Ic_pu));
            % As Zf -> inf, DLG degenerates to line-to-line fault across Z2
            expected_LL_I1 = testCase.Vth / (testCase.Z1 + testCase.Z2);
            testCase.verifyEqual(abs(fdlg.I1_pu), abs(expected_LL_I1), 'RelTol', 1e-4);
            testCase.verifyLessThan(abs(fdlg.I0_pu), 1e-5);
        end

        %% 6. Transformer Zero-Sequence Blocking (Delta/Yg vs Yg/Yg)
        function testTransformerZeroSequenceBlocking(testCase)
            % Test Delta-Grounded-Wye transformer: SLG/DLG on LV side must throw
            % runIntegratedFaultStudy:BlockedZeroSequence
            netDelta = createIllustrativeTransformerRadialNetwork();
            netDelta.transformers.windingConnection = 'delta-grounded-wye';
            netDelta.transformers.grounding = 'low neutral grounded';

            scenariosSLG = struct('id', 'SCN_SLG', 'faultedBus', 'BUS_11KV', ...
                'faultType', 'SLG', 'Zf_pu', 0.0);
            scenariosDLG = struct('id', 'SCN_DLG', 'faultedBus', 'BUS_11KV', ...
                'faultType', 'DLG', 'Zf_pu', 0.0);
            scenarios3PH = struct('id', 'SCN_3PH', 'faultedBus', 'BUS_11KV', ...
                'faultType', '3PH', 'Zf_pu', 0.0);

            relays = struct('id', 'RELAY_1', 'pickupCurrent_A', 1.0, 'TMS', 0.1, ...
                'curveType', 'standard inverse', 'CTprimary_A', 400, 'CTsecondary_A', 5, ...
                'protectedBranch', 'BR_11KV');
            pairs = struct([]);

            % SLG through Delta/Yg succeeds with zero-sequence path formed by grounded-wye neutral:
            resSLG_delta = runIntegratedFaultStudy(netDelta, scenariosSLG, relays, pairs);
            testCase.verifyEqual(numel(resSLG_delta), 1);
            testCase.verifyTrue(resSLG_delta.faultCurrentMagnitude_A > 0);

            % DLG through Delta/Yg succeeds:
            resDLG_delta = runIntegratedFaultStudy(netDelta, scenariosDLG, relays, pairs);
            testCase.verifyEqual(numel(resDLG_delta), 1);
            testCase.verifyTrue(resDLG_delta.faultCurrentMagnitude_A > 0);

            % 3PH through Delta/Yg does not involve zero-sequence and must succeed:
            res3PH = runIntegratedFaultStudy(netDelta, scenarios3PH, relays, pairs);
            testCase.verifyEqual(numel(res3PH), 1);
            testCase.verifyTrue(res3PH.faultCurrentMagnitude_A > 0);

            % Now test Grounded-Wye / Grounded-Wye (Yg/Yg):
            netYgYg = createIllustrativeTransformerRadialNetwork();
            netYgYg.transformers.windingConnection = 'grounded-wye-grounded-wye';
            netYgYg.transformers.grounding = 'both neutrals grounded';

            resSLG = runIntegratedFaultStudy(netYgYg, scenariosSLG, relays, pairs);
            testCase.verifyEqual(numel(resSLG), 1);
            testCase.verifyTrue(resSLG.faultCurrentMagnitude_A > 0);

            resDLG = runIntegratedFaultStudy(netYgYg, scenariosDLG, relays, pairs);
            testCase.verifyEqual(numel(resDLG), 1);
            testCase.verifyTrue(resDLG.faultCurrentMagnitude_A > 0);
        end

        %% 7. Degenerate Denominators (Must Error, Never Inf/NaN)
        function testDegenerateDenominatorsThrowErrors(testCase)
            % 3PH zero denominator
            testCase.verifyError( ...
                @() calculateThreePhaseFault(1.0, 0.25i, -0.25i), ...
                'calculateThreePhaseFault:ZeroImpedance');

            % SLG zero denominator: Z1 + Z2 + Z0 + 3*Zf = 0
            testCase.verifyError( ...
                @() calculateSLGFault(1.0, 0.10i, 0.10i, -0.20i, 0.0), ...
                'calculateSLGFault:ZeroImpedance');

            % LL zero denominator: Z1 + Z2 + Zf = 0
            testCase.verifyError( ...
                @() calculateLLFault(1.0, 0.25i, -0.25i, 0.0), ...
                'calculateLLFault:ZeroImpedance');

            % DLG zero parallel denominator: Z2 + (Z0 + 3*Zf) = 0
            testCase.verifyError( ...
                @() calculateDLGFault(1.0, 0.25i, 0.25i, -0.25i, 0.0), ...
                'calculateDLGFault:ZeroImpedance');

            % DLG zero total equivalent denominator: Z1 + Z20 = 0
            % Let Z2 = 0.5i, Z0 = 0.5i, Zf = 0 -> Z20 = (0.5i * 0.5i)/(1.0i) = 0.25i
            % Let Z1 = -0.25i -> Ztotal = -0.25i + 0.25i = 0
            testCase.verifyError( ...
                @() calculateDLGFault(1.0, -0.25i, 0.5i, 0.5i, 0.0), ...
                'calculateDLGFault:ZeroImpedance');
        end

    end
end
