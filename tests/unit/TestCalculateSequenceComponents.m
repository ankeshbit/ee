
classdef TestCalculateSequenceComponents < matlab.unittest.TestCase

    methods (Test)

        function testBalancedPositiveSequence(testCase)
            a = exp(1i * 2*pi/3);
            V = [1; a^2; a];

            seq = calculateSequenceComponents(V);

            testCase.verifyEqual(seq.V0, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual(seq.V1, 1, 'AbsTol', 1e-10);
            testCase.verifyEqual(seq.V2, 0, 'AbsTol', 1e-10);
        end

        function testBalancedNegativeSequence(testCase)
            a = exp(1i * 2*pi/3);
            V = [1; a; a^2];

            seq = calculateSequenceComponents(V);

            testCase.verifyEqual(seq.V0, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual(seq.V1, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual(seq.V2, 1, 'AbsTol', 1e-10);
        end

        function testZeroSequence(testCase)
            V = [1; 1; 1];

            seq = calculateSequenceComponents(V);

            testCase.verifyEqual(seq.V0, 1, 'AbsTol', 1e-10);
            testCase.verifyEqual(seq.V1, 0, 'AbsTol', 1e-10);
            testCase.verifyEqual(seq.V2, 0, 'AbsTol', 1e-10);
        end

        function testInvalidInput(testCase)
            testCase.verifyError( ...
                @() calculateSequenceComponents([1; 2]), ...
                'MATLAB:incorrectNumel');
        end

    end
end
