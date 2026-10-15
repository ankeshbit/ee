classdef TestConfigurationConsistency < matlab.unittest.TestCase
% TestConfigurationConsistency Verifies that all configuration parameters
% originate from the authoritative master configuration struct, carry explicit
% units and provenance, and that the analytical engine and Simulink model builder
% share identical numerical parameter values.

    properties
        repoRoot
        masterCfg
    end

    methods (TestClassSetup)
        function setupPaths(testCase)
            thisFile = mfilename('fullpath');
            unitDir = fileparts(thisFile);
            testCase.repoRoot = fileparts(fileparts(unitDir));
            addpath(genpath(fullfile(testCase.repoRoot, 'matlab')));
            addpath(genpath(fullfile(testCase.repoRoot, 'scripts')));
            testCase.masterCfg = getSystemMasterConfiguration();
        end
    end

    methods (Test)

        function testProvenanceAndUnitsIntegrity(testCase)
            % Every configuration item must have explicit units and provenance marked 'ILLUSTRATIVE'
            cfg = testCase.masterCfg;

            % System base
            testCase.verifyEqual(cfg.systemBase.SbaseVA.provenance, 'ILLUSTRATIVE');
            testCase.verifyNotEmpty(cfg.systemBase.SbaseVA.unit);
            testCase.verifyEqual(cfg.systemBase.VbaseHV_V.provenance, 'ILLUSTRATIVE');
            testCase.verifyEqual(cfg.systemBase.VbaseLV_V.provenance, 'ILLUSTRATIVE');

            % Source
            testCase.verifyEqual(cfg.source.Vth_pu.provenance, 'ILLUSTRATIVE');
            testCase.verifyEqual(cfg.source.Z1_pu.provenance, 'ILLUSTRATIVE');
            testCase.verifyEqual(cfg.source.physical.R_Ohm.provenance, 'ILLUSTRATIVE');
            testCase.verifyEqual(cfg.source.physical.L_H.provenance, 'ILLUSTRATIVE');

            % Transformer
            testCase.verifyEqual(cfg.transformer.ratedSbaseVA.provenance, 'ILLUSTRATIVE');
            testCase.verifyEqual(cfg.transformer.Z1_pu.provenance, 'ILLUSTRATIVE');
            testCase.verifyEqual(cfg.transformer.physical.Rw1_pu.provenance, 'ILLUSTRATIVE');
            testCase.verifyEqual(cfg.transformer.physical.Xl1_pu.provenance, 'ILLUSTRATIVE');

            % Feeders
            testCase.verifyEqual(cfg.feeders.BRA.Z1_pu.provenance, 'ILLUSTRATIVE');
            testCase.verifyEqual(cfg.feeders.BRB.Z1_pu.provenance, 'ILLUSTRATIVE');
            testCase.verifyEqual(cfg.feeders.BRA.physical.R_Ohm.provenance, 'ILLUSTRATIVE');
            testCase.verifyEqual(cfg.feeders.BRB.physical.R_Ohm.provenance, 'ILLUSTRATIVE');

            % Relays
            for r = cfg.relays
                testCase.verifyEqual(r.CTprimary_A.provenance, 'ILLUSTRATIVE');
                testCase.verifyEqual(r.CTsecondary_A.provenance, 'ILLUSTRATIVE');
                testCase.verifyEqual(r.pickupCurrent_A.provenance, 'ILLUSTRATIVE');
                testCase.verifyEqual(r.TMS.provenance, 'ILLUSTRATIVE');
            end

            % Breakers
            for b = cfg.breakers
                testCase.verifyEqual(b.openingDelay_s.provenance, 'ILLUSTRATIVE');
            end
        end

        function testAnalyticalEngineMatchesMasterConfig(testCase)
            % Analytical network and relay configuration must match master config
            cfg = testCase.masterCfg;
            net = createIllustrativeRadialNetwork();
            relayCfg = createRadialRelayStudyConfiguration();

            % Base power & voltage
            testCase.verifyEqual(net.base.SbaseVA, cfg.systemBase.SbaseVA.value);
            testCase.verifyEqual(net.base.VbaseV, cfg.systemBase.VbaseLV_V.value);

            % Source impedances
            testCase.verifyEqual(net.source.Z1_pu, cfg.source.Z1_pu.value);
            testCase.verifyEqual(net.source.Z0_pu, cfg.source.Z0_pu.value);

            % Feeders
            testCase.verifyEqual(net.branches(1).Z1_pu, cfg.feeders.BRA.Z1_pu.value);
            testCase.verifyEqual(net.branches(2).Z1_pu, cfg.feeders.BRB.Z1_pu.value);

            % Relays
            rB = relayCfg.relays(strcmp({relayCfg.relays.id}, 'RELAY_BUS_B'));
            rB_master = cfg.relays(strcmp({cfg.relays.id}, 'RELAY_BUS_B'));
            testCase.verifyEqual(rB.CTprimary_A, rB_master.CTprimary_A.value);
            testCase.verifyEqual(rB.pickupCurrent_A, rB_master.pickupCurrent_A.value);
            testCase.verifyEqual(rB.TMS, rB_master.TMS.value);

            % Breakers
            bB = relayCfg.breakers(strcmp({relayCfg.breakers.id}, 'CB_BUS_B'));
            bB_master = cfg.breakers(strcmp({cfg.breakers.id}, 'CB_BUS_B'));
            testCase.verifyEqual(bB.openingDelay_s, bB_master.openingDelay_s.value);
        end

        function testModelBuilderMatchesAnalyticalEngine(testCase)
            % Verify that the programmatically built Simulink model matches
            % the master configuration and analytical engine parameter values
            cfg = testCase.masterCfg;
            modelName = 'radial_fault_study_network';
            modelFile = fullfile(testCase.repoRoot, 'simulink', 'models', [modelName, '.slx']);

            testCase.assumeTrue(exist(modelFile, 'file') > 0, 'Model file must exist');

            wasLoaded = bdIsLoaded(modelName);
            if ~wasLoaded
                load_system(modelFile);
            end

            cleanup = onCleanup(@() p_cleanupModel(modelName, wasLoaded));

            % 1. Source impedance
            rSrc = str2double(get_param([modelName, '/Source_Impedance'], 'R'));
            lSrc = str2double(get_param([modelName, '/Source_Impedance'], 'L'));
            testCase.verifyEqual(rSrc, cfg.source.physical.R_Ohm.value, 'AbsTol', 1e-6, ...
                'Model source R must match master config');
            testCase.verifyEqual(lSrc, cfg.source.physical.L_H.value, 'AbsTol', 1e-6, ...
                'Model source L must match master config');

            % 2. Transformer
            rw1 = str2double(get_param([modelName, '/Transformer'], 'pu_Rw1'));
            xl1 = str2double(get_param([modelName, '/Transformer'], 'pu_Xl1'));
            testCase.verifyEqual(rw1, cfg.transformer.physical.Rw1_pu.value, 'AbsTol', 1e-6, ...
                'Model transformer Rw1 must match master config');
            testCase.verifyEqual(xl1, cfg.transformer.physical.Xl1_pu.value, 'AbsTol', 1e-6, ...
                'Model transformer Xl1 must match master config');

            % 3. Feeder BRA
            rBra = str2double(get_param([modelName, '/Feeder_BRA'], 'R'));
            lBra = str2double(get_param([modelName, '/Feeder_BRA'], 'L'));
            testCase.verifyEqual(rBra, cfg.feeders.BRA.physical.R_Ohm.value, 'AbsTol', 1e-6, ...
                'Model feeder BRA R must match master config');
            testCase.verifyEqual(lBra, cfg.feeders.BRA.physical.L_H.value, 'AbsTol', 1e-6, ...
                'Model feeder BRA L must match master config');

            % 4. Relay B Pickup and CT Ratio
            relayB = cfg.relays(strcmp({cfg.relays.id}, 'RELAY_BUS_B'));
            ctGainB = str2double(get_param([modelName, '/Gain_M_B'], 'Gain'));
            pickupB = str2double(get_param([modelName, '/Check_Pickup_B'], 'const'));
            expectedGainB = relayB.CTsecondary_A.value / relayB.CTprimary_A.value;
            testCase.verifyEqual(ctGainB, expectedGainB, 'AbsTol', 1e-6, ...
                'Model CT B ratio must match master config');
            testCase.verifyEqual(pickupB, relayB.pickupCurrent_A.value, 'AbsTol', 1e-6, ...
                'Model Relay B pickup must match master config');

            % 5. Breaker B Opening Delay
            bkrB = cfg.breakers(strcmp({cfg.breakers.id}, 'CB_BUS_B'));
            bkrDelayB = str2double(get_param([modelName, '/Breaker_Delay_B'], 'DelayTime'));
            testCase.verifyEqual(bkrDelayB, bkrB.openingDelay_s.value, 'AbsTol', 1e-6, ...
                'Model Breaker B opening delay must match master config');
        end

    end

end

function p_cleanupModel(modelName, wasLoaded)
    if ~wasLoaded && bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
end
