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
    else
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
    end

    addpath(fullfile(projectRoot, 'matlab', 'simulink_layout'));

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
        % -------------------------------------------------------------
        % 1. Add blocks from verified library paths
        % -------------------------------------------------------------
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

        % -------------------------------------------------------------
        % 2. Title, Areas, and Grid Layout
        % -------------------------------------------------------------
        % Title banner and wiring legend
        addTitle(modelName, ...
            'Minimal Circuit Prototype — 11 kV Three-Phase Network', ...
            'Physical Conserving Simscape Electrical Model (11 kV Source -> Sensor -> R-L Load)', ...
            [40, 20, 680, 80]);

        % Area 1: Power Circuit (horizontal chain Source -> Sensor -> Load)
        addLabeledArea(modelName, 'Area_Power_Network', [40, 100, 620, 300], ...
            '11 kV Three-Phase Power Network', struct('backgroundColor', '[0.94, 0.96, 1.00]'));

        % Area 2: Measurements & Converters
        addLabeledArea(modelName, 'Area_Measurements', [40, 320, 620, 460], ...
            'Measurement Signal Interface', struct('backgroundColor', '[0.96, 0.96, 0.96]'));

        % Row 1 (y = 150): Source -> Sensor -> Load (horizontal single-line flow)
        place([modelName, '/Source'], 100, 150, 70, 50, struct('showName', 'on'));
        place([modelName, '/Sensor'], 280, 140, 70, 70, struct('showName', 'on'));
        place([modelName, '/Load'],   480, 150, 70, 50, struct('showName', 'on'));

        % Row 2 (y = 240): Grounds directly beneath their associated components
        place([modelName, '/Solver'],      50,  240, 40, 30, struct('showName', 'off'));
        place([modelName, '/GND'],         120, 240, 30, 30, struct('showName', 'on'));
        place([modelName, '/Neutral_GND'], 500, 240, 30, 30, struct('showName', 'on'));

        % Row 3 & 4 (y = 350, 400): PS Converters and Outports
        place([modelName, '/PS_V'],  280, 350, 60, 30, struct('showName', 'off'));
        place([modelName, '/V_abc'], 440, 350, 40, 30, struct('showName', 'on'));
        place([modelName, '/PS_I'],  280, 410, 60, 30, struct('showName', 'off'));
        place([modelName, '/I_abc'], 440, 410, 40, 30, struct('showName', 'on'));

        % -------------------------------------------------------------
        % 3. Configure parameters
        % -------------------------------------------------------------
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

        % -------------------------------------------------------------
        % 4. Connect physical lines
        % -------------------------------------------------------------
        % Solver config to Electrical Reference
        add_line(modelName, 'Solver/RConn1', 'GND/LConn1', 'autorouting', 'on');
        % Source neutral to Electrical Reference directly below
        add_line(modelName, 'Source/LConn1', 'GND/LConn1', 'autorouting', 'on');
        % Source three-phase output to Sensor input (horizontal)
        add_line(modelName, 'Source/RConn1', 'Sensor/LConn1', 'autorouting', 'on');
        % Sensor three-phase output to Load input (horizontal)
        add_line(modelName, 'Sensor/RConn3', 'Load/LConn1', 'autorouting', 'on');
        % Load neutral to Grounded Neutral directly below
        add_line(modelName, 'Load/RConn1', 'Neutral_GND/LConn1', 'autorouting', 'on');

        % Measurement outputs to PS-Simulink converters (vertical drop to measurement area)
        add_line(modelName, 'Sensor/RConn1', 'PS_V/LConn1', 'autorouting', 'on');
        add_line(modelName, 'Sensor/RConn2', 'PS_I/LConn1', 'autorouting', 'on');

        % Converters to Simulink outports (horizontal)
        add_line(modelName, 'PS_V/1', 'V_abc/1', 'autorouting', 'on');
        add_line(modelName, 'PS_I/1', 'I_abc/1', 'autorouting', 'on');

        % -------------------------------------------------------------
        % 5. Configure solver and logging
        % -------------------------------------------------------------
        set_param(modelName, ...
            'StopTime', '0.04', ...
            'Solver', 'ode23t', ...
            'MaxStep', '5e-5', ...
            'SaveOutput', 'on', ...
            'OutputSaveName', 'yout', ...
            'SaveTime', 'on', ...
            'TimeSaveName', 'tout');

        % -------------------------------------------------------------
        % 6. Save model and export documentation figure
        % -------------------------------------------------------------
        save_system(modelName, modelPath);

        imgDir = fullfile(projectRoot, 'docs', 'images');
        if ~exist(imgDir, 'dir'), mkdir(imgDir); end
        try
            print(['-s', modelName], '-dpng', '-r200', fullfile(imgDir, 'minimal_circuit_prototype.png'));
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
