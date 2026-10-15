classdef TestSensitivityAnalysis < matlab.unittest.TestCase
    % TestSensitivityAnalysis Automated sensitivity checks across parameters.
    %
    % Verifies that results move strictly in the physically expected direction:
    % 1. Increasing fault impedance (Zf) -> lower fault current -> longer trip time.
    % 2. Increasing distance / line impedance -> lower fault current -> longer trip time.
    % 3. Increasing source strength (Ssc) -> lower source impedance -> higher fault current -> shorter trip time.
    % 4. Increasing TMS -> strictly proportional longer trip time.

    properties
        baseCfg
    end

    methods (TestMethodSetup)
        function setUp(testCase)
            testCase.baseCfg = getSystemMasterConfiguration();
        end
    end

    methods (Test)

        %% 1. Fault Impedance Sensitivity
        function testFaultImpedanceSensitivity(testCase)
            % As Zf increases, fault current must decrease and relay trip time must increase.
            Zf_values = [0.0, 0.02, 0.05, 0.10, 0.20];
            net = createIllustrativeRadialNetwork();
            relay = testCase.baseCfg.relays(strcmp({testCase.baseCfg.relays.id}, 'RELAY_BUS_B'));
            relays = struct('id', relay.id, 'pickupCurrent_A', relay.pickupCurrent_A.value, ...
                'TMS', relay.TMS.value, 'curveType', relay.curveType, ...
                'CTprimary_A', relay.CTprimary_A.value, 'CTsecondary_A', relay.CTsecondary_A.value, ...
                'protectedBranch', 'BR_B');
            pairs = struct([]);

            faultCurrents = zeros(size(Zf_values));
            tripTimes = zeros(size(Zf_values));

            for idx = 1:numel(Zf_values)
                zf = Zf_values(idx);
                scenarios = struct('id', sprintf('SCN_%d', idx), 'faultedBus', 'BUS_B', ...
                    'faultType', '3PH', 'Zf_pu', zf);
                res = runIntegratedFaultStudy(net, scenarios, relays, pairs);

                faultCurrents(idx) = res.faultCurrentMagnitude_A;
                tripTimes(idx) = res.relayResults(1).operatingTime_s;
            end

            % Verify strict monotonic decrease in fault current:
            testCase.verifyTrue(all(diff(faultCurrents) < 0), ...
                'Fault current must strictly decrease as fault impedance increases.');

            % Verify strict monotonic increase in trip time:
            testCase.verifyTrue(all(diff(tripTimes) > 0), ...
                'Relay trip time must strictly increase as fault impedance increases.');
        end

        %% 2. Fault Location / Path Distance Sensitivity
        function testFaultLocationSensitivity(testCase)
            % Fault at Bus A (closest) vs Bus B (downstream)
            net = createIllustrativeRadialNetwork();
            relay = testCase.baseCfg.relays(strcmp({testCase.baseCfg.relays.id}, 'RELAY_33KV'));
            relays = struct('id', relay.id, 'pickupCurrent_A', relay.pickupCurrent_A.value, ...
                'TMS', relay.TMS.value, 'curveType', relay.curveType, ...
                'CTprimary_A', relay.CTprimary_A.value, 'CTsecondary_A', relay.CTsecondary_A.value, ...
                'protectedBranch', 'BR_A');
            pairs = struct([]);

            scenarios = [
                struct('id', 'SCN_A', 'faultedBus', 'BUS_A', 'faultType', '3PH', 'Zf_pu', 0.0), ...
                struct('id', 'SCN_B', 'faultedBus', 'BUS_B', 'faultType', '3PH', 'Zf_pu', 0.0)
            ];

            res = runIntegratedFaultStudy(net, scenarios, relays, pairs);

            If_A = res(1).faultCurrentMagnitude_A;
            If_B = res(2).faultCurrentMagnitude_A;

            % Bus A is closer to source than Bus B, so If_A must be strictly greater than If_B:
            testCase.verifyGreaterThan(If_A, If_B, ...
                'Fault current at Bus A must be strictly greater than at downstream Bus B.');

            % Also test parameterized feeder length: 2 km vs 10 km vs 30 km
            lengths_km = [2, 10, 30];
            z_per_km = 0.005 + 0.01i; % pu/km
            currents_by_len = zeros(size(lengths_km));

            for k = 1:numel(lengths_km)
                netCustom = net;
                netCustom.branches(1).Z1_pu = lengths_km(k) * z_per_km;
                netCustom.branches(1).Z2_pu = lengths_km(k) * z_per_km;
                sc = struct('id', 'SCN', 'faultedBus', 'BUS_A', 'faultType', '3PH', 'Zf_pu', 0.0);
                r = runIntegratedFaultStudy(netCustom, sc, relays, pairs);
                currents_by_len(k) = r.faultCurrentMagnitude_A;
            end

            testCase.verifyTrue(all(diff(currents_by_len) < 0), ...
                'Fault current must strictly decrease as feeder length increases.');
        end

        %% 3. Source Strength Sensitivity
        function testSourceStrengthSensitivity(testCase)
            % Stronger source (higher MVAsc) -> lower source impedance -> higher fault current
            MVAsc_values = [200, 500, 1000, 2000];
            faultCurrents = zeros(size(MVAsc_values));
            tripTimes = zeros(size(MVAsc_values));

            net = createIllustrativeRadialNetwork();
            relay = testCase.baseCfg.relays(strcmp({testCase.baseCfg.relays.id}, 'RELAY_BUS_B'));
            relays = struct('id', relay.id, 'pickupCurrent_A', relay.pickupCurrent_A.value, ...
                'TMS', relay.TMS.value, 'curveType', relay.curveType, ...
                'CTprimary_A', relay.CTprimary_A.value, 'CTsecondary_A', relay.CTsecondary_A.value, ...
                'protectedBranch', 'BR_B');
            pairs = struct([]);

            for idx = 1:numel(MVAsc_values)
                mv = MVAsc_values(idx);
                netCustom = net;
                % Zsource_pu = Sbase / MVAsc:
                Z_mag = net.base.SbaseVA / (mv * 1e6);
                XR = 10;
                phi = atan(XR);
                netCustom.source.Z1_pu = Z_mag * (cos(phi) + 1i*sin(phi));
                netCustom.source.Z2_pu = netCustom.source.Z1_pu;

                sc = struct('id', 'SCN', 'faultedBus', 'BUS_B', 'faultType', '3PH', 'Zf_pu', 0.0);
                r = runIntegratedFaultStudy(netCustom, sc, relays, pairs);

                faultCurrents(idx) = r.faultCurrentMagnitude_A;
                tripTimes(idx) = r.relayResults(1).operatingTime_s;
            end

            % Verify strict monotonic increase in fault current with source strength:
            testCase.verifyTrue(all(diff(faultCurrents) > 0), ...
                'Fault current must strictly increase as source short-circuit MVA increases.');

            % Verify strict monotonic decrease in relay trip time:
            testCase.verifyTrue(all(diff(tripTimes) < 0), ...
                'Trip time must strictly decrease as source strength increases.');
        end

        %% 4. Relay Time Multiplier Setting (TMS) Sensitivity
        function testTMSSensitivity(testCase)
            % Trip time is strictly proportional to TMS: t(TMS2)/t(TMS1) == TMS2/TMS1
            TMS_values = [0.05, 0.10, 0.20, 0.40];
            I_sec = 25.0; % CT secondary amperes
            Is_sec = 1.0;

            t_values = zeros(size(TMS_values));
            for k = 1:numel(TMS_values)
                t_values(k) = calculateRelayOperatingTime(I_sec, Is_sec, TMS_values(k), 'standard inverse');
            end

            % Verify strict monotonic increase:
            testCase.verifyTrue(all(diff(t_values) > 0), ...
                'Relay operating time must strictly increase with TMS.');

            % Verify exact linearity:
            for k = 2:numel(TMS_values)
                ratio_t = t_values(k) / t_values(1);
                ratio_TMS = TMS_values(k) / TMS_values(1);
                testCase.verifyEqual(ratio_t, ratio_TMS, 'RelTol', 1e-12);
            end
        end

    end
end
