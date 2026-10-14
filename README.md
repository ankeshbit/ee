# Power System Fault Analysis & Protection Coordination Simulator

## Overview

This project is a MATLAB, Simulink, and Simscape Electrical workspace for developing a power-system fault-analysis and protection-coordination simulator.

The repository includes:
- **MATLAB Analytical Engine:** Sequence-network calculations for 3PH, SLG, LL, and DLG faults, per-unit base systems, transformer vector group analysis, IEC inverse-time overcurrent relays, and protection coordination matrices.
- **Simscape Electrical Physical Engine:** Native time-domain simulation (`radial_fault_study_network.slx`) modeling a 33/11 kV distribution system with source impedance, Yg/Yg transformer leakage, distribution feeder sections, and configurable physical fault elements.
- **Multi-Fault Validation:** All four power system fault types (3PH, SLG, LL, DLG) and healthy steady state are fully implemented, stabilized against DAE index singularities, and validated against analytical sequence networks with sub-0.15% agreement for balanced and line-to-line faults.
- **Automated Regression Test Suite:** Over 160 unit and integration tests covering analytical, simulation, and protection coordination functions.

## Objectives

- Establish a traceable MATLAB analytical engine for symmetrical-component and fault-study calculations.
- Build a native Simulink/Simscape Electrical simulation engine for physical time-domain studies.
- Compare analytical and simulated results using explicit validation cases and tolerances.
- Provide a maintainable structure for protection behavior and coordination studies.

## Planned Features

- Configurable network and per-unit base definitions.
- Three-phase, single-line-to-ground, line-to-line, and double-line-to-ground fault studies.
- Sequence-network and impedance calculations.
- IEC inverse-time relay operating-characteristic and breaker-behavior studies.
- Ideal CT conversion and primary/backup protection coordination analysis.
- Integrated radial fault studies across multiple buses and fault types.
- Transformer-aware 33 kV/11 kV voltage-base and sequence-impedance modeling.
- Multi-branch radial studies with explicit branch and transformer relay locations.
- Protection zones, breaker clearing-time analysis, CT screening, fault
  sensitivity studies, and structured reports.
- Breaker-failure scenarios and explicit zone-selectivity outcomes.
- Optional sequence/phase phasor results and a protection selectivity matrix.
- Analytical-versus-simulation comparison reports and plots.
- MATLAB unit tests and integration tests.

## Technology Stack

- MATLAB
- Simulink
- Simscape
- Simscape Electrical
- Git

## Folder Structure

```text
power-system-fault-analysis-simulator/
├── docs/                 # Assumptions, architecture, validation, and setup guidance
├── matlab/               # Future MATLAB analytical and reporting code
├── simulink/             # Future Simulink and Simscape Electrical assets
├── tests/                # Unit and integration tests
├── results/              # Generated plots and reports
└── scripts/              # Setup and test utilities
```

See the individual directory documentation for the intended scope of each area.

## Prerequisites

Before development, verify access to a supported MATLAB release and the required Simulink, Simscape, and Simscape Electrical products. Product availability and licensing must be checked locally; this repository does not assume that any toolbox is installed.

Review [docs/setup-guide.md](docs/setup-guide.md) before adding implementation files.

## Setup

1. Clone or open the repository in a local workspace.
2. Open MATLAB and run the environment checks described in [docs/setup-guide.md](docs/setup-guide.md).
3. Review and complete the checklist in [docs/assumptions.md](docs/assumptions.md).
4. Agree on the validation cases and tolerances in [docs/validation-plan.md](docs/validation-plan.md).
5. Add implementation and tests incrementally while preserving the separation described in [docs/system-architecture.md](docs/system-architecture.md).

## Development Status

**Phase G Complete: Automated Fault Study, Visualization, Validation & Reporting.**
- **Unified Automated Fault Study:** Single reproducible entry point [`scripts/run_complete_fault_study.m`](scripts/run_complete_fault_study.m) executes all 6 physical Simscape Electrical scenarios (HEALTHY, 3PH, SLG, LL, DLG, 3PH_CBF) alongside analytical sequence networks.
- **Dynamic Relays & Breakers:** Real-time physical breaker switching, IEC Standard Inverse overcurrent relays, trip commands, and fault-current extinction verification ($I_{\text{post}} < 0.010\,\text{A}$).
- **Cross-Validation Accuracy:** Dynamic relay operating times match analytical IEC predictions within $\pm 4.5\,\text{ms}$ across all fault types (acceptance limit $\pm 20\,\text{ms}$).
- **Publication-Quality Visualizations ([results/plots/](results/plots/)):** 41 generated figures (both `.png` and editable `.fig`):
  - Phase currents with fault inception, relay trip, and breaker opening markers
  - Bus A and Bus B three-phase voltage waveforms
  - Relay timer accumulator ($\sigma_B$) and breaker contact states
  - Grouped bar chart comparing analytical vs simulated currents with error percentage
  - Relay timing error bar chart with $\pm 20\,\text{ms}$ tolerance band
- **Consolidated Multi-Format Reports ([results/reports/](results/reports/)):**
  - Interactive HTML report ([`fault_study_report.html`](results/reports/fault_study_report.html))
  - Machine-readable CSV summary ([`fault_study_summary.csv`](results/reports/fault_study_summary.csv))
  - Full MAT result structure ([`fault_study_summary.mat`](results/reports/fault_study_summary.mat))
  - Text summary report ([`fault_study_report.txt`](results/reports/fault_study_report.txt))
- **Acceptance Criteria:** 14 out of 14 checks passed, 100% overall pass.

## Running the Complete Fault Study

In MATLAB:
```matlab
% Execute complete fault study (both analytical and physical Simscape runs)
study = run_complete_fault_study();

% Options:
opts.skipSimulation  = false; % set to true for fast analytical-only execution
opts.quiet           = false; % display progress to console
opts.generatePlots   = true;  % export figures to results/plots/
opts.generateReports = true;  % generate HTML, CSV, MAT, TXT reports
study = run_complete_fault_study(opts);
```

## Running Regression Tests

To run the complete Phase G verification suite (including full Phase D and Phase F regressions):
```matlab
addpath(genpath('matlab'));
addpath(genpath('scripts'));
addpath(genpath('tests'));

results = runtests('tests/integration/TestPhaseGReporting.m');
table(results)
```

## Comparison Metrics & Conventions

- **Current Comparison Basis:**
  - Analytical values represent symmetrical positive-sequence fault current magnitudes ($|I_1| \times I_{\text{base}}$).
  - Simulated values represent the maximum phase RMS line current sensed by the physical CTs ($I_{\max}$).
  - For balanced faults (3PH), both metrics coincide ($< 0.7\%$ difference). For asymmetric faults (SLG, LL, DLG), the phase element senses the faulted phase line current ($I_{\max} > I_1$).
- **Relay Timing Error:**
  - Computed as $\Delta t = (t_{\text{simulated trip}} - t_{\text{fault inception}}) - t_{\text{analytical IEC}}$.
  - Acceptance threshold: $|\Delta t| \le 20\,\text{ms}$. Actual observed error: $\le 4.5\,\text{ms}$.
- **Coordination Time Interval (CTI) vs. Clearing-Time Margin:**
  - $\text{CTI} = t_{\text{backup relay}} - t_{\text{primary relay}}$ ($0.4044\,\text{s} \ge 0.250\,\text{s}$).
  - $\text{Clearing Margin} = t_{\text{backup relay}} - (t_{\text{primary relay}} + t_{\text{breaker delay}})$ ($0.3544\,\text{s} \ge 0.200\,\text{s}$).

## Known Limitations

- **Directional Supervision:** Directional decisions are evaluated analytically via phasor angles; dynamic directional blocks are not active in the physical Simulink model.
- **Breaker-Failure Scenario Scope:** Dynamic breaker failure (CB_BUS_B stuck closed with backup clearing by CB_BUS_A) is validated dynamically for 3PH fault (`PF_3PH_CBF`). Other fault types use analytical clearing estimates.
- **Circuit Breaker Model:** Breakers are modeled with physical transition resistance without arc reignition or TRV physics.
