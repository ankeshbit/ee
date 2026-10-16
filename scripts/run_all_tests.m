%% run_all_tests.m
% Root-level test suite runner with exit-code reporting for CI / batch execution.
%
% Usage:
%   From MATLAB CLI:
%       results = run_all_tests();
%   From shell (returns non-zero exit code on failure):
%       matlab -batch "run('scripts/run_all_tests.m')"

function results = run_all_tests(testTarget)

    thisFile = mfilename('fullpath');
    repoRoot = fileparts(fileparts(thisFile));

    if nargin < 1 || isempty(testTarget)
        testTarget = fullfile(repoRoot, 'tests');
    end

    % Add project paths
    addpath(genpath(fullfile(repoRoot, 'matlab')));
    addpath(genpath(fullfile(repoRoot, 'scripts')));
    addpath(genpath(fullfile(repoRoot, 'tests')));

    fprintf('=================================================================\n');
    fprintf(' RUNNING COMPLETE TEST SUITE\n');
    fprintf(' MATLAB Release: R%s\n', version('-release'));
    fprintf(' Test Suite Target: %s\n', testTarget);
    fprintf(' Date: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
    fprintf('=================================================================\n\n');

    if isfolder(testTarget)
        suiteResults = runtests(testTarget, 'IncludeSubfolders', true);
    else
        suiteResults = runtests(testTarget);
    end

    totalTests = numel(suiteResults);
    numPassed = sum([suiteResults.Passed]);
    numFailed = sum([suiteResults.Failed]);
    numIncomplete = sum([suiteResults.Incomplete]);

    fprintf('\n=================================================================\n');
    fprintf(' TEST SUITE SUMMARY\n');
    fprintf(' Total Tests:      %d\n', totalTests);
    fprintf(' Passed:           %d\n', numPassed);
    fprintf(' Failed:           %d\n', numFailed);
    fprintf(' Incomplete/Skip:  %d\n', numIncomplete);
    fprintf('=================================================================\n');

    if numFailed > 0
        fprintf('\nFAILED TESTS:\n');
        failedResults = suiteResults([suiteResults.Failed]);
        for k = 1:numel(failedResults)
            fprintf('  [FAIL] %s\n', failedResults(k).Name);
        end
    end

    if numIncomplete > 0
        fprintf('\n=================================================================\n');
        fprintf(' SKIPPED / INCOMPLETE TESTS (%d total):\n', numIncomplete);
        fprintf('=================================================================\n');
        incompResults = suiteResults([suiteResults.Incomplete]);
        for k = 1:numel(incompResults)
            fprintf('  [SKIP] %s\n', incompResults(k).Name);
        end
        fprintf('=================================================================\n');
    end

    if nargout > 0
        results = suiteResults;
    end

    requireSim = strcmp(getenv('REQUIRE_SIMULATION_TESTS'), '1');
    hasFailure = (numFailed > 0) || (requireSim && numIncomplete > 0);

    % Exit with non-zero status if running via -batch and tests failed
    if hasFailure
        fprintf('\nOVERALL RESULT: FAILED\n');
        if requireSim && numIncomplete > 0
            fprintf('Reason: REQUIRE_SIMULATION_TESTS=1 but %d test(s) were incomplete/skipped.\n', numIncomplete);
        end
        if isBatchExecution()
            exit(1);
        else
            error('run_all_tests:TestFailure', '%d test(s) failed / incomplete in suite.', numFailed + numIncomplete);
        end
    else
        fprintf('\nOVERALL RESULT: SUCCESS\n');
        if isBatchExecution()
            exit(0);
        end
    end

end

function tf = isBatchExecution()
    % Detect if executing in headless batch mode where exit is appropriate
    tf = ~usejava('jvm') || ~feature('ShowFigureWindows');
end
