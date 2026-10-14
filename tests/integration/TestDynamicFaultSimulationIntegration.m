classdef TestDynamicFaultSimulationIntegration < matlab.unittest.TestCase
% TestDynamicFaultSimulationIntegration Integration test for dynamic Simscape simulation.
%
% This integration test requires a fully licensed and verified Simscape Electrical
% environment. If the capability diagnostic reports any status other than READY,
% the test uses assumeTrue to cleanly mark the test as unavailable/incomplete,
% preventing unexecuted tests from being falsely reported as passing.

    properties
        diagnostic
        network
        scenario
    end

    methods (TestClassSetup)
        function checkEnvironment(testCase)
            options = struct('quiet', true);
            testCase.diagnostic = checkSimulationCapabilities(options);
            testCase.network = createIllustrativeRadialNetwork();
            testCase.scenario = struct( ...
                'scenarioId', 'INT_3PH_BUS_B', ...
                'faultedBus', 'BUS_B', ...
                'faultType', '3PH', ...
                'Zf_pu', 0.05, ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.20);
        end
    end

    methods (Test)

        function testPhysicalSimulationExecution(testCase)
            % Check if prerequisites are satisfied. If not, mark test as unavailable (incomplete).
            isReady = strcmp(testCase.diagnostic.status, 'READY');
            testCase.assumeTrue(isReady, sprintf( ...
                ['Dynamic Simscape Electrical simulation is unavailable in current environment: %s. ', ...
                 'License status: Simscape_Electrical=%d. Integration test skipped pending valid license.'], ...
                testCase.diagnostic.status, testCase.diagnostic.simscapeElectricalLicensed));

            % The following executes ONLY when the environment is confirmed READY
            simResult = runDynamicFaultSimulation(testCase.network, testCase.scenario);

            testCase.verifyEqual(simResult.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(simResult.isSimulated);
            testCase.verifyNotEmpty(simResult.time_s);
            testCase.verifyTrue(simResult.isValidMeasurementWindow);

            % Verify cross-engine benchmark comparison against analytical result (2099.46 A)
            expectedAnalytical_A = 2099.46;
            comp = compareAnalyticalAndSimulation( ...
                expectedAnalytical_A, simResult, 'faultCurrent_A', 'BUS_B');
            testCase.verifyEqual(comp.status, 'PASSED');
        end

    end

end
