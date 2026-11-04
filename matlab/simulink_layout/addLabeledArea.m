function areaH = addLabeledArea(sys, name, pos, labelText, options)
% addLabeledArea Add a visual Area grouping annotation box in a Simulink diagram.
%
% Syntax:
%   areaH = addLabeledArea(sys, name, pos, labelText)
%   areaH = addLabeledArea(sys, name, pos, labelText, options)
%
% Inputs:
%   sys       - Model or subsystem path (e.g. 'radial_fault_study_network')
%   name      - Unique identifier name for the area block
%   pos       - [left, top, right, bottom] in px (snapped to 10 px grid)
%   labelText - Display title text for the area
%   options   - (Optional) struct with fields:
%                 .fontSize        - Font size (default: 11)
%                 .fontName        - Font name (default: 'Arial')
%                 .fontWeight      - Font weight ('bold', 'normal')
%                 .foregroundColor - Foreground color string
%                 .backgroundColor - Background color string (e.g. '[0.94, 0.95, 0.98]')

    if nargin < 4 || isempty(labelText)
        labelText = name;
    end
    if nargin < 5 || isempty(options)
        options = struct();
    end

    pos = round(pos / 10) * 10;
    areaPath = [sys, '/', name];

    % Delete existing area with same name if already present
    if exist_block(areaPath)
        delete_block(areaPath);
    end

    areaH = add_block('built-in/Area', areaPath, 'Position', pos);

    % Configure appearance
    set_param(areaH, 'Text', labelText);
    set_param(areaH, 'FontName', 'Arial');

    fontSize = 11;
    if isfield(options, 'fontSize'), fontSize = options.fontSize; end
    set_param(areaH, 'FontSize', fontSize);

    if isfield(options, 'fontWeight')
        set_param(areaH, 'FontWeight', options.fontWeight);
    else
        set_param(areaH, 'FontWeight', 'bold');
    end

    if isfield(options, 'backgroundColor')
        set_param(areaH, 'BackgroundColor', options.backgroundColor);
    end
    if isfield(options, 'foregroundColor')
        set_param(areaH, 'ForegroundColor', options.foregroundColor);
    end
end

function tf = exist_block(blkPath)
    try
        get_param(blkPath, 'Handle');
        tf = true;
    catch
        tf = false;
    end
end

