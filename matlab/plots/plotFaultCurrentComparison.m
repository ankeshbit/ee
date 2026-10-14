function plotFaultCurrentComparison(compTable, pngFile, figFile, quietMode)
% plotFaultCurrentComparison  Grouped bar chart comparing analytical and
% simulated fault currents for all fault types, with error annotations.
%
% Convention: Analytical = |I_fault| from symmetrical-component network
%             equations. Simulated = max phase-RMS measured by physical CTs
%             in the Simscape model. For asymmetric faults these differ; the
%             chart labels the comparison basis explicitly.
%
% Inputs:
%   compTable  - Struct array from collectFaultStudyResults (.comparisonTable)
%   pngFile    - PNG export path
%   figFile    - .fig export path ('' to skip)
%   quietMode  - Suppress screen display (default: true)

if nargin < 4, quietMode = true; end
if nargin < 3 || isempty(figFile), figFile = ''; end
if isempty(compTable) || ~isstruct(compTable(1)), return; end

% Extract data for valid rows
labels     = {};
anaVals    = [];
simVals    = [];
errPct     = [];
simStatus  = {};

for i = 1:numel(compTable)
    r = compTable(i);
    if ~isfield(r,'faultType'), continue; end
    labels{end+1}    = r.faultType; %#ok<AGROW>
    anaVals(end+1)   = r.analyticalCurrent_A; %#ok<AGROW>
    if isfield(r,'simulatedFundamentalRMS_A') && ~isnan(r.simulatedFundamentalRMS_A)
        simVals(end+1)  = r.simulatedFundamentalRMS_A; %#ok<AGROW>
        errPct(end+1)   = r.percentageError; %#ok<AGROW>
        simStatus{end+1} = 'Simulated'; %#ok<AGROW>
    else
        simVals(end+1)  = NaN; %#ok<AGROW>
        errPct(end+1)   = NaN; %#ok<AGROW>
        simStatus{end+1} = r.simulationStatus; %#ok<AGROW>
    end
end

if isempty(labels), return; end

nBars = numel(labels);

if quietMode, fig = figure('Visible','off'); else, fig = figure(); end
fig.Color = [1 1 1];
fig.Position = [100 100 820 480];

ax = axes(fig);

% Build bar matrix [nBars x 2]
barData = [anaVals(:), simVals(:)];
hb = bar(ax, barData, 'grouped');
hb(1).FaceColor = [0.18 0.55 0.84];   % analytical — blue
hb(1).FaceAlpha = 0.85;
if numel(hb) >= 2
    hb(2).FaceColor = [0.93 0.39 0.25]; % simulated — orange
    hb(2).FaceAlpha = 0.85;
end

ax.XTick = 1:nBars;
ax.XTickLabel = labels;
ax.FontSize   = 11;
ax.FontName   = 'Arial';
ax.Box        = 'on';
grid(ax,'on');
ax.GridAlpha  = 0.2;

xlabel(ax,'Fault Type','FontWeight','bold');
ylabel(ax,'Fault Current (A)','FontWeight','bold');
title(ax,'Fault Current: Analytical vs. Simulated (Max Phase RMS)', ...
    'FontWeight','bold','FontSize',12);
legend(ax,{'Analytical (|I_{fault}|)','Simulated (I_{max} RMS)'}, ...
    'Location','northeast','FontSize',10);

% Error annotations above each group
yMax = max([anaVals, simVals(~isnan(simVals))], [], 'all');
if isnan(yMax) || yMax == 0, yMax = 1; end
yOffset = yMax * 0.03;

for i = 1:nBars
    if isnan(errPct(i)), continue; end
    xPos = i;
    yPos = max(anaVals(i), simVals(i)) + yOffset;
    text(ax, xPos, yPos, sprintf('%.1f%%', errPct(i)), ...
        'HorizontalAlignment','center','FontSize',9, ...
        'Color',[0.3 0.3 0.3],'FontWeight','bold');
end

% Footnote
annotation(fig,'textbox',[0.02 0.01 0.96 0.06], ...
    'String',['Note: Analytical calculates phase currents using sequence networks with coupled line parameters (Z0=0.48 pu). ' ...
    'Simulated uses physical max-phase RMS measured by CTs in Simscape (Z0=0.28 pu + load). ' ...
    'Discrepancy in ground faults reflects physical uncoupled RLC vs coupled overhead line models.'], ...
    'EdgeColor','none','FontSize',7,'Color',[0.5 0.5 0.5]);

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
