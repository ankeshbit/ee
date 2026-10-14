# Setup & Environment Guide

This guide covers MATLAB environment checks, capability diagnostics, test suite execution, and licensing troubleshooting.

---

## 1. Check the MATLAB Release & Installed Products

Open MATLAB and run:

```matlab
version
ver
```

Verify that the following toolboxes are listed in `ver`:
- **MATLAB**
- **Simulink**
- **Simscape**
- **Simscape Electrical**

---

## 2. Check License Availability

Run explicit license tests:

```matlab
disp(['Simulink:            ', num2str(license('test', 'Simulink'))]);
disp(['Simscape:            ', num2str(license('test', 'Simscape'))]);
disp(['Simscape Electrical: ', num2str(license('test', 'Simscape_Electrical'))]);
disp(['Power System Blocks: ', num2str(license('test', 'Power_System_Blocks'))]);
```

- A return value of `1` indicates that a valid license feature is detected.
- **Licensing Finding:** In MATLAB R2026b environments where `Simscape_Electrical` feature token test returns `0` (error `-5.2`), `Power_System_Blocks` returns `1`. Simulink automatically checks out `power_system_blocks` during model compilation and time-domain execution of `ee_lib` models, enabling physical simulation to run successfully.

---

## 3. Run Integration Capability Diagnostic & Component Verification

### A. Capability Diagnostic
Execute the automated capability diagnostic function:

```matlab
addpath(genpath('matlab'));
diagnostic = checkSimulationCapabilities();
```

The diagnostic prints an audit report and returns a structured record with overall status (`READY` when `Power_System_Blocks` is verified).

### B. Component Verification
Verify exact library block paths, parameter read/write configurability, and test-model instantiation:

```matlab
compReport = verifySimscapeComponents();
```

Returns a structured report covering 15 components across `ee_lib` and `nesl_utility`.

---

## 4. Run the Minimal Circuit Prototype

Execute the verified three-phase physical circuit prototype (`simulink/models/minimal_circuit_prototype.slx`):

```matlab
addpath(genpath('matlab'));
result = runMinimalCircuitPrototype();
```

Or execute the standalone script:

```matlab
run('scripts/run_minimal_circuit_prototype.m');
```

To programmatically reconstruct the `.slx` model from scratch:

```matlab
run('scripts/build_minimal_circuit_prototype.m');
```

---

## 5. Run the 33/11 kV Radial Fault Study Simulation

Execute the validated 33/11 kV power system fault study model (`simulink/models/radial_fault_study_network.slx`):

```matlab
addpath(genpath('matlab'));
addpath(genpath('scripts'));

% Run healthy and 3-phase fault benchmark
run('scripts/run_radial_fault_simulation.m');
```

Or run via MATLAB API:

```matlab
% Healthy case
resHealthy = runRadialFaultSimulation(struct('faultType', 'HEALTHY'));

% Three-phase bolted fault at Bus B
res3PH = runRadialFaultSimulation(struct('faultType', '3PH', 'faultedBus', 'BUS_B', 'Zf_Ohm', 0.001));
```

To programmatically reconstruct the model from scratch:

```matlab
run('scripts/build_radial_fault_model.m');
```

---

## 6. Run the Analytical Engine & Studies

To run analytical fault studies:

```matlab
addpath(genpath('matlab'));

% Load illustrative networks
netRadial = createIllustrativeRadialNetwork();
netXfmr = createIllustrativeTransformerRadialNetwork();

% Run integrated fault study
scenarios = struct('id', 'SCN1', 'faultedBus', 'BUS_B', 'faultType', '3PH', 'Zf_pu', 0.05);
relays = struct('id', 'R1', 'measurementElementType', 'branch', 'measurementElementId', 'BR_B', ...
    'measurementSide', 'from', 'curveType', 'SI', 'pickupCurrent_A', 2.5, 'TMS', 0.1, ...
    'CTprimary_A', 400, 'CTsecondary_A', 5);
coordinationPairs = struct('primaryRelayId', 'R1', 'backupRelayId', '', 'minimumCTI_s', 0.3);

studyResults = runIntegratedFaultStudy(netRadial, scenarios, relays, coordinationPairs);
```

---

## 7. Validate Dynamic Simulation Inputs

Validate a prospective dynamic simulation configuration before running:

```matlab
scenario = struct('scenarioId', 'SCN_3PH', 'faultedBus', 'BUS_B', 'faultType', '3PH', 'Zf_pu', 0.05);
validConfig = validateSimulationInput(netRadial, scenario);
```

---

## 8. Run the Test Suites

### Run All Unit Tests
All analytical and simulation infrastructure unit tests run without requiring Simscape Electrical:

```matlab
addpath(genpath('matlab'));
addpath(genpath('tests'));

suiteUnit = testsuite('tests/unit');
runner = matlab.unittest.TestRunner.withTextOutput('Verbosity', 1);
resultsUnit = runner.run(suiteUnit);
```

### Run Integration Tests
Integration tests cleanly check for environment prerequisites:

```matlab
suiteInt = testsuite('tests/integration');
resultsInt = runner.run(suiteInt);
```

If the `Simscape_Electrical` license is unavailable, the physical simulation integration test (`TestDynamicFaultSimulationIntegration`) is filtered by assumption (`Incomplete = 1`) rather than falsely passing or failing.

---

## 7. Troubleshooting: `Simscape_Electrical` License Test Returning 0

### Diagnosis
Test explicit checkout to observe the error details:

```matlab
[status, msg] = license('checkout', 'Simscape_Electrical');
disp(['Status: ', num2str(status)]);
disp(['Message: ', msg]);
```

If this returns:
```text
MathWorks Licensing Error 5
Unable to find a license for Simscape_Electrical.
Error Code: -5.2
```
This indicates that the local license file (e.g. `trial_*.lic`) or active MathWorks account license entitlement does not include the `Simscape_Electrical` feature code, even though the software files are installed.

### Resolution Steps
1. **MathWorks Account Entitlement:** Log in to the [MathWorks License Center](https://www.mathworks.com/licensecenter) and confirm that your license number includes "Simscape Electrical".
2. **Update Current Licenses:**
   - In MATLAB, select **Home > Help > Licensing > Update Current Licenses**.
   - Alternatively, select **Activate Software** to re-download the license file containing all authorized toolboxes.
3. **Campus / Student Licenses:** If using an academic institution license, verify that your MathWorks account is associated with the campus-wide license rather than an individual trial.
4. **Trial Extension:** If using a trial, request that your MathWorks representative enable the `Simscape Electrical` add-on on your trial pass.
5. **Verify Resolution:** Re-run `checkSimulationCapabilities()` and confirm status transitions to `READY`.
