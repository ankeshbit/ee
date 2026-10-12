# Setup Guide

This guide covers Phase 0 environment checks. It does not install MATLAB or any toolbox and does not assume that Simscape Electrical is available.

## Check the MATLAB Release

Open MATLAB and run:

```matlab
version
ver
```

Record the MATLAB release, platform, and update level in the project setup record. Use the project-approved release consistently when comparing results.

## Check Product Availability

Inspect the installed products with:

```matlab
ver
license('inuse')
```

Confirm that the required products are both installed and licensed for the current MATLAB session:

- MATLAB
- Simulink
- Simscape
- Simscape Electrical

The exact product name displayed by `ver` can vary by MATLAB release. If a required product is absent or unavailable, mark the environment as blocked rather than substituting an unverified implementation.

## Check Simulink Access

If Simulink is available, verify that it can be opened in the current environment. Do not create or modify a model as part of the Phase 0 check. Record any startup, licensing, or compatibility errors.

## Repository Setup

Use paths relative to the repository root. Do not hard-code user-specific absolute paths in MATLAB scripts or model callbacks. Before implementation, review [assumptions.md](assumptions.md), [system-architecture.md](system-architecture.md), and [validation-plan.md](validation-plan.md).

## Reporting the Environment

Record:

- MATLAB release and update.
- Operating system and architecture.
- Installed and licensed toolbox status.
- Intended solver and tolerance defaults, once approved.
- Any blocked checks or deviations.

These checks establish environment readiness only; they do not constitute electrical or engineering validation.
