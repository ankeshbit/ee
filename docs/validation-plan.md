# Validation Plan

## Purpose

Validation will establish whether analytical calculations and Simulink/Simscape Electrical simulations agree for explicitly defined study cases. No validation is claimed at repository initialization.

## Validation Stages

1. **Environment validation:** Record MATLAB release, operating system, and available toolbox licenses.
2. **Configuration validation:** Check network topology, units, base values, transformer data, and protection settings before a study runs.
3. **Unit validation:** Test individual conversions, impedance calculations, sequence-network operations, and result-shaping helpers against independently calculated examples.
4. **Analytical study validation:** Run approved fault cases with known expected relationships and documented reference values.
5. **Simulation validation:** Run the same cases in Simulink and extract measurements at matching buses, phases, and timestamps.
6. **Cross-engine comparison:** Compare corresponding phasors, RMS values, fault currents, voltages, relay pickup/operate times, and breaker events.

## Comparison Method

Each comparison must identify the case, parameter source, units, solver settings, sample or event alignment method, and result provenance. Steady-state or phasor quantities should be compared separately from transient waveform quantities. Event timing should use a documented threshold or event-detection method.

For each quantity, report absolute error and a normalized relative error where the reference magnitude is nonzero. Near-zero reference values require an absolute tolerance or a documented floor to avoid unstable relative-error percentages.

## Tolerances and Acceptance

Tolerances must be approved per quantity and study type before results are assessed. They should account for numerical precision, solver settings, discretization, initialization, measurement filtering, and model simplifications. A result passes only when it is within the applicable tolerance and the underlying assumptions are satisfied.

Failures must record the case identifier, expected and observed values, error, tolerance, environment, and likely cause. Tolerance changes require an engineering rationale and a documentation update; they must not be used to conceal model or calculation defects.

## Evidence

Store reproducible test inputs and concise generated reports under version control only when appropriate. Large or disposable generated artifacts belong in ignored result locations. Validation status should be reported as not started, passed, failed, or blocked by an explicit environment or assumption issue.
