function report = verifySimscapeComponents(options)
% verifySimscapeComponents Inspect, instantiate, and verify candidate Simscape Electrical components.
%
% Syntax:
%   report = verifySimscapeComponents()
%   report = verifySimscapeComponents(options)
%
% Options fields:
%   options.quiet     - Boolean. If true, suppresses console output (default: false)
%   options.testModel - Temporary model name (default: 'temp_verify_components')
%
% Returns a structured verification report detailing:
%   - Candidate block paths in ee_lib and nesl_utility
%   - Existence verification in installed library
%   - Test instantiation in a temporary Simulink model
%   - Parameter read/write accessibility
%   - Licensing errors, if encountered
%   - Summary status (allFound, allInstantiated, allConfigurable)

    if nargin < 1 || isempty(options)
        options = struct();
    end
    if ~isfield(options, 'quiet')
        options.quiet = false;
    end
    if ~isfield(options, 'testModel')
        options.testModel = sprintf('temp_verify_%s', datestr(now, 'HHMMSS_FFF')); %#ok<TNOW1,DATST>
    end

    % Inventory of candidate components to verify
    candidates = { ...
        'Three-Phase Voltage Source', ...
            'ee_lib/Sources/Voltage Source (Three-Phase)', ...
            struct('param', 'vline_rms', 'val', '11000'); ...
        'Three-Phase Transformer', ...
            'ee_lib/Passive/Transformers/Two-Winding Transformer (Three-Phase)', ...
            struct('param', 'SRated', 'val', '10e6'); ...
        'Three-Phase Current & Voltage Sensor', ...
            'ee_lib/Sensors & Transducers/Current and Voltage Sensor (Three-Phase)', ...
            struct('param', 'vMeasurementType', 'val', 'ee.enum.vMeasurementType.phaseToGround'); ...
        'Three-Phase Current Sensor', ...
            'ee_lib/Sensors & Transducers/Current Sensor (Three-Phase)', ...
            struct(); ...
        'Three-Phase Phase Voltage Sensor', ...
            'ee_lib/Sensors & Transducers/Phase Voltage Sensor (Three-Phase)', ...
            struct(); ...
        'Three-Phase Line Voltage Sensor', ...
            'ee_lib/Sensors & Transducers/Line Voltage Sensor (Three-Phase)', ...
            struct(); ...
        'Three-Phase Fault Block', ...
            'ee_lib/Utilities/Fault (Three-Phase)', ...
            struct('param', 'R_pn_fault', 'val', '0.05'); ...
        'Three-Phase Circuit Breaker', ...
            'ee_lib/Switches & Breakers/Circuit Breaker (Three-Phase)', ...
            struct(); ...
        'Three-Phase RLC Assembly', ...
            'ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', ...
            struct('param', 'component_structure', 'val', 'ee.enum.rlc.structure.SeriesRL'); ...
        'Electrical Reference', ...
            'ee_lib/Connectors & References/Electrical Reference', ...
            struct(); ...
        'Three-Phase Grounded Neutral', ...
            'ee_lib/Connectors & References/Grounded Neutral (Three-Phase)', ...
            struct(); ...
        'Busbar', ...
            'ee_lib/Connectors & References/Busbar', ...
            struct(); ...
        'Solver Configuration', ...
            'nesl_utility/Solver Configuration', ...
            struct(); ...
        'PS-Simulink Converter', ...
            'nesl_utility/PS-Simulink Converter', ...
            struct(); ...
        'Simulink-PS Converter', ...
            'nesl_utility/Simulink-PS Converter', ...
            struct() ...
    };

    numCands = size(candidates, 1);
    compList = repmat(struct( ...
        'name', '', ...
        'blockPath', '', ...
        'found', false, ...
        'instantiated', false, ...
        'parametersConfigurable', false, ...
        'errorMessage', ''), numCands, 1);

    % Create temporary test model
    tempMdl = options.testModel;
    if bdIsLoaded(tempMdl)
        close_system(tempMdl, 0);
    end
    new_system(tempMdl);

    try
        % Preload library systems
        load_system('ee_lib');
        load_system('nesl_utility');

        for i = 1:numCands
            cName = candidates{i, 1};
            cPath = candidates{i, 2};
            cTestParam = candidates{i, 3};

            compList(i).name = cName;
            compList(i).blockPath = cPath;

            % 1. Verify existence in installed library
            libName = strtok(cPath, '/');
            blockNameOnly = regexprep(cPath, '.*/', '');
            try
                foundBlocks = find_system(libName, 'LookUnderMasks', 'all', 'Name', blockNameOnly);
                compList(i).found = ~isempty(foundBlocks);
            catch
                compList(i).found = false;
            end

            if ~compList(i).found
                compList(i).errorMessage = 'Block not found in library.';
                continue;
            end

            % 2. Test instantiation in temporary model
            safeBlockName = sprintf('blk_%d', i);
            targetPath = [tempMdl, '/', safeBlockName];

            try
                add_block(cPath, targetPath);
                compList(i).instantiated = true;
            catch ME
                compList(i).instantiated = false;
                compList(i).errorMessage = sprintf('Instantiation failed: %s (%s)', ME.message, ME.identifier);
                continue;
            end

            % 3. Test parameter inspection and setting
            try
                params = get_param(targetPath, 'DialogParameters');
                if isempty(params) || ~isstruct(params)
                    % Some utility blocks have minimal or no dialog parameters
                    compList(i).parametersConfigurable = true;
                else
                    % If a test parameter was specified, attempt to set it
                    if isfield(cTestParam, 'param')
                        set_param(targetPath, cTestParam.param, cTestParam.val);
                    end
                    compList(i).parametersConfigurable = true;
                end
            catch ME
                compList(i).parametersConfigurable = false;
                compList(i).errorMessage = sprintf('Parameter configuration failed: %s (%s)', ME.message, ME.identifier);
            end
        end

        close_system(tempMdl, 0);

    catch ME
        if bdIsLoaded(tempMdl)
            close_system(tempMdl, 0);
        end
        rethrow(ME);
    end

    report = struct();
    report.components = compList;
    report.totalChecked = numCands;
    report.foundCount = sum([compList.found]);
    report.instantiatedCount = sum([compList.instantiated]);
    report.configurableCount = sum([compList.parametersConfigurable]);
    report.allFound = (report.foundCount == numCands);
    report.allInstantiated = (report.instantiatedCount == numCands);
    report.allConfigurable = (report.configurableCount == numCands);

    if ~options.quiet
        printComponentReport(report);
    end
end

function printComponentReport(rep)
    fprintf('\n============================================================\n');
    fprintf(' SIMSCAPE ELECTRICAL COMPONENT VERIFICATION REPORT\n');
    fprintf('============================================================\n');
    fprintf(' Total Candidates Checked: %d\n', rep.totalChecked);
    fprintf(' Found in Libraries:       %d / %d\n', rep.foundCount, rep.totalChecked);
    fprintf(' Instantiated:             %d / %d\n', rep.instantiatedCount, rep.totalChecked);
    fprintf(' Parameters Configurable:  %d / %d\n', rep.configurableCount, rep.totalChecked);
    fprintf('------------------------------------------------------------\n');
    for i = 1:numel(rep.components)
        c = rep.components(i);
        statusStr = '[PASS]';
        if ~c.found || ~c.instantiated || ~c.parametersConfigurable
            statusStr = '[FAIL]';
        end
        fprintf(' %s %-32s -> %s\n', statusStr, c.name, c.blockPath);
        if ~isempty(c.errorMessage)
            fprintf('        Error: %s\n', c.errorMessage);
        end
    end
    fprintf('============================================================\n\n');
end
