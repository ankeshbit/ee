%% dump_relay_study_table.m
% Prints raw numbers from runIntegratedFaultStudy and evaluateRadialProtectionScenarios
% for BUS_A, BUS_B, and BUS_11KV across all four fault types.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(fullfile(repoRoot, 'matlab')));
addpath(genpath(fullfile(repoRoot, 'scripts')));
addpath(genpath(fullfile(repoRoot, 'tests')));

cfg = createRadialRelayStudyConfiguration();

buses = {'BUS_A', 'BUS_B', 'BUS_11KV'};
faultTypes = {'3PH', 'SLG', 'LL', 'DLG'};

fprintf('========================================================================================================\n');
fprintf(' RAW DUMP: runIntegratedFaultStudy vs evaluateRadialProtectionScenarios\n');
fprintf('========================================================================================================\n');

for bIdx = 1:numel(buses)
    bus = buses{bIdx};
    for fIdx = 1:numel(faultTypes)
        ft = faultTypes{fIdx};
        scn = struct('id', sprintf('DUMP_%s_%s', bus, ft), ...
            'faultedBus', bus, ...
            'faultType', ft, ...
            'Zf_pu', 0.0);
        
        % 1. runIntegratedFaultStudy
        anaRes = runIntegratedFaultStudy(cfg.network, scn, cfg.relays, cfg.coordinationPairs);
        
        % 2. evaluateRadialProtectionScenarios (analytical mode: simResults = [])
        sDef = struct('id', scn.id, 'faultedBus', bus, 'faultType', ft, ...
            'isFault', true);
        evalStudy = evaluateRadialProtectionScenarios([], cfg, struct('quiet', true, 'scenarios', {{sDef}}));
        
        fprintf('\n--------------------------------------------------------------------------------------------------------\n');
        fprintf('Bus: %-8s | Fault: %-5s | Fault Current (Fault Point): %9.2f A\n', ...
            bus, ft, anaRes.faultCurrentMagnitude_A);
        fprintf('--------------------------------------------------------------------------------------------------------\n');
        fprintf('RELAY RESULTS from runIntegratedFaultStudy:\n');
        fprintf('  %-14s | %-12s | %-12s | %-10s | %-12s | %-8s\n', ...
            'Relay ID', 'I_pri (A)', 'I_sec (A)', 'Multiple M', 't_op (s)', 'Operates');
        for r = 1:numel(anaRes.relayResults)
            rr = anaRes.relayResults(r);
            fprintf('  %-14s | %12.4f | %12.4f | %10.4f | %12.4f | %-8s\n', ...
                rr.relayId, rr.faultCurrentPrimary_A, rr.relayCurrentSecondary_A, ...
                rr.pickupRatio, rr.operatingTime_s, mat2str(rr.operates));
        end
        
        fprintf('\nRELAY EVALUATIONS from evaluateRadialProtectionScenarios:\n');
        fprintf('  %-14s | %-12s | %-12s | %-10s | %-12s | %-10s | %-15s\n', ...
            'Relay ID', 'I_pri (A)', 'I_sec (A)', 'Multiple M', 't_op (s)', 'TripStatus', 'Role');
        evalRows = evalStudy.relayTable(strcmp(evalStudy.relayTable.scenarioId, scn.id), :);
        for rowIdx = 1:height(evalRows)
            er = evalRows(rowIdx, :);
            fprintf('  %-14s | %12.4f | %12.4f | %10.4f | %12.4f | %-10s | %-15s\n', ...
                er.relayId{1}, er.I_primary_A, er.I_secondary_A, ...
                er.multiple_M, er.operatingTime_s, er.tripStatus{1}, er.role{1});
        end
    end
end
fprintf('\n========================================================================================================\n');
