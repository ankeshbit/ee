classdef TestAcceptanceValidationRegression < matlab.unittest.TestCase
% TestAcceptanceValidationRegression Regression tests for Bug 2.1:
% Ensures zero evaluated criteria never produces PASS, missing scenarios are detected,
% and explicit statuses (PASS, FAIL, BLOCKED, INCOMPLETE) are enforced.

    methods (Test)

        function testEmptyResultsMustNeverPass(testCase)
            [outcomes, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria({});
            testCase.verifyFalse(overallPass, 'Empty results must never produce overallPass = true.');
            testCase.verifyEqual(overallStatus, 'INCOMPLETE');
            testCase.verifyNotEmpty(outcomes);
            testCase.verifyTrue(all(~[outcomes.pass]), 'All criteria for missing scenarios must be marked pass = false.');
        end

        function testAllSimulationsBlocked(testCase)
            expected = {'PF_HEALTHY', 'PF_3PH', 'PF_SLG', 'PF_LL', 'PF_DLG', 'PF_3PH_CBF'};
            sims = cell(size(expected));
            for i = 1:numel(expected)
                sims{i} = struct('scenarioId', expected{i}, 'status', 'BLOCKED');
            end

            [outcomes, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(sims);
            testCase.verifyFalse(overallPass, 'Blocked simulations must not pass.');
            testCase.verifyEqual(overallStatus, 'BLOCKED');
            testCase.verifyTrue(all(strcmp({outcomes.status}, 'BLOCKED')));
        end

        function testAllSimulationsSkipped(testCase)
            expected = {'PF_HEALTHY', 'PF_3PH', 'PF_SLG', 'PF_LL', 'PF_DLG', 'PF_3PH_CBF'};
            sims = cell(size(expected));
            for i = 1:numel(expected)
                sims{i} = struct('scenarioId', expected{i}, 'status', 'SKIPPED');
            end

            [outcomes, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(sims);
            testCase.verifyFalse(overallPass);
            testCase.verifyEqual(overallStatus, 'INCOMPLETE');
        end

        function testOneFailedMandatoryScenario(testCase)
            % 5 scenarios pass, but PF_3PH failed
            sims = p_buildPassingSimResults();
            sims{2}.status = 'SIMULATION_FAILED';

            [~, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(sims);
            testCase.verifyFalse(overallPass);
            testCase.verifyEqual(overallStatus, 'FAIL');
        end

        function testMissingOneMandatoryScenario(testCase)
            % Provide only 5 of 6 scenarios (missing PF_3PH_CBF)
            sims = p_buildPassingSimResults();
            sims(6) = []; % remove CBF

            [~, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(sims);
            testCase.verifyFalse(overallPass, 'Missing mandatory scenario must not result in pass.');
            testCase.verifyEqual(overallStatus, 'INCOMPLETE');
        end

        function testAllMandatoryCriteriaPassing(testCase)
            sims = p_buildPassingSimResults();
            rtTable = struct('scenarioId', 'PF_3PH', 'timingErrorMs', -2.1);

            [outcomes, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(sims, rtTable);
            testCase.verifyTrue(overallPass);
            testCase.verifyEqual(overallStatus, 'PASS');
            testCase.verifyTrue(all([outcomes.pass]));
        end

        function testSpuriousTripOnHealthyFails(testCase)
            sims = p_buildPassingSimResults();
            % Simulate spurious trip on healthy
            sims{1}.relay.B.tripStatus = 'TRIPPED';

            [~, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(sims);
            testCase.verifyFalse(overallPass);
            testCase.verifyEqual(overallStatus, 'FAIL');
        end

        function testExcessiveBreakerDelayFails(testCase)
            sims = p_buildPassingSimResults();
            % Set 3PH breaker delay to 400 ms (> 300 ms limit)
            sims{2}.relay.B.breakerOpenTime_s = sims{2}.faultInception_s + 0.400;

            [~, overallPass, overallStatus] = evaluateStudyAcceptanceCriteria(sims);
            testCase.verifyFalse(overallPass);
            testCase.verifyEqual(overallStatus, 'FAIL');
        end

    end

end

function sims = p_buildPassingSimResults()
    scenarios = {'PF_HEALTHY', 'PF_3PH', 'PF_SLG', 'PF_LL', 'PF_DLG', 'PF_3PH_CBF'};
    sims = cell(size(scenarios));
    for i = 1:numel(scenarios)
        sId = scenarios{i};
        r = struct();
        r.scenarioId = sId;
        r.status = 'COMPLETED';
        r.faultInception_s = 0.05;
        if strcmp(sId, 'PF_HEALTHY')
            r.faultType = 'HEALTHY';
            r.relay = struct('B', struct('tripStatus', 'NO_TRIP', 'breakerOpenTime_s', NaN));
        elseif strcmp(sId, 'PF_3PH_CBF')
            r.faultType = '3PH';
            r.relay = struct('B', struct('tripStatus', 'TRIPPED', 'breakerOpenTime_s', NaN), ...
                             'A', struct('tripStatus', 'TRIPPED', 'breakerOpenTime_s', 0.60));
            r.clearingVerification = struct('faultCleared', true, 'postClearingCurrentPeak_A', 0.005);
        else
            r.faultType = strrep(sId, 'PF_', '');
            r.relay = struct('B', struct('tripStatus', 'TRIPPED', 'breakerOpenTime_s', 0.26));
            r.clearingVerification = struct('faultCleared', true, 'postClearingCurrentPeak_A', 0.005);
        end
        sims{i} = r;
    end
end

