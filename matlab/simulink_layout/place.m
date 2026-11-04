function pos = place(blockPath, col, row, width, height, options)
% place Set block position on a clean grid aligned to multiples of 10 px.
%
% Syntax:
%   pos = place(blockPath, col, row)
%   pos = place(blockPath, col, row, width, height)
%   pos = place(blockPath, col, row, width, height, options)
%
% Inputs:
%   blockPath - Full path to Simulink block
%   col       - Grid column index (1, 2, ...) or absolute X coordinate (if >= 50)
%   row       - Grid row index (1, 2, ...) or absolute Y coordinate (if >= 50)
%   width     - (Optional) Block width in px (default: 60)
%   height    - (Optional) Block height in px (default: 40)
%   options   - (Optional) struct with fields:
%                 .colWidth     - Grid column step (default: 140)
%                 .rowHeight    - Grid row step (default: 100)
%                 .originX      - Origin X coordinate (default: 60)
%                 .originY      - Origin Y coordinate (default: 100)
%                 .showName     - 'on' or 'off' (default: preserve or 'on')
%                 .fontSize     - Font size in pt (default: 10)
%                 .fontName     - Font name (default: 'Arial')
%                 .orientation  - 'right', 'down', 'left', 'up' (optional)

    if nargin < 4 || isempty(width)
        width = 60;
    end
    if nargin < 5 || isempty(height)
        height = 40;
    end
    if nargin < 6 || isempty(options)
        options = struct();
    end

    originX   = 60;
    originY   = 100;
    colWidth  = 140;
    rowHeight = 100;
    fontSize  = 10;
    fontName  = 'Arial';

    if isfield(options, 'originX'),   originX   = options.originX;   end
    if isfield(options, 'originY'),   originY   = options.originY;   end
    if isfield(options, 'colWidth'),  colWidth  = options.colWidth;  end
    if isfield(options, 'rowHeight'), rowHeight = options.rowHeight; end
    if isfield(options, 'fontSize'),  fontSize  = options.fontSize;  end
    if isfield(options, 'fontName'),  fontName  = options.fontName;  end

    % Determine (x, y) top-left coordinate
    if col < 40
        x = originX + (col - 1) * colWidth;
    else
        x = col;
    end

    if row < 40
        y = originY + (row - 1) * rowHeight;
    else
        y = row;
    end

    % Snap coordinates and dimensions to 10-pixel grid
    x = round(x / 10) * 10;
    y = round(y / 10) * 10;
    width  = round(width / 10) * 10;
    height = round(height / 10) * 10;

    pos = [x, y, x + width, y + height];

    if ~isempty(blockPath)
        set_param(blockPath, 'Position', pos);
        set_param(blockPath, 'FontName', fontName, 'FontSize', fontSize);

        if isfield(options, 'showName') && ~isempty(options.showName)
            set_param(blockPath, 'ShowName', options.showName);
        end
        if isfield(options, 'orientation') && ~isempty(options.orientation)
            set_param(blockPath, 'Orientation', options.orientation);
        end
    end
end

