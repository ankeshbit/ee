# Validation Plan

## Purpose

Validation will establish whether analytical calculations and Simulink/Simscape Electrical simulations agree for explicitly defined study cases. No validation is claimed at repository initialization.

## Validation Stages

1. **Environment validation:** Record MATLAB release, operating system, and available toolbox licenses.
2. **Configuration validation:** Check network topology, units, base values, transformer data, and protection settings before a study runs.
3. **Unit validation:** Test individual conversions, voltage-base and
   per-unit impedance conversions, transformer configuration and
   zero-sequence rules, sequence-network operations, CT conversion, relay
   operating-time equations, coordination checks, and result-shaping helpers
   against independently calculated examples.
4. **Analytical study validation:** Run approved fault cases with known expected relationships and documented reference values.
   The integrated radial reference case independently checks source-plus-path
   sequence impedance, per-unit-to-ampere conversion, relay path selection,
   and coordination output across multiple buses and fault types.
5. **Simulation validation:** Run identical fault scenarios in Simscape Electrical,
   enforcing the license gate via `checkSimulationCapabilities`. When licensed, extract
   measurements using `validateMeasurementWindow`, `extractSimulationRMS`, and `estimateFundamentalPhasor`.
6. **Cross-engine comparison:** Evaluate simulation measurements against analytical benchmark
   quantities via `compareAnalyticalAndSimulation`, checking voltage bases, units, absolute error,
   and relative percentage error.

## Comparison Method

Each comparison must identify the case, parameter source, units, solver settings, sample or event alignment method, and result provenance. Steady-state or phasor quantities should be compared separately from transient waveform quantities. Event timing should use a documented threshold or event-detection method.

`compareAnalyticalAndSimulation` enforces:
- Valid measurement window over integer steady-state cycles (excluding the subtransient inception cycle).
- Rejection of cross-transformer comparisons where voltage/current bases differ without explicit conversion (`INCOMPATIBLE_BASIS`).
- Clean skipping of unexecuted or blocked simulations (`SKIPPED`).
- Relative error computation for nonzero references: $\text{Pct Err} = 100 \times |X_{\text{sim}} - X_{\text{ana}}| / |X_{\text{ana}}|$.
- Absolute error computation: $\text{Abs Err} = |X_{\text{sim}} - X_{\text{ana}}|$.

## Tolerances and Acceptance

Standard approved comparison tolerances:
- **Steady-state fault current RMS magnitude:** Relative tolerance $\le 5.0\%$, absolute tolerance $0.01\,\text{A}$.
- **Prefault voltage RMS magnitude:** Relative tolerance $\le 2.0\%$, absolute tolerance $1.0\,\text{V}$.
- **Fundamental complex phasor angle:** Absolute angle tolerance $\le 2.0^\circ$.

Failures must record the case identifier, expected and observed values, error, tolerance, environment, and likely cause. Tolerance changes require an engineering rationale and a documentation update; they must not be used to conceal model or calculation defects.

Coordination validation uses independently calculated secondary currents and
IEC operating times. A pair is coordinated only when both relays operate and
the scenario-specific `t_backup - t_primary` meets the configured minimum CTI.
Non-operating relays are reported as non-coordinated rather than being treated
as evidence of selectivity.

The integrated study engine is an analytical, illustrative radial model. Passing
unit or integration tests verifies software behavior against stated equations;
it does not validate any real network, transformer data, protection setting, or
selectivity claim.

The transformer reference case checks the independently calculated 33 kV and
11 kV bases, common 10 MVA base, source-plus-transformer-plus-branch sequence
impedance, fault-current conversion at the faulted bus voltage, and explicit
rejection of blocked zero-sequence configurations.

The branched radial reference case uses one 33/11 kV transformer followed by
an 11 kV bus with two outgoing feeder branches. Tests check connected
branching, disconnected and multiply connected topology rejection, unique
source-to-fault paths, sibling feeder isolation, explicit transformer
high-side/low-side relay locations, relay-specific current bases, and
coordination using relay-specific operating times. These tests verify the
stated analytical model only; they do not establish protection selectivity,
CT performance, or field deployment suitability.

## Advanced protection-analysis reference cases

Focused tests independently verify zero and positive breaker delays, infinite
clearing time for a non-operating relay, protection-zone reference validation,
forward/reverse/unsupported directional states, CT screening threshold and
missing-data states, sensitivity-study table dimensions, and report filtering
for coordination and non-operating results. These checks validate software
behavior against the documented analytical criteria only; they do not validate
commercial directional elements, CT saturation performance, breaker hardware,
or field protection selectivity.

Breaker-failure tests cover normal primary clearing, primary breaker failure
with successful backup, non-operating or disabled backups, multiple failed
breakers, directional blocking, missing or overlapping zone coverage,
breaker-state handling, CTI versus clearing-time margin, and
sensitivity/report integration. These deterministic analytical checks do not
validate breaker interrupting physics, breaker-failure schemes, commercial
directional protection, or field selectivity.

## Evidence

Store reproducible test inputs and concise generated reports under version control only when appropriate. Large or disposable generated artifacts belong in ignored result locations. Validation status should be reported as not started, passed, failed, or blocked by an explicit environment or assumption issue.
### Phasor and selectivity validation

Focused tests cover sequence reconstruction, faulted-bus voltage sag, all
four fault types, transformer-side bases, off-path unsupported measurements,
zero-sequence blocking, and selectivity-table consumption. These tests validate
the stated radial equivalent only; they do not establish commercial relay
directional behavior or field protection selectivity.

## Phase D: Physical Multi-Fault Simulation Validation

### Acceptance Criteria and Tolerance Limits
For each supported physical fault mode in the 33/11 kV radial network (`radial_fault_study_network.slx`), physical simulations must satisfy:
1. **Convergence and Finiteness:**
   Waveforms must be finite and time vectors strictly monotonic across the entire duration.
2. **Timing Activation:**
   Pre-fault window ($t < 0.05\,\text{s}$) currents must remain within healthy load limits ($< 100\,\text{A}$). Following fault inception ($t > 0.05\,\text{s}$), currents must rise to their expected fault envelope.
3. **Fundamental AC RMS Extraction:**
   Fundamental-frequency phasors are estimated using orthogonal Fourier projection over an integer steady-state window ($t = 0.07$ to $0.15\,\text{s}$), completely separating steady-state AC from decaying DC offset.
4. **Sequence Component Verification:**
   - **3PH:** Positive sequence $I_1$ must match analytical within $0.5\%$; $I_0 < 1.0\,\text{A}$, $I_2 < 50.0\,\text{A}$.
   - **SLG (AG):** Symmetrical components $I_0, I_1, I_2$ must be equal and comparable; relative error against sequence calculations including load superposition must be $\le 3.0\%$ (unloaded: $\le 0.1\%$).
   - **LL (BC):** Zero-sequence $I_0 < 1.0\,\text{A}$; positive and negative sequence $I_1 \approx I_2$ within $0.5\%$ of analytical benchmark ($1623.38\,\text{A}$ phase fault current).
   - **DLG (BCG):** Symmetrical components $I_0, I_1, I_2$ must all be non-zero; relative error of $I_1$ within $2.5\%$ with load superposition ($< 0.1\%$ unloaded).
   - **Healthy:** Positive-sequence current matches 1 MW load ($52.49\,\text{A}$) within $1.5\%$; $I_0 < 0.5\,\text{A}$, $I_2 < 0.5\,\text{A}$.

