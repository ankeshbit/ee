function plotRmsAndRelayOperation(simResult, pngFile, figFile, quietMode)
% plotRmsAndRelayOperation  Three-pane plot showing:
%   (1) Instantaneous max phase current at Bus B
%   (2) Relay B timer accumulator (sigma) with pickup and trip annotations
%   (3) Breaker contact state (0=closed, 1=open)
%
% Signals are drawn from actual Simulink output ports — no post-processing
% synthesis. If any signal is unavailable the corresponding pane is omitted.

if nargin < 4, quietMode = true; end
if nargin < 3 || isempty(figFile), figFile = ''; end

if ~strcmp(simResult.status,'COMPLETED'), return; end
if ~isfield(simResult,'waveforms'),        return; end
w = simResult.waveforms;
if ~isfield(w,'sigmaB'), return; end

t        = simResult.time_s(:);
tFault   = simResult.faultInception_s;
ft       = simResult.faultType;
sid      = simResult.scenarioId;
sigmaB   = w.sigmaB(:);
tripCmdB = zeros(numel(t),1);
brkStateB = zeros(numel(t),1);
if isfield(w,'tripCmdB'),    tripCmdB  = w.tripCmdB(:);   end
if isfield(w,'breakerStateB'), brkStateB = w.breakerStateB(:); end

% Instantaneous max phase current (available from measurements)
iMax = NaN(numel(t),1);
if isfield(simResult,'measurements') && isfield(simResult.measurements,'I_BusB')
    iABC = simResult.measurements.I_BusB;
    if size(iABC,1) ~= numel(t) && size(iABC,2) == numel(t), iABC = iABC.'; end
    if size(iABC,1) == numel(t)
        iMax = max(abs(iABC),[],2);
    end
end

nPanes = 2 + ~all(isnan(iMax));

if quietMode, fig = figure('Visible','off'); else, fig = figure(); end
fig.Color = [1 1 1];
fig.Position = [100 100 960 600];

paneIdx = 0;

%% Pane 1: Max phase current
if ~all(isnan(iMax))
    paneIdx = paneIdx + 1;
    ax1 = subplot(nPanes, 1, paneIdx, 'Parent', fig);
    plot(ax1, t, iMax, 'Color', [0.18 0.55 0.84], 'LineWidth', 1.3);
    xline(ax1, tFault, '--', 'Color', [0.5 0 0.5], 'Label', 'Fault');
    if isfield(simResult.relay,'B') && isfield(simResult.relay.B,'tripTime_s')
        xline(ax1, simResult.relay.B.tripTime_s, '--', 'Color', [0.85 0.55 0], 'Label', 'Trip');
    end
    grid(ax1,'on'); ax1.GridAlpha = 0.2; ax1.Box = 'on';
    ylabel(ax1,'|I| max (A)','FontWeight','bold');
    title(ax1, sprintf('Max Phase Current — %s [%s]',ft,sid), ...
        'Interpreter','none','FontSize',10,'FontWeight','bold');
end

%% Pane 2: Relay sigma (timer accumulator, dimensionless 0→1)
paneIdx = paneIdx + 1;
ax2 = subplot(nPanes, 1, paneIdx, 'Parent', fig);
hold(ax2,'on');
plot(ax2, t, sigmaB, 'Color', [0.93 0.39 0.25], 'LineWidth', 1.5);
yline(ax2, 1.0, '--', 'Color', [0.6 0 0], 'LineWidth', 1.4, 'Label', 'Trip (σ=1)');
xline(ax2, tFault, '--', 'Color', [0.5 0 0.5], 'LineWidth', 1.0, 'Label', 'Fault');
hold(ax2,'off');
grid(ax2,'on'); ax2.GridAlpha = 0.2; ax2.Box = 'on'; ax2.YLim = [-0.05 1.2];
ylabel(ax2,'Relay σ_B (pu)','FontWeight','bold');
title(ax2,'Relay B Timer Accumulator','FontSize',10);

%% Pane 3: Breaker state
paneIdx = paneIdx + 1;
ax3 = subplot(nPanes, 1, paneIdx, 'Parent', fig);
stairs(ax3, t, brkStateB, 'Color', [0.22 0.71 0.29], 'LineWidth', 2.0);
xline(ax3, tFault, '--', 'Color', [0.5 0 0.5], 'LineWidth', 1.0);
grid(ax3,'on'); ax3.GridAlpha = 0.2; ax3.Box = 'on';
ax3.YLim = [-0.1 1.3]; ax3.YTick = [0 1];
ax3.YTickLabel = {'Closed (0)','Open (1)'};
xlabel(ax3,'Time (s)','FontWeight','bold');
ylabel(ax3,'CB_BUS_B State','FontWeight','bold');
title(ax3,'Circuit Breaker Contact State','FontSize',10);

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
