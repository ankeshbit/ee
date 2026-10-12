classdef TestProtectionSelectivityMatrix < matlab.unittest.TestCase

    methods (Test)

        function testMatrixConsumesPhasorAndSensitivityResults(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            scenario = struct('id', 'B', 'faultedBus', 'BUS_B', ...
                'faultType', 'three phase', 'Zf_pu', 0);
            relays = relaySet();
            phasors = calculateNetworkPhasors(network, scenario, relays);
            sensitivity = runFaultSensitivityStudy(network, scenario, ...
                relays, [], struct());
            matrix = buildProtectionSelectivityMatrix(phasors, sensitivity);
            testCase.verifyEqual(height(matrix), numel(relays));
            testCase.verifyTrue(any(strcmp(matrix.relayId, 'R_B')));
            testCase.verifyTrue(any(isfinite(matrix.phaseCurrentMagnitude_A)));
        end

        function testMatrixPreservesUnsupportedMeasurement(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            scenario = struct('id', 'B', 'faultedBus', 'BUS_B', ...
                'faultType', 'three phase', 'Zf_pu', 0);
            relays = relaySet();
            matrix = buildProtectionSelectivityMatrix( ...
                calculateNetworkPhasors(network, scenario, relays), struct());
            row = matrix(strcmp(matrix.relayId, 'R_C'), :);
            testCase.verifyEqual(row.selectivityStatus{1}, ...
                'unsupportedOffFaultPath');
        end

        function testSensitivityStudyOptionIncludesPhasors(testCase)
            network = createIllustrativeBranchedTransformerRadialNetwork();
            scenario = struct('id', 'B', 'faultedBus', 'BUS_B', ...
                'faultType', 'three phase', 'Zf_pu', 0);
            study = runFaultSensitivityStudy(network, scenario, ...
                relaySet(), [], struct('includePhasors', true));
            testCase.verifyEqual(numel(study.phasorResults), 1);
            testCase.verifyGreaterThanOrEqual(height(study.selectivityMatrix), 1);
            report = generateFaultSensitivityReport(study);
            testCase.verifyEqual(height(report.selectivityMatrix), ...
                height(study.selectivityMatrix));
        end
    end
end

function values = relaySet()
values = struct( ...
    'id', {'R_B', 'R_C'}, ...
    'measurementElementType', {'branch', 'branch'}, ...
    'measurementElementId', {'BR_2', 'BR_3'}, ...
    'measurementSide', {'from', 'from'}, ...
    'pickupCurrent_A', {1, 1}, 'TMS', {1, 1}, ...
    'curveType', {'Very Inverse', 'Very Inverse'}, ...
    'CTprimary_A', {400, 400}, 'CTsecondary_A', {5, 5});
end
