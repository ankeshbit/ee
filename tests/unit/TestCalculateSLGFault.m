
classdef TestCalculateSLGFault < matlab.unittest.TestCase

    methods (Test)

        function testBoltedSLGFault(testCase)
            fault = calculateSLGFault(1, 0.1, 0.1, 0.1, 0);

            expectedSequenceCurrent = 1 / 0.3;

            testCase.verifyEqual( ...
                fault.I0_pu, expectedSequenceCurrent, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.I1_pu, expectedSequenceCurrent, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.I2_pu, expectedSequenceCurrent, 'AbsTol', 1e-10);

            testCase.verifyEqual( ...
                fault.Ia_pu, 10, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.Ib_pu, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.Ic_pu, 0, 'AbsTol', 1e-10);
        end

        function testFaultImpedance(testCase)
            fault = calculateSLGFault(1, 0.1, 0.1, 0.1, 0.1);

            expectedSequenceCurrent = 1 / 0.6;

            testCase.verifyEqual( ...
                fault.I0_pu, expectedSequenceCurrent, 'AbsTol', 1e-10);
            testCase.verifyEqual( ...
                fault.Ia_pu, 3*expectedSequenceCurrent, 'AbsTol', 1e-10);
        end

        function testZeroTotalImpedance(testCase)
            testCase.verifyError( ...
                @() calculateSLGFault(1, 0, 0, 0, 0), ...
                'calculateSLGFault:ZeroImpedance');
        end

    end
end
