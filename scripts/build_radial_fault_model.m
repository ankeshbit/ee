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
%   - Remote Backup Breaker: CB_33KV (Three-Phase Circuit Breaker, 80 ms delay)
%   - Transformer T1: 33/11 kV, 10 MVA Two-Winding Transformer, Yg/Yg (Ynyn0)
%   - Feeder Section BR_A: Z1_pu = 0.05 pu on 10 MVA, 11 kV base
%   - Bus A: Intermediate 11 kV bus with Phase Voltage Sensor
%   - Backup Feeder Breaker: CB_BUS_A (Three-Phase Circuit Breaker, 60 ms delay)
%   - Current Sensor: I_Sensor_BusA (measures through-current from Bus A into Feeder BRB)
%   - Feeder Section BR_B: Z1_pu = 0.05 pu on 10 MVA, 11 kV base
%   - Bus B: Terminal 11 kV bus with Phase Voltage Sensor
%   - Primary Feeder Breaker: CB_BUS_B (Three-Phase Circuit Breaker, 50 ms delay)
%   - Current Sensor: I_Sensor_BusB (measures current entering Load & Fault at Bus B)
%   - Prefault Load at Bus B: Star-connected 1 MW load (R = 121 Ohm)
%   - Fault Element at Bus B: Native Three-Phase Fault block with configurable fault type
%   - Dynamic Relays in Dedicated Subsystems:
%       * RELAY_33KV: CT 200/5, Pickup 1.5 A sec, TMS = 0.40, IEC Standard Inverse (Remote Backup)
%       * RELAY_BUS_A: CT 600/5, Pickup 1.0 A sec, TMS = 0.25, IEC Standard Inverse (Feeder Backup)
%       * RELAY_BUS_B: CT 400/5, Pickup 1.0 A sec, TMS = 0.10, IEC Standard Inverse (Primary Feeder)
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
    addpath(fullfile(projectRoot, 'matlab', 'simulink_layout'));
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
        % =============================================================
        % 1. Title Banner and Section Area Annotations
        % =============================================================
        addTitle(modelName, ...
            '33/11 kV Radial Fault Study Network with Dynamic Protective Relays', ...
            'Automated Symmetrical & Asymmetrical Fault Analysis, Relay Coordination, and Breaker Switching (Phase F/G)', ...
            [40, 20, 1420, 80]);

        % Area 1: Power Network
        addLabeledArea(modelName, 'Area_Power_Network', [40, 100, 1450, 420], ...
            '33/11 kV Power Network (Single-Line Diagram Flow: Left to Right)', ...
            struct('backgroundColor', '[0.93, 0.95, 0.99]', 'fontSize', 11));

        % Area 2: Measurement Interface & Outports 1-4
        addLabeledArea(modelName, 'Area_Measurements', [40, 440, 1450, 600], ...
            'Measurements and Physical-to-Simulink Signal Converters', ...
            struct('backgroundColor', '[0.96, 0.96, 0.96]', 'fontSize', 11));

        % Area 3: Protection Relays
        addLabeledArea(modelName, 'Area_Relays', [40, 620, 1450, 850], ...
            'Protection Relays (IEC 60255-151 Inverse-Time Elements)', ...
            struct('backgroundColor', '[0.94, 0.98, 0.94]', 'fontSize', 11));

        % Area 4: Breakers and Switching Logic
        addLabeledArea(modelName, 'Area_Breakers', [40, 870, 1450, 1100], ...
            'Breakers and Dynamic Switching Control (Mechanism Delay & Failure Gating)', ...
            struct('backgroundColor', '[0.99, 0.95, 0.93]', 'fontSize', 11));

        % =============================================================
        % 2. Power Network Components (Flow: Left to Right)
        % =============================================================
        % Solver & Global Reference (Corner: x = 50..150, y = 320..390)
        add_block('nesl_utility/Solver Configuration', [modelName, '/Solver']);
        set_param([modelName, '/Solver'], 'ResidualTolerance', '1e-4', 'MaxNonlinIter', '100');
        place([modelName, '/Solver'], 50, 320, 50, 30, struct('showName', 'off'));

        add_block('ee_lib/Connectors & References/Electrical Reference', [modelName, '/GND']);
        place([modelName, '/GND'], 120, 320, 30, 30, struct('showName', 'on'));

        % Main line elements (Row y = 160)
        % Source (33 kV)
        add_block('ee_lib/Sources/Voltage Source (Three-Phase)', [modelName, '/Source']);
        place([modelName, '/Source'], 70, 160, 60, 45, struct('showName', 'on'));

        % Source Thevenin Impedance
        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Source_Impedance']);
        place([modelName, '/Source_Impedance'], 180, 160, 60, 45, struct('showName', 'on'));

        % Remote Backup Breaker CB_33KV
        add_block('ee_lib/Switches & Breakers/Circuit Breaker (Three-Phase)', [modelName, '/CB_33KV']);
        place([modelName, '/CB_33KV'], 290, 160, 60, 45, struct('showName', 'on'));

        % Transformer T1 (33/11 kV)
        add_block('ee_lib/Passive/Transformers/Two-Winding Transformer (Three-Phase)', [modelName, '/Transformer']);
        place([modelName, '/Transformer'], 400, 150, 60, 65, struct('showName', 'on'));

        % Feeder BRA (Bus 11KV to Bus A)
        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Feeder_BRA']);
        place([modelName, '/Feeder_BRA'], 510, 160, 60, 45, struct('showName', 'on'));

        % Bus A Voltage Sensor, Fault, Shunts (Hanging below Bus A)
        add_block('ee_lib/Sensors & Transducers/Phase Voltage Sensor (Three-Phase)', [modelName, '/V_Sensor_BusA']);
        place([modelName, '/V_Sensor_BusA'], 520, 260, 50, 50, struct('showName', 'on'));

        add_block('ee_lib/Utilities/Fault (Three-Phase)', [modelName, '/Fault_BusA']);
        place([modelName, '/Fault_BusA'], 610, 260, 50, 50, struct('showName', 'on'));

        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Shunt_BusA']);
        place([modelName, '/Shunt_BusA'], 700, 260, 40, 40, struct('showName', 'off'));

        add_block('ee_lib/Connectors & References/Grounded Neutral (Three-Phase)', [modelName, '/BusA_Neutral_GND']);
        place([modelName, '/BusA_Neutral_GND'], 610, 360, 30, 30, struct('showName', 'on'));

        % Breaker CB_BUS_A and Current Sensor Bus A
        add_block('ee_lib/Switches & Breakers/Circuit Breaker (Three-Phase)', [modelName, '/CB_BUS_A']);
        place([modelName, '/CB_BUS_A'], 720, 160, 60, 45, struct('showName', 'on'));

        add_block('ee_lib/Sensors & Transducers/Current Sensor (Three-Phase)', [modelName, '/I_Sensor_BusA']);
        place([modelName, '/I_Sensor_BusA'], 820, 160, 50, 45, struct('showName', 'on'));

        % Feeder BRB (Bus A to Bus B)
        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Feeder_BRB']);
        place([modelName, '/Feeder_BRB'], 920, 160, 60, 45, struct('showName', 'on'));

        % Bus B Voltage Sensor, Fault, Shunt (Hanging below Bus B)
        add_block('ee_lib/Sensors & Transducers/Phase Voltage Sensor (Three-Phase)', [modelName, '/V_Sensor_BusB']);
        place([modelName, '/V_Sensor_BusB'], 930, 260, 50, 50, struct('showName', 'on'));

        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Shunt_BusB']);
        place([modelName, '/Shunt_BusB'], 1020, 260, 40, 40, struct('showName', 'off'));

        add_block('ee_lib/Connectors & References/Grounded Neutral (Three-Phase)', [modelName, '/BusB_Neutral_GND']);
        place([modelName, '/BusB_Neutral_GND'], 980, 360, 30, 30, struct('showName', 'on'));

        % Breaker CB_BUS_B, Current Sensor Bus B, Load & Fault at Bus B
        add_block('ee_lib/Switches & Breakers/Circuit Breaker (Three-Phase)', [modelName, '/CB_BUS_B']);
        place([modelName, '/CB_BUS_B'], 1120, 160, 60, 45, struct('showName', 'on'));

        add_block('ee_lib/Sensors & Transducers/Current Sensor (Three-Phase)', [modelName, '/I_Sensor_BusB']);
        place([modelName, '/I_Sensor_BusB'], 1220, 160, 50, 45, struct('showName', 'on'));

        add_block('ee_lib/Utilities/Fault (Three-Phase)', [modelName, '/Fault_BusB']);
        place([modelName, '/Fault_BusB'], 1220, 260, 50, 50, struct('showName', 'on'));

        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Load_BusB']);
        place([modelName, '/Load_BusB'], 1340, 160, 60, 45, struct('showName', 'on'));

        add_block('ee_lib/Connectors & References/Grounded Neutral (Three-Phase)', [modelName, '/Load_Neutral_GND']);
        place([modelName, '/Load_Neutral_GND'], 1350, 260, 30, 30, struct('showName', 'on'));

        % =============================================================
        % 3. Measurement Converters & Outports (Area 2)
        % =============================================================
        add_block('nesl_utility/PS-Simulink Converter', [modelName, '/PS_V_BusA']);
        place([modelName, '/PS_V_BusA'], 520, 490, 50, 30, struct('showName', 'off'));

        add_block('built-in/Outport', [modelName, '/V_BusA']);            % Port 1
        set_param([modelName, '/V_BusA'], 'Port', '1');
        place([modelName, '/V_BusA'], 620, 495, 35, 20, struct('showName', 'on'));

        add_block('nesl_utility/PS-Simulink Converter', [modelName, '/PS_I_BusA']);
        place([modelName, '/PS_I_BusA'], 820, 490, 50, 30, struct('showName', 'off'));

        add_block('built-in/Outport', [modelName, '/I_BusA']);            % Port 2
        set_param([modelName, '/I_BusA'], 'Port', '2');
        place([modelName, '/I_BusA'], 920, 495, 35, 20, struct('showName', 'on'));

        add_block('nesl_utility/PS-Simulink Converter', [modelName, '/PS_V_BusB']);
        place([modelName, '/PS_V_BusB'], 930, 540, 50, 30, struct('showName', 'off'));

        add_block('built-in/Outport', [modelName, '/V_BusB']);            % Port 3
        set_param([modelName, '/V_BusB'], 'Port', '3');
        place([modelName, '/V_BusB'], 1030, 545, 35, 20, struct('showName', 'on'));

        add_block('nesl_utility/PS-Simulink Converter', [modelName, '/PS_I_BusB']);
        place([modelName, '/PS_I_BusB'], 1220, 490, 50, 30, struct('showName', 'off'));

        add_block('built-in/Outport', [modelName, '/I_BusB']);            % Port 4
        set_param([modelName, '/I_BusB'], 'Port', '4');
        place([modelName, '/I_BusB'], 1320, 495, 35, 20, struct('showName', 'on'));

        % =============================================================
        % 4. Breakers & Switching Interface (Area 4)
        % =============================================================
        % Master Clock & Startup Gate (25 ms initial settling filter)
        add_block('simulink/Sources/Clock', [modelName, '/Master_Clock']);
        place([modelName, '/Master_Clock'], 60, 890, 30, 20, struct('showName', 'off'));

        add_block('simulink/Logic and Bit Operations/Compare To Constant', [modelName, '/Check_Startup_Gate']);
        set_param([modelName, '/Check_Startup_Gate'], 'const', '0.025', 'relop', '>=');
        place([modelName, '/Check_Startup_Gate'], 130, 885, 60, 30, struct('showName', 'off'));

        % Configuration Constants
        add_block('simulink/Sources/Constant', [modelName, '/Config_Breaker_Clearing']);
        set_param([modelName, '/Config_Breaker_Clearing'], 'Value', '0');
        place([modelName, '/Config_Breaker_Clearing'], 60, 940, 110, 25, struct('showName', 'on'));

        add_block('simulink/Sources/Constant', [modelName, '/Config_Fail_CB_A']);
        set_param([modelName, '/Config_Fail_CB_A'], 'Value', '0');
        place([modelName, '/Config_Fail_CB_A'], 60, 990, 110, 25, struct('showName', 'on'));

        add_block('simulink/Sources/Constant', [modelName, '/Config_Fail_CB_B']);
        set_param([modelName, '/Config_Fail_CB_B'], 'Value', '0');
        place([modelName, '/Config_Fail_CB_B'], 60, 1040, 110, 25, struct('showName', 'on'));

        % Breaker 33KV Control Converter
        add_block('nesl_utility/Simulink-PS Converter', [modelName, '/PS_Trip_CB_33KV']);
        place([modelName, '/PS_Trip_CB_33KV'], 290, 935, 45, 30, struct('showName', 'off'));

        % Breaker B Mechanism Delays, Failure Logic, and Outports (Ports 5, 6, 9)
        bkrB = cfg.breakers(strcmp({cfg.breakers.id}, 'CB_BUS_B'));
        add_block('simulink/Continuous/Transport Delay', [modelName, '/Breaker_Delay_B']);
        set_param([modelName, '/Breaker_Delay_B'], ...
            'DelayTime', num2str(bkrB.openingDelay_s.value), ...
            'InitialOutput', '0', ...
            'BufferSize', '8192');
        place([modelName, '/Breaker_Delay_B'], 1100, 930, 50, 30, struct('showName', 'on'));

        add_block('simulink/Math Operations/Gain', [modelName, '/Neg_Fail_B']);
        set_param([modelName, '/Neg_Fail_B'], 'Gain', '-1');
        place([modelName, '/Neg_Fail_B'], 1020, 1040, 35, 25, struct('showName', 'off'));

        add_block('simulink/Math Operations/Bias', [modelName, '/Inv_Fail_B']);
        set_param([modelName, '/Inv_Fail_B'], 'Bias', '1');
        place([modelName, '/Inv_Fail_B'], 1080, 1040, 35, 25, struct('showName', 'off'));

        add_block('simulink/Math Operations/Product', [modelName, '/Gate_CB_B']);
        set_param([modelName, '/Gate_CB_B'], 'Inputs', '3');
        place([modelName, '/Gate_CB_B'], 1180, 940, 40, 40, struct('showName', 'off'));

        add_block('nesl_utility/Simulink-PS Converter', [modelName, '/PS_Trip_CB_B']);
        place([modelName, '/PS_Trip_CB_B'], 1250, 945, 45, 30, struct('showName', 'off'));

        add_block('built-in/Outport', [modelName, '/Trip_Cmd_B']);        % Port 5
        set_param([modelName, '/Trip_Cmd_B'], 'Port', '5');
        place([modelName, '/Trip_Cmd_B'], 1330, 905, 35, 20, struct('showName', 'on'));

        add_block('built-in/Outport', [modelName, '/Breaker_State_B']);    % Port 6
        set_param([modelName, '/Breaker_State_B'], 'Port', '6');
        place([modelName, '/Breaker_State_B'], 1330, 945, 35, 20, struct('showName', 'on'));

        % Breaker A Mechanism Delays, Failure Logic, and Outports (Ports 7, 8, 10)
        bkrA = cfg.breakers(strcmp({cfg.breakers.id}, 'CB_BUS_A'));
        add_block('simulink/Continuous/Transport Delay', [modelName, '/Breaker_Delay_A']);
        set_param([modelName, '/Breaker_Delay_A'], ...
            'DelayTime', num2str(bkrA.openingDelay_s.value), ...
            'InitialOutput', '0', ...
            'BufferSize', '8192');
        place([modelName, '/Breaker_Delay_A'], 700, 930, 50, 30, struct('showName', 'on'));

        add_block('simulink/Math Operations/Gain', [modelName, '/Neg_Fail_A']);
        set_param([modelName, '/Neg_Fail_A'], 'Gain', '-1');
        place([modelName, '/Neg_Fail_A'], 620, 990, 35, 25, struct('showName', 'off'));

        add_block('simulink/Math Operations/Bias', [modelName, '/Inv_Fail_A']);
        set_param([modelName, '/Inv_Fail_A'], 'Bias', '1');
        place([modelName, '/Inv_Fail_A'], 680, 990, 35, 25, struct('showName', 'off'));

        add_block('simulink/Math Operations/Product', [modelName, '/Gate_CB_A']);
        set_param([modelName, '/Gate_CB_A'], 'Inputs', '3');
        place([modelName, '/Gate_CB_A'], 780, 940, 40, 40, struct('showName', 'off'));

        add_block('nesl_utility/Simulink-PS Converter', [modelName, '/PS_Trip_CB_A']);
        place([modelName, '/PS_Trip_CB_A'], 850, 945, 45, 30, struct('showName', 'off'));

        add_block('built-in/Outport', [modelName, '/Trip_Cmd_A']);        % Port 7
        set_param([modelName, '/Trip_Cmd_A'], 'Port', '7');
        place([modelName, '/Trip_Cmd_A'], 930, 905, 35, 20, struct('showName', 'on'));

        add_block('built-in/Outport', [modelName, '/Breaker_State_A']);    % Port 8
        set_param([modelName, '/Breaker_State_A'], 'Port', '8');
        place([modelName, '/Breaker_State_A'], 930, 945, 35, 20, struct('showName', 'on'));

        % Integrator Accumulation Outports (Ports 9 and 10)
        add_block('built-in/Outport', [modelName, '/Integrator_Sigma_B']);% Port 9
        set_param([modelName, '/Integrator_Sigma_B'], 'Port', '9');
        place([modelName, '/Integrator_Sigma_B'], 1330, 750, 35, 20, struct('showName', 'on'));

        add_block('built-in/Outport', [modelName, '/Integrator_Sigma_A']);% Port 10
        set_param([modelName, '/Integrator_Sigma_A'], 'Port', '10');
        place([modelName, '/Integrator_Sigma_A'], 930, 750, 35, 20, struct('showName', 'on'));

        % =============================================================
        % 5. Build Subsystems in Area 3: Protection Relays
        % =============================================================
        % 5A. RELAY_33KV Subsystem (Remote Backup)
        relay33Path = [modelName, '/RELAY_33KV'];
        add_block('built-in/Subsystem', relay33Path);
        place(relay33Path, 250, 680, 120, 80, struct('showName', 'on'));
        p_buildRelay33Subsystem(relay33Path);

        % 5B. RELAY_BUS_A Subsystem (Feeder Backup Relay)
        relayAPath = [modelName, '/RELAY_BUS_A'];
        add_block('built-in/Subsystem', relayAPath);
        place(relayAPath, 720, 670, 130, 90, struct('showName', 'on'));
        relayA = cfg.relays(strcmp({cfg.relays.id}, 'RELAY_BUS_A'));
        p_buildRelayFeederSubsystem(relayAPath, relayA, 'A');

        % 5C. RELAY_BUS_B Subsystem (Primary Feeder Relay)
        relayBPath = [modelName, '/RELAY_BUS_B'];
        add_block('built-in/Subsystem', relayBPath);
        place(relayBPath, 1120, 670, 130, 90, struct('showName', 'on'));
        relayB = cfg.relays(strcmp({cfg.relays.id}, 'RELAY_BUS_B'));
        p_buildRelayFeederSubsystem(relayBPath, relayB, 'B');

        % =============================================================
        % 6. Connect Physical Conserving Lines
        % =============================================================
        % Ground references
        add_line(modelName, 'Solver/RConn1', 'GND/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Source/LConn1', 'GND/LConn1', 'autorouting', 'on');

        % Source -> Source Impedance -> CB_33KV -> Transformer Primary
        add_line(modelName, 'Source/RConn1', 'Source_Impedance/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Source_Impedance/RConn1', 'CB_33KV/LConn2', 'autorouting', 'on');
        add_line(modelName, 'CB_33KV/RConn1', 'Transformer/LConn1', 'autorouting', 'on');

        % Transformer Secondary -> Feeder BR_A
        add_line(modelName, 'Transformer/RConn1', 'Feeder_BRA/LConn1', 'autorouting', 'on');

        % Bus A node connections
        add_line(modelName, 'Feeder_BRA/RConn1', 'V_Sensor_BusA/LConn1', 'autorouting', 'on');
        add_line(modelName, 'V_Sensor_BusA/RConn2', 'BusA_Neutral_GND/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Feeder_BRA/RConn1', 'Shunt_BusA/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Shunt_BusA/RConn1', 'BusA_Neutral_GND/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Feeder_BRA/RConn1', 'Fault_BusA/LConn1', 'autorouting', 'on');

        % Bus A -> CB_BUS_A -> I_Sensor_BusA -> Feeder BR_B
        add_line(modelName, 'Feeder_BRA/RConn1', 'CB_BUS_A/LConn2', 'autorouting', 'on');
        add_line(modelName, 'CB_BUS_A/RConn1', 'I_Sensor_BusA/LConn1', 'autorouting', 'on');
        add_line(modelName, 'I_Sensor_BusA/RConn2', 'Feeder_BRB/LConn1', 'autorouting', 'on');

        % Bus B node connections
        add_line(modelName, 'Feeder_BRB/RConn1', 'V_Sensor_BusB/LConn1', 'autorouting', 'on');
        add_line(modelName, 'V_Sensor_BusB/RConn2', 'BusB_Neutral_GND/LConn1', 'autorouting', 'on');
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

        % =============================================================
        % 7. Connect Simulink Signal Flow (Relays & Breakers)
        % =============================================================
        % Clock to Startup Gate
        add_line(modelName, 'Master_Clock/1', 'Check_Startup_Gate/1', 'autorouting', 'on');

        % RELAY_33KV: Trip output directly drives CB_33KV via PS converter
        add_line(modelName, 'RELAY_33KV/1', 'PS_Trip_CB_33KV/1', 'autorouting', 'on');
        add_line(modelName, 'PS_Trip_CB_33KV/RConn1', 'CB_33KV/LConn1', 'autorouting', 'on');

        % RELAY_BUS_A: receives I_BusA and Gate, outputs Trip and Sigma
        add_line(modelName, 'PS_I_BusA/1', 'RELAY_BUS_A/1', 'autorouting', 'on');
        add_line(modelName, 'Check_Startup_Gate/1', 'RELAY_BUS_A/2', 'autorouting', 'on');
        add_line(modelName, 'RELAY_BUS_A/2', 'Integrator_Sigma_A/1', 'autorouting', 'on'); % Sigma

        % CB_BUS_A tripping and breaker failure logic
        add_line(modelName, 'RELAY_BUS_A/1', 'Trip_Cmd_A/1', 'autorouting', 'on');
        add_line(modelName, 'RELAY_BUS_A/1', 'Breaker_Delay_A/1', 'autorouting', 'on');
        add_line(modelName, 'Breaker_Delay_A/1', 'Gate_CB_A/1', 'autorouting', 'on');
        add_line(modelName, 'Config_Breaker_Clearing/1', 'Gate_CB_A/2', 'autorouting', 'on');
        add_line(modelName, 'Config_Fail_CB_A/1', 'Neg_Fail_A/1', 'autorouting', 'on');
        add_line(modelName, 'Neg_Fail_A/1', 'Inv_Fail_A/1', 'autorouting', 'on');
        add_line(modelName, 'Inv_Fail_A/1', 'Gate_CB_A/3', 'autorouting', 'on');
        add_line(modelName, 'Gate_CB_A/1', 'Breaker_State_A/1', 'autorouting', 'on');
        add_line(modelName, 'Gate_CB_A/1', 'PS_Trip_CB_A/1', 'autorouting', 'on');
        add_line(modelName, 'PS_Trip_CB_A/RConn1', 'CB_BUS_A/LConn1', 'autorouting', 'on');

        % RELAY_BUS_B: receives I_BusB and Gate, outputs Trip and Sigma
        add_line(modelName, 'PS_I_BusB/1', 'RELAY_BUS_B/1', 'autorouting', 'on');
        add_line(modelName, 'Check_Startup_Gate/1', 'RELAY_BUS_B/2', 'autorouting', 'on');
        add_line(modelName, 'RELAY_BUS_B/2', 'Integrator_Sigma_B/1', 'autorouting', 'on'); % Sigma

        % CB_BUS_B tripping and breaker failure logic
        add_line(modelName, 'RELAY_BUS_B/1', 'Trip_Cmd_B/1', 'autorouting', 'on');
        add_line(modelName, 'RELAY_BUS_B/1', 'Breaker_Delay_B/1', 'autorouting', 'on');
        add_line(modelName, 'Breaker_Delay_B/1', 'Gate_CB_B/1', 'autorouting', 'on');
        add_line(modelName, 'Config_Breaker_Clearing/1', 'Gate_CB_B/2', 'autorouting', 'on');
        add_line(modelName, 'Config_Fail_CB_B/1', 'Neg_Fail_B/1', 'autorouting', 'on');
        add_line(modelName, 'Neg_Fail_B/1', 'Inv_Fail_B/1', 'autorouting', 'on');
        add_line(modelName, 'Inv_Fail_B/1', 'Gate_CB_B/3', 'autorouting', 'on');
        add_line(modelName, 'Gate_CB_B/1', 'Breaker_State_B/1', 'autorouting', 'on');
        add_line(modelName, 'Gate_CB_B/1', 'PS_Trip_CB_B/1', 'autorouting', 'on');
        add_line(modelName, 'PS_Trip_CB_B/RConn1', 'CB_BUS_B/LConn1', 'autorouting', 'on');

        % =============================================================
        % 8. Configure Physical & Engineering Parameters
        % =============================================================
        % 33 kV Source
        set_param([modelName, '/Source'], ...
            'vline_rms', num2str(cfg.source.voltage_V.value), ...
            'vline_rms_unit', 'V', ...
            'freq', num2str(cfg.systemBase.frequency_Hz.value), ...
            'freq_unit', 'Hz', ...
            'impedance_option', '0');

        % Source Thevenin Impedance
        set_param([modelName, '/Source_Impedance'], ...
            'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
            'R', num2str(cfg.source.physical.R_Ohm.value), ...
            'R_unit', 'Ohm', ...
            'L', num2str(cfg.source.physical.L_H.value), ...
            'L_unit', 'H', ...
            'G_parasitic', num2str(cfg.source.physical.G_parasitic_S.value));

        % 33/11 kV Transformer T1
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

        % Feeder Sections BRA and BRB
        set_param([modelName, '/Feeder_BRA'], ...
            'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
            'R', num2str(cfg.feeders.BRA.physical.R_Ohm.value), ...
            'R_unit', 'Ohm', ...
            'L', num2str(cfg.feeders.BRA.physical.L_H.value), ...
            'L_unit', 'H', ...
            'G_parasitic', num2str(cfg.feeders.BRA.physical.G_parasitic_S.value));

        set_param([modelName, '/Feeder_BRB'], ...
            'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
            'R', num2str(cfg.feeders.BRB.physical.R_Ohm.value), ...
            'R_unit', 'Ohm', ...
            'L', num2str(cfg.feeders.BRB.physical.L_H.value), ...
            'L_unit', 'H', ...
            'G_parasitic', num2str(cfg.feeders.BRB.physical.G_parasitic_S.value));

        % Prefault Load at Bus B
        set_param([modelName, '/Load_BusB'], ...
            'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
            'R', num2str(cfg.load.R_Ohm.value), ...
            'R_unit', 'Ohm', ...
            'L', '0.001', ...
            'L_unit', 'H');

        % Fault Blocks (Bus B active temporal, Bus A disabled by default)
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

        set_param([modelName, '/Fault_BusA'], ...
            'fault_type_option', 'ee.enum.fault_type_option.abc', ...
            'enable_temporal_fault', 'ee.enum.enable.no', ...
            'fault_start_time', '999.0', ...
            'fault_start_time_unit', 's', ...
            'fault_duration', '0.20', ...
            'fault_duration_unit', 's', ...
            'R_pn_fault', '0.001', ...
            'R_pn_fault_unit', 'Ohm', ...
            'R_ng_fault', '0.001', ...
            'R_ng_fault_unit', 'Ohm');

        % Circuit Breakers
        cbList = {'CB_33KV', 'CB_BUS_A', 'CB_BUS_B'};
        for cIdx = 1:numel(cbList)
            set_param([modelName, '/', cbList{cIdx}], ...
                'R_closed', '0.001', ...
                'G_open', '1e-6', ...
                'threshold', '0.5');
        end

        % Bus Stabilization Shunts (100 kOhm to ground)
        set_param([modelName, '/Shunt_BusA'], 'component_structure', 'ee.enum.rlc.structure.R', 'R', '100000');
        set_param([modelName, '/Shunt_BusB'], 'component_structure', 'ee.enum.rlc.structure.R', 'R', '100000');

        % =============================================================
        % 9. Solver and Data Logging Configuration
        % =============================================================
        set_param(modelName, ...
            'StopTime', '0.15', ...
            'Solver', 'ode23t', ...
            'MaxStep', '5e-5', ...
            'ConsistencyChecking', 'off', ...
            'SaveOutput', 'on', ...
            'OutputSaveName', 'yout', ...
            'SaveTime', 'on', ...
            'TimeSaveName', 'tout');

        % =============================================================
        % 10. Save Model and Export High-Resolution PNG Documentation
        % =============================================================
        save_system(modelName, modelPath);

        imgDir = fullfile(projectRoot, 'docs', 'images');
        if ~exist(imgDir, 'dir'), mkdir(imgDir); end

        try
            % Top-level model diagram
            print(['-s', modelName], '-dpng', '-r200', fullfile(imgDir, 'radial_fault_model.png'));

            % Relay subsystems
            open_system(relayBPath);
            print(['-s', relayBPath], '-dpng', '-r200', fullfile(imgDir, 'relay_bus_b_subsystem.png'));
            close_system(relayBPath);

            open_system(relayAPath);
            print(['-s', relayAPath], '-dpng', '-r200', fullfile(imgDir, 'relay_bus_a_subsystem.png'));
            close_system(relayAPath);

            open_system(relay33Path);
            print(['-s', relay33Path], '-dpng', '-r200', fullfile(imgDir, 'relay_33kv_subsystem.png'));
            close_system(relay33Path);
        catch
            % Best-effort print in headless environments
        end

        close_system(modelName);

    catch ME
        if bdIsLoaded(modelName)
            close_system(modelName, 0);
        end
        rethrow(ME);
    end
end

%% =====================================================================
% Helper: Build Standard Inverse Relay Subsystem (Bus A or Bus B)
% =====================================================================
function p_buildRelayFeederSubsystem(subPath, relayCfg, suffix)
    % Clear default In1/Out1 from newly created subsystem
    p_clearSubsystem(subPath);

    % Call arrangeSystem as an initial baseline per procedure
    try
        Simulink.BlockDiagram.arrangeSystem(subPath);
    catch
    end

    % Subsystem Title Annotation
    addTitle(subPath, ...
        sprintf('Relay %s: %s', suffix, relayCfg.name), ...
        sprintf('CT: %d/%d A, Pickup: %.2f A sec, TMS: %.2f, Curve: %s', ...
            relayCfg.CTprimary_A.value, relayCfg.CTsecondary_A.value, ...
            relayCfg.pickupCurrent_A.value, relayCfg.TMS.value, relayCfg.curveType), ...
        [30, 15, 1200, 65]);

    % Inports
    add_block('built-in/Inport', [subPath, '/I_abc']);
    set_param([subPath, '/I_abc'], 'Port', '1');
    place([subPath, '/I_abc'], 40, 100, 30, 20, struct('showName', 'on'));

    add_block('built-in/Inport', [subPath, '/Gate']);
    set_param([subPath, '/Gate'], 'Port', '2');
    place([subPath, '/Gate'], 40, 230, 30, 20, struct('showName', 'on'));

    % Outports
    add_block('built-in/Outport', [subPath, '/Trip']);
    set_param([subPath, '/Trip'], 'Port', '1');
    place([subPath, '/Trip'], 1380, 195, 30, 20, struct('showName', 'on'));

    add_block('built-in/Outport', [subPath, '/Sigma']);
    set_param([subPath, '/Sigma'], 'Port', '2');
    place([subPath, '/Sigma'], 1050, 120, 30, 20, struct('showName', 'on'));

    % Calculations for lookup table
    bp = [1.0, 1.005, 1.01, 1.02, 1.05, 1.1, 1.2, 1.5, 2, 3, 5, 10, 20, 30, 50, 100];
    bp_str = mat2str(bp);
    rate = (bp.^0.02 - 1) ./ (0.14 * relayCfg.TMS.value);
    rate(1) = 0.0;
    tbl_str = mat2str(round(rate, 5));
    gainVal = num2str(relayCfg.CTsecondary_A.value / relayCfg.CTprimary_A.value);

    % Column 1: Math Square (Three-phase current squared)
    sqName = ['Square_I_', suffix];
    add_block('simulink/Math Operations/Math Function', [subPath, '/', sqName]);
    set_param([subPath, '/', sqName], 'Operator', 'square');
    place([subPath, '/', sqName], 100, 90, 45, 35, struct('showName', 'on'));

    % Column 2: Integrator & Transport Delay (1 cycle T = 20 ms at 50 Hz)
    intName = ['Int_I2_', suffix];
    add_block('simulink/Continuous/Integrator', [subPath, '/', intName]);
    place([subPath, '/', intName], 180, 85, 40, 35, struct('showName', 'on'));

    delName = ['Delay_I2_', suffix];
    add_block('simulink/Continuous/Transport Delay', [subPath, '/', delName]);
    set_param([subPath, '/', delName], ...
        'DelayTime', '0.020', ...
        'BufferSize', '8192', ...
        'InitialOutput', '0');
    place([subPath, '/', delName], 180, 140, 40, 35, struct('showName', 'on'));

    % Column 3: Subtract sliding window start
    subName = ['Sub_I2_', suffix];
    add_block('simulink/Math Operations/Subtract', [subPath, '/', subName]);
    place([subPath, '/', subName], 255, 95, 30, 35, struct('showName', 'off'));

    % Column 4: Gain (1/T = 50)
    gName = ['Gain_I2_', suffix];
    add_block('simulink/Math Operations/Gain', [subPath, '/', gName]);
    set_param([subPath, '/', gName], 'Gain', '50');
    place([subPath, '/', gName], 320, 95, 40, 35, struct('showName', 'off'));

    % Column 5: Lower saturation at 0 (prevents negative numerical artifact)
    satName = ['Sat_I2_', suffix];
    add_block('simulink/Discontinuities/Saturation', [subPath, '/', satName]);
    set_param([subPath, '/', satName], 'LowerLimit', '0', 'UpperLimit', 'inf');
    place([subPath, '/', satName], 395, 95, 35, 35, struct('showName', 'off'));

    % Column 6: Sqrt -> RMS Phase Currents
    sqrtName = ['Sqrt_I_', suffix];
    add_block('simulink/Math Operations/Sqrt', [subPath, '/', sqrtName]);
    place([subPath, '/', sqrtName], 465, 95, 40, 35, struct('showName', 'on'));

    % Column 7: Maximum Phase Current Selector
    maxName = ['Max_Phase_', suffix];
    add_block('simulink/Math Operations/MinMax', [subPath, '/', maxName]);
    set_param([subPath, '/', maxName], 'Function', 'max', 'Inputs', '1');
    place([subPath, '/', maxName], 540, 95, 45, 35, struct('showName', 'on'));

    % Column 8: CT Ratio (Primary to Secondary Current)
    ctName = ['Gain_M_', suffix];
    add_block('simulink/Math Operations/Gain', [subPath, '/', ctName]);
    set_param([subPath, '/', ctName], 'Gain', gainVal);
    place([subPath, '/', ctName], 620, 95, 45, 35, struct('showName', 'on'));

    % Column 9: Pickup Comparator and Startup Gate AND
    chkName = ['Check_Pickup_', suffix];
    add_block('simulink/Logic and Bit Operations/Compare To Constant', [subPath, '/', chkName]);
    set_param([subPath, '/', chkName], 'const', num2str(relayCfg.pickupCurrent_A.value), 'relop', '>=');
    place([subPath, '/', chkName], 700, 90, 55, 35, struct('showName', 'on'));

    andName = ['And_Pickup_', suffix];
    add_block('simulink/Logic and Bit Operations/Logical Operator', [subPath, '/', andName]);
    set_param([subPath, '/', andName], 'Operator', 'AND', 'Inputs', '2');
    place([subPath, '/', andName], 785, 95, 35, 40, struct('showName', 'off'));

    % Column 10: IEC Inverse Operating Rate & Reset Rate Switch
    tblName = ['IEC_Rate_Table_', suffix];
    add_block('simulink/Lookup Tables/1-D Lookup Table', [subPath, '/', tblName]);
    set_param([subPath, '/', tblName], 'BreakpointsForDimension1', bp_str, 'Table', tbl_str);
    place([subPath, '/', tblName], 700, 175, 55, 35, struct('showName', 'on'));

    rstRateName = ['Reset_Rate_', suffix];
    add_block('simulink/Sources/Constant', [subPath, '/', rstRateName]);
    set_param([subPath, '/', rstRateName], 'Value', '-2.0');
    place([subPath, '/', rstRateName], 700, 240, 45, 25, struct('showName', 'off'));

    swName = ['Rate_Switch_', suffix];
    add_block('simulink/Signal Routing/Switch', [subPath, '/', swName]);
    set_param([subPath, '/', swName], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    place([subPath, '/', swName], 860, 180, 40, 35, struct('showName', 'off'));

    % Column 11: Accumulating Integrator (Sigma 0 to 1)
    intRelayName = ['Integrator_', suffix];
    add_block('simulink/Continuous/Integrator', [subPath, '/', intRelayName]);
    set_param([subPath, '/', intRelayName], ...
        'LimitOutput', 'on', ...
        'UpperSaturationLimit', '1.0', ...
        'LowerSaturationLimit', '0.0');
    place([subPath, '/', intRelayName], 940, 180, 40, 35, struct('showName', 'on'));

    % Column 12: Trip Threshold Comparator (>= 0.999)
    trigName = ['Check_Trip_', suffix];
    add_block('simulink/Logic and Bit Operations/Compare To Constant', [subPath, '/', trigName]);
    set_param([subPath, '/', trigName], 'const', '0.999', 'relop', '>=');
    place([subPath, '/', trigName], 1020, 180, 55, 35, struct('showName', 'on'));

    % Column 13: SR Flip-Flop Trip Latch
    boolName = ['Conv_Bool_', suffix];
    add_block('simulink/Signal Attributes/Data Type Conversion', [subPath, '/', boolName]);
    set_param([subPath, '/', boolName], 'OutDataTypeStr', 'boolean');
    place([subPath, '/', boolName], 1105, 185, 35, 25, struct('showName', 'off'));

    zeroName = ['Reset_Zero_', suffix];
    add_block('simulink/Sources/Constant', [subPath, '/', zeroName]);
    set_param([subPath, '/', zeroName], 'Value', '0', 'OutDataTypeStr', 'boolean');
    place([subPath, '/', zeroName], 1105, 235, 35, 25, struct('showName', 'off'));

    latchName = ['Trip_Latch_', suffix];
    add_block('simulink_extras/Flip Flops/S-R Flip-Flop', [subPath, '/', latchName]);
    place([subPath, '/', latchName], 1175, 180, 45, 50, struct('showName', 'on'));

    % Column 14: Data Type Conversion to Double
    dblName = ['Conv_Double_', suffix];
    add_block('simulink/Signal Attributes/Data Type Conversion', [subPath, '/', dblName]);
    set_param([subPath, '/', dblName], 'OutDataTypeStr', 'double');
    place([subPath, '/', dblName], 1260, 190, 40, 30, struct('showName', 'off'));

    % Internal Signal Connections
    add_line(subPath, 'I_abc/1', [sqName, '/1'], 'autorouting', 'on');
    add_line(subPath, [sqName, '/1'], [intName, '/1'], 'autorouting', 'on');
    add_line(subPath, [intName, '/1'], [delName, '/1'], 'autorouting', 'on');
    add_line(subPath, [intName, '/1'], [subName, '/1'], 'autorouting', 'on');
    add_line(subPath, [delName, '/1'], [subName, '/2'], 'autorouting', 'on');
    add_line(subPath, [subName, '/1'], [gName, '/1'], 'autorouting', 'on');
    add_line(subPath, [gName, '/1'], [satName, '/1'], 'autorouting', 'on');
    add_line(subPath, [satName, '/1'], [sqrtName, '/1'], 'autorouting', 'on');
    add_line(subPath, [sqrtName, '/1'], [maxName, '/1'], 'autorouting', 'on');
    add_line(subPath, [maxName, '/1'], [ctName, '/1'], 'autorouting', 'on');

    add_line(subPath, [ctName, '/1'], [chkName, '/1'], 'autorouting', 'on');
    add_line(subPath, [chkName, '/1'], [andName, '/1'], 'autorouting', 'on');
    add_line(subPath, 'Gate/1', [andName, '/2'], 'autorouting', 'on');

    add_line(subPath, [ctName, '/1'], [tblName, '/1'], 'autorouting', 'on');
    add_line(subPath, [tblName, '/1'], [swName, '/1'], 'autorouting', 'on');
    add_line(subPath, [andName, '/1'], [swName, '/2'], 'autorouting', 'on');
    add_line(subPath, [rstRateName, '/1'], [swName, '/3'], 'autorouting', 'on');

    add_line(subPath, [swName, '/1'], [intRelayName, '/1'], 'autorouting', 'on');
    add_line(subPath, [intRelayName, '/1'], 'Sigma/1', 'autorouting', 'on');
    add_line(subPath, [intRelayName, '/1'], [trigName, '/1'], 'autorouting', 'on');

    add_line(subPath, [trigName, '/1'], [boolName, '/1'], 'autorouting', 'on');
    add_line(subPath, [boolName, '/1'], [latchName, '/1'], 'autorouting', 'on');
    add_line(subPath, [zeroName, '/1'], [latchName, '/2'], 'autorouting', 'on');
    add_line(subPath, [latchName, '/1'], [dblName, '/1'], 'autorouting', 'on');

    add_line(subPath, [dblName, '/1'], 'Trip/1', 'autorouting', 'on');
end

%% =====================================================================
% Helper: Build Remote Backup 33 kV Relay Subsystem
% =====================================================================
function p_buildRelay33Subsystem(subPath)
    p_clearSubsystem(subPath);

    try
        Simulink.BlockDiagram.arrangeSystem(subPath);
    catch
    end

    addTitle(subPath, ...
        'Relay 33KV: 33 kV Incomer Overcurrent Relay (Remote Backup)', ...
        'CT: 200/5 A, Pickup: 1.50 A sec, TMS: 0.40 (Remote backup held closed during standard feeder faults)', ...
        [30, 15, 650, 65]);

    add_block('built-in/Inport', [subPath, '/I_abc']);
    set_param([subPath, '/I_abc'], 'Port', '1');
    place([subPath, '/I_abc'], 50, 95, 30, 20, struct('showName', 'on'));

    add_block('simulink/Sinks/Terminator', [subPath, '/Terminator_33KV']);
    place([subPath, '/Terminator_33KV'], 130, 95, 30, 20, struct('showName', 'off'));

    add_block('simulink/Sources/Constant', [subPath, '/Const_Zero_33KV']);
    set_param([subPath, '/Const_Zero_33KV'], 'Value', '0');
    place([subPath, '/Const_Zero_33KV'], 130, 150, 45, 30, struct('showName', 'on'));

    add_block('built-in/Outport', [subPath, '/Trip']);
    set_param([subPath, '/Trip'], 'Port', '1');
    place([subPath, '/Trip'], 240, 155, 30, 20, struct('showName', 'on'));

    add_line(subPath, 'I_abc/1', 'Terminator_33KV/1', 'autorouting', 'on');
    add_line(subPath, 'Const_Zero_33KV/1', 'Trip/1', 'autorouting', 'on');
end

%% =====================================================================
% Helper: Clear default In1 / Out1 ports from new subsystem
% =====================================================================
function p_clearSubsystem(subPath)
    lines = find_system(subPath, 'FindAll', 'on', 'Type', 'line');
    if ~isempty(lines), delete_line(lines); end

    blocks = find_system(subPath, 'SearchDepth', 1, 'Type', 'block');
    for k = 1:numel(blocks)
        if ~strcmp(blocks{k}, subPath)
            delete_block(blocks{k});
        end
    end
end
