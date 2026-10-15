classdef TestTextbookIndependentValidation < matlab.unittest.TestCase
    % TestTextbookIndependentValidation Independently derived reference benchmarks.
    % Compares symmetrical component solver outputs against hand-calculated sequence
    % derivations documented in docs/textbook_reference_derivations.md.
    %
    % Textbook System:
    %   Sbase = 100 MVA, Vbase = 11 kV (Ibase = 5248.638024 A)
    %   Vth = 1.0 pu, Z1 = 0.25j pu, Z2 = 0.25j pu, Z0 = 0.50j pu

    properties
        Vth = 1.0;
        Z1 = 0.25i;
        Z2 = 0.25i;
        Z0 = 0.50i;
        Ibase_A = 5248.638024;
    end

    methods (Test)

        %% Case 1: Symmetrical Three-Phase Fault (3PH)
        function testThreePhaseBoltedTextbookCase(testCase)
            % Bolted 3PH: If_pu = Vth / Z1 = 1.0 / (0.25j) = -4.0j pu (|If| = 4.0 pu)
            % If_A = 4.0 * 5248.638024 = 20,994.5521 A
            Zf = 0.0;
            If_pu = calculateThreePhaseFault(testCase.Vth, testCase.Z1, Zf);

            testCase.verifyEqual(real(If_pu), 0.0, 'AbsTol', 1e-12);
            testCase.verifyEqual(imag(If_pu), -4.0, 'AbsTol', 1e-12);
            testCase.verifyEqual(abs(If_pu), 4.0, 'AbsTol', 1e-12);

            If_A = abs(If_pu) * testCase.Ibase_A;
            testCase.verifyEqual(If_A, 20994.5521, 'RelTol', 1e-6);
        end

        function testThreePhaseImpedanceTextbookCase(testCase)
            % Zf = 0.05 pu: Ztotal = 0.05 + 0.25j (|Ztotal| = sqrt(0.065) approx 0.25495098 pu)
            % |If_pu| = 1.0 / sqrt(0.065) approx 3.9223227 pu
            % If_A = 3.9223227 * 5248.638024 approx 20,586.848 A
            Zf = 0.05;
            If_pu = calculateThreePhaseFault(testCase.Vth, testCase.Z1, Zf);

            expected_mag = 1.0 / sqrt(0.05^2 + 0.25^2);
            testCase.verifyEqual(abs(If_pu), expected_mag, 'AbsTol', 1e-9);

            If_A = abs(If_pu) * testCase.Ibase_A;
            testCase.verifyEqual(If_A, 20586.848, 'RelTol', 1e-5);
        end

        %% Case 2: Single-Line-to-Ground Fault (SLG)
        function testSLGBoltedTextbookCase(testCase)
            % Bolted SLG: Ztotal = Z1 + Z2 + Z0 = 1.0j pu
            % I1 = 1.0 / (1.0j) = -1.0j pu
            % Ia = 3 * I1 = -3.0j pu (|Ia| = 3.0 pu)
            % If_A = 3.0 * 5248.638024 = 15,745.9141 A
            Zf = 0.0;
            fault = calculateSLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, Zf);

            testCase.verifyEqual(fault.I1_pu, -1.0i, 'AbsTol', 1e-12);
            testCase.verifyEqual(fault.I2_pu, -1.0i, 'AbsTol', 1e-12);
            testCase.verifyEqual(fault.I0_pu, -1.0i, 'AbsTol', 1e-12);

            testCase.verifyEqual(abs(fault.Ia_pu), 3.0, 'AbsTol', 1e-12);
            testCase.verifyEqual(abs(fault.Ib_pu), 0.0, 'AbsTol', 1e-12);
            testCase.verifyEqual(abs(fault.Ic_pu), 0.0, 'AbsTol', 1e-12);

            Ia_A = abs(fault.Ia_pu) * testCase.Ibase_A;
            testCase.verifyEqual(Ia_A, 15745.9141, 'RelTol', 1e-6);
        end

        function testSLGImpedanceTextbookCase(testCase)
            % Zf = 0.05 pu: Ztotal = 3*0.05 + 1.0j = 0.15 + 1.0j pu (|Ztotal| = sqrt(1.0225) approx 1.01118742)
            % |I1| = 1.0 / sqrt(1.0225) approx 0.98893635 pu
            % |Ia| = 3 * |I1| approx 2.96680905 pu
            % If_A approx 15,571.706 A
            Zf = 0.05;
            fault = calculateSLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, Zf);

            expected_I1_mag = 1.0 / sqrt(0.15^2 + 1.0^2);
            expected_Ia_mag = 3 * expected_I1_mag;

            testCase.verifyEqual(abs(fault.I1_pu), expected_I1_mag, 'AbsTol', 1e-9);
            testCase.verifyEqual(abs(fault.Ia_pu), expected_Ia_mag, 'AbsTol', 1e-9);

            Ia_A = abs(fault.Ia_pu) * testCase.Ibase_A;
            testCase.verifyEqual(Ia_A, 15571.706, 'RelTol', 1e-5);
        end

        %% Case 3: Line-to-Line Fault (LL)
        function testLLBoltedTextbookCase(testCase)
            % Bolted LL: Z1 + Z2 = 0.5j pu
            % I1 = 1.0 / (0.5j) = -2.0j pu, I0 = 0, I2 = 2.0j pu
            % |Ib| = |Ic| = sqrt(3) * 2.0 = 2*sqrt(3) approx 3.464101615 pu
            % If_A = 2*sqrt(3) * 5248.638024 approx 18,181.821 A
            Zf = 0.0;
            fault = calculateLLFault(testCase.Vth, testCase.Z1, testCase.Z2, Zf);

            testCase.verifyEqual(fault.I0_pu, 0.0, 'AbsTol', 1e-12);
            testCase.verifyEqual(fault.I1_pu, -2.0i, 'AbsTol', 1e-12);
            testCase.verifyEqual(fault.I2_pu, 2.0i, 'AbsTol', 1e-12);
            testCase.verifyEqual(abs(fault.Ia_pu), 0.0, 'AbsTol', 1e-12);

            expected_Ibc = 2 * sqrt(3);
            testCase.verifyEqual(abs(fault.Ib_pu), expected_Ibc, 'AbsTol', 1e-9);
            testCase.verifyEqual(abs(fault.Ic_pu), expected_Ibc, 'AbsTol', 1e-9);

            If_A = abs(fault.Ib_pu) * testCase.Ibase_A;
            testCase.verifyEqual(If_A, 18181.821, 'RelTol', 1e-5);
        end

        function testLLImpedanceTextbookCase(testCase)
            % Zf = 0.05 pu: Ztotal = 0.05 + 0.5j pu (|Ztotal| = sqrt(0.2525) approx 0.50249378)
            % |I1| = 1.0 / sqrt(0.2525) approx 1.9900744 pu
            % |Ib| = sqrt(3) * |I1| approx 3.4469106 pu
            % If_A approx 18,091.59 A
            Zf = 0.05;
            fault = calculateLLFault(testCase.Vth, testCase.Z1, testCase.Z2, Zf);

            expected_I1 = 1.0 / sqrt(0.05^2 + 0.5^2);
            expected_Ibc = sqrt(3) * expected_I1;

            testCase.verifyEqual(abs(fault.I1_pu), expected_I1, 'AbsTol', 1e-9);
            testCase.verifyEqual(abs(fault.Ib_pu), expected_Ibc, 'AbsTol', 1e-9);

            If_A = abs(fault.Ib_pu) * testCase.Ibase_A;
            testCase.verifyEqual(If_A, 18091.59, 'RelTol', 1e-5);
        end

        %% Case 4: Double-Line-to-Ground Fault (DLG)
        function testDLGBoltedTextbookCase(testCase)
            % Bolted DLG: Zparallel = (0.25j * 0.5j) / (0.75j) = (1/6)j pu
            % Ztotal = 0.25j + (1/6)j = (5/12)j pu
            % I1 = 1 / ((5/12)j) = -2.4j pu
            % I2 = -I1 * (0.5/0.75) = 1.6j pu
            % I0 = -I1 * (0.25/0.75) = 0.8j pu
            % |Ib| = |Ic| = sqrt(13.44) approx 3.666060556 pu
            % If_max,A = 3.666060556 * 5248.638024 approx 19,241.82 A
            % Ig = 3 * I0 = 2.4j pu -> |Ig_A| = 2.4 * 5248.638024 = 12,596.731 A
            Zf = 0.0;
            fault = calculateDLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, Zf);

            testCase.verifyEqual(fault.I1_pu, -2.4i, 'AbsTol', 1e-12);
            testCase.verifyEqual(fault.I2_pu, 1.6i, 'AbsTol', 1e-12);
            testCase.verifyEqual(fault.I0_pu, 0.8i, 'AbsTol', 1e-12);
            testCase.verifyEqual(abs(fault.Ia_pu), 0.0, 'AbsTol', 1e-12);

            expected_Ibc = sqrt(13.44);
            testCase.verifyEqual(abs(fault.Ib_pu), expected_Ibc, 'AbsTol', 1e-9);
            testCase.verifyEqual(abs(fault.Ic_pu), expected_Ibc, 'AbsTol', 1e-9);

            If_max_A = abs(fault.Ib_pu) * testCase.Ibase_A;
            testCase.verifyEqual(If_max_A, 19241.82, 'RelTol', 1e-5);

            Ig_A = abs(fault.Ib_pu + fault.Ic_pu) * testCase.Ibase_A;
            testCase.verifyEqual(Ig_A, 12596.731, 'RelTol', 1e-5);
        end

        function testDLGImpedanceTextbookCase(testCase)
            % Zf = 0.05 pu:
            % Hand derivation from docs/textbook_reference_derivations.md:
            % I1 approx 0.09077156 - 2.37821483j pu
            % I2 approx 0.09077156 + 1.62178517j pu
            % I0 approx -0.18154312 + 0.75642965j pu
            % |Ib| approx 3.90489754 pu, |Ic| approx 3.38746542 pu
            % If_max,A approx 20,495.39 A
            % Ig_A = 3 * |I0| * Ibase approx 12,248.33 A
            Zf = 0.05;
            fault = calculateDLGFault(testCase.Vth, testCase.Z1, testCase.Z2, testCase.Z0, Zf);

            testCase.verifyEqual(real(fault.I1_pu), 0.09077156, 'AbsTol', 1e-6);
            testCase.verifyEqual(imag(fault.I1_pu), -2.37821483, 'AbsTol', 1e-6);

            testCase.verifyEqual(real(fault.I2_pu), 0.09077156, 'AbsTol', 1e-6);
            testCase.verifyEqual(imag(fault.I2_pu), 1.62178517, 'AbsTol', 1e-6);

            testCase.verifyEqual(real(fault.I0_pu), -0.18154312, 'AbsTol', 1e-6);
            testCase.verifyEqual(imag(fault.I0_pu), 0.75642965, 'AbsTol', 1e-6);

            testCase.verifyEqual(abs(fault.Ia_pu), 0.0, 'AbsTol', 1e-12);
            testCase.verifyEqual(abs(fault.Ib_pu), 3.90489754, 'AbsTol', 1e-5);
            testCase.verifyEqual(abs(fault.Ic_pu), 3.38746542, 'AbsTol', 1e-5);

            If_max_A = max(abs(fault.Ib_pu), abs(fault.Ic_pu)) * testCase.Ibase_A;
            testCase.verifyEqual(If_max_A, 20495.39, 'RelTol', 1e-5);

            Ig_A = abs(fault.Ib_pu + fault.Ic_pu) * testCase.Ibase_A;
            testCase.verifyEqual(Ig_A, 12248.90, 'RelTol', 1e-4);
        end


    end
end
