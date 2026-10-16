classdef TestSimulationContractsAndValidation < matlab.unittest.TestCase
% TestSimulationContractsAndValidation Unit tests for schema and input/output contracts.

    properties
        validNetwork
        validScenario
    end

    methods (TestMethodSetup)
        function setupData(testCase)
            testCase.validNetwork = createIllustrativeRadialNetwork();
            testCase.validScenario = struct( ...
                'scenarioId', 'SCN_3PH_B', ...
                'faultedBus', 'BUS_B', ...
                'faultType', '3PH', ...
                'Zf_pu', 0.05);
        end
    end

    methods (Test)

        function testValidSimulationInput(testCase)
            config = validateSimulationInput(testCase.validNetwork, testCase.validScenario);

            testCase.verifyEqual(config.scenario.scenarioId, 'SCN_3PH_B');
            testCase.verifyEqual(config.scenario.faultedBus, 'BUS_B');
            testCase.verifyEqual(config.scenario.faultType, '3PH');
            testCase.verifyEqual(config.scenario.Zf_pu, 0.05);
            testCase.verifyEqual(config.scenario.faultInsertionTime_s, 0.05);
            testCase.verifyEqual(config.scenario.simulationStopTime_s, 0.20);
            testCase.verifyEqual(config.simConfig.solver, 'ode23t');
            testCase.verifyEqual(config.simConfig.systemFrequency_Hz, 50.0);
            testCase.verifyNotEmpty(config.measurementLocations);
        end

        function testMissingScenarioFieldThrows(testCase)
            badScenario = struct('faultedBus', 'BUS_B', 'faultType', '3PH');
            testCase.verifyError( ...
                @() validateSimulationInput(testCase.validNetwork, badScenario), ...
                'validateSimulationInput:MissingScenarioField');
        end

        function testEmptyScenarioIdThrows(testCase)
            badScenario = testCase.validScenario;
            badScenario.scenarioId = '   ';
            testCase.verifyError( ...
                @() validateSimulationInput(testCase.validNetwork, badScenario), ...
                'validateSimulationInput:EmptyScenarioId');
        end

        function testInvalidFaultedBusThrows(testCase)
            badScenario = testCase.validScenario;
            badScenario.faultedBus = 'NON_EXISTENT_BUS';
            testCase.verifyError( ...
                @() validateSimulationInput(testCase.validNetwork, badScenario), ...
                'validateSimulationInput:InvalidFaultedBus');
        end

        function testUnsupportedFaultTypeThrows(testCase)
            badScenario = testCase.validScenario;
            badScenario.faultType = 'UNSUPPORTED_TYPE';
            testCase.verifyError( ...
                @() validateSimulationInput(testCase.validNetwork, badScenario), ...
                'validateSimulationInput:InvalidFaultType');
        end

        function testNegativeImpedanceThrows(testCase)
            badScenario = testCase.validScenario;
            badScenario.Zf_pu = -0.1;
            testCase.verifyError( ...
                @() validateSimulationInput(testCase.validNetwork, badScenario), ...
                'MATLAB:validateSimulationInput:expectedNonnegative');
        end

        function testInvalidStopTimeThrows(testCase)
            badScenario = testCase.validScenario;
            badScenario.faultInsertionTime_s = 0.10;
            badScenario.simulationStopTime_s = 0.05;
            testCase.verifyError( ...
                @() validateSimulationInput(testCase.validNetwork, badScenario), ...
                'validateSimulationInput:InvalidStopTime');
        end

        function testInvalidMeasurementLocationThrows(testCase)
            testCase.verifyError( ...
                @() validateSimulationInput(testCase.validNetwork, testCase.validScenario, ...
                    struct(), {'UNKNOWN_FEEDER'}), ...
                'validateSimulationInput:UnknownMeasurementLocation');
        end

        function testCreateResultSchemaDefault(testCase)
            res = createSimulationResultSchema('NOT_RUN', 'SCN_01');
            testCase.verifyEqual(res.status, 'NOT_RUN');
            testCase.verifyEqual(res.scenarioId, 'SCN_01');
            testCase.verifyFalse(res.isSimulated);
            testCase.verifyEmpty(res.time_s);

            isValid = validateSimulationResult(res);
            testCase.verifyTrue(isValid);
        end

        function testRejectionOfFalsifiedSimulationResult(testCase)
            fakeRes = createSimulationResultSchema('BLOCKED', 'SCN_01');
            fakeRes.isSimulated = true; % Dishonest claim
            testCase.verifyError( ...
                @() validateSimulationResult(fakeRes), ...
                'validateSimulationResult:FalseSimulationClaim');
        end

        function testRejectionOfInventedMeasurementsOnBlockedResult(testCase)
            fakeRes = createSimulationResultSchema('BLOCKED', 'SCN_01');
            fakeRes.time_s = [0, 0.01, 0.02]; % Dishonest fake data
            testCase.verifyError( ...
                @() validateSimulationResult(fakeRes), ...
                'validateSimulationResult:InventedMeasurements');
        end

        function testValidSimulatedResultPasses(testCase)
            validRes = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
            validRes.isSimulated = true;
            validRes.time_s = linspace(0, 0.2, 2001);
            validRes.isValidMeasurementWindow = true;

            testCase.verifyTrue(validateSimulationResult(validRes));
        end

        function testCompareWithIncompatibleBasesRejected(testCase)
            simRes = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
            simRes.isSimulated = true;
            simRes.time_s = linspace(0, 0.2, 2001);
            simRes.isValidMeasurementWindow = true;

            options = struct();
            options.simulatedVal = 2099.46;
            options.analyticalBasis = struct('VbaseV', 11e3);
            options.simulatedBasis  = struct('VbaseV', 33e3); % Mismatched side!

            comp = compareAnalyticalAndSimulation(2099.46, simRes, 'current_A', 'BUS_B', options);
            testCase.verifyEqual(comp.status, 'INCOMPATIBLE_BASIS');
            testCase.verifyTrue(contains(comp.explanation, 'Incompatible voltage bases'));
        end

        function testCompareWithBlockedSimulationIsSkipped(testCase)
            blockedRes = createSimulationResultSchema('BLOCKED', 'SCN_01');
            comp = compareAnalyticalAndSimulation(2099.46, blockedRes, 'current_A', 'BUS_B');
            testCase.verifyEqual(comp.status, 'SKIPPED');
            testCase.verifyTrue(contains(comp.explanation, 'not executed'));
        end

        function testComparePassAndFailTolerances(testCase)
            simRes = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
            simRes.isSimulated = true;
            simRes.time_s = linspace(0, 0.2, 2001);
            simRes.isValidMeasurementWindow = true;

            % Within tolerance: 2099.46 vs 2100.0 (error < 0.03%)
            optPass = struct('simulatedVal', 2100.0, 'relTolPercent', 2.0);
            compPass = compareAnalyticalAndSimulation(2099.46, simRes, 'current_A', 'BUS_B', optPass);
            testCase.verifyEqual(compPass.status, 'PASSED');

            % Exceeding tolerance: 2099.46 vs 2300.0 (error ~9.5%)
            optFail = struct('simulatedVal', 2300.0, 'relTolPercent', 2.0, 'absTol', 10.0);
            compFail = compareAnalyticalAndSimulation(2099.46, simRes, 'current_A', 'BUS_B', optFail);
            testCase.verifyEqual(compFail.status, 'FAILED');
        end

        function testCompareZeroAnalyticalBenchmarkRequiresAbsoluteTolerance(testCase)
            simRes = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
            simRes.isSimulated = true;
            simRes.time_s = linspace(0, 0.2, 2001);
            simRes.isValidMeasurementWindow = true;

            % Analytical 0, simulated 10000, absTol 0.01 must FAIL
            optFail = struct('simulatedVal', 10000.0, 'absTol', 0.01, 'relTolPercent', 5.0);
            compFail = compareAnalyticalAndSimulation(0.0, simRes, 'current_A', 'BUS_B', optFail);
            testCase.verifyEqual(compFail.status, 'FAILED');

            % Analytical 0, simulated 0.005, absTol 0.01 must pass
            optPass = struct('simulatedVal', 0.005, 'absTol', 0.01, 'relTolPercent', 5.0);
            compPass = compareAnalyticalAndSimulation(0.0, simRes, 'current_A', 'BUS_B', optPass);
            testCase.verifyEqual(compPass.status, 'PASSED');
        end

    end

end
