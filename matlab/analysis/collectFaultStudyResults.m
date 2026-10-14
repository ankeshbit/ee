function [compTable, relayTable] = collectFaultStudyResults( ...
    anaResults, simResults, cfg, faultStart_s)
% collectFaultStudyResults  Combine analytical and simulation results into
% structured comparison and relay-timing tables for Phase G reporting.
%
% Inputs:
%   anaResults   - Array from runIntegratedFaultStudy (1 element per fault type)
%   simResults   - Cell array from runDynamicBreakerSwitchingSimulation
%   cfg          - Struct from createRadialRelayStudyConfiguration
%   faultStart_s - Fault inception time in seconds (e.g. 0.05)
%
% Outputs:
%   compTable    - Struct array: analytical vs simulated fault-current comparison
%                  Fields: scenarioId, faultType, analyticalCurrent_A,
%                  simulatedFundamentalRMS_A, absoluteError_A, percentageError,
%                  comparisonBasis, simulationStatus
%   relayTable   - Struct array: relay timing cross-validation
%                  Fields: scenarioId, faultType, Imax_A, M_max,
%                  analyticalTime_s, simulatedRelayTime_s, timingErrorMs,
%                  breakerOpenTime_s, validComparison

if nargin < 4 || isempty(faultStart_s)
    faultStart_s = 0.05;
end

compTable  = [];
relayTable = [];

%% Map simulation results by scenarioId for quick lookup
simMap = containers.Map('KeyType','char','ValueType','any');
for i = 1:numel(simResults)
    r = simResults{i};
    if ~isempty(r) && isfield(r,'scenarioId')
        simMap(r.scenarioId) = r;
    end
end

%% Match fault types to their scenario IDs
% Analytical scenarios: ANA_3PH_BUS_B, ANA_SLG_BUS_B, etc.
% Simulation scenarios: PF_3PH, PF_SLG, etc.
simIdMap = struct('ft3PH','PF_3PH','ftSLG','PF_SLG','ftLL','PF_LL','ftDLG','PF_DLG');
relayB = cfg.relays(strcmp({cfg.relays.id},'RELAY_BUS_B'));

%% Current comparison table
for i = 1:numel(anaResults)
    ana  = anaResults(i);
    ft   = ana.faultType;

    % Locate matching simulation
    pfId = p_simIdFor(ft);
    sim  = [];
    if simMap.isKey(pfId)
        sim = simMap(pfId);
    end

    row = struct();
    row.scenarioId            = ana.scenarioId;
    row.faultType             = ft;
    row.faultedBus            = ana.faultedBus;
    row.analyticalCurrent_A   = ana.faultCurrentMagnitude_A;
    row.comparisonBasis       = p_comparisonBasis(ft);
    row.simulationStatus      = 'NOT_RUN';
    row.simulatedFundamentalRMS_A = NaN;
    row.simulatedPeakRMS_A    = NaN;
    row.absoluteError_A       = NaN;
    row.percentageError       = NaN;
    row.validComparison       = false;
    row.comparisonNote        = '';

    if ~isempty(sim) && strcmp(sim.status,'COMPLETED') && ...
            isfield(sim,'analyticalPredictions') && ...
            isfield(sim.analyticalPredictions,'I_phaseMax_A')
        ap = sim.analyticalPredictions;
        row.simulationStatus       = 'COMPLETED';
        row.simulatedFundamentalRMS_A = ap.I_phaseMax_A;  % max phase RMS (fundamental extracted)
        absErr = abs(ap.I_phaseMax_A - ana.faultCurrentMagnitude_A);
        row.absoluteError_A        = absErr;
        if ana.faultCurrentMagnitude_A > eps
            row.percentageError    = 100 * absErr / ana.faultCurrentMagnitude_A;
        end
        row.validComparison        = true;
        row.comparisonNote         = 'Analytical: |I1|*Ibase vs Simulated: max phase RMS';
    elseif ~isempty(sim)
        row.simulationStatus = sim.status;
    end

    if isempty(compTable)
        compTable = row;
    else
        compTable(end+1) = row; %#ok<AGROW>
    end
end

%% Relay timing table
for i = 1:numel(simResults)
    sim = simResults{i};
    if isempty(sim) || ~isfield(sim,'faultType'), continue; end
    ft    = sim.faultType;
    if strcmp(ft,'HEALTHY'), continue; end   % no meaningful trip time for healthy
    if contains(sim.scenarioId,'CBF'),  continue; end   % exclude CBF (backup relay)

    rRow = struct();
    rRow.scenarioId           = sim.scenarioId;
    rRow.faultType            = ft;
    rRow.Imax_A               = NaN;
    rRow.M_max                = NaN;
    rRow.analyticalTime_s     = NaN;
    rRow.simulatedRelayTime_s = NaN;
    rRow.timingErrorMs        = NaN;
    rRow.breakerOpenTime_s    = NaN;
    rRow.validComparison      = false;
    rRow.simulationStatus     = sim.status;
    rRow.analyticalTimeVerified_s = NaN;
    rRow.verificationMatch    = false;

    if strcmp(sim.status,'COMPLETED') && ...
            isfield(sim,'relay') && isfield(sim.relay,'B') && ...
            isfield(sim.relay.B,'tripTime_s') && ~isnan(sim.relay.B.tripTime_s) && ...
            isfield(sim,'analyticalPredictions') && ...
            isfield(sim.analyticalPredictions,'I_phaseMax_A')
        ap = sim.analyticalPredictions;
        simRelayTime = sim.relay.B.tripTime_s - faultStart_s;
        rRow.Imax_A               = ap.I_phaseMax_A;
        rRow.M_max                = ap.multiple_M_max;
        rRow.analyticalTime_s     = ap.anaRelayB_trip_Imax_s;
        rRow.simulatedRelayTime_s = simRelayTime;
        rRow.timingErrorMs        = (simRelayTime - ap.anaRelayB_trip_Imax_s) * 1e3;
        rRow.breakerOpenTime_s    = sim.relay.B.breakerOpenTime_s - faultStart_s;
        rRow.validComparison      = true;
        % Independent verification of analytical value
        if ~isempty(relayB)
            Isec = ap.I_phaseMax_A * relayB.CTsecondary_A / relayB.CTprimary_A;
            tCheck = calculateRelayOperatingTime( ...
                Isec, relayB.pickupCurrent_A, relayB.TMS, relayB.curveType);
            rRow.analyticalTimeVerified_s = tCheck;
            rRow.verificationMatch = abs(tCheck - ap.anaRelayB_trip_Imax_s) < 1e-6;
        end
    end

    if isempty(relayTable)
        relayTable = rRow;
    else
        relayTable(end+1) = rRow; %#ok<AGROW>
    end
end

if isempty(compTable),  compTable  = struct([]); end
if isempty(relayTable), relayTable = struct([]); end
end

function id = p_simIdFor(ft)
switch upper(ft)
    case '3PH', id = 'PF_3PH';
    case 'SLG', id = 'PF_SLG';
    case 'LL',  id = 'PF_LL';
    case 'DLG', id = 'PF_DLG';
    otherwise,  id = '';
end
end

function s = p_comparisonBasis(ft)
switch upper(ft)
    case '3PH'
        s = 'Analytical |I1|*Ibase = max-phase RMS (balanced 3PH, Z1=0.28 pu)';
    case 'SLG'
        s = 'Analytical Ia-RMS (Z0=0.48 pu) vs Simulated Ia-RMS (Z0=0.28 pu uncoupled RLC + load)';
    case 'LL'
        s = 'Analytical |sqrt(3)*I1|*Ibase = Ibc-RMS (Z1+Z2=0.56 pu) vs Simulated Ibc-RMS';
    case 'DLG'
        s = 'Analytical max-phase RMS (Z0=0.48 pu) vs Simulated max-phase RMS (Z0=0.28 pu + load)';
    otherwise
        s = 'Analytical magnitude vs simulated max-phase RMS';
end
end
