classdef TestCalculateThreePhaseFault < matlab.unittest.TestCase
    methods (Test)
        function testBoltedFault(testCase)
            If = calculateThreePhaseFault(1, 0.1 + 0.2i, 0);
            expected = 1 / (0.1 + 0.2i);

            testCase.verifyEqual(If, expected, 'AbsTol', 1e-12);
        end

        function testFaultImpedance(testCase)
            If = calculateThreePhaseFault(1, 0.1i, 0.1i);

            testCase.verifyEqual(If, -5i, 'AbsTol', 1e-12);
        end

        function testZeroTotalImpedance(testCase)
            testCase.verifyError( ...
                @() calculateThreePhaseFault(1, 0, 0), ...
                'calculateThreePhaseFault:ZeroImpedance');
        end
    end
end
