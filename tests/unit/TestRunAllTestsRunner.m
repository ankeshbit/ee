classdef TestRunAllTestsRunner < matlab.unittest.TestCase
% TestRunAllTestsRunner Unit tests for run_all_tests runner behavior.
% Tests runner execution under all test outcomes, recursion guards,
% and environment variable toggles (REQUIRE_SIMULATION_TESTS).

    methods (Test)

        function testAllTestsPass(testCase)
            % Test that run_all_tests returns successfully when all tests pass
            tempTestDir = fullfile(tempdir, ['runner_test_pass_', num2str(randi(1e6))]);
            if ~exist(tempTestDir, 'dir'), mkdir(tempTestDir); end
            cleanDir = onCleanup(@() rmdir(tempTestDir, 's'));

            testFile = fullfile(tempTestDir, 'TestMockPass.m');
            fid = fopen(testFile, 'w');
            fprintf(fid, 'classdef TestMockPass < matlab.unittest.TestCase\n');
            fprintf(fid, '    methods (Test)\n');
            fprintf(fid, '        function testPassing(tc)\n');
            fprintf(fid, '            tc.verifyTrue(true);\n');
            fprintf(fid, '        end\n');
            fprintf(fid, '    end\n');
            fprintf(fid, 'end\n');
            fclose(fid);

            opts = struct('quiet', true, 'suppressExit', true);
            results = run_all_tests(testFile, opts);

            testCase.verifyEqual(numel(results), 1);
            testCase.verifyEqual(sum([results.Passed]), 1);
            testCase.verifyEqual(sum([results.Failed]), 0);
            testCase.verifyEqual(sum([results.Incomplete]), 0);
        end

        function testTestFailureThrows(testCase)
            % Test that run_all_tests raises an error when a test fails
            tempTestDir = fullfile(tempdir, ['runner_test_fail_', num2str(randi(1e6))]);
            if ~exist(tempTestDir, 'dir'), mkdir(tempTestDir); end
            cleanDir = onCleanup(@() rmdir(tempTestDir, 's'));

            testFile = fullfile(tempTestDir, 'TestMockFail.m');
            fid = fopen(testFile, 'w');
            fprintf(fid, 'classdef TestMockFail < matlab.unittest.TestCase\n');
            fprintf(fid, '    methods (Test)\n');
            fprintf(fid, '        function testFailing(tc)\n');
            fprintf(fid, '            tc.verifyTrue(false, ''Deliberate failure'');\n');
            fprintf(fid, '        end\n');
            fprintf(fid, '    end\n');
            fprintf(fid, 'end\n');
            fclose(fid);

            opts = struct('quiet', true, 'suppressExit', true);
            testCase.verifyError(@() run_all_tests(testFile, opts), ...
                'run_all_tests:TestFailure');
        end

        function testIncompletePassesWhenRequireSimUnset(testCase)
            % Test that an incomplete test does not fail when REQUIRE_SIMULATION_TESTS is unset
            origEnv = getenv('REQUIRE_SIMULATION_TESTS');
            cleanEnv = onCleanup(@() setenv('REQUIRE_SIMULATION_TESTS', origEnv));
            setenv('REQUIRE_SIMULATION_TESTS', '');

            tempTestDir = fullfile(tempdir, ['runner_test_incomp_pass_', num2str(randi(1e6))]);
            if ~exist(tempTestDir, 'dir'), mkdir(tempTestDir); end
            cleanDir = onCleanup(@() rmdir(tempTestDir, 's'));

            testFile = fullfile(tempTestDir, 'TestMockIncompPass.m');
            fid = fopen(testFile, 'w');
            fprintf(fid, 'classdef TestMockIncompPass < matlab.unittest.TestCase\n');
            fprintf(fid, '    methods (Test)\n');
            fprintf(fid, '        function testIncomp(tc)\n');
            fprintf(fid, '            tc.assumeTrue(false, ''Assumption unmet'');\n');
            fprintf(fid, '        end\n');
            fprintf(fid, '    end\n');
            fprintf(fid, 'end\n');
            fclose(fid);

            opts = struct('quiet', true, 'suppressExit', true);
            results = run_all_tests(testFile, opts);

            testCase.verifyEqual(numel(results), 1);
            testCase.verifyEqual(sum([results.Passed]), 0);
            testCase.verifyEqual(sum([results.Failed]), 0);
            testCase.verifyEqual(sum([results.Incomplete]), 1);
        end

        function testIncompleteFailsWhenRequireSimSet(testCase)
            % Test that an incomplete test fails when REQUIRE_SIMULATION_TESTS=1
            origEnv = getenv('REQUIRE_SIMULATION_TESTS');
            cleanEnv = onCleanup(@() setenv('REQUIRE_SIMULATION_TESTS', origEnv));
            setenv('REQUIRE_SIMULATION_TESTS', '1');

            tempTestDir = fullfile(tempdir, ['runner_test_incomp_fail_', num2str(randi(1e6))]);
            if ~exist(tempTestDir, 'dir'), mkdir(tempTestDir); end
            cleanDir = onCleanup(@() rmdir(tempTestDir, 's'));

            testFile = fullfile(tempTestDir, 'TestMockIncompFail.m');
            fid = fopen(testFile, 'w');
            fprintf(fid, 'classdef TestMockIncompFail < matlab.unittest.TestCase\n');
            fprintf(fid, '    methods (Test)\n');
            fprintf(fid, '        function testIncomp(tc)\n');
            fprintf(fid, '            tc.assumeTrue(false, ''Assumption unmet'');\n');
            fprintf(fid, '        end\n');
            fprintf(fid, '    end\n');
            fprintf(fid, 'end\n');
            fclose(fid);

            opts = struct('quiet', true, 'suppressExit', true);
            testCase.verifyError(@() run_all_tests(testFile, opts), ...
                'run_all_tests:TestFailure');
        end

    end

end
