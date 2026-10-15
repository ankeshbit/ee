%% run_all_tests.m
% Root-level test suite runner with exit-code reporting for CI / batch execution.
%
% Usage:
%   From MATLAB CLI:
%       results = run_all_tests();
%   From shell (returns non-zero exit code on failure):
%       matlab -batch "run('scripts/run_all_tests.m')"

function results = run_all_tests()

    thisFile = mfilename('fullpath');
    repoRoot = fileparts(fileparts(thisFile));

    % Add project paths
    addpath(genpath(fullfile(repoRoot, 'matlab')));
    addpath(genpath(fullfile(repoRoot, 'scripts')));
    addpath(genpath(fullfile(repoRoot, 'tests')));

    fprintf('=================================================================\n');
    fprintf(' RUNNING COMPLETE TEST SUITE\n');
    fprintf(' MATLAB Release: R%s\n', version('-release'));
    fprintf(' Test Suite Directory: tests\n');
    fprintf(' Date: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
    fprintf('=================================================================\n\n');

    testsDir = fullfile(repoRoot, 'tests');
    suiteResults = runtests(testsDir, 'IncludeSubfolders', true);

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
        fprintf('\nINCOMPLETE / FILTERED TESTS:\n');
        incompResults = suiteResults([suiteResults.Incomplete]);
        for k = 1:numel(incompResults)
            fprintf('  [SKIP] %s\n', incompResults(k).Name);
        end
    end

    if nargout > 0
        results = suiteResults;
    end

    % Exit with non-zero status if running via -batch and tests failed
    if numFailed > 0
        fprintf('\nOVERALL RESULT: FAILED\n');
        if isBatchExecution()
            exit(1);
        else
            error('run_all_tests:TestFailure', '%d test(s) failed in suite.', numFailed);
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
