classdef TestCompareAnalyticalAndSimulationRegression < matlab.unittest.TestCase
% TestCompareAnalyticalAndSimulationRegression Regression tests for Bug 2.3:
% Validates tolerances, finite inputs, complex phasors, simulation status mapping,
% power/voltage bases, and error handling in compareAnalyticalAndSimulation.

    methods (Test)

        function testRejectNaNAnalyticalValue(testCase)
            simRes = p_buildValidSimResult();
            comp = compareAnalyticalAndSimulation(NaN, simRes, 'current_A', 'BUS_B');
            testCase.verifyEqual(comp.status, 'INVALID_MEASUREMENT');
            testCase.verifyTrue(contains(comp.explanation, 'Analytical value must be a non-empty, finite'));
        end

        function testRejectInfAnalyticalValue(testCase)
            simRes = p_buildValidSimResult();
            comp = compareAnalyticalAndSimulation(Inf, simRes, 'current_A', 'BUS_B');
            testCase.verifyEqual(comp.status, 'INVALID_MEASUREMENT');
        end

        function testRejectNegativeTolerance(testCase)
            simRes = p_buildValidSimResult();
            testCase.verifyError( ...
                @() compareAnalyticalAndSimulation(100, simRes, 'current_A', 'BUS_B', struct('relTolPercent', -2.0)), ...
                'compareAnalyticalAndSimulation:InvalidTolerance');
            testCase.verifyError( ...
                @() compareAnalyticalAndSimulation(100, simRes, 'current_A', 'BUS_B', struct('absTol', -0.5)), ...
                'compareAnalyticalAndSimulation:InvalidTolerance');
        end

        function testComplexPhasorComparison(testCase)
            simRes = p_buildValidSimResult();
            % Analytical phasor: 100 + 50j
            anaPhasor = 100 + 50j;
            % Simulated phasor: 101 + 49j (abs diff ~ 1.414, relative ~ 1.26%)
            simPhasor = 101 + 49j;

            opts = struct('simulatedVal', simPhasor, 'relTolPercent', 2.0);
            comp = compareAnalyticalAndSimulation(anaPhasor, simRes, 'phasor_A', 'BUS_B', opts);
            testCase.verifyEqual(comp.status, 'PASSED');
            testCase.verifyEqual(comp.absoluteError, abs(simPhasor - anaPhasor), 'AbsTol', 1e-6);
        end

        function testBlockedSimulationReturnsBlocked(testCase)
            blockedRes = createSimulationResultSchema('BLOCKED', 'SCN_01');
            comp = compareAnalyticalAndSimulation(1000, blockedRes, 'current_A', 'BUS_B');
            testCase.verifyEqual(comp.status, 'BLOCKED');
            testCase.verifyTrue(contains(comp.explanation, 'blocked'));
        end

        function testFailedSimulationReturnsFailed(testCase)
            failRes = createSimulationResultSchema('SIMULATION_FAILED', 'SCN_01');
            comp = compareAnalyticalAndSimulation(1000, failRes, 'current_A', 'BUS_B');
            testCase.verifyEqual(comp.status, 'FAILED');
            testCase.verifyTrue(contains(comp.explanation, 'failed'));
        end

        function testInvalidMeasurementWindowReturnsInvalid(testCase)
            simRes = p_buildValidSimResult();
            simRes.isValidMeasurementWindow = false;
            comp = compareAnalyticalAndSimulation(1000, simRes, 'current_A', 'BUS_B');
            testCase.verifyEqual(comp.status, 'INVALID_MEASUREMENT');
        end

        function testIncompatiblePowerBasis(testCase)
            simRes = p_buildValidSimResult();
            opts = struct('simulatedVal', 1000, ...
                          'analyticalBasis', struct('SbaseVA', 10e6, 'VbaseV', 11e3), ...
                          'simulatedBasis', struct('SbaseVA', 100e6, 'VbaseV', 11e3)); % 100 MVA vs 10 MVA
            comp = compareAnalyticalAndSimulation(1000, simRes, 'current_A', 'BUS_B', opts);
            testCase.verifyEqual(comp.status, 'INCOMPATIBLE_BASIS');
            testCase.verifyTrue(contains(comp.explanation, 'Incompatible power bases'));
        end

        function testIncompatibleVoltageBasis(testCase)
            simRes = p_buildValidSimResult();
            opts = struct('simulatedVal', 1000, ...
                          'analyticalBasis', struct('VbaseV', 11e3), ...
                          'simulatedBasis', struct('VbaseV', 33e3)); % LV vs HV
            comp = compareAnalyticalAndSimulation(1000, simRes, 'current_A', 'BUS_B', opts);
            testCase.verifyEqual(comp.status, 'INCOMPATIBLE_BASIS');
        end

        function testZeroAnalyticalBenchmark(testCase)
            simRes = p_buildValidSimResult();
            % Zero benchmark with small residual current: 0.005 A, absTol = 0.01 A
            optsPass = struct('simulatedVal', 0.005, 'absTol', 0.01);
            compPass = compareAnalyticalAndSimulation(0.0, simRes, 'current_A', 'BUS_B', optsPass);
            testCase.verifyEqual(compPass.status, 'PASSED');
            testCase.verifyTrue(isnan(compPass.percentageError));

            % Zero benchmark with large residual current: 1.0 A, absTol = 0.01 A
            optsFail = struct('simulatedVal', 1.0, 'absTol', 0.01);
            compFail = compareAnalyticalAndSimulation(0.0, simRes, 'current_A', 'BUS_B', optsFail);
            testCase.verifyEqual(compFail.status, 'FAILED');
        end

        function testNonExistentLocationReturnsInvalid(testCase)
            simRes = p_buildValidSimResult();
            comp = compareAnalyticalAndSimulation(1000, simRes, 'current_A', 'NON_EXISTENT_BUS');
            testCase.verifyEqual(comp.status, 'INVALID_MEASUREMENT');
        end

        function testExplicitlySkippedSimulationReturnsSkipped(testCase)
            % Explicitly skipped simulation (NOT_RUN / SKIPPED) must return SKIPPED
            skippedRes = createSimulationResultSchema('NOT_RUN', 'SCN_01');
            comp = compareAnalyticalAndSimulation(1000, skippedRes, 'current_A', 'BUS_B');
            testCase.verifyEqual(comp.status, 'SKIPPED');
            testCase.verifyTrue(contains(comp.explanation, 'not executed'));
        end

        function testSuccessfulSimulationComparison(testCase)
            % Simulation result matches analytical within tolerance -> PASSED
            simRes = p_buildValidSimResult();
            comp = compareAnalyticalAndSimulation(1874.5, simRes, 'current_A', 'BUS_B', struct('relTolPercent', 2.0));
            testCase.verifyEqual(comp.status, 'PASSED');
            testCase.verifyEqual(comp.absoluteError, 0.0, 'AbsTol', 1e-4);
        end

        function testFailedComparisonDueToNumericalMismatch(testCase)
            % Discrepancy exceeds tolerance -> FAILED
            simRes = p_buildValidSimResult();
            % Analytical: 1874.5 A, simulated: 2500.0 A (discrepancy ~33%)
            comp = compareAnalyticalAndSimulation(1874.5, simRes, 'current_A', 'BUS_B', ...
                struct('simulatedVal', 2500.0, 'relTolPercent', 5.0, 'absTol', 1.0));
            testCase.verifyEqual(comp.status, 'FAILED');
            testCase.verifyTrue(comp.percentageError > 5.0);
            testCase.verifyTrue(contains(comp.explanation, 'Discrepancy exceeds tolerance'));
        end

        function testInvalidOrIncompleteSimulationMeasurements(testCase)
            % Case 1: Status MEASUREMENTS_INVALID
            simResInv = createSimulationResultSchema('MEASUREMENTS_INVALID', 'SCN_01');
            compInv = compareAnalyticalAndSimulation(1000, simResInv, 'current_A', 'BUS_B');
            testCase.verifyEqual(compInv.status, 'INVALID_MEASUREMENT');

            % Case 2: NaN simulated value
            simResNaN = p_buildValidSimResult();
            compNaN = compareAnalyticalAndSimulation(1000, simResNaN, 'current_A', 'BUS_B', struct('simulatedVal', NaN));
            testCase.verifyEqual(compNaN.status, 'INVALID_MEASUREMENT');

            % Case 3: Empty simulation struct
            compEmpty = compareAnalyticalAndSimulation(1000, struct(), 'current_A', 'BUS_B');
            testCase.verifyEqual(compEmpty.status, 'SKIPPED');
        end

    end

end

function res = p_buildValidSimResult()
    res = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
    res.isSimulated = true;
    res.time_s = linspace(0, 0.2, 2001);
    res.isValidMeasurementWindow = true;
    res.rms = struct('BUS_B', 1874.5);
    res.measurements = struct('BUS_B', 1874.5);
    res.phasors = struct('BUS_B', 1874.5);
end

