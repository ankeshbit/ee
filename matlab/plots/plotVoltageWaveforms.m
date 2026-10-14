function plotVoltageWaveforms(simResult, pngFile, figFile, quietMode)
% plotVoltageWaveforms  Plot three-phase bus voltages at Bus A and Bus B.
%
% Inputs:
%   simResult  - Completed result from runDynamicBreakerSwitchingSimulation
%   pngFile    - Full path for PNG export
%   figFile    - Full path for .fig export ('' to skip)
%   quietMode  - Suppress screen display (default: true)

if nargin < 4, quietMode = true; end
if nargin < 3 || isempty(figFile), figFile = ''; end

if ~strcmp(simResult.status,'COMPLETED'), return; end
if ~isfield(simResult,'measurements'), return; end
m = simResult.measurements;
if ~isfield(m,'V_BusA') || ~isfield(m,'V_BusB'), return; end

t   = simResult.time_s(:);
vA  = m.V_BusA;   % [T x 3]
vB  = m.V_BusB;   % [T x 3]
for v = {vA, vB}
    if size(v{1},1) ~= numel(t) && size(v{1},2) == numel(t)
        v{1} = v{1}.';
    end
end
if size(vA,1)~=numel(t), vA=vA.'; end
if size(vB,1)~=numel(t), vB=vB.'; end

tFault    = simResult.faultInception_s;
tripTime  = NaN;  openTime = NaN;
if isfield(simResult,'relay') && isfield(simResult.relay,'B')
    b = simResult.relay.B;
    if isfield(b,'tripTime_s'),        tripTime = b.tripTime_s; end
    if isfield(b,'breakerOpenTime_s'), openTime = b.breakerOpenTime_s; end
end

if quietMode, fig = figure('Visible','off'); else, fig = figure(); end
fig.Color = [1 1 1];
fig.Position = [100 100 960 640];

colors = [0.18 0.55 0.84; 0.93 0.39 0.25; 0.22 0.71 0.29];

% Bus A subplot
ax1 = subplot(2,1,1,'Parent',fig);
hold(ax1,'on');
for ph = 1:3
    plot(ax1, t, vA(:,ph)/1e3, 'Color', colors(ph,:), 'LineWidth', 1.2);
end
p_addMarkers(ax1, tFault, tripTime, openTime);
hold(ax1,'off');
grid(ax1,'on');  ax1.GridAlpha = 0.2;  ax1.Box = 'on';
ylabel(ax1,'Voltage (kV)','FontWeight','bold');
title(ax1,sprintf('Bus A Voltage — %s [%s]', simResult.faultType, simResult.scenarioId), ...
    'FontSize',10,'Interpreter','none');
legend(ax1,{'V_a','V_b','V_c'},'Location','northwest','FontSize',8);

% Bus B subplot
ax2 = subplot(2,1,2,'Parent',fig);
hold(ax2,'on');
for ph = 1:3
    plot(ax2, t, vB(:,ph)/1e3, 'Color', colors(ph,:), 'LineWidth', 1.2);
end
p_addMarkers(ax2, tFault, tripTime, openTime);
hold(ax2,'off');
grid(ax2,'on');  ax2.GridAlpha = 0.2;  ax2.Box = 'on';
xlabel(ax2,'Time (s)','FontWeight','bold');
ylabel(ax2,'Voltage (kV)','FontWeight','bold');
title(ax2,'Bus B Voltage (Faulted Bus)','FontSize',10);
legend(ax2,{'V_a','V_b','V_c'},'Location','northwest','FontSize',8);

p_saveFig(fig, pngFile, figFile);
end

function p_addMarkers(ax, tFault, tripTime, openTime)
if ~isnan(tFault),   xline(ax,tFault,  '--','Color',[0.5 0 0.5],'LineWidth',1.2,'Label','Fault'); end
if ~isnan(tripTime), xline(ax,tripTime,'--','Color',[0.85 0.55 0],'LineWidth',1.4,'Label','Trip'); end
if ~isnan(openTime), xline(ax,openTime,'-', 'Color',[0.7 0.1 0.1],'LineWidth',1.8,'Label','CB Open'); end
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
