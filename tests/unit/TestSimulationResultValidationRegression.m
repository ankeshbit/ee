classdef TestSimulationResultValidationRegression < matlab.unittest.TestCase
% TestSimulationResultValidationRegression Regression tests for Bug 2.5:
% Validates simulation result contract enforcement, waveform dimensions,
% non-finite measurement rejection, sampling metadata, and fake data prevention.

    methods (Test)

        function testValidResultPasses(testCase)
            r = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
            r.isSimulated = true;
            r.time_s = linspace(0, 0.2, 1001)';
            r.voltages_V = struct('V_BusB', ones(1001, 3) * 6350);
            r.currents_A = struct('I_BusB', ones(1001, 3) * 1874);
            r.measurements = struct('V_BusB', r.voltages_V.V_BusB, 'I_BusB', r.currents_A.I_BusB);
            r.rms = struct('I_RMS', 1874.0, 'V_RMS', 6350.0);
            r.phasors = struct('I1', 1874.0);
            r.isValidMeasurementWindow = true;

            testCase.verifyTrue(validateSimulationResult(r));
        end

        function testRejectWaveformDimensionMismatch(testCase)
            r = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
            r.isSimulated = true;
            r.time_s = linspace(0, 0.2, 1001)';
            % Waveform has only 500 rows instead of 1001
            r.voltages_V = struct('V_BusB', ones(500, 3));
            testCase.verifyError( ...
                @() validateSimulationResult(r), ...
                'validateSimulationResult:DimensionMismatch');
        end

        function testRejectNonFiniteWaveformData(testCase)
            r = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
            r.isSimulated = true;
            r.time_s = linspace(0, 0.2, 1001)';
            vData = ones(1001, 3);
            vData(50, 2) = NaN;
            r.voltages_V = struct('V_BusB', vData);
            testCase.verifyError( ...
                @() validateSimulationResult(r), ...
                'validateSimulationResult:NonFiniteData');
        end

        function testRejectNonFiniteRMS(testCase)
            r = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
            r.isSimulated = true;
            r.time_s = linspace(0, 0.2, 1001)';
            r.rms = struct('I_RMS', Inf);
            testCase.verifyError( ...
                @() validateSimulationResult(r), ...
                'validateSimulationResult:NonFiniteRMS');
        end

        function testRejectFabricatedWaveformsOnBlockedResult(testCase)
            % Unsimulated result containing fabricated numeric waveforms
            r = createSimulationResultSchema('BLOCKED', 'SCN_01');
            r.isSimulated = false;
            r.time_s = [];
            r.voltages_V = struct('V_BusB', ones(100, 3)); % Fabricated!
            testCase.verifyError( ...
                @() validateSimulationResult(r), ...
                'validateSimulationResult:InventedMeasurements');
        end

        function testRejectNonStructSampling(testCase)
            r = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
            r.isSimulated = true;
            r.time_s = linspace(0, 0.2, 1001)';
            r.sampling = 10000; % non-struct
            testCase.verifyError( ...
                @() validateSimulationResult(r), ...
                'validateSimulationResult:InvalidSampling');
        end

        function testRejectNonStructProvenance(testCase)
            r = createSimulationResultSchema('SIMULATION_COMPLETED', 'SCN_01');
            r.isSimulated = true;
            r.time_s = linspace(0, 0.2, 1001)';
            r.provenance = 'string_not_struct';
            testCase.verifyError( ...
                @() validateSimulationResult(r), ...
                'validateSimulationResult:InvalidProvenance');
        end

        function testRejectMissingContractField(testCase)
            r = createSimulationResultSchema('NOT_RUN', 'SCN_01');
            r = rmfield(r, 'sampling');
            testCase.verifyError( ...
                @() validateSimulationResult(r), ...
                'validateSimulationResult:MissingField');
        end

    end

end

