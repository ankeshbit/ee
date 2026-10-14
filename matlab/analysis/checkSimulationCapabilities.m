function diagnostic = checkSimulationCapabilities(options)
% checkSimulationCapabilities Inspect MATLAB, Simulink, and Simscape capabilities.
%
% Syntax:
%   diagnostic = checkSimulationCapabilities()
%   diagnostic = checkSimulationCapabilities(options)
%
% Options fields (optional, used for test injection or display control):
%   options.quiet     - Boolean. If true, suppresses console output. (default: false)
%   options.overrides - Struct of simulated capability values for testing:
%                         simulinkInstalled, simulinkLicensed,
%                         simscapeInstalled, simscapeLicensed,
%                         simscapeElectricalInstalled, simscapeElectricalLicensed,
%                         modelBuildingAPIsAvailable, simulationAPIsAvailable,
%                         componentsAvailable.
%
% Return structure fields:
%   matlabRelease               - MATLAB release string (e.g., 'R2026b')
%   matlabVersion               - Full MATLAB version string
%   operatingSystem             - Operating system description
%   simulinkInstalled           - Boolean indicating Simulink presence in ver
%   simulinkLicensed            - Boolean indicating license('test','Simulink') == 1
%   simscapeInstalled           - Boolean indicating Simscape presence in ver
%   simscapeLicensed            - Boolean indicating license('test','Simscape') == 1
%   simscapeElectricalInstalled - Boolean indicating Simscape Electrical in ver
%   simscapeElectricalLicensed  - Boolean indicating Simscape_Electrical license == 1
%   modelBuildingAPIsAvailable  - Boolean indicating Simulink model-construction APIs exist
%   simulationAPIsAvailable     - Boolean indicating Simulink simulation APIs exist
%   componentsAvailable         - Boolean indicating required electrical library blocks exist
%   apiDetails                  - Struct detailing individual API checks
%   componentDetails            - Struct detailing checked electrical library blocks
%   satisfiedRequirements       - Cell array of satisfied requirement strings
%   missingRequirements         - Cell array of missing requirement strings
%   unverifiedRequirements     - Cell array of unverified requirement strings
%   status                      - Overall status string:
%                                 'READY'
%                                 'BLOCKED_LICENSE'
%                                 'BLOCKED_MISSING_PRODUCT'
%                                 'BLOCKED_COMPONENT'
%                                 'NEEDS_VERIFICATION'
%   message                     - Explanatory summary message

    if nargin < 1 || isempty(options)
        options = struct();
    end
    if ~isfield(options, 'quiet')
        options.quiet = false;
    end
    if ~isfield(options, 'overrides')
        options.overrides = struct();
    end

    diagnostic = struct();
    diagnostic.matlabRelease = ['R', version('-release')];
    diagnostic.matlabVersion = version;
    try
        diagnostic.operatingSystem = system_dependent('getos');
    catch
        diagnostic.operatingSystem = computer;
    end

    % 1. Inspect installed products via ver
    allVer = ver;
    installedNames = {allVer.Name};

    simulinkInstalled = any(strcmpi(installedNames, 'Simulink'));
    simscapeInstalled = any(strcmpi(installedNames, 'Simscape'));
    simscapeElectricalInstalled = any(strcmpi(installedNames, 'Simscape Electrical'));

    if ~isfield(options, 'allowPowerSystemBlocks')
        options.allowPowerSystemBlocks = false;
    end

    % 2. Inspect licenses via license('test', ...)
    simulinkLicensed = (license('test', 'Simulink') == 1);
    simscapeLicensed = (license('test', 'Simscape') == 1);
    testSimscapeElec = (license('test', 'Simscape_Electrical') == 1);
    testPowerSystemBlocks = (license('test', 'Power_System_Blocks') == 1);

    if options.allowPowerSystemBlocks
        simscapeElectricalLicensed = testSimscapeElec || testPowerSystemBlocks;
    else
        simscapeElectricalLicensed = testSimscapeElec;
    end

    diagnostic.simscapeElectricalDirectLicensed = testSimscapeElec;
    diagnostic.powerSystemBlocksLicensed = testPowerSystemBlocks;
    if testSimscapeElec
        diagnostic.simscapeElectricalFeatureToken = 'Simscape_Electrical';
    elseif testPowerSystemBlocks
        diagnostic.simscapeElectricalFeatureToken = 'Power_System_Blocks';
    else
        diagnostic.simscapeElectricalFeatureToken = 'NONE';
    end

    % 3. Check APIs
    apiChecks = struct();
    apiChecks.new_system   = (exist('new_system', 'builtin') == 5 || exist('new_system', 'file') > 0);
    apiChecks.load_system  = (exist('load_system', 'builtin') == 5 || exist('load_system', 'file') > 0);
    apiChecks.close_system = (exist('close_system', 'builtin') == 5 || exist('close_system', 'file') > 0);
    apiChecks.save_system  = (exist('save_system', 'builtin') == 5 || exist('save_system', 'file') > 0);
    apiChecks.add_block    = (exist('add_block', 'builtin') == 5 || exist('add_block', 'file') > 0);
    apiChecks.set_param    = (exist('set_param', 'builtin') == 5 || exist('set_param', 'file') > 0);
    apiChecks.get_param    = (exist('get_param', 'builtin') == 5 || exist('get_param', 'file') > 0);
    apiChecks.add_line     = (exist('add_line', 'builtin') == 5 || exist('add_line', 'file') > 0);
    apiChecks.sim          = (exist('sim', 'builtin') == 5 || exist('sim', 'file') > 0);

    modelBuildingAPIsAvailable = apiChecks.new_system && apiChecks.load_system && ...
                                 apiChecks.add_block && apiChecks.set_param && apiChecks.add_line;
    simulationAPIsAvailable = apiChecks.sim && apiChecks.set_param && apiChecks.get_param;

    % 4. Check Simscape Electrical component library availability
    compDetails = struct();
    eeLibPath = which('ee_lib');
    compDetails.eeLibFound = ~isempty(eeLibPath);
    compDetails.eeLibPath = eeLibPath;

    % Check verified key block paths if ee_lib is located
    verifiedBlocks = { ...
        'ee_lib/Sources/Voltage Source (Three-Phase)', ...
        'ee_lib/Passive/Transformers/Two-Winding Transformer (Three-Phase)', ...
        'ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)', ...
        'ee_lib/Sensors & Transducers/Current and Voltage Sensor (Three-Phase)', ...
        'ee_lib/Utilities/Fault (Three-Phase)', ...
        'ee_lib/Connectors & References/Electrical Reference', ...
        'ee_lib/Connectors & References/Grounded Neutral (Three-Phase)', ...
        'ee_lib/Connectors & References/Busbar' ...
    };

    allBlocksFound = false;
    if compDetails.eeLibFound
        try
            load_system('ee_lib');
            allFound = true;
            for bIdx = 1:numel(verifiedBlocks)
                blkName = verifiedBlocks{bIdx};
                try
                    h = find_system('ee_lib', 'SearchDepth', 3, 'LookUnderMasks', 'all', 'Name', regexprep(blkName, '.*/', ''));
                    if isempty(h)
                        allFound = false;
                    end
                catch
                    allFound = false;
                end
            end
            allBlocksFound = allFound;
        catch
            allBlocksFound = false;
        end
    end
    compDetails.verifiedBlocksFound = allBlocksFound;
    componentsAvailable = compDetails.eeLibFound && allBlocksFound;

    % 5. Apply overrides if provided (for test dependency injection)
    overrides = options.overrides;
    if isfield(overrides, 'simulinkInstalled')
        simulinkInstalled = overrides.simulinkInstalled;
    end
    if isfield(overrides, 'simulinkLicensed')
        simulinkLicensed = overrides.simulinkLicensed;
    end
    if isfield(overrides, 'simscapeInstalled')
        simscapeInstalled = overrides.simscapeInstalled;
    end
    if isfield(overrides, 'simscapeLicensed')
        simscapeLicensed = overrides.simscapeLicensed;
    end
    if isfield(overrides, 'simscapeElectricalInstalled')
        simscapeElectricalInstalled = overrides.simscapeElectricalInstalled;
    end
    if isfield(overrides, 'simscapeElectricalLicensed')
        simscapeElectricalLicensed = overrides.simscapeElectricalLicensed;
    end
    if isfield(overrides, 'modelBuildingAPIsAvailable')
        modelBuildingAPIsAvailable = overrides.modelBuildingAPIsAvailable;
    end
    if isfield(overrides, 'simulationAPIsAvailable')
        simulationAPIsAvailable = overrides.simulationAPIsAvailable;
    end
    if isfield(overrides, 'componentsAvailable')
        componentsAvailable = overrides.componentsAvailable;
    end

    diagnostic.simulinkInstalled = simulinkInstalled;
    diagnostic.simulinkLicensed = simulinkLicensed;
    diagnostic.simscapeInstalled = simscapeInstalled;
    diagnostic.simscapeLicensed = simscapeLicensed;
    diagnostic.simscapeElectricalInstalled = simscapeElectricalInstalled;
    diagnostic.simscapeElectricalLicensed = simscapeElectricalLicensed;
    diagnostic.modelBuildingAPIsAvailable = modelBuildingAPIsAvailable;
    diagnostic.simulationAPIsAvailable = simulationAPIsAvailable;
    diagnostic.componentsAvailable = componentsAvailable;
    diagnostic.apiDetails = apiChecks;
    diagnostic.componentDetails = compDetails;

    % 6. Tally satisfied, missing, and unverified requirements
    satisfied = {};
    missing = {};
    unverified = {};

    % Satisfied vs Missing checks
    if simulinkInstalled
        satisfied{end+1} = 'Simulink product installed'; %#ok<*AGROW>
    else
        missing{end+1} = 'Simulink product not installed';
    end

    if simulinkLicensed
        satisfied{end+1} = 'Simulink license valid';
    else
        missing{end+1} = 'Simulink license unavailable';
    end

    if simscapeInstalled
        satisfied{end+1} = 'Simscape product installed';
    else
        missing{end+1} = 'Simscape product not installed';
    end

    if simscapeLicensed
        satisfied{end+1} = 'Simscape license valid';
    else
        missing{end+1} = 'Simscape license unavailable';
    end

    if simscapeElectricalInstalled
        satisfied{end+1} = 'Simscape Electrical product installed';
    else
        missing{end+1} = 'Simscape Electrical product not installed';
    end

    if simscapeElectricalLicensed
        if diagnostic.simscapeElectricalDirectLicensed
            satisfied{end+1} = 'Simscape Electrical license valid';
        else
            satisfied{end+1} = 'Simscape Electrical license valid (via Power_System_Blocks feature)';
        end
    else
        missing{end+1} = 'Simscape Electrical license unavailable (license("test","Simscape_Electrical") == 0)';
    end

    if modelBuildingAPIsAvailable
        satisfied{end+1} = 'Simulink model-building APIs available (new_system, add_block, add_line, set_param)';
    else
        missing{end+1} = 'Simulink model-building APIs missing or incomplete';
    end

    if simulationAPIsAvailable
        satisfied{end+1} = 'Simulink simulation APIs available (sim, get_param, set_param)';
    else
        missing{end+1} = 'Simulink simulation APIs missing';
    end

    if componentsAvailable
        satisfied{end+1} = 'Simscape Electrical library and key physical components verified (ee_lib)';
    elseif ~simscapeElectricalInstalled
        missing{end+1} = 'Simscape Electrical library missing (product not installed)';
    else
        missing{end+1} = 'Simscape Electrical library components not verified';
    end

    % Unverified requirements (cannot be tested/exercised until prerequisites met)
    if ~simscapeElectricalLicensed
        unverified{end+1} = 'Simscape Electrical physical model compilation (requires license checkout)';
        unverified{end+1} = 'Dynamic time-domain fault simulation execution (requires license checkout)';
        unverified{end+1} = 'Cross-engine analytical vs simulation numeric validation';
    end

    diagnostic.satisfiedRequirements = satisfied;
    diagnostic.missingRequirements = missing;
    diagnostic.unverifiedRequirements = unverified;

    % 7. Determine overall status
    if ~simulinkInstalled || ~simscapeInstalled || ~simscapeElectricalInstalled
        diagnostic.status = 'BLOCKED_MISSING_PRODUCT';
        diagnostic.message = 'Required MathWorks products are missing from the installation.';
    elseif ~simulinkLicensed || ~simscapeLicensed || ~simscapeElectricalLicensed
        diagnostic.status = 'BLOCKED_LICENSE';
        diagnostic.message = sprintf('Simscape Electrical or required foundation license is unavailable (Simscape_Electrical test: %d).', ...
            simscapeElectricalLicensed);
    elseif ~modelBuildingAPIsAvailable || ~simulationAPIsAvailable
        diagnostic.status = 'NEEDS_VERIFICATION';
        diagnostic.message = 'Required Simulink/Simscape APIs are missing or in an indeterminate state.';
    elseif ~componentsAvailable
        diagnostic.status = 'BLOCKED_COMPONENT';
        diagnostic.message = 'Required electrical library blocks are not available in the installed release.';
    else
        diagnostic.status = 'READY';
        diagnostic.message = 'Environment, products, licenses, APIs, and electrical library components are verified and ready.';
    end

    % 8. Console output
    if ~options.quiet
        printDiagnosticSummary(diagnostic);
    end
end

function printDiagnosticSummary(diag)
    fprintf('\n============================================================\n');
    fprintf(' SIMULATION CAPABILITY DIAGNOSTIC REPORT\n');
    fprintf('============================================================\n');
    fprintf(' MATLAB Release:       %s (%s)\n', diag.matlabRelease, diag.matlabVersion);
    fprintf(' Operating System:     %s\n', diag.operatingSystem);
    fprintf(' Overall Status:       [%s]\n', diag.status);
    fprintf(' Status Summary:       %s\n', diag.message);
    fprintf('------------------------------------------------------------\n');
    fprintf(' PRODUCT & LICENSE AUDIT:\n');
    fprintf('   Simulink:            Installed = %d, Licensed = %d\n', ...
        diag.simulinkInstalled, diag.simulinkLicensed);
    fprintf('   Simscape:            Installed = %d, Licensed = %d\n', ...
        diag.simscapeInstalled, diag.simscapeLicensed);
    fprintf('   Simscape Electrical: Installed = %d, Licensed = %d\n', ...
        diag.simscapeElectricalInstalled, diag.simscapeLicensed);
    fprintf('   Simscape_Electrical license test: %d\n', diag.simscapeElectricalLicensed);
    fprintf('------------------------------------------------------------\n');
    fprintf(' CAPABILITIES & APIS:\n');
    fprintf('   Model Building APIs: %d\n', diag.modelBuildingAPIsAvailable);
    fprintf('   Simulation APIs:     %d\n', diag.simulationAPIsAvailable);
    fprintf('   Component Library:   %d (ee_lib found: %d)\n', ...
        diag.componentsAvailable, diag.componentDetails.eeLibFound);
    fprintf('------------------------------------------------------------\n');
    fprintf(' SATISFIED REQUIREMENTS (%d):\n', numel(diag.satisfiedRequirements));
    for i = 1:numel(diag.satisfiedRequirements)
        fprintf('   [PASS] %s\n', diag.satisfiedRequirements{i});
    end
    fprintf(' MISSING REQUIREMENTS (%d):\n', numel(diag.missingRequirements));
    for i = 1:numel(diag.missingRequirements)
        fprintf('   [FAIL] %s\n', diag.missingRequirements{i});
    end
    if ~isempty(diag.unverifiedRequirements)
        fprintf(' UNVERIFIED REQUIREMENTS (%d):\n', numel(diag.unverifiedRequirements));
        for i = 1:numel(diag.unverifiedRequirements)
            fprintf('   [UNVERIFIED] %s\n', diag.unverifiedRequirements{i});
        end
    end
    fprintf('============================================================\n\n');
end
