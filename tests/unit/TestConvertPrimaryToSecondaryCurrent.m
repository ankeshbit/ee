classdef TestConvertPrimaryToSecondaryCurrent < matlab.unittest.TestCase

    methods (Test)

        function testFourHundredToFiveCT(testCase)
            actual = convertPrimaryToSecondaryCurrent(240, 400, 5);

            testCase.verifyEqual(actual, 3, 'AbsTol', 1e-12);
        end

        function testEightHundredToOneCT(testCase)
            actual = convertPrimaryToSecondaryCurrent(400, 800, 1);

            testCase.verifyEqual(actual, 0.5, 'AbsTol', 1e-12);
        end

        function testZeroPrimaryCurrent(testCase)
            testCase.verifyEqual( ...
                convertPrimaryToSecondaryCurrent(0, 400, 5), 0);
        end

        function testInvalidPrimaryCurrent(testCase)
            testCase.verifyError( ...
                @() convertPrimaryToSecondaryCurrent(-1, 400, 5), ...
                'convertPrimaryToSecondaryCurrent:InvalidCurrent');
        end

        function testInvalidCTRatings(testCase)
            invalidRatings = {0, -1, NaN, Inf, 1 + 1i, [400 800], '400'};

            for inputIndex = 1:numel(invalidRatings)
                testCase.verifyError( ...
                    @() convertPrimaryToSecondaryCurrent(100, ...
                    invalidRatings{inputIndex}, 5), ...
                    'convertPrimaryToSecondaryCurrent:InvalidCTRating');
                testCase.verifyError( ...
                    @() convertPrimaryToSecondaryCurrent(100, 400, ...
                    invalidRatings{inputIndex}), ...
                    'convertPrimaryToSecondaryCurrent:InvalidCTRating');
            end
        end

        function testInvalidPrimaryCurrentValues(testCase)
            invalidCurrents = {NaN, Inf, 1 + 1i, [1 2], '100'};

            for inputIndex = 1:numel(invalidCurrents)
                testCase.verifyError( ...
                    @() convertPrimaryToSecondaryCurrent( ...
                    invalidCurrents{inputIndex}, 400, 5), ...
                    'convertPrimaryToSecondaryCurrent:InvalidCurrent');
            end
        end

    end
end
