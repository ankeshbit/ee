
classdef TestCalculateDLGFault < matlab.unittest.TestCase

    methods (Test)

        function testBoltedDLGFault(testCase)
            fault = calculateDLGFault(1, 0.1, 0.1, 0.1, 0);

            testCase.verifyEqual( ...
                fault.I1_pu, 20/3, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.I2_pu, -10/3, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.I0_pu, -10/3, 'AbsTol', 1e-10);

            testCase.verifyEqual( ...
                fault.Ia_pu, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.Ib_pu + fault.Ic_pu, ...
                3*fault.I0_pu, 'AbsTol', 1e-10);
        end


        function testFaultImpedance(testCase)
            fault = calculateDLGFault(1, 0.1, 0.1, 0.1, 0.1);

            testCase.verifyEqual( ...
                fault.I1_pu, 50/9, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.I2_pu, -40/9, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.I0_pu, -10/9, 'AbsTol', 1e-10);

            % For a B-C-to-ground fault, phase A is unfaulted.
            testCase.verifyEqual( ...
                fault.Ia_pu, 0, 'AbsTol', 1e-10);

            % Ground current equals the sum of the two faulted phase currents.
            testCase.verifyEqual( ...
                fault.Ib_pu + fault.Ic_pu, ...
                3*fault.I0_pu, 'AbsTol', 1e-10);
        end


        function testZeroParallelDenominator(testCase)
            testCase.verifyError( ...
                @() calculateDLGFault(1, 0.1, 0.1, -0.1, 0), ...
                'calculateDLGFault:ZeroImpedance');
        end

    end
end
