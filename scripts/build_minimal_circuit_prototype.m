function modelPath = build_minimal_circuit_prototype(targetDir)
% build_minimal_circuit_prototype Construct and save the minimal Simscape Electrical prototype.
%
% Syntax:
%   modelPath = build_minimal_circuit_prototype()
%   modelPath = build_minimal_circuit_prototype(targetDir)
%
% This function creates a physically meaningful minimal three-phase circuit:
%   - Source: 11 kV line-to-line RMS, 50 Hz Three-Phase Voltage Source
%   - Sensors: Three-phase Current & Voltage Sensor
%   - Load: Three-phase series R-L branch (R = 10 Ohm, L = 0.01 H)
%   - Neutral: Grounded Neutral (Three-Phase)
%   - References & Utilities: Electrical Reference, Solver Configuration
%   - Converters & Sinks: PS-Simulink Converters, Outports for V_abc and I_abc
%
% Returns the full file path to the saved .slx model.

    if nargin < 1 || isempty(targetDir)
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
        targetDir = fullfile(projectRoot, 'simulink', 'models');
    end

    if ~exist(targetDir, 'dir')
        mkdir(targetDir);
    end

    modelName = 'minimal_circuit_prototype';
    modelPath = fullfile(targetDir, [modelName, '.slx']);

    % Close model if already loaded in memory
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end

    % Create new Simulink model
    new_system(modelName);

    try
        % 1. Add blocks from verified library paths
        add_block('nesl_utility/Solver Configuration', [modelName, '/Solver']);
        add_block('ee_lib/Connectors & References/Electrical Reference', [modelName, '/GND']);
        add_block('ee_lib/Sources/Voltage Source (Three-Phase)', [modelName, '/Source']);
        add_block('ee_lib/Sensors & Transducers/Current and Voltage Sensor (Three-Phase)', [modelName, '/Sensor']);
        add_block('ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', [modelName, '/Load']);
        add_block('ee_lib/Connectors & References/Grounded Neutral (Three-Phase)', [modelName, '/Neutral_GND']);
        add_block('nesl_utility/PS-Simulink Converter', [modelName, '/PS_V']);
        add_block('nesl_utility/PS-Simulink Converter', [modelName, '/PS_I']);
        add_block('built-in/Outport', [modelName, '/V_abc']);
        add_block('built-in/Outport', [modelName, '/I_abc']);

        % 2. Configure parameters
        % Source: 11 kV line-to-line RMS, 50 Hz, ideal (zero internal impedance: impedance_option = '0')
        set_param([modelName, '/Source'], ...
            'vline_rms', '11000', ...
            'vline_rms_unit', 'V', ...
            'freq', '50', ...
            'freq_unit', 'Hz', ...
            'impedance_option', '0');

        % Sensor: Line-to-ground / Phase-to-neutral measurement
        set_param([modelName, '/Sensor'], ...
            'vMeasurementType', 'ee.enum.vmeasurement.lg');

        % Load: Series R-L (R = 10 Ohm, L = 0.01 H)
        set_param([modelName, '/Load'], ...
            'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
            'R', '10', ...
            'R_unit', 'Ohm', ...
            'L', '0.01', ...
            'L_unit', 'H');

        % 3. Connect physical lines
        % Solver config to Electrical Reference
        add_line(modelName, 'Solver/RConn1', 'GND/LConn1', 'autorouting', 'on');
        % Source neutral to Electrical Reference
        add_line(modelName, 'Source/LConn1', 'GND/LConn1', 'autorouting', 'on');
        % Source three-phase output to Sensor input
        add_line(modelName, 'Source/RConn1', 'Sensor/LConn1', 'autorouting', 'on');
        % Sensor three-phase output to Load input
        add_line(modelName, 'Sensor/RConn3', 'Load/LConn1', 'autorouting', 'on');
        % Load neutral to Grounded Neutral
        add_line(modelName, 'Load/RConn1', 'Neutral_GND/LConn1', 'autorouting', 'on');

        % Measurement outputs to PS-Simulink converters
        add_line(modelName, 'Sensor/RConn1', 'PS_V/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Sensor/RConn2', 'PS_I/LConn1', 'autorouting', 'on');

        % Converters to Simulink outports
        add_line(modelName, 'PS_V/1', 'V_abc/1', 'autorouting', 'on');
        add_line(modelName, 'PS_I/1', 'I_abc/1', 'autorouting', 'on');

        % 4. Configure solver and logging
        set_param(modelName, ...
            'StopTime', '0.04', ...
            'Solver', 'ode23t', ...
            'MaxStep', '5e-5', ...
            'SaveOutput', 'on', ...
            'OutputSaveName', 'yout', ...
            'SaveTime', 'on', ...
            'TimeSaveName', 'tout');

        % 5. Save model
        save_system(modelName, modelPath);
        close_system(modelName);

    catch ME
        if bdIsLoaded(modelName)
            close_system(modelName, 0);
        end
        rethrow(ME);
    end
end
