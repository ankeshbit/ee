% scripts/run_radial_fault_simulation.m
% Reproducible entry-point script for 33/11 kV Simscape Electrical fault study.
%
% This script executes:
%   Case 1: Healthy steady-state operation of the 33/11 kV radial network.
%   Case 2: Balanced three-phase bolted fault at Bus B.
%
% Compares physical time-domain measurements against analytical sequence-network benchmarks.

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir)
    thisDir = pwd;
end
projectRoot = fullfile(thisDir, '..');
addpath(genpath(fullfile(projectRoot, 'matlab')));
addpath(genpath(fullfile(projectRoot, 'scripts')));

fprintf('====================================================================\n');
fprintf('  33/11 KV RADIAL NETWORK SIMSCAPE ELECTRICAL FAULT STUDY BENCHMARK\n');
fprintf('====================================================================\n\n');

% -------------------------------------------------------------------------
% CASE 1: HEALTHY STEADY STATE
% -------------------------------------------------------------------------
fprintf('>>> RUNNING CASE 1: Healthy Steady-State Operation...\n');
scnHealthy = struct( ...
    'scenarioId', 'SCN_HEALTHY_33_11KV', ...
    'faultType', 'HEALTHY', ...
    'faultedBus', 'BUS_B', ...
    'simulationStopTime_s', 0.08);

resHealthy = runRadialFaultSimulation(scnHealthy, struct('quiet', false));

% -------------------------------------------------------------------------
% CASE 2: THREE-PHASE FAULT AT BUS B
% -------------------------------------------------------------------------
fprintf('\n>>> RUNNING CASE 2: Three-Phase Bolted Fault at Bus B...\n');
scn3PH = struct( ...
    'scenarioId', 'SCN_3PH_BUS_B', ...
    'faultType', '3PH', ...
    'faultedBus', 'BUS_B', ...
    'Zf_Ohm', 0.001, ...
    'faultInsertionTime_s', 0.05, ...
    'simulationStopTime_s', 0.15);

res3PH = runRadialFaultSimulation(scn3PH, struct('quiet', false));

% -------------------------------------------------------------------------
% CROSS-ENGINE VALIDATION BENCHMARK
% -------------------------------------------------------------------------
% Analytical Engine Calculation:
% Base: Sbase = 10 MVA, Vbase,11 = 11 kV -> Ibase,11 = 524.8638 A
% Impedance path: Source (0.10 pu) + Transformer (0.08 pu) + BR_A (0.05 pu) + BR_B (0.05 pu) = 0.28 pu
% Analytical Fault Current: If = 1.0 / 0.28 pu = 3.5714 pu -> If = 1874.51 A RMS
analyticalIf_A = 10e6 / (sqrt(3) * 11e3 * 0.28);
simulatedI1_A = res3PH.phasors.I1_magnitude_A;
absError_A = abs(simulatedI1_A - analyticalIf_A);
relError_pct = 100 * absError_A / analyticalIf_A;

fprintf('====================================================================\n');
fprintf('  CROSS-ENGINE BENCHMARK COMPARISON (ANALYTICAL vs SIMULATION)\n');
fprintf('====================================================================\n');
fprintf(' Faulted Location:                 BUS_B (11 kV Terminal Bus)\n');
fprintf(' Fault Type:                       Three-Phase Bolted (3PH, Zf ~ 0)\n');
fprintf(' Total Sequence Impedance (Zth):   0.28 pu (0.10 src + 0.08 tx + 0.10 line)\n');
fprintf(' Analytical Fault Current (RMS):   %0.2f A\n', analyticalIf_A);
fprintf(' Simscape Fundamental I1 (RMS):    %0.2f A\n', simulatedI1_A);
fprintf(' Absolute Discrepancy:             %0.2f A\n', absError_A);
fprintf(' Percentage Relative Error:        %0.3f %%\n', relError_pct);
fprintf(' Tolerated Acceptance Limit:       1.000 %%\n');
if relError_pct < 1.0
    fprintf(' Verification Outcome:             [PASSED - HIGH FIDELITY AGREEMENT]\n');
else
    fprintf(' Verification Outcome:             [FAILED]\n');
end
fprintf('====================================================================\n\n');
