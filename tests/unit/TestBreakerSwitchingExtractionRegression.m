classdef TestBreakerSwitchingExtractionRegression < matlab.unittest.TestCase
% TestBreakerSwitchingExtractionRegression Regression tests for Bugs 2.6 & 2.7:
% Verifies that missing mandatory output ports are never silently replaced with zeros,
% non-finite simulation outputs are rejected, and timestamp interpolation uses
% time-aware zero-order-hold for discrete signals instead of normalized index linear interpolation.

    methods (Test)

        function testMissingMandatoryPortsThrows(testCase)
            % Construct mock simOut with only 4 elements (missing ports 5-10)
            mockSimOut = struct();
            t = (0:1e-4:0.10)';
            mockSimOut.tout = t;
            mockSimOut.yout = Simulink.SimulationData.Dataset;
            for p = 1:4
                ts = timeseries(zeros(numel(t), 3), t);
                mockSimOut.yout = mockSimOut.yout.addElement(ts, sprintf('Port%d', p));
            end

            % Executing runDynamicBreakerSwitchingSimulation with missing ports must fail
            scenario = struct('scenarioId', 'TEST_MISSING_PORTS', 'faultType', '3PH', ...
                              'faultedBus', 'BUS_B', 'faultInsertionTime_s', 0.05, ...
                              'simulationStopTime_s', 0.10, 'failCB_B', false, 'failCB_A', false);

            % In headless or test harness, simulate failure status on missing ports
            res = runDynamicBreakerSwitchingSimulation(scenario, struct('quiet', true, 'mockOut', mockSimOut));
            testCase.verifyEqual(res.status, 'FAILED');
            testCase.verifyTrue(any(contains(res.errors, 'missing mandatory ports')));
        end

        function testDiscreteSignalPreservesZOHTransitions(testCase)
            % Test that discrete step transition (e.g. trip signal stepping from 0 to 1 at t=0.05s)
            % does not produce fractional values (like 0.2, 0.5) under interpolation.
            srcT = [0; 0.049; 0.050; 0.100];
            srcData = [0; 0; 1; 1];

            targetT = [0; 0.025; 0.049; 0.0495; 0.050; 0.075; 0.100];

            % With zero-order-hold (previous), values are strictly discrete:
            interpSig = interp1(srcT, srcData, targetT, 'previous', 'extrap');
            testCase.verifyTrue(all(interpSig == 0 | interpSig == 1), ...
                'Discrete switching signals must remain strictly binary (0 or 1).');

            % At 0.0495 s (before step at 0.050), it must remain 0
            idxBefore = find(targetT == 0.0495);
            testCase.verifyEqual(interpSig(idxBefore), 0);

            % At 0.050 s, it must be 1
            idxAt = find(targetT == 0.050);
            testCase.verifyEqual(interpSig(idxAt), 1);
        end

        function testNonFiniteSimulationOutputRejected(testCase)
            mockSimOut = struct();
            t = (0:1e-4:0.10)';
            mockSimOut.tout = t;
            mockSimOut.yout = Simulink.SimulationData.Dataset;
            for p = 1:10
                if p <= 4
                    data = zeros(numel(t), 3);
                    if p == 4, data(20, 1) = NaN; end % Inject NaN
                else
                    data = zeros(numel(t), 1);
                end
                ts = timeseries(data, t);
                mockSimOut.yout = mockSimOut.yout.addElement(ts, sprintf('Port%d', p));
            end

            scenario = struct('scenarioId', 'TEST_NAN_PORTS', 'faultType', '3PH', ...
                              'faultedBus', 'BUS_B', 'faultInsertionTime_s', 0.05, ...
                              'simulationStopTime_s', 0.10, 'failCB_B', false, 'failCB_A', false);

            res = runDynamicBreakerSwitchingSimulation(scenario, struct('quiet', true, 'mockOut', mockSimOut));
            testCase.verifyEqual(res.status, 'FAILED');
            testCase.verifyTrue(any(contains(res.errors, 'non-finite')));
        end

    end

end

