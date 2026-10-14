% scripts/run_minimal_circuit_prototype.m
% Reproducible entry-point script for Simscape Electrical minimal circuit prototype.
%
% This script:
%   1. Runs the capability diagnostic (auditing products, licenses, and components).
%   2. Validates prerequisites.
%   3. Builds or loads the minimal circuit prototype model.
%   4. Executes the simulation in Simulink using ode23t.
%   5. Extracts actual physical measurements (voltages, currents, RMS).
%   6. Emits structured diagnostics and summary results.

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir)
    thisDir = pwd;
end
projectRoot = fullfile(thisDir, '..');
addpath(genpath(fullfile(projectRoot, 'matlab')));
addpath(genpath(fullfile(projectRoot, 'scripts')));

fprintf('============================================================\n');
fprintf(' EXECUTING SIMSCAPE ELECTRICAL MINIMAL CIRCUIT PROTOTYPE\n');
fprintf('============================================================\n');

% Run the prototype entry-point
options = struct('quiet', false, 'stopTime_s', 0.04);
result = runMinimalCircuitPrototype(options);

% Check execution status
if strcmp(result.status, 'SIMULATION_COMPLETED') && result.isSimulated
    fprintf('\n>>> SUCCESS: Physical simulation completed with genuine measurements.\n');
    fprintf('>>> Model path: %s\n', result.modelPath);
    fprintf('>>> Provenance: %s (%s)\n', result.provenance.source, result.provenance.timestamp);
else
    fprintf('\n>>> FAILED/BLOCKED: Simulation did not complete normally.\n');
    fprintf('>>> Status: %s\n', result.status);
end
