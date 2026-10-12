# Engineering Assumptions Checklist

This checklist identifies decisions that must be verified and recorded before engineering implementation. Items are intentionally unconfirmed at repository initialization.

## Network and Per-Unit System

- [ ] Confirm system frequency and nominal phase-to-phase voltage levels.
- [ ] Define and approve the system MVA base and voltage bases by voltage level.
- [ ] Define how current and impedance bases are derived and converted.
- [ ] Define the reference bus, phase sequence, and angle convention.
- [ ] Confirm whether network data is entered in physical units, per-unit values, or both.
- [ ] Define data precision, rounding, and significant-figure conventions.

## Sequence Networks and Fault Studies

- [ ] Verify positive-, negative-, and zero-sequence impedances for each network element.
- [ ] Confirm mutual coupling assumptions and whether they are neglected.
- [ ] Confirm source grounding and zero-sequence return-path assumptions.
- [ ] Define the fault impedance model and any prefault voltage assumptions.
- [ ] Define the fault types and fault-location representation to be supported.

## Transformers

- [ ] Verify transformer ratings, impedance bases, and tap settings.
- [ ] Confirm winding configuration and grounding (for example, wye, delta, and grounded-neutral details).
- [ ] Confirm zero-sequence transfer behavior through each transformer.
- [ ] Document phase-shift conventions and the reference used for vector groups.
- [ ] Confirm treatment of off-nominal taps and phase-shifting transformers.

## Protection and Switching

- [ ] Verify relay input quantities, CT/VT ratios, polarity, and measurement locations.
- [ ] Define relay equations, characteristic curves, pickup settings, time-dial settings, and units.
- [ ] Define breaker logic, interrupting delay, failure behavior, and reclosing assumptions.
- [ ] Define coordination objectives, grading margins, and selectivity criteria.
- [ ] Identify any vendor-specific behavior that must not be approximated without evidence.

## Software and Simulation Environment

- [ ] Record the MATLAB release used for each validation run.
- [ ] Verify availability and license status for Simulink, Simscape, and Simscape Electrical.
- [ ] Confirm supported model configuration and solver choices.
- [ ] Define simulation stop time, maximum step size, initialization method, and tolerances.
- [ ] Define numerical comparison tolerances for magnitudes, angles, timing, and event ordering.
- [ ] Record all assumptions and deviations in version-controlled documentation.
