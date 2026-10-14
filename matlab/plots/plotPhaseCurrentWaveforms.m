function plotPhaseCurrentWaveforms(simResult, pngFile, figFile, quietMode)
% plotPhaseCurrentWaveforms  Plot three-phase fault currents at Bus B with
% protective relay and breaker event markers.
%
% Inputs:
%   simResult  - Completed result struct from runDynamicBreakerSwitchingSimulation
%   pngFile    - Full path to save PNG export
%   figFile    - Full path to save editable .fig file (may be '' to skip)
%   quietMode  - If true, do not display figure on screen (default: true)

if nargin < 4, quietMode = true; end
if nargin < 3 || isempty(figFile), figFile = ''; end

% Validate inputs
if ~strcmp(simResult.status, 'COMPLETED')
    return;
end
if ~isfield(simResult,'measurements') || ~isfield(simResult.measurements,'I_BusB')
    return;
end

t   = simResult.time_s(:);
iABC = simResult.measurements.I_BusB;   % [T x 3]  Ia Ib Ic (primary A)
if size(iABC,1) ~= numel(t)
    if size(iABC,2) == numel(t)
        iABC = iABC.';
    else
        warning('plotPhaseCurrentWaveforms:DimMismatch','Current matrix dimension mismatch.');
        return;
    end
end

tFault = simResult.faultInception_s;
ft     = simResult.faultType;
sid    = simResult.scenarioId;

% Event times
tripTime_s  = NaN;  openTime_s  = NaN;  extTime_s   = NaN;
if isfield(simResult,'relay') && isfield(simResult.relay,'B')
    b = simResult.relay.B;
    if isfield(b,'tripTime_s'),       tripTime_s = b.tripTime_s; end
    if isfield(b,'breakerOpenTime_s'), openTime_s = b.breakerOpenTime_s; end
end
if isfield(simResult,'clearingVerification')
    cv = simResult.clearingVerification;
    if isfield(cv,'extinctionTime_s') && ~isnan(cv.extinctionTime_s)
        extTime_s = cv.extinctionTime_s;
    end
end

%% Create figure
if quietMode
    fig = figure('Visible','off');
else
    fig = figure();
end
fig.Color = [1 1 1];
fig.Position = [100 100 960 520];

ax = axes(fig);
colors = [0.18 0.55 0.84;   % Ia — blue
           0.93 0.39 0.25;   % Ib — red-orange
           0.22 0.71 0.29];  % Ic — green

hold(ax,'on');
h = gobjects(1,3);
h(1) = plot(ax, t, iABC(:,1), 'Color', colors(1,:), 'LineWidth', 1.4);
h(2) = plot(ax, t, iABC(:,2), 'Color', colors(2,:), 'LineWidth', 1.4);
h(3) = plot(ax, t, iABC(:,3), 'Color', colors(3,:), 'LineWidth', 1.4);

% Event markers
yLim = ylim(ax);
ySpan = yLim(2) - yLim(1);
evtHandles = [];
evtLabels  = {};

if ~isnan(tFault)
    xline(ax, tFault, '--', 'Color',[0.5 0 0.5], 'LineWidth',1.2, ...
        'Label','Fault','LabelVerticalAlignment','top','LabelHorizontalAlignment','right');
end
if ~isnan(tripTime_s)
    xline(ax, tripTime_s, '--', 'Color',[0.85 0.55 0], 'LineWidth',1.4, ...
        'Label','Trip','LabelVerticalAlignment','top');
end
if ~isnan(openTime_s)
    xline(ax, openTime_s, '-', 'Color',[0.7 0.1 0.1], 'LineWidth',2.0, ...
        'Label','CB Open','LabelVerticalAlignment','bottom');
end
if ~isnan(extTime_s)
    xline(ax, extTime_s, ':', 'Color',[0.2 0.2 0.2], 'LineWidth',1.4, ...
        'Label','Extinction','LabelVerticalAlignment','top');
end

hold(ax,'off');
grid(ax,'on');
ax.GridAlpha = 0.25;
ax.Box = 'on';
ax.FontSize = 10;
ax.FontName = 'Arial';

xlabel(ax,'Time (s)','FontWeight','bold');
ylabel(ax,'Phase Current (A)','FontWeight','bold');
titleStr = sprintf('Phase Currents at Bus B — %s Fault  [%s]', ft, sid);
title(ax, titleStr, 'FontSize', 11, 'FontWeight', 'bold', 'Interpreter','none');
legend(ax, h, {'Phase A (I_a)','Phase B (I_b)','Phase C (I_c)'}, ...
    'Location','northwest','FontSize',9);

% Annotation box
annot = '';
if ~isnan(tripTime_s)
    relayDelay = tripTime_s - tFault;
    annot = [annot sprintf('Relay trip: %.3f s (%.1f ms after fault)\n', ...
        tripTime_s, relayDelay*1e3)];
end
if ~isnan(openTime_s)
    clearDelay = openTime_s - tFault;
    annot = [annot sprintf('CB opens:  %.3f s (%.1f ms after fault)\n', ...
        openTime_s, clearDelay*1e3)];
end
if ~isempty(annot)
    annotation(fig,'textbox',[0.58 0.05 0.38 0.15], ...
        'String', strtrim(annot), 'EdgeColor', [0.6 0.6 0.6], ...
        'BackgroundColor', [0.98 0.98 0.98], 'FitBoxToText','on', ...
        'FontSize', 8, 'FontName','Arial');
end

%% Save
p_saveFigure(fig, pngFile, figFile);
end

function p_saveFigure(fig, pngFile, figFile)
if ~isempty(pngFile)
    pDir = fileparts(pngFile);
    if ~isempty(pDir) && ~exist(pDir,'dir'), mkdir(pDir); end
    exportgraphics(fig, pngFile, 'Resolution', 200);
end
if ~isempty(figFile)
    fDir = fileparts(figFile);
    if ~isempty(fDir) && ~exist(fDir,'dir'), mkdir(fDir); end
    savefig(fig, figFile);
end
close(fig);
end
