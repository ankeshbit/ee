classdef TestDynamicSimulationEntryPoint < matlab.unittest.TestCase
% TestDynamicSimulationEntryPoint Unit tests for runDynamicFaultSimulation.

    properties
        validNetwork
        validScenario
    end

    methods (TestMethodSetup)
        function setupData(testCase)
            testCase.validNetwork = createIllustrativeRadialNetwork();
            testCase.validScenario = struct( ...
                'scenarioId', 'SCN_3PH_BUS_B', ...
                'faultedBus', 'BUS_B', ...
                'faultType', '3PH', ...
                'Zf_pu', 0.05);
        end
    end

    methods (Test)

        function testEntryPointBlockedInCurrentEnvironment(testCase)
            options = struct('quiet', true);
            diag = checkSimulationCapabilities(options);
            simResult = runDynamicFaultSimulation( ...
                testCase.validNetwork, testCase.validScenario, struct(), {}, options);

            if strcmp(diag.status, 'READY')
                testCase.verifyEqual(simResult.status, 'SIMULATION_COMPLETED');
                testCase.verifyTrue(simResult.isSimulated);
                testCase.verifyNotEmpty(simResult.time_s);
            else
                testCase.verifyEqual(simResult.status, 'BLOCKED');
                testCase.verifyFalse(simResult.isSimulated);
                testCase.verifyEmpty(simResult.time_s);
            end

            % Schema validity
            testCase.verifyTrue(validateSimulationResult(simResult));
        end

        function testEntryPointRejectsInvalidInput(testCase)
            badScenario = testCase.validScenario;
            badScenario.faultedBus = 'NON_EXISTENT';
            options = struct('quiet', true);

            simResult = runDynamicFaultSimulation( ...
                testCase.validNetwork, badScenario, struct(), {}, options);

            testCase.verifyEqual(simResult.status, 'BUILD_FAILED');
            testCase.verifyFalse(simResult.isSimulated);
            testCase.verifyNotEmpty(simResult.errors);
        end

        function testEntryPointWithInjectedBlockedProduct(testCase)
            options = struct('quiet', true);
            options.overrides = struct( ...
                'simulinkInstalled', false, ...
                'simulinkLicensed', false, ...
                'simscapeInstalled', true, ...
                'simscapeLicensed', true, ...
                'simscapeElectricalInstalled', true, ...
                'simscapeElectricalLicensed', false, ...
                'modelBuildingAPIsAvailable', true, ...
                'simulationAPIsAvailable', true, ...
                'componentsAvailable', true);

            simResult = runDynamicFaultSimulation( ...
                testCase.validNetwork, testCase.validScenario, struct(), {}, options);

            testCase.verifyEqual(simResult.status, 'BLOCKED');
            testCase.verifyFalse(simResult.isSimulated);
            testCase.verifyTrue(any(contains(simResult.warnings, 'BLOCKED_MISSING_PRODUCT')));
        end

        function testEntryPointHandoffWithInjectedReadyEnvironment(testCase)
            options = struct('quiet', true);
            options.overrides = struct( ...
                'simulinkInstalled', true, ...
                'simulinkLicensed', true, ...
                'simscapeInstalled', true, ...
                'simscapeLicensed', true, ...
                'simscapeElectricalInstalled', true, ...
                'simscapeElectricalLicensed', true, ...
                'modelBuildingAPIsAvailable', true, ...
                'simulationAPIsAvailable', true, ...
                'componentsAvailable', true);

            % In READY environment, physical simulation completes successfully
            simResult = runDynamicFaultSimulation( ...
                testCase.validNetwork, testCase.validScenario, struct(), {}, options);

            testCase.verifyEqual(simResult.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(simResult.isSimulated);
            testCase.verifyNotEmpty(simResult.time_s);
            testCase.verifyTrue(validateSimulationResult(simResult));
        end

    end

end
