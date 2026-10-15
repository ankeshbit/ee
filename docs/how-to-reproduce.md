# How to Reproduce & Execute Study Workflows

This document provides exact, copy-pasteable command-line instructions to rebuild models, execute regression test suites, run complete physical fault studies, and regenerate multi-format reports from scratch.

---

## 1. Environment & Prerequisites

### Supported Platforms
- **Operating Systems:** Windows 10/11, Linux (Ubuntu 20.04+), macOS.
- **MATLAB Release:** MATLAB R2026b (or R2023b through R2026b).
- **Required Toolboxes:**
  - MATLAB
  - Simulink
  - Simscape
  - Simscape Electrical (or Specialized Power Systems / `Power_System_Blocks`)

Verify toolbox licensing by running:
```bash
matlab -batch "ver"
```

---

## 2. Rebuilding the Physical Simscape Models

To rebuild the dynamic Simscape circuit model (`simulink/models/radial_fault_study_network.slx`) directly from the authoritative master configuration ([`matlab/config/getSystemMasterConfiguration.m`](../matlab/config/getSystemMasterConfiguration.m)):

```bash
matlab -batch "addpath(genpath('matlab')); addpath(genpath('scripts')); build_radial_fault_model('simulink/models');"
```

### Expected Output:
```text
Building radial fault network model in simulink/models...
  Source: 33 kV, 500 MVAsc (X/R = 10)
  Transformer: 10 MVA, 33/11 kV (Z = 0.08 pu)
  Feeders: Feeder 1 (10 km), Feeder 2 (5 km)
  Relays: Primary Relay B (CT 400/5, TMS 0.10), Backup Relay A (CT 600/5, TMS 0.25)
  Breakers: CB_BUS_B (50 ms delay), CB_BUS_A (60 ms delay)
Model saved successfully to simulink/models/radial_fault_study_network.slx
```

---

## 3. Running the Complete Automated Test Suite

To run all 243 automated unit and integration tests across analytical and physical engines with non-zero exit code on failure:

```bash
matlab -batch "run('scripts/run_all_tests.m')"
```

### Expected Output Summary:
```text
=================================================================
 RUNNING COMPLETE TEST SUITE
 MATLAB Release: R2026b
 Test Suite Directory: tests
=================================================================

Running TestBranchedRadialFaultStudy ........ Done
Running TestBreakerFailureScenario ....... Done
Running TestDynamicFaultSimulationIntegration [FILTERED] Done
Running TestMinimalCircuitPrototypeIntegration . Done
Running TestNetworkPhasorAnalysis ....... Done
Running TestPhaseFDynamicBreakerSwitching ............ Done
Running TestPhaseGReporting ............ Done
Running TestRadialAllFaultTypesIntegration ......... Done
Running TestRadialFaultSimulationIntegration .. Done
Running TestRadialRelayProtectionIntegration ........ Done
Running TestRunIntegratedFaultStudy ........... Done
Running TestAdvancedProtectionAnalysis ........ Done
Running TestAnalyticalEngineVerification .......... Done
Running TestCalculateBaseValues .. Done
Running TestCalculateDLGFault ... Done
Running TestCalculateLLFault ... Done
Running TestCalculateRelayOperatingTime ................ Done
Running TestCalculateSLGFault ... Done
Running TestCalculateSequenceComponents .... Done
Running TestCalculateThreePhaseFault ... Done
Running TestCheckRelayCoordination ............ Done
Running TestConfigurationConsistency ... Done
Running TestConvertPrimaryToSecondaryCurrent ...... Done
Running TestDynamicSimulationEntryPoint .... Done
Running TestFaultImpedanceConventions ....... Done
Running TestProtectionIndependentValidation ...... Done
Running TestProtectionSelectivityMatrix ... Done
Running TestRadialRelayProtectionConfiguration ....... Done
Running TestSensitivityAnalysis .... Done
Running TestSimscapeComponentVerification ..... Done
Running TestSimulationCapabilityDiagnostic ...... Done
Running TestSimulationContractsAndValidation ............... Done
Running TestSimulationMeasurementProcessing ....... Done
Running TestTextbookIndependentValidation ........ Done
Running TestTransformerNetwork .......... Done

=================================================================
 TEST SUITE SUMMARY
 Total Tests:      243
 Passed:           242
 Failed:           0
 Incomplete/Skip:  1
=================================================================

INCOMPLETE / FILTERED TESTS:
  [SKIP] TestDynamicFaultSimulationIntegration/testPhysicalSimulationExecution

OVERALL RESULT: SUCCESS
```
*(Process exit status: 0)*

---

## 4. Running the Complete Fault Study & Report Generation

To execute all 6 physical and analytical scenarios (`HEALTHY`, `3PH`, `SLG`, `LL`, `DLG`, `3PH_CBF`), generate all 41 publication figures, and export HTML, CSV, MAT, and TXT reports:

```bash
matlab -batch "run('scripts/run_complete_fault_study.m')"
```

### Expected Output Summary:
```text
=================================================================
 AUTOMATED FAULT STUDY & VERIFICATION SUITE
 MATLAB Release: R2026b
=================================================================

1. System Configuration Loaded
2. Physical Simulation Rebuilt & Verified
3. Executing Scenarios:
   - PF_HEALTHY   : Load = 74.97 A, Breakers Closed [PASS]
   - PF_3PH       : Fault = 1884.5 A, Trip = 0.2125 s, Cleared = true [PASS]
   - PF_SLG       : Fault = 1946.0 A, Trip = 0.2114 s, Cleared = true [PASS]
   - PF_LL        : Fault = 1646.1 A, Trip = 0.2290 s, Cleared = true [PASS]
   - PF_DLG       : Fault = 1926.2 A, Trip = 0.2150 s, Cleared = true [PASS]
   - PF_3PH_CBF   : CB_B Stuck Closed -> Backup CB_A Trip = 0.5466 s [PASS]

4. Generating Publication Plots (41 figures saved to results/plots/)
5. Generating Consolidated Reports:
   - results/reports/fault_study_report.html
   - results/reports/fault_study_summary.csv
   - results/reports/fault_study_summary.mat
   - results/reports/fault_study_report.txt

OVERALL VERDICT: PASS (14/14 Acceptance Criteria Passed)
```

---

## 5. Running the Phase F Dynamic Relay Switching Report

To run the dedicated Phase F dynamic relay timing and physical breaker switching report with tightened $\pm 10\,\text{ms}$ acceptance criteria:

```bash
matlab -batch "run('scripts/phase_f_validation_report.m')"
```

### Expected Output Summary:
```text
=================================================================
 PHASE F VALIDATION REPORT
 MATLAB R2026b
=================================================================
1. ENVIRONMENT CHECK: Status READY
2. MODEL REBUILD: Rebuilt successfully
3. RELAY CONFIGURATION: Primary Relay B (CT 400/5, TMS 0.10), Backup Relay A (CT 600/5, TMS 0.25)
4. SCENARIO RESULTS:
   PF_3PH          3PH      TripB=0.2625 s  OpenB=0.3125 s  Cleared=true  [PASS]
   PF_SLG          SLG      TripB=0.2614 s  OpenB=0.3114 s  Cleared=true  [PASS]
   PF_LL           LL       TripB=0.2790 s  OpenB=0.3290 s  Cleared=true  [PASS]
   PF_DLG          DLG      TripB=0.2650 s  OpenB=0.3150 s  Cleared=true  [PASS]
   PF_HEALTHY      HEALTHY  No Trip                         Cleared=false [PASS]
   PF_3PH_CBF      3PH      CB_B Failed     OpenA=0.7366 s  Cleared=true  [PASS]

5. ANALYTICAL vs SIMULATED TIMING CROSS-VALIDATION (±10 ms tolerance):
   3PH       AnaB=0.2146 s  SimB=0.2125 s  Err=-2.1 ms  [PASS]
   SLG       AnaB=0.2124 s  SimB=0.2114 s  Err=-0.9 ms  [PASS]
   LL        AnaB=0.2245 s  SimB=0.2290 s  Err=+4.5 ms  [PASS]
   DLG       AnaB=0.2131 s  SimB=0.2150 s  Err=+2.0 ms  [PASS]

6. CURRENT EXTINCTION: Residual current peak < 0.010 A across all scenarios.
```

---

## 6. Continuous Integration (CI) Behavior

When executing in a headless CI runner (e.g., GitHub Actions) without active Simscape Electrical licenses:
- Pure analytical tests (180+ tests) execute and pass in seconds.
- Dynamic physical simulation integration tests that require `Simscape_Electrical` detect the headless environment via `checkSimulationCapabilities` and filter gracefully with status `[SKIP]`.
- The test runner `scripts/run_all_tests.m` exits with status `0` as long as no test fails.
