classdef TestSimscapeComponentVerification < matlab.unittest.TestCase
% TestSimscapeComponentVerification Unit tests for component verification and prototype logic.

    methods (TestClassSetup)
        function addProjectPaths(~)
            repoRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            scriptsDir = fullfile(repoRoot, 'scripts');
            if exist(scriptsDir, 'dir')
                addpath(scriptsDir);
            end
        end
    end

    methods (Test)

        function testAllCandidateComponentsVerified(testCase)
            options = struct('quiet', true);
            report = verifySimscapeComponents(options);

            testCase.verifyTrue(report.allFound);
            testCase.verifyTrue(report.allInstantiated);
            testCase.verifyTrue(report.allConfigurable);
            testCase.verifyEqual(report.foundCount, report.totalChecked);
            testCase.verifyEqual(report.instantiatedCount, report.totalChecked);
        end

        function testComponentVerificationHandlesMissingBlock(testCase)
            % Test that non-existent block is handled safely without crashing
            tempMdl = sprintf('temp_test_miss_%s', datestr(now, 'HHMMSS_FFF')); %#ok<TNOW1,DATST>
            new_system(tempMdl);

            try
                badPath = 'ee_lib/NonExistent/FakeBlock';
                testCase.verifyError( ...
                    @() add_block(badPath, [tempMdl, '/Bad']), ...
                    'Simulink:Commands:InvBlockSpecifier');
                close_system(tempMdl, 0);
            catch ME
                if bdIsLoaded(tempMdl)
                    close_system(tempMdl, 0);
                end
                rethrow(ME);
            end
        end

        function testPrototypeModelBuildAndSave(testCase)
            tempDir = fullfile(tempdir, 'ee_test_scratch');
            if ~exist(tempDir, 'dir')
                mkdir(tempDir);
            end

            modelPath = build_minimal_circuit_prototype(tempDir);
            testCase.verifyTrue(exist(modelPath, 'file') == 2);

            % Clean up temporary model
            [~, mdlName] = fileparts(modelPath);
            if bdIsLoaded(mdlName)
                close_system(mdlName, 0);
            end
            delete(modelPath);
            rmdir(tempDir);
        end

        function testPrototypeBlockedWithInjectedOverrides(testCase)
            options = struct('quiet', true);
            options.overrides = struct( ...
                'simulinkInstalled', true, ...
                'simulinkLicensed', false, ...
                'simscapeInstalled', true, ...
                'simscapeLicensed', true, ...
                'simscapeElectricalInstalled', true, ...
                'simscapeElectricalLicensed', false, ...
                'modelBuildingAPIsAvailable', true, ...
                'simulationAPIsAvailable', true, ...
                'componentsAvailable', true);

            res = runMinimalCircuitPrototype(options);
            testCase.verifyEqual(res.status, 'BLOCKED');
            testCase.verifyFalse(res.isSimulated);
            testCase.verifyEmpty(res.time_s);
        end

        function testPrototypeSchemaValidity(testCase)
            options = struct('quiet', true, 'stopTime_s', 0.04);
            res = runMinimalCircuitPrototype(options);

            testCase.verifyTrue(validateSimulationResult(res));
            testCase.verifyEqual(res.status, 'SIMULATION_COMPLETED');
            testCase.verifyTrue(res.isSimulated);
            testCase.verifyNotEmpty(res.time_s);
            testCase.verifyTrue(res.isValidMeasurementWindow);
            testCase.verifyTrue(all(isfinite(res.rms.V_RMS_phase)));
            testCase.verifyTrue(all(isfinite(res.rms.I_RMS_phase)));
        end

    end

end
