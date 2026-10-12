classdef TestCalculateLLFault < matlab.unittest.TestCase

    methods (Test)

        function testBoltedLLFault(testCase)
            fault = calculateLLFault(1, 0.1, 0.1, 0);

            expectedPositiveCurrent = 5;
            expectedPhaseCurrentMagnitude = sqrt(3) * expectedPositiveCurrent;

            testCase.verifyEqual( ...
                fault.I0_pu, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.I1_pu, expectedPositiveCurrent, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.I2_pu, -expectedPositiveCurrent, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.Ia_pu, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                abs(fault.Ib_pu), expectedPhaseCurrentMagnitude, ...
                'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                abs(fault.Ic_pu), expectedPhaseCurrentMagnitude, ...
                'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.Ib_pu + fault.Ic_pu, 0, 'AbsTol', 1e-10);
        end

        function testFaultImpedance(testCase)
            fault = calculateLLFault(1, 0.1, 0.1, 0.1);

            testCase.verifyEqual( ...
                fault.I1_pu, 10/3, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.I2_pu, -10/3, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.I0_pu, 0, 'AbsTol', 1e-10);
        end

        function testZeroImpedance(testCase)
            testCase.verifyError( ...
                @() calculateLLFault(1, 0, 0, 0), ...
                'calculateLLFault:ZeroImpedance');
        end

    end
end
