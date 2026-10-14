function plotRelayTimingComparison(relayTable, pngFile, figFile, quietMode)
% plotRelayTimingComparison  Plot comparing analytical IEC operating times
% against dynamic Simscape relay trip times, with signed error bars and
% the ±20 ms acceptance band.
%
% Inputs:
%   relayTable - Struct array from collectFaultStudyResults (.relayTimingTable)
%   pngFile    - PNG export path
%   figFile    - .fig export path ('' to skip)
%   quietMode  - Suppress screen display (default: true)

if nargin < 4, quietMode = true; end
if nargin < 3 || isempty(figFile), figFile = ''; end
if isempty(relayTable) || ~isstruct(relayTable(1)), return; end

RELAY_TOL_MS = 20;   % ±20 ms acceptance band

% Collect valid rows
faults   = {};
anaTime  = [];
simTime  = [];
errMs    = [];
passed   = [];

for i = 1:numel(relayTable)
    r = relayTable(i);
    if ~isfield(r,'validComparison') || ~r.validComparison, continue; end
    faults{end+1}  = r.faultType; %#ok<AGROW>
    anaTime(end+1) = r.analyticalTime_s   * 1e3;   % ms
    simTime(end+1) = r.simulatedRelayTime_s * 1e3;  % ms
    errMs(end+1)   = r.timingErrorMs;
    passed(end+1)  = abs(r.timingErrorMs) <= RELAY_TOL_MS;
end

if isempty(faults), return; end
nRows = numel(faults);

if quietMode, fig = figure('Visible','off'); else, fig = figure(); end
fig.Color = [1 1 1];
fig.Position = [100 100 880 560];

%% Top pane: Absolute operating times
ax1 = subplot(2,1,1,'Parent',fig);
hold(ax1,'on');
x = 1:nRows;
bar(ax1, x - 0.2, anaTime, 0.35, 'FaceColor',[0.18 0.55 0.84], 'FaceAlpha',0.85);
bar(ax1, x + 0.2, simTime, 0.35, 'FaceColor',[0.93 0.39 0.25], 'FaceAlpha',0.85);
hold(ax1,'off');
ax1.XTick = x;
ax1.XTickLabel = faults;
grid(ax1,'on'); ax1.GridAlpha = 0.2; ax1.Box = 'on';
ylabel(ax1,'Operating Time (ms)','FontWeight','bold');
title(ax1,'Relay B Operating Time — Analytical (IEC SI) vs. Simulated', ...
    'FontSize',11,'FontWeight','bold');
legend(ax1,{'Analytical t_{op}','Simulated trip time'}, ...
    'Location','northwest','FontSize',9);

%% Bottom pane: Signed error with tolerance band
ax2 = subplot(2,1,2,'Parent',fig);
hold(ax2,'on');
clrs = zeros(nRows,3);
for i = 1:nRows
    if passed(i), clrs(i,:) = [0.22 0.71 0.29];
    else,         clrs(i,:) = [0.85 0.18 0.18];
    end
end
for i = 1:nRows
    bar(ax2, i, errMs(i), 0.5, 'FaceColor', clrs(i,:), 'FaceAlpha', 0.85);
end
yline(ax2,  RELAY_TOL_MS, '--', 'Color',[0.7 0.1 0.1], 'LineWidth',1.4, ...
    'Label','+20 ms', 'LabelHorizontalAlignment','right');
yline(ax2, -RELAY_TOL_MS, '--', 'Color',[0.7 0.1 0.1], 'LineWidth',1.4, ...
    'Label','-20 ms', 'LabelHorizontalAlignment','right');
yline(ax2, 0, '-', 'Color',[0.4 0.4 0.4], 'LineWidth',0.8);

% Annotate each bar
for i = 1:nRows
    yPos = errMs(i) + sign(errMs(i)) * 0.5;
    if errMs(i) == 0, yPos = 0.5; end
    text(ax2, i, yPos, sprintf('%+.1f ms', errMs(i)), ...
        'HorizontalAlignment','center','FontSize',9, ...
        'Color', clrs(i,:), 'FontWeight','bold');
end

hold(ax2,'off');
ax2.XTick = 1:nRows;
ax2.XTickLabel = faults;
grid(ax2,'on'); ax2.GridAlpha = 0.2; ax2.Box = 'on';
xlabel(ax2,'Fault Type','FontWeight','bold');
ylabel(ax2,'Timing Error (ms)','FontWeight','bold');
title(ax2,'Relay Timing Error (Sim − Analytical)  |  ±20 ms Band', ...
    'FontSize',10);

p_saveFig(fig, pngFile, figFile);
end

function p_saveFig(fig, pngFile, figFile)
if ~isempty(pngFile)
    d = fileparts(pngFile); if ~isempty(d)&&~exist(d,'dir'), mkdir(d); end
    exportgraphics(fig, pngFile, 'Resolution', 200);
end
if ~isempty(figFile)
    d = fileparts(figFile); if ~isempty(d)&&~exist(d,'dir'), mkdir(d); end
    savefig(fig, figFile);
end
close(fig);
end
