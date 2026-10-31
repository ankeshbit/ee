%% run_all_tests.m
% Root-level test suite runner with exit-code reporting for CI / batch execution.
%
% Usage:
%   From MATLAB CLI:
%       results = run_all_tests();
%       results = run_all_tests(testTarget);
%       results = run_all_tests(testTarget, options);
%   From shell (returns non-zero exit code on failure in batch mode):
%       matlab -batch "run('scripts/run_all_tests.m')"
%
% Options:
%   options.quiet        - Suppress header and summary printing (default: false, auto-enabled if nested)
%   options.suppressExit - Suppress exit(0)/exit(1) in batch mode (default: false, auto-enabled if nested)

function results = run_all_tests(testTarget, options)

    thisFile = mfilename('fullpath');
    repoRoot = fileparts(fileparts(thisFile));

    if nargin < 1 || isempty(testTarget)
        testTarget = fullfile(repoRoot, 'tests');
    end
    if nargin < 2 || isempty(options)
        options = struct();
    end
    if ~isstruct(options) || ~isscalar(options)
        options = struct();
    end
    if ~isfield(options, 'quiet')
        options.quiet = false;
    end
    if ~isfield(options, 'suppressExit')
        options.suppressExit = false;
    end

    % Manage recursion / call depth tracking
    currentDepthStr = getenv('_RUN_ALL_TESTS_DEPTH');
    if isempty(currentDepthStr)
        depth = 0;
    else
        depth = str2double(currentDepthStr);
        if isnan(depth), depth = 0; end
    end

    depth = depth + 1;
    setenv('_RUN_ALL_TESTS_DEPTH', num2str(depth));
    cleanDepth = onCleanup(@() p_restoreDepth(depth - 1));

    isNested = (depth > 1);
    suppressOutput = isNested || options.quiet;
    suppressExit = isNested || options.suppressExit;

    % Add project paths
    addpath(genpath(fullfile(repoRoot, 'matlab')));
    addpath(genpath(fullfile(repoRoot, 'scripts')));
    addpath(genpath(fullfile(repoRoot, 'tests')));

    if ~suppressOutput
        fprintf('=================================================================\n');
        fprintf(' RUNNING COMPLETE TEST SUITE\n');
        fprintf(' MATLAB Release: R%s\n', version('-release'));
        fprintf(' Test Suite Target: %s\n', testTarget);
        fprintf(' Date: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
        fprintf('=================================================================\n\n');
    end

    if isfolder(testTarget)
        suiteResults = runtests(testTarget, 'IncludeSubfolders', true);
    else
        suiteResults = runtests(testTarget);
    end

    totalTests = numel(suiteResults);
    numPassed = sum([suiteResults.Passed]);
    numFailed = sum([suiteResults.Failed]);
    numIncomplete = sum([suiteResults.Incomplete]);

    if ~suppressOutput
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
    end

    if nargout > 0
        results = suiteResults;
    end

    requireSim = strcmp(getenv('REQUIRE_SIMULATION_TESTS'), '1');
    hasFailure = (numFailed > 0) || (requireSim && numIncomplete > 0);

    % Exit with non-zero status if running via -batch and tests failed
    if hasFailure
        if ~suppressOutput
            fprintf('\nOVERALL RESULT: FAILED\n');
            if requireSim && numIncomplete > 0
                fprintf('Reason: REQUIRE_SIMULATION_TESTS=1 but %d test(s) were incomplete/skipped.\n', numIncomplete);
            end
        end
        if isBatchExecution() && ~suppressExit
            exit(1);
        else
            error('run_all_tests:TestFailure', '%d test(s) failed / incomplete in suite.', numFailed + numIncomplete);
        end
    else
        if ~suppressOutput
            fprintf('\nOVERALL RESULT: SUCCESS\n');
        end
        if isBatchExecution() && ~suppressExit
            exit(0);
        end
    end

end

function tf = isBatchExecution()
    % Detect if executing in headless batch mode where exit is appropriate
    tf = ~usejava('jvm') || ~feature('ShowFigureWindows');
end

function p_restoreDepth(prevDepth)
    if prevDepth <= 0
        setenv('_RUN_ALL_TESTS_DEPTH', '');
    else
        setenv('_RUN_ALL_TESTS_DEPTH', num2str(prevDepth));
    end
end
