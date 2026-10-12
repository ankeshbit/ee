classdef TestCalculateBaseValues < matlab.unittest.TestCase
    methods (Test)
        function testStandard11kVSystem(testCase)
            b = calculateBaseValues(100e6, 11e3);

            testCase.verifyEqual(b.SbaseVA, 100e6);
            testCase.verifyEqual(b.VbaseV, 11e3);
            testCase.verifyEqual(b.IbaseA, 100e6/(sqrt(3)*11e3), ...
                'RelTol', 1e-12);
            testCase.verifyEqual(b.ZbaseOhm, 1.21, ...
                'RelTol', 1e-12);
        end

        function testInvalidPowerBase(testCase)
            testCase.verifyError( ...
                @() calculateBaseValues(0, 11e3), ...
                'MATLAB:expectedPositive');
        end
    end
end
