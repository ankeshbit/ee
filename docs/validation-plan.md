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
5. **Simulation validation:** Run the same cases in Simulink and extract measurements at matching buses, phases, and timestamps.
6. **Cross-engine comparison:** Compare corresponding phasors, RMS values, fault currents, voltages, relay pickup/operate times, and breaker events.

## Comparison Method

Each comparison must identify the case, parameter source, units, solver settings, sample or event alignment method, and result provenance. Steady-state or phasor quantities should be compared separately from transient waveform quantities. Event timing should use a documented threshold or event-detection method.

For each quantity, report absolute error and a normalized relative error where the reference magnitude is nonzero. Near-zero reference values require an absolute tolerance or a documented floor to avoid unstable relative-error percentages.

## Tolerances and Acceptance

Tolerances must be approved per quantity and study type before results are assessed. They should account for numerical precision, solver settings, discretization, initialization, measurement filtering, and model simplifications. A result passes only when it is within the applicable tolerance and the underlying assumptions are satisfied.

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
