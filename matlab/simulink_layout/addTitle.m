function noteH = addTitle(sys, titleText, subtitleText, pos)
% addTitle Add a clean model title banner with subtitle and wiring legend.
%
% Syntax:
%   noteH = addTitle(sys, titleText, subtitleText)
%   noteH = addTitle(sys, titleText, subtitleText, pos)
%
% Inputs:
%   sys          - Model or subsystem path
%   titleText    - Main title string
%   subtitleText - One-line purpose description
%   pos          - (Optional) [left, top, right, bottom] in px (default: [40, 20, 800, 80])

    if nargin < 3 || isempty(subtitleText)
        subtitleText = '';
    end
    if nargin < 4 || isempty(pos)
        pos = [40, 20, 840, 80];
    end

    pos = round(pos / 10) * 10;
    notePath = [sys, '/Model_Title_Header'];

    if exist_block(notePath)
        delete_block(notePath);
    end

    legendStr = 'Legend: Blue = Simscape Physical Conserving Lines  |  Black = Simulink Signals';
    if isempty(subtitleText)
        fullText = sprintf('%s\n%s', titleText, legendStr);
    else
        fullText = sprintf('%s\n%s\n%s', titleText, subtitleText, legendStr);
    end

    noteH = add_block('built-in/Note', notePath, 'Position', pos);
    set_param(noteH, 'Text', fullText);
    set_param(noteH, 'FontName', 'Arial');
    set_param(noteH, 'FontSize', 11);
    set_param(noteH, 'FontWeight', 'bold');
    set_param(noteH, 'HorizontalAlignment', 'left');
end

function tf = exist_block(blkPath)
    try
        get_param(blkPath, 'Handle');
        tf = true;
    catch
        tf = false;
    end
end

