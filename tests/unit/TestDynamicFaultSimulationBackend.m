classdef TestDynamicFaultSimulationBackend < matlab.unittest.TestCase
% TestDynamicFaultSimulationBackend Tests for Phase 3:
% Dynamic fault simulation backend execution, blocked state handling,
% and schema contract validation across supported fault types.

    properties
        network
        validScenario
    end

    methods (TestMethodSetup)
        function setupData(testCase)
            testCase.network = createIllustrativeRadialNetwork();
            testCase.validScenario = struct( ...
                'scenarioId', 'TEST_BACKEND_3PH', ...
                'faultedBus', 'BUS_B', ...
                'faultType', '3PH', ...
                'Zf_pu', 0.05, ...
                'faultInsertionTime_s', 0.05, ...
                'simulationStopTime_s', 0.15);
        end
    end

    methods (Test)

        function testBlockedEnvironmentHandling(testCase)
            % Force simulated blocked capability override
            overrides = struct('simscapeElectricalLicensed', false);
            opts = struct('quiet', true, 'overrides', overrides, 'allowPowerSystemBlocks', false);

            simRes = runDynamicFaultSimulation(testCase.network, testCase.validScenario, ...
                struct(), {}, opts);

            testCase.verifyEqual(simRes.status, 'BLOCKED');
            testCase.verifyFalse(simRes.isSimulated);
            testCase.verifyEmpty(simRes.time_s);
            testCase.verifyTrue(contains(simRes.provenance.source, 'BLOCKED'));
            testCase.verifyTrue(validateSimulationResult(simRes));
        end

        function testUnsupportedFaultTypeHandledGracefully(testCase)
            badScn = testCase.validScenario;
            badScn.faultType = 'UNSUPPORTED_TYPE';

            simRes = runDynamicFaultSimulation(testCase.network, badScn, struct(), {}, struct('quiet', true));
            testCase.verifyEqual(simRes.status, 'BUILD_FAILED');
            testCase.verifyFalse(simRes.isSimulated);
            testCase.verifyTrue(validateSimulationResult(simRes));
        end

        function testExecutionWhenEnvironmentReady(testCase)
            % Check if actual Simscape environment is ready
            diag = checkSimulationCapabilities(struct('quiet', true, 'allowPowerSystemBlocks', true));
            testCase.assumeTrue(strcmp(diag.status, 'READY'), ...
                'Simscape Electrical environment is not ready on this runner.');

            simRes = runDynamicFaultSimulation(testCase.network, testCase.validScenario, ...
                struct(), {}, struct('quiet', true, 'allowPowerSystemBlocks', true));

            testCase.verifyEqual(simRes.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(simRes.isSimulated);
            testCase.verifyNotEmpty(simRes.time_s);
            testCase.verifyTrue(all(diff(simRes.time_s) > 0));
            testCase.verifyTrue(isfield(simRes.rms, 'faultCurrent_A'));
            testCase.verifyGreaterThan(simRes.rms.faultCurrent_A, 0);
            testCase.verifyTrue(validateSimulationResult(simRes));
        end

    end

end

