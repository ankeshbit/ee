function comparison = compareAnalyticalAndSimulation( ...
    analyticalVal, simulationResult, quantityName, locationId, options)
% compareAnalyticalAndSimulation Compare analytical benchmark against dynamic simulation result.
%
% Syntax:
%   comparison = compareAnalyticalAndSimulation(analyticalVal, simulationResult, quantityName, locationId)
%   comparison = compareAnalyticalAndSimulation(analyticalVal, simulationResult, quantityName, locationId, options)
%
% Inputs:
%   analyticalVal    - Expected analytical value (scalar numeric or complex phasor).
%   simulationResult - Simulation result struct conforming to Phase B contract.
%   quantityName     - String naming quantity (e.g. 'faultCurrent_A', 'voltage_V').
%   locationId       - String identifying measurement location (e.g. 'BUS_B').
%   options          - (optional) struct with:
%                      relTolPercent   : Relative error tolerance % (default 5.0)
%                      absTol          : Absolute error tolerance (default 1e-2)
%                      simulatedVal    : Override simulated value extracted manually
%                      analyticalBasis : Struct with SbaseVA, VbaseV
%                      simulatedBasis  : Struct with SbaseVA, VbaseV
%                      units           : Unit string (default 'A' or 'V')
%
% Outputs:
%   comparison       - Struct containing:
%                      quantityName
%                      locationId
%                      units
%                      analyticalValue
%                      simulatedValue
%                      absoluteError
%                      percentageError
%                      relTolPercent
%                      absTol
%                      status          : 'PASSED', 'FAILED', 'BLOCKED',
%                                        'INCOMPATIBLE_BASIS', 'INVALID_MEASUREMENT', 'SKIPPED'
%                      explanation     : Informative diagnosis text

    if nargin < 4
        error('compareAnalyticalAndSimulation:NotEnoughInputs', ...
            'analyticalVal, simulationResult, quantityName, and locationId are required.');
    end
    if nargin < 5 || isempty(options)
        options = struct();
    end
    if ~isstruct(options) || ~isscalar(options)
        error('compareAnalyticalAndSimulation:InvalidOptions', 'options must be a scalar struct.');
    end

    % Validate tolerances
    relTolPercent = 5.0;
    if isfield(options, 'relTolPercent') && ~isempty(options.relTolPercent)
        val = options.relTolPercent;
        if ~isnumeric(val) || ~isscalar(val) || ~isreal(val) || ~isfinite(val) || val < 0
            error('compareAnalyticalAndSimulation:InvalidTolerance', ...
                'relTolPercent must be a finite, real, non-negative scalar.');
        end
        relTolPercent = double(val);
    end

    absTol = 1e-2;
    if isfield(options, 'absTol') && ~isempty(options.absTol)
        val = options.absTol;
        if ~isnumeric(val) || ~isscalar(val) || ~isreal(val) || ~isfinite(val) || val < 0
            error('compareAnalyticalAndSimulation:InvalidTolerance', ...
                'absTol must be a finite, real, non-negative scalar.');
        end
        absTol = double(val);
    end

    units = 'A';
    if isfield(options, 'units') && ~isempty(options.units)
        units = char(options.units);
    end

    comparison = struct();
    comparison.quantityName = char(quantityName);
    comparison.locationId = char(locationId);
    comparison.units = units;
    comparison.analyticalValue = analyticalVal;
    comparison.simulatedValue = NaN;
    comparison.absoluteError = NaN;
    comparison.percentageError = NaN;
    comparison.relTolPercent = relTolPercent;
    comparison.absTol = absTol;
    comparison.status = 'SKIPPED';
    comparison.explanation = '';

    % 1. Validate analyticalVal
    if isempty(analyticalVal) || ~isnumeric(analyticalVal) || ~isscalar(analyticalVal) || ...
       any(~isfinite(analyticalVal))
        comparison.status = 'INVALID_MEASUREMENT';
        comparison.explanation = 'Analytical value must be a non-empty, finite numeric scalar.';
        return;
    end

    % 2. Check simulationResult structure and status
    if isempty(simulationResult) || ~isstruct(simulationResult) || ~isfield(simulationResult, 'status')
        comparison.status = 'SKIPPED';
        comparison.explanation = 'No valid simulation result provided.';
        return;
    end

    simStatus = upper(strtrim(char(simulationResult.status)));

    if strcmp(simStatus, 'BLOCKED')
        comparison.status = 'BLOCKED';
        comparison.explanation = sprintf( ...
            'Simulation was blocked by environment prerequisites (status: %s). Dynamic comparison skipped.', simStatus);
        return;
    end

    if strcmp(simStatus, 'NOT_RUN') || strcmp(simStatus, 'SKIPPED')
        comparison.status = 'SKIPPED';
        comparison.explanation = sprintf( ...
            'Simulation was not executed (status: %s). Dynamic comparison skipped.', simStatus);
        return;
    end

    if strcmp(simStatus, 'BUILD_FAILED') || strcmp(simStatus, 'SIMULATION_FAILED') || strcmp(simStatus, 'FAILED')
        comparison.status = 'FAILED';
        comparison.explanation = sprintf( ...
            'Simulation execution failed (status: %s). Dynamic comparison cannot be evaluated.', simStatus);
        return;
    end

    if strcmp(simStatus, 'MEASUREMENTS_INVALID')
        comparison.status = 'INVALID_MEASUREMENT';
        comparison.explanation = 'Simulation measurements were flagged as invalid.';
        return;
    end

    if isfield(simulationResult, 'isValidMeasurementWindow') && ~simulationResult.isValidMeasurementWindow
        comparison.status = 'INVALID_MEASUREMENT';
        comparison.explanation = 'Simulation completed but measurement window was invalid or incomplete.';
        return;
    end

    % 3. Check basis compatibility
    if isfield(options, 'analyticalBasis') && isfield(options, 'simulatedBasis') && ...
       isstruct(options.analyticalBasis) && isstruct(options.simulatedBasis)
        aBase = options.analyticalBasis;
        sBase = options.simulatedBasis;
        if isfield(aBase, 'VbaseV') && isfield(sBase, 'VbaseV') && ...
           isnumeric(aBase.VbaseV) && isnumeric(sBase.VbaseV) && ...
           abs(aBase.VbaseV - sBase.VbaseV) > 1e-3
            comparison.status = 'INCOMPATIBLE_BASIS';
            comparison.explanation = sprintf( ...
                'Incompatible voltage bases across transformer side: Analytical base is %g V, simulated base is %g V.', ...
                aBase.VbaseV, sBase.VbaseV);
            return;
        end
        if isfield(aBase, 'SbaseVA') && isfield(sBase, 'SbaseVA') && ...
           isnumeric(aBase.SbaseVA) && isnumeric(sBase.SbaseVA) && ...
           abs(aBase.SbaseVA - sBase.SbaseVA) > 1e-3
            comparison.status = 'INCOMPATIBLE_BASIS';
            comparison.explanation = sprintf( ...
                'Incompatible power bases: Analytical power base is %g VA, simulated power base is %g VA.', ...
                aBase.SbaseVA, sBase.SbaseVA);
            return;
        end
    end

    % 4. Extract simulated value
    simVal = NaN;
    if isfield(options, 'simulatedVal') && ~isempty(options.simulatedVal)
        simVal = options.simulatedVal;
    elseif isfield(simulationResult, 'rms') && isstruct(simulationResult.rms) && isfield(simulationResult.rms, locationId)
        simVal = simulationResult.rms.(locationId);
    elseif isfield(simulationResult, 'measurements') && isstruct(simulationResult.measurements) && isfield(simulationResult.measurements, locationId)
        simVal = simulationResult.measurements.(locationId);
    elseif isfield(simulationResult, 'phasors') && isstruct(simulationResult.phasors) && isfield(simulationResult.phasors, locationId)
        simVal = simulationResult.phasors.(locationId);
    end

    if isempty(simVal) || ~isnumeric(simVal) || ~isscalar(simVal) || any(~isfinite(simVal))
        comparison.status = 'INVALID_MEASUREMENT';
        comparison.explanation = sprintf( ...
            'No valid finite measurement found for location "%s" in simulation result.', locationId);
        return;
    end

    comparison.simulatedValue = simVal;

    % 5. Compute errors (handles both scalar real and complex numbers via abs())
    absErr = abs(simVal - analyticalVal);
    comparison.absoluteError = absErr;

    if abs(analyticalVal) > eps
        pctErr = 100 * (absErr / abs(analyticalVal));
        comparison.percentageError = pctErr;
    else
        pctErr = NaN;
        comparison.percentageError = NaN;
    end

    % 6. Determine pass / fail
    isWithinAbs = (absErr <= absTol);
    if isnan(pctErr)
        isMatch = isWithinAbs;
    else
        isMatch = isWithinAbs || (pctErr <= relTolPercent);
    end

    if isMatch
        comparison.status = 'PASSED';
        comparison.explanation = sprintf( ...
            'Agreement satisfied within tolerance (Abs Err: %0.4g %s, Pct Err: %0.2f%%).', ...
            absErr, units, comparison.percentageError);
    else
        comparison.status = 'FAILED';
        comparison.explanation = sprintf( ...
            'Discrepancy exceeds tolerance (Abs Err: %0.4g %s > tol %0.4g, Pct Err: %0.2f%% > tol %0.2f%%).', ...
            absErr, units, absTol, comparison.percentageError, relTolPercent);
    end
end
