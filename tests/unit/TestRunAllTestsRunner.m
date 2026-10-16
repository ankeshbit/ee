classdef TestRunAllTestsRunner < matlab.unittest.TestCase
% TestRunAllTestsRunner Unit tests for test runner behavior under REQUIRE_SIMULATION_TESTS.

    methods (Test)

        function testRequireSimulationFailsOnIncomplete(testCase)
            origEnv = getenv('REQUIRE_SIMULATION_TESTS');
            cleanUp = onCleanup(@() setenv('REQUIRE_SIMULATION_TESTS', origEnv));

            setenv('REQUIRE_SIMULATION_TESTS', '1');
            target = fullfile(fileparts(mfilename('fullpath')), '..', 'integration', ...
                'TestDynamicFaultSimulationIntegration.m');

            testCase.verifyError(@() run_all_tests(target), ...
                'run_all_tests:TestFailure');
        end

    end

end
