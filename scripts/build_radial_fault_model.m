function modelPath = build_radial_fault_model(targetDir)
% build_radial_fault_model Programmatically construct the 33/11 kV radial fault study model
% with integrated dynamic protective relays and physical circuit breakers (Phase F).
%
% Syntax:
%   modelPath = build_radial_fault_model()
%   modelPath = build_radial_fault_model(targetDir)
%
% Target Network Architecture (PRD & Phase F specification):
%   - Source: 33 kV line-to-line RMS, 50 Hz Three-Phase Voltage Source
%   - Source Thevenin Impedance: Z1_pu = 0.10 pu on 10 MVA, 33 kV base
%       (R = 0.1089 Ohm, L = 34.665 mH, G_parasitic = 1e-6)
%   - Remote Backup Breaker: CB_33KV (Three-Phase Circuit Breaker, 80 ms delay)
%   - Transformer T1: 33/11 kV, 10 MVA Two-Winding Transformer, Yg/Yg (Ynyn0)
%       Z1_pu = 0.08 pu (Xl1 = 0.04 pu, Xl2 = 0.04 pu, Rw1 = 0.002 pu, Rw2 = 0.002 pu)
%   - Feeder Section BR_A: Z1_pu = 0.05 pu on 10 MVA, 11 kV base
%       (R = 0.0605 Ohm, L = 1.9258 mH, G_parasitic = 1e-6)
%   - Bus A: Intermediate 11 kV bus with Phase Voltage Sensor
%   - Backup Feeder Breaker: CB_BUS_A (Three-Phase Circuit Breaker, 60 ms delay)
%   - Current Sensor: I_Sensor_BusA (measures through-current from Bus A into Feeder BRB)
%   - Feeder Section BR_B: Z1_pu = 0.05 pu on 10 MVA, 11 kV base
%       (R = 0.0605 Ohm, L = 1.9258 mH, G_parasitic = 1e-6)
%   - Bus B: Terminal 11 kV bus with Phase Voltage Sensor
%   - Primary Feeder Breaker: CB_BUS_B (Three-Phase Circuit Breaker, 50 ms delay)
%   - Current Sensor: I_Sensor_BusB (measures current entering Load & Fault at Bus B)
%   - Prefault Load at Bus B: Star-connected 1 MW load (R = 121 Ohm)
%   - Fault Element at Bus B: Native Three-Phase Fault block with configurable fault type
%   - Dynamic Relays:
%       * Relay Bus B: CT 400/5, Pickup 1.0 A sec, TMS = 0.10, IEC Standard Inverse
%       * Relay Bus A: CT 600/5, Pickup 1.0 A sec, TMS = 0.25, IEC Standard Inverse
%   - Configurable Overrides:
%       * Config_Breaker_Clearing: '0' = breakers held closed (default, Phase C/D compatibility),
%                                 '1' = dynamic relay and physical breaker switching enabled.
%       * Config_Fail_CB_B:        '1' = simulate CB_BUS_B failure to open (backup clearing test).
%       * Config_Fail_CB_A:        '1' = simulate CB_BUS_A failure to open.
%   - Signal Outports:
%       * Port 1: V_BusA (3-phase voltages at Bus A)
%       * Port 2: I_BusA (3-phase currents leaving Bus A into Feeder BRB)
%       * Port 3: V_BusB (3-phase voltages at Bus B)
%       * Port 4: I_BusB (3-phase currents entering Bus B load & fault)
%       * Port 5: Trip_Cmd_B (Relay Bus B trip command)
%       * Port 6: Breaker_State_B (CB_BUS_B contact state: 0 = closed, 1 = open)
%       * Port 7: Trip_Cmd_A (Relay Bus A trip command)
%       * Port 8: Breaker_State_A (CB_BUS_A contact state: 0 = closed, 1 = open)
%       * Port 9: Integrator_Sigma_B (Relay Bus B operating time accumulation)
%       * Port 10: Integrator_Sigma_A (Relay Bus A operating time accumulation)

    if nargin < 1 || isempty(targetDir)
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
        targetDir = fullfile(projectRoot, 'simulink', 'models');
    else
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
    end

    addpath(genpath(fullfile(projectRoot, 'matlab')));
    cfg = getSystemMasterConfiguration();

    if ~exist(targetDir, 'dir')
        mkdir(targetDir);
    end

    modelName = 'radial_fault_study_network';
    modelPath = fullfile(targetDir, [modelName, '.slx']);

    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end

    new_system(modelName);

    try
        % -------------------------------------------------------------
        % 1. Add Simscape Electrical Power Conserving Blocks
        % -------------------------------------------------------------
        % Utilities & Grounding
        add_block('nesl_utility/Solver Configuration', [modelName, '/Solver']);
        set_param([modelName, '/Solver'], ...
            'ResidualTolerance', '1e-4', ...
            'MaxNonlinIter', '100');
        add_block('ee_lib/Connectors & References/Electrical Reference', [modelName, '/GND']);
        add_block('ee_lib/Connectors & References/Grounded Neutral (Three-Phase)', [modelName, '/Load_Neutral_GND']);
        add_block('ee_lib/Connectors & References/Grounded Neutral (Three-Phase)', [modelName, '/BusA_Neutral_GND']);
        add_block('ee_lib/Connectors & References/Grounded Neutral (Three-Phase)', [modelName, '/BusB_Neutral_GND']);

        % Source & Source Thevenin Impedance (33 kV)
        add_block('ee_lib/Sources/Voltage Source (Three-Phase)', [modelName, '/Source']);
        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Source_Impedance']);

        % 33 kV Remote Backup Breaker
        add_block('ee_lib/Switches & Breakers/Circuit Breaker (Three-Phase)', [modelName, '/CB_33KV']);

        % 33/11 kV Transformer
        add_block('ee_lib/Passive/Transformers/Two-Winding Transformer (Three-Phase)', [modelName, '/Transformer']);

        % Feeder BR_A (Bus 11KV to Bus A)
        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Feeder_BRA']);

        % Bus A: Voltage Sensor, Breaker CB_BUS_A, Current Sensor
        add_block('ee_lib/Sensors & Transducers/Phase Voltage Sensor (Three-Phase)', [modelName, '/V_Sensor_BusA']);
        add_block('ee_lib/Switches & Breakers/Circuit Breaker (Three-Phase)', [modelName, '/CB_BUS_A']);
        add_block('ee_lib/Sensors & Transducers/Current Sensor (Three-Phase)', [modelName, '/I_Sensor_BusA']);

        % Feeder BR_B (Bus A to Bus B)
        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Feeder_BRB']);

        % Bus B: Voltage Sensor, Breaker CB_BUS_B, Current Sensor, Load & Fault
        add_block('ee_lib/Sensors & Transducers/Phase Voltage Sensor (Three-Phase)', [modelName, '/V_Sensor_BusB']);
        add_block('ee_lib/Switches & Breakers/Circuit Breaker (Three-Phase)', [modelName, '/CB_BUS_B']);
        add_block('ee_lib/Sensors & Transducers/Current Sensor (Three-Phase)', [modelName, '/I_Sensor_BusB']);
        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Load_BusB']);
        add_block('ee_lib/Utilities/Fault (Three-Phase)', [modelName, '/Fault_BusB']);

        % Bus Stabilization Shunts (resolves DAE initial condition singularity for SLG/DLG ground faults)
        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Shunt_BusA']);
        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Shunt_BusB']);

        % -------------------------------------------------------------
        % 2. Converters & Interfaces
        % -------------------------------------------------------------
        % Physical Signal to Simulink (Measurements)
        add_block('nesl_utility/PS-Simulink Converter', [modelName, '/PS_V_BusA']);
        add_block('nesl_utility/PS-Simulink Converter', [modelName, '/PS_I_BusA']);
        add_block('nesl_utility/PS-Simulink Converter', [modelName, '/PS_V_BusB']);
        add_block('nesl_utility/PS-Simulink Converter', [modelName, '/PS_I_BusB']);

        % Simulink to Physical Signal (Breaker Switching Control)
        add_block('nesl_utility/Simulink-PS Converter', [modelName, '/PS_Trip_CB_B']);
        add_block('nesl_utility/Simulink-PS Converter', [modelName, '/PS_Trip_CB_A']);
        add_block('nesl_utility/Simulink-PS Converter', [modelName, '/PS_Trip_CB_33KV']);

        % -------------------------------------------------------------
        % 3. Signal Outports (Ordered 1 to 10)
        % -------------------------------------------------------------
        add_block('built-in/Outport', [modelName, '/V_BusA']);            % Port 1
        add_block('built-in/Outport', [modelName, '/I_BusA']);            % Port 2
        add_block('built-in/Outport', [modelName, '/V_BusB']);            % Port 3
        add_block('built-in/Outport', [modelName, '/I_BusB']);            % Port 4
        add_block('built-in/Outport', [modelName, '/Trip_Cmd_B']);        % Port 5
        add_block('built-in/Outport', [modelName, '/Breaker_State_B']);    % Port 6
        add_block('built-in/Outport', [modelName, '/Trip_Cmd_A']);        % Port 7
        add_block('built-in/Outport', [modelName, '/Breaker_State_A']);    % Port 8
        add_block('built-in/Outport', [modelName, '/Integrator_Sigma_B']);% Port 9
        add_block('built-in/Outport', [modelName, '/Integrator_Sigma_A']);% Port 10

        % -------------------------------------------------------------
        % 4. Parameter Configuration
        % -------------------------------------------------------------
        % 33 kV Source: ideal voltage output from master config
        set_param([modelName, '/Source'], ...
            'vline_rms', num2str(cfg.source.voltage_V.value), ...
            'vline_rms_unit', 'V', ...
            'freq', num2str(cfg.systemBase.frequency_Hz.value), ...
            'freq_unit', 'Hz', ...
            'impedance_option', '0');

        % Source Thevenin Impedance: from master config
        set_param([modelName, '/Source_Impedance'], ...
            'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
            'R', num2str(cfg.source.physical.R_Ohm.value), ...
            'R_unit', 'Ohm', ...
            'L', num2str(cfg.source.physical.L_H.value), ...
            'L_unit', 'H', ...
            'G_parasitic', num2str(cfg.source.physical.G_parasitic_S.value));

        % 33/11 kV Two-Winding Transformer T1: from master config
        set_param([modelName, '/Transformer'], ...
            'SRated', num2str(cfg.transformer.ratedSbaseVA.value), ...
            'FRated', num2str(cfg.systemBase.frequency_Hz.value), ...
            'VRated1', num2str(cfg.transformer.ratedHighVoltageV.value), ...
            'VRated2', num2str(cfg.transformer.ratedLowVoltageV.value), ...
            'Winding1Connection', 'ee.enum.windingconnection.Yg', ...
            'Winding2Connection', 'ee.enum.windingconnection.Yg', ...
            'param_option', 'ee.enum.transformer_parameterization.circuitimpedances', ...
            'leakage_reactance_option', 'ee.enum.transformer_leakage.include', ...
            'pu_Rw1', num2str(cfg.transformer.physical.Rw1_pu.value), ...
            'pu_Rw2', num2str(cfg.transformer.physical.Rw2_pu.value), ...
            'pu_Xl1', num2str(cfg.transformer.physical.Xl1_pu.value), ...
            'pu_Xl2', num2str(cfg.transformer.physical.Xl2_pu.value));

        % Feeder Section BR_A: from master config
        set_param([modelName, '/Feeder_BRA'], ...
            'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
            'R', num2str(cfg.feeders.BRA.physical.R_Ohm.value), ...
            'R_unit', 'Ohm', ...
            'L', num2str(cfg.feeders.BRA.physical.L_H.value), ...
            'L_unit', 'H', ...
            'G_parasitic', num2str(cfg.feeders.BRA.physical.G_parasitic_S.value));

        % Feeder Section BR_B: from master config
        set_param([modelName, '/Feeder_BRB'], ...
            'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
            'R', num2str(cfg.feeders.BRB.physical.R_Ohm.value), ...
            'R_unit', 'Ohm', ...
            'L', num2str(cfg.feeders.BRB.physical.L_H.value), ...
            'L_unit', 'H', ...
            'G_parasitic', num2str(cfg.feeders.BRB.physical.G_parasitic_S.value));

        % Prefault Load at Bus B: from master config
        set_param([modelName, '/Load_BusB'], ...
            'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
            'R', num2str(cfg.load.R_Ohm.value), ...
            'R_unit', 'Ohm', ...
            'L', '0.001', ...
            'L_unit', 'H');

        % Three-Phase Fault Element at Bus B
        set_param([modelName, '/Fault_BusB'], ...
            'fault_type_option', 'ee.enum.fault_type_option.abc', ...
            'enable_temporal_fault', 'ee.enum.enable.yes', ...
            'fault_start_time', '0.05', ...
            'fault_start_time_unit', 's', ...
            'fault_duration', '0.20', ...
            'fault_duration_unit', 's', ...
            'R_pn_fault', '0.001', ...
            'R_pn_fault_unit', 'Ohm', ...
            'R_ng_fault', '0.001', ...
            'R_ng_fault_unit', 'Ohm');

        % Three-Phase Circuit Breakers: R_closed = 0.001 Ohm, G_open = 1e-6 S
        cbList = {'CB_33KV', 'CB_BUS_A', 'CB_BUS_B'};
        for cIdx = 1:numel(cbList)
            set_param([modelName, '/', cbList{cIdx}], ...
                'R_closed', '0.001', ...
                'G_open', '1e-6', ...
                'threshold', '0.5');
        end

        % Bus Stabilization Shunts: 100 kOhm to ground
        set_param([modelName, '/Shunt_BusA'], ...
            'component_structure', 'ee.enum.rlc.structure.R', ...
            'R', '100000');
        set_param([modelName, '/Shunt_BusB'], ...
            'component_structure', 'ee.enum.rlc.structure.R', ...
            'R', '100000');

        % -------------------------------------------------------------
        % 5. Connect Simscape Physical Conserving Lines
        % -------------------------------------------------------------
        % Ground references
        add_line(modelName, 'Solver/RConn1', 'GND/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Source/LConn1', 'GND/LConn1', 'autorouting', 'on');

        % Source -> Source Impedance -> CB_33KV -> Transformer Primary
        add_line(modelName, 'Source/RConn1', 'Source_Impedance/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Source_Impedance/RConn1', 'CB_33KV/LConn2', 'autorouting', 'on');
        add_line(modelName, 'CB_33KV/RConn1', 'Transformer/LConn1', 'autorouting', 'on');

        % Transformer Secondary -> Feeder BR_A
        add_line(modelName, 'Transformer/RConn1', 'Feeder_BRA/LConn1', 'autorouting', 'on');

        % Bus A: Voltage sensor tapped at Feeder BRA output, referenced to neutral ground
        add_line(modelName, 'Feeder_BRA/RConn1', 'V_Sensor_BusA/LConn1', 'autorouting', 'on');
        add_line(modelName, 'V_Sensor_BusA/RConn2', 'BusA_Neutral_GND/LConn1', 'autorouting', 'on');

        % Bus A Stabilization Shunt to Ground
        add_line(modelName, 'Feeder_BRA/RConn1', 'Shunt_BusA/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Shunt_BusA/RConn1', 'BusA_Neutral_GND/LConn1', 'autorouting', 'on');

        % Bus A -> CB_BUS_A -> I_Sensor_BusA -> Feeder BR_B
        add_line(modelName, 'Feeder_BRA/RConn1', 'CB_BUS_A/LConn2', 'autorouting', 'on');
        add_line(modelName, 'CB_BUS_A/RConn1', 'I_Sensor_BusA/LConn1', 'autorouting', 'on');
        add_line(modelName, 'I_Sensor_BusA/RConn2', 'Feeder_BRB/LConn1', 'autorouting', 'on');

        % Bus B: Voltage sensor tapped at Feeder BRB output, referenced to neutral ground
        add_line(modelName, 'Feeder_BRB/RConn1', 'V_Sensor_BusB/LConn1', 'autorouting', 'on');
        add_line(modelName, 'V_Sensor_BusB/RConn2', 'BusB_Neutral_GND/LConn1', 'autorouting', 'on');

        % Bus B Stabilization Shunt to Ground
        add_line(modelName, 'Feeder_BRB/RConn1', 'Shunt_BusB/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Shunt_BusB/RConn1', 'BusB_Neutral_GND/LConn1', 'autorouting', 'on');

        % Bus B -> CB_BUS_B -> I_Sensor_BusB -> Load & Fault
        add_line(modelName, 'Feeder_BRB/RConn1', 'CB_BUS_B/LConn2', 'autorouting', 'on');
        add_line(modelName, 'CB_BUS_B/RConn1', 'I_Sensor_BusB/LConn1', 'autorouting', 'on');
        add_line(modelName, 'I_Sensor_BusB/RConn2', 'Load_BusB/LConn1', 'autorouting', 'on');
        add_line(modelName, 'I_Sensor_BusB/RConn2', 'Fault_BusB/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Load_BusB/RConn1', 'Load_Neutral_GND/LConn1', 'autorouting', 'on');

        % Measurement Physical Signals to Converters
        add_line(modelName, 'V_Sensor_BusA/RConn1', 'PS_V_BusA/LConn1', 'autorouting', 'on');
        add_line(modelName, 'I_Sensor_BusA/RConn1', 'PS_I_BusA/LConn1', 'autorouting', 'on');
        add_line(modelName, 'V_Sensor_BusB/RConn1', 'PS_V_BusB/LConn1', 'autorouting', 'on');
        add_line(modelName, 'I_Sensor_BusB/RConn1', 'PS_I_BusB/LConn1', 'autorouting', 'on');

        % Converters to Simulink Outports 1-4
        add_line(modelName, 'PS_V_BusA/1', 'V_BusA/1', 'autorouting', 'on');
        add_line(modelName, 'PS_I_BusA/1', 'I_BusA/1', 'autorouting', 'on');
        add_line(modelName, 'PS_V_BusB/1', 'V_BusB/1', 'autorouting', 'on');
        add_line(modelName, 'PS_I_BusB/1', 'I_BusB/1', 'autorouting', 'on');

        % -------------------------------------------------------------
        % 6. Configuration Override Constants
        % -------------------------------------------------------------
        % Enable_Breaker_Clearing: '0' = hold closed (default), '1' = active
        add_block('simulink/Sources/Constant', [modelName, '/Config_Breaker_Clearing']);
        set_param([modelName, '/Config_Breaker_Clearing'], 'Value', '0');

        % Fail_CB_B: '1' = simulate CB_BUS_B failure (failed to open)
        add_block('simulink/Sources/Constant', [modelName, '/Config_Fail_CB_B']);
        set_param([modelName, '/Config_Fail_CB_B'], 'Value', '0');

        % Fail_CB_A: '1' = simulate CB_BUS_A failure
        add_block('simulink/Sources/Constant', [modelName, '/Config_Fail_CB_A']);
        set_param([modelName, '/Config_Fail_CB_A'], 'Value', '0');

        % Master clock and startup gate (enable relay after initial 25 ms settling)
        add_block('simulink/Sources/Clock', [modelName, '/Master_Clock']);
        add_block('simulink/Logic and Bit Operations/Compare To Constant', [modelName, '/Check_Startup_Gate']);
        set_param([modelName, '/Check_Startup_Gate'], 'const', '0.025', 'relop', '>=');
        add_line(modelName, 'Master_Clock/1', 'Check_Startup_Gate/1', 'autorouting', 'on');

        % -------------------------------------------------------------
        % 7. Primary Relay Bus B Subsystem (RELAY_BUS_B -> CB_BUS_B)
        % -------------------------------------------------------------
        relayB = cfg.relays(strcmp({cfg.relays.id}, 'RELAY_BUS_B'));
        bkrB   = cfg.breakers(strcmp({cfg.breakers.id}, 'CB_BUS_B'));
        gainValB = num2str(relayB.CTsecondary_A.value / relayB.CTprimary_A.value);
        bp = [1.0, 1.005, 1.01, 1.02, 1.05, 1.1, 1.2, 1.5, 2, 3, 5, 10, 20, 30, 50, 100];
        bp_str = mat2str(bp);
        rate_B = (bp.^0.02 - 1) ./ (0.14 * relayB.TMS.value);
        rate_B(1) = 0.0;
        tbl_B_str = mat2str(round(rate_B, 5));

        % Sliding 1-cycle RMS (T = 0.020 s at 50 Hz) for 3-phase currents
        add_block('simulink/Math Operations/Math Function', [modelName, '/Square_I_B']);
        set_param([modelName, '/Square_I_B'], 'Operator', 'square');
        add_block('simulink/Continuous/Integrator', [modelName, '/Int_I2_B']);
        add_block('simulink/Continuous/Transport Delay', [modelName, '/Delay_I2_B']);
        set_param([modelName, '/Delay_I2_B'], 'DelayTime', '0.020', 'BufferSize', '4096', 'InitialOutput', '0');
        add_block('simulink/Math Operations/Subtract', [modelName, '/Sub_I2_B']);
        add_block('simulink/Math Operations/Gain', [modelName, '/Gain_I2_B']);
        set_param([modelName, '/Gain_I2_B'], 'Gain', '50');
        add_block('simulink/Discontinuities/Saturation', [modelName, '/Sat_I2_B']);
        set_param([modelName, '/Sat_I2_B'], 'LowerLimit', '0', 'UpperLimit', 'inf');
        add_block('simulink/Math Operations/Sqrt', [modelName, '/Sqrt_I_B']);

        add_block('simulink/Math Operations/MinMax', [modelName, '/Max_Phase_B']);
        set_param([modelName, '/Max_Phase_B'], 'Function', 'max', 'Inputs', '1');
        add_block('simulink/Math Operations/Gain', [modelName, '/Gain_M_B']);
        set_param([modelName, '/Gain_M_B'], 'Gain', gainValB);

        add_block('simulink/Logic and Bit Operations/Compare To Constant', [modelName, '/Check_Pickup_B']);
        set_param([modelName, '/Check_Pickup_B'], 'const', num2str(relayB.pickupCurrent_A.value), 'relop', '>=');

        add_block('simulink/Logic and Bit Operations/Logical Operator', [modelName, '/And_Pickup_B']);
        set_param([modelName, '/And_Pickup_B'], 'Operator', 'AND', 'Inputs', '2');

        add_block('simulink/Lookup Tables/1-D Lookup Table', [modelName, '/IEC_Rate_Table_B']);
        set_param([modelName, '/IEC_Rate_Table_B'], ...
            'BreakpointsForDimension1', bp_str, ...
            'Table', tbl_B_str);

        add_block('simulink/Sources/Constant', [modelName, '/Reset_Rate_B']);
        set_param([modelName, '/Reset_Rate_B'], 'Value', '-2.0');

        add_block('simulink/Signal Routing/Switch', [modelName, '/Rate_Switch_B']);
        set_param([modelName, '/Rate_Switch_B'], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');

        add_block('simulink/Continuous/Integrator', [modelName, '/Integrator_B']);
        set_param([modelName, '/Integrator_B'], ...
            'LimitOutput', 'on', ...
            'UpperSaturationLimit', '1.0', ...
            'LowerSaturationLimit', '0.0');

        add_block('simulink/Logic and Bit Operations/Compare To Constant', [modelName, '/Check_Trip_B']);
        set_param([modelName, '/Check_Trip_B'], 'const', '0.999', 'relop', '>=');

        add_block('simulink/Signal Attributes/Data Type Conversion', [modelName, '/Conv_Bool_B']);
        set_param([modelName, '/Conv_Bool_B'], 'OutDataTypeStr', 'boolean');
        add_block('simulink/Sources/Constant', [modelName, '/Reset_Zero_B']);
        set_param([modelName, '/Reset_Zero_B'], 'Value', '0', 'OutDataTypeStr', 'boolean');
        add_block('simulink_extras/Flip Flops/S-R Flip-Flop', [modelName, '/Trip_Latch_B']);
        add_block('simulink/Signal Attributes/Data Type Conversion', [modelName, '/Conv_Double_B']);
        set_param([modelName, '/Conv_Double_B'], 'OutDataTypeStr', 'double');

        add_block('simulink/Continuous/Transport Delay', [modelName, '/Breaker_Delay_B']);
        set_param([modelName, '/Breaker_Delay_B'], 'DelayTime', num2str(bkrB.openingDelay_s.value), 'InitialOutput', '0', 'BufferSize', '4096');

        % Breaker failure & master enable gating for CB_BUS_B
        add_block('simulink/Math Operations/Gain', [modelName, '/Neg_Fail_B']);
        set_param([modelName, '/Neg_Fail_B'], 'Gain', '-1');
        add_block('simulink/Math Operations/Bias', [modelName, '/Inv_Fail_B']);
        set_param([modelName, '/Inv_Fail_B'], 'Bias', '1');
        add_block('simulink/Math Operations/Product', [modelName, '/Gate_CB_B']);
        set_param([modelName, '/Gate_CB_B'], 'Inputs', '3');

        % Connect Relay B
        add_line(modelName, 'PS_I_BusB/1', 'Square_I_B/1', 'autorouting', 'on');
        add_line(modelName, 'Square_I_B/1', 'Int_I2_B/1', 'autorouting', 'on');
        add_line(modelName, 'Int_I2_B/1', 'Delay_I2_B/1', 'autorouting', 'on');
        add_line(modelName, 'Int_I2_B/1', 'Sub_I2_B/1', 'autorouting', 'on');
        add_line(modelName, 'Delay_I2_B/1', 'Sub_I2_B/2', 'autorouting', 'on');
        add_line(modelName, 'Sub_I2_B/1', 'Gain_I2_B/1', 'autorouting', 'on');
        add_line(modelName, 'Gain_I2_B/1', 'Sat_I2_B/1', 'autorouting', 'on');
        add_line(modelName, 'Sat_I2_B/1', 'Sqrt_I_B/1', 'autorouting', 'on');
        add_line(modelName, 'Sqrt_I_B/1', 'Max_Phase_B/1', 'autorouting', 'on');
        add_line(modelName, 'Max_Phase_B/1', 'Gain_M_B/1', 'autorouting', 'on');

        add_line(modelName, 'Gain_M_B/1', 'Check_Pickup_B/1', 'autorouting', 'on');
        add_line(modelName, 'Check_Pickup_B/1', 'And_Pickup_B/1', 'autorouting', 'on');
        add_line(modelName, 'Check_Startup_Gate/1', 'And_Pickup_B/2', 'autorouting', 'on');

        add_line(modelName, 'Gain_M_B/1', 'IEC_Rate_Table_B/1', 'autorouting', 'on');
        add_line(modelName, 'IEC_Rate_Table_B/1', 'Rate_Switch_B/1', 'autorouting', 'on');
        add_line(modelName, 'And_Pickup_B/1', 'Rate_Switch_B/2', 'autorouting', 'on');
        add_line(modelName, 'Reset_Rate_B/1', 'Rate_Switch_B/3', 'autorouting', 'on');

        add_line(modelName, 'Rate_Switch_B/1', 'Integrator_B/1', 'autorouting', 'on');
        add_line(modelName, 'Integrator_B/1', 'Integrator_Sigma_B/1', 'autorouting', 'on');
        add_line(modelName, 'Integrator_B/1', 'Check_Trip_B/1', 'autorouting', 'on');

        add_line(modelName, 'Check_Trip_B/1', 'Conv_Bool_B/1', 'autorouting', 'on');
        add_line(modelName, 'Conv_Bool_B/1', 'Trip_Latch_B/1', 'autorouting', 'on');
        add_line(modelName, 'Reset_Zero_B/1', 'Trip_Latch_B/2', 'autorouting', 'on');
        add_line(modelName, 'Trip_Latch_B/1', 'Conv_Double_B/1', 'autorouting', 'on');

        add_line(modelName, 'Conv_Double_B/1', 'Trip_Cmd_B/1', 'autorouting', 'on');
        add_line(modelName, 'Conv_Double_B/1', 'Breaker_Delay_B/1', 'autorouting', 'on');

        add_line(modelName, 'Breaker_Delay_B/1', 'Gate_CB_B/1', 'autorouting', 'on');
        add_line(modelName, 'Config_Breaker_Clearing/1', 'Gate_CB_B/2', 'autorouting', 'on');
        add_line(modelName, 'Config_Fail_CB_B/1', 'Neg_Fail_B/1', 'autorouting', 'on');
        add_line(modelName, 'Neg_Fail_B/1', 'Inv_Fail_B/1', 'autorouting', 'on');
        add_line(modelName, 'Inv_Fail_B/1', 'Gate_CB_B/3', 'autorouting', 'on');

        add_line(modelName, 'Gate_CB_B/1', 'Breaker_State_B/1', 'autorouting', 'on');
        add_line(modelName, 'Gate_CB_B/1', 'PS_Trip_CB_B/1', 'autorouting', 'on');
        add_line(modelName, 'PS_Trip_CB_B/RConn1', 'CB_BUS_B/LConn1', 'autorouting', 'on');

        % -------------------------------------------------------------
        % 8. Backup Relay Bus A Subsystem (RELAY_BUS_A -> CB_BUS_A)
        % -------------------------------------------------------------
        relayA = cfg.relays(strcmp({cfg.relays.id}, 'RELAY_BUS_A'));
        bkrA   = cfg.breakers(strcmp({cfg.breakers.id}, 'CB_BUS_A'));
        gainValA = num2str(relayA.CTsecondary_A.value / relayA.CTprimary_A.value);
        rate_A = (bp.^0.02 - 1) ./ (0.14 * relayA.TMS.value);
        rate_A(1) = 0.0;
        tbl_A_str = mat2str(round(rate_A, 5));

        % Sliding 1-cycle RMS (T = 0.020 s at 50 Hz) for 3-phase currents
        add_block('simulink/Math Operations/Math Function', [modelName, '/Square_I_A']);
        set_param([modelName, '/Square_I_A'], 'Operator', 'square');
        add_block('simulink/Continuous/Integrator', [modelName, '/Int_I2_A']);
        add_block('simulink/Continuous/Transport Delay', [modelName, '/Delay_I2_A']);
        set_param([modelName, '/Delay_I2_A'], 'DelayTime', '0.020', 'BufferSize', '4096', 'InitialOutput', '0');
        add_block('simulink/Math Operations/Subtract', [modelName, '/Sub_I2_A']);
        add_block('simulink/Math Operations/Gain', [modelName, '/Gain_I2_A']);
        set_param([modelName, '/Gain_I2_A'], 'Gain', '50');
        add_block('simulink/Discontinuities/Saturation', [modelName, '/Sat_I2_A']);
        set_param([modelName, '/Sat_I2_A'], 'LowerLimit', '0', 'UpperLimit', 'inf');
        add_block('simulink/Math Operations/Sqrt', [modelName, '/Sqrt_I_A']);

        add_block('simulink/Math Operations/MinMax', [modelName, '/Max_Phase_A']);
        set_param([modelName, '/Max_Phase_A'], 'Function', 'max', 'Inputs', '1');
        add_block('simulink/Math Operations/Gain', [modelName, '/Gain_M_A']);
        set_param([modelName, '/Gain_M_A'], 'Gain', gainValA);

        add_block('simulink/Logic and Bit Operations/Compare To Constant', [modelName, '/Check_Pickup_A']);
        set_param([modelName, '/Check_Pickup_A'], 'const', num2str(relayA.pickupCurrent_A.value), 'relop', '>=');

        add_block('simulink/Logic and Bit Operations/Logical Operator', [modelName, '/And_Pickup_A']);
        set_param([modelName, '/And_Pickup_A'], 'Operator', 'AND', 'Inputs', '2');

        add_block('simulink/Lookup Tables/1-D Lookup Table', [modelName, '/IEC_Rate_Table_A']);
        set_param([modelName, '/IEC_Rate_Table_A'], ...
            'BreakpointsForDimension1', bp_str, ...
            'Table', tbl_A_str);

        add_block('simulink/Sources/Constant', [modelName, '/Reset_Rate_A']);
        set_param([modelName, '/Reset_Rate_A'], 'Value', '-2.0');

        add_block('simulink/Signal Routing/Switch', [modelName, '/Rate_Switch_A']);
        set_param([modelName, '/Rate_Switch_A'], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');

        add_block('simulink/Continuous/Integrator', [modelName, '/Integrator_A']);
        set_param([modelName, '/Integrator_A'], ...
            'LimitOutput', 'on', ...
            'UpperSaturationLimit', '1.0', ...
            'LowerSaturationLimit', '0.0');

        add_block('simulink/Logic and Bit Operations/Compare To Constant', [modelName, '/Check_Trip_A']);
        set_param([modelName, '/Check_Trip_A'], 'const', '0.999', 'relop', '>=');

        add_block('simulink/Signal Attributes/Data Type Conversion', [modelName, '/Conv_Bool_A']);
        set_param([modelName, '/Conv_Bool_A'], 'OutDataTypeStr', 'boolean');
        add_block('simulink/Sources/Constant', [modelName, '/Reset_Zero_A']);
        set_param([modelName, '/Reset_Zero_A'], 'Value', '0', 'OutDataTypeStr', 'boolean');
        add_block('simulink_extras/Flip Flops/S-R Flip-Flop', [modelName, '/Trip_Latch_A']);
        add_block('simulink/Signal Attributes/Data Type Conversion', [modelName, '/Conv_Double_A']);
        set_param([modelName, '/Conv_Double_A'], 'OutDataTypeStr', 'double');

        add_block('simulink/Continuous/Transport Delay', [modelName, '/Breaker_Delay_A']);
        set_param([modelName, '/Breaker_Delay_A'], 'DelayTime', num2str(bkrA.openingDelay_s.value), 'InitialOutput', '0', 'BufferSize', '4096');

        % Breaker failure & master enable gating for CB_BUS_A
        add_block('simulink/Math Operations/Gain', [modelName, '/Neg_Fail_A']);
        set_param([modelName, '/Neg_Fail_A'], 'Gain', '-1');
        add_block('simulink/Math Operations/Bias', [modelName, '/Inv_Fail_A']);
        set_param([modelName, '/Inv_Fail_A'], 'Bias', '1');
        add_block('simulink/Math Operations/Product', [modelName, '/Gate_CB_A']);
        set_param([modelName, '/Gate_CB_A'], 'Inputs', '3');

        % Connect Relay A
        add_line(modelName, 'PS_I_BusA/1', 'Square_I_A/1', 'autorouting', 'on');
        add_line(modelName, 'Square_I_A/1', 'Int_I2_A/1', 'autorouting', 'on');
        add_line(modelName, 'Int_I2_A/1', 'Delay_I2_A/1', 'autorouting', 'on');
        add_line(modelName, 'Int_I2_A/1', 'Sub_I2_A/1', 'autorouting', 'on');
        add_line(modelName, 'Delay_I2_A/1', 'Sub_I2_A/2', 'autorouting', 'on');
        add_line(modelName, 'Sub_I2_A/1', 'Gain_I2_A/1', 'autorouting', 'on');
        add_line(modelName, 'Gain_I2_A/1', 'Sat_I2_A/1', 'autorouting', 'on');
        add_line(modelName, 'Sat_I2_A/1', 'Sqrt_I_A/1', 'autorouting', 'on');
        add_line(modelName, 'Sqrt_I_A/1', 'Max_Phase_A/1', 'autorouting', 'on');
        add_line(modelName, 'Max_Phase_A/1', 'Gain_M_A/1', 'autorouting', 'on');

        add_line(modelName, 'Gain_M_A/1', 'Check_Pickup_A/1', 'autorouting', 'on');
        add_line(modelName, 'Check_Pickup_A/1', 'And_Pickup_A/1', 'autorouting', 'on');
        add_line(modelName, 'Check_Startup_Gate/1', 'And_Pickup_A/2', 'autorouting', 'on');

        add_line(modelName, 'Gain_M_A/1', 'IEC_Rate_Table_A/1', 'autorouting', 'on');
        add_line(modelName, 'IEC_Rate_Table_A/1', 'Rate_Switch_A/1', 'autorouting', 'on');
        add_line(modelName, 'And_Pickup_A/1', 'Rate_Switch_A/2', 'autorouting', 'on');
        add_line(modelName, 'Reset_Rate_A/1', 'Rate_Switch_A/3', 'autorouting', 'on');

        add_line(modelName, 'Rate_Switch_A/1', 'Integrator_A/1', 'autorouting', 'on');
        add_line(modelName, 'Integrator_A/1', 'Integrator_Sigma_A/1', 'autorouting', 'on');
        add_line(modelName, 'Integrator_A/1', 'Check_Trip_A/1', 'autorouting', 'on');

        add_line(modelName, 'Check_Trip_A/1', 'Conv_Bool_A/1', 'autorouting', 'on');
        add_line(modelName, 'Conv_Bool_A/1', 'Trip_Latch_A/1', 'autorouting', 'on');
        add_line(modelName, 'Reset_Zero_A/1', 'Trip_Latch_A/2', 'autorouting', 'on');
        add_line(modelName, 'Trip_Latch_A/1', 'Conv_Double_A/1', 'autorouting', 'on');

        add_line(modelName, 'Conv_Double_A/1', 'Trip_Cmd_A/1', 'autorouting', 'on');
        add_line(modelName, 'Conv_Double_A/1', 'Breaker_Delay_A/1', 'autorouting', 'on');

        add_line(modelName, 'Breaker_Delay_A/1', 'Gate_CB_A/1', 'autorouting', 'on');
        add_line(modelName, 'Config_Breaker_Clearing/1', 'Gate_CB_A/2', 'autorouting', 'on');
        add_line(modelName, 'Config_Fail_CB_A/1', 'Neg_Fail_A/1', 'autorouting', 'on');
        add_line(modelName, 'Neg_Fail_A/1', 'Inv_Fail_A/1', 'autorouting', 'on');
        add_line(modelName, 'Inv_Fail_A/1', 'Gate_CB_A/3', 'autorouting', 'on');

        add_line(modelName, 'Gate_CB_A/1', 'Breaker_State_A/1', 'autorouting', 'on');
        add_line(modelName, 'Gate_CB_A/1', 'PS_Trip_CB_A/1', 'autorouting', 'on');
        add_line(modelName, 'PS_Trip_CB_A/RConn1', 'CB_BUS_A/LConn1', 'autorouting', 'on');

        % -------------------------------------------------------------
        % 9. Remote Backup Breaker CB_33KV Control
        % -------------------------------------------------------------
        % Default: held closed (value = 0)
        add_block('simulink/Sources/Constant', [modelName, '/Const_Zero_33KV']);
        set_param([modelName, '/Const_Zero_33KV'], 'Value', '0');
        add_line(modelName, 'Const_Zero_33KV/1', 'PS_Trip_CB_33KV/1', 'autorouting', 'on');
        add_line(modelName, 'PS_Trip_CB_33KV/RConn1', 'CB_33KV/LConn1', 'autorouting', 'on');

        % -------------------------------------------------------------
        % 10. Solver and Data Logging Configuration
        % -------------------------------------------------------------
        % ode23t (trapezoidal stiff) is the recommended solver for Simscape
        % power systems. The extra options below resolve DAE IC-solver
        % convergence failures for asymmetric faults (SLG / DLG):
        %
        %   InitialStep 1e-6 s  : forces a very small first step so the
        %                          solver linearises from a good starting
        %                          point before the integrator warms up.
        %   AbsTol  1e-6       : prevents overly aggressive rejection of
        %                         asymmetric initial states.
        %   RelTol  1e-4       : standard for power-system models.
        %   ConsistencyChecking 'off' : the primary fix for SLG/DLG;
        %                         suppresses the secondary IC consistency
        %                         pass that fails when a grounded-neutral
        %                         fault path is active at t=0.
        % Simulink ODE solver config.
        % ConsistencyChecking=off prevents Simulink re-checking the IC that
        % Simscape's own IC solver already accepted.
        % Note: InitialStep/AbsTol/RelTol are ODE parameters; NE_DAE_IC_Failure
        % comes from the Simscape NE layer and is controlled by the Solver
        % Configuration block (ResidualsTolerance / MaxNonlinIter) above.
        set_param(modelName, ...
            'StopTime', '0.15', ...
            'Solver', 'ode23t', ...
            'MaxStep', '5e-5', ...
            'ConsistencyChecking', 'off', ...
            'SaveOutput', 'on', ...
            'OutputSaveName', 'yout', ...
            'SaveTime', 'on', ...
            'TimeSaveName', 'tout');

        % 11. Save model
        save_system(modelName, modelPath);
        close_system(modelName);

    catch ME
        if bdIsLoaded(modelName)
            close_system(modelName, 0);
        end
        rethrow(ME);
    end
end
