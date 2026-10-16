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
%                      status          : 'PASSED', 'FAILED', 'INCOMPATIBLE_BASIS',
%                                        'INVALID_MEASUREMENT', 'SKIPPED'
%                      explanation     : Informative diagnosis text

    if nargin < 5 || isempty(options)
        options = struct();
    end

    relTolPercent = 5.0;
    if isfield(options, 'relTolPercent') && ~isempty(options.relTolPercent)
        relTolPercent = options.relTolPercent;
    end

    absTol = 1e-2;
    if isfield(options, 'absTol') && ~isempty(options.absTol)
        absTol = options.absTol;
    end

    units = 'A';
    if isfield(options, 'units') && ~isempty(options.units)
        units = options.units;
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

    % 1. Check if simulation was run and completed
    if isempty(simulationResult) || ~isfield(simulationResult, 'status')
        comparison.status = 'SKIPPED';
        comparison.explanation = 'No valid simulation result provided.';
        return;
    end

    simStatus = upper(char(simulationResult.status));

    if strcmp(simStatus, 'BLOCKED') || strcmp(simStatus, 'NOT_RUN')
        comparison.status = 'SKIPPED';
        comparison.explanation = sprintf( ...
            'Simulation was not executed (status: %s). Dynamic comparison skipped.', simStatus);
        return;
    end

    if strcmp(simStatus, 'BUILD_FAILED') || strcmp(simStatus, 'SIMULATION_FAILED')
        comparison.status = 'SKIPPED';
        comparison.explanation = sprintf( ...
            'Simulation execution failed (status: %s). Dynamic comparison skipped.', simStatus);
        return;
    end

    if ~simulationResult.isValidMeasurementWindow
        comparison.status = 'INVALID_MEASUREMENT';
        comparison.explanation = 'Simulation completed but measurement window was invalid or incomplete.';
        return;
    end

    % 2. Check basis compatibility
    if isfield(options, 'analyticalBasis') && isfield(options, 'simulatedBasis')
        aBase = options.analyticalBasis;
        sBase = options.simulatedBasis;
        if isfield(aBase, 'VbaseV') && isfield(sBase, 'VbaseV') && abs(aBase.VbaseV - sBase.VbaseV) > 1e-3
            comparison.status = 'INCOMPATIBLE_BASIS';
            comparison.explanation = sprintf( ...
                'Incompatible voltage bases across transformer side: Analytical base is %g V, simulated base is %g V.', ...
                aBase.VbaseV, sBase.VbaseV);
            return;
        end
    end

    % 3. Extract simulated value
    simVal = NaN;
    if isfield(options, 'simulatedVal') && ~isempty(options.simulatedVal)
        simVal = options.simulatedVal;
    elseif isfield(simulationResult, 'rms') && isfield(simulationResult.rms, locationId)
        simVal = simulationResult.rms.(locationId);
    elseif isfield(simulationResult, 'measurements') && isfield(simulationResult.measurements, locationId)
        simVal = simulationResult.measurements.(locationId);
    end

    if isempty(simVal) || any(isnan(simVal))
        comparison.status = 'INVALID_MEASUREMENT';
        comparison.explanation = sprintf( ...
            'No valid measurement found for location "%s" in simulation result.', locationId);
        return;
    end

    comparison.simulatedValue = simVal;

    % 4. Compute errors
    absErr = abs(simVal - analyticalVal);
    comparison.absoluteError = absErr;

    if abs(analyticalVal) > eps
        pctErr = 100 * (absErr / abs(analyticalVal));
        comparison.percentageError = pctErr;
    else
        comparison.percentageError = NaN;
    end

    % 5. Determine pass / fail
    isWithinAbs = (absErr <= absTol);
    if isnan(comparison.percentageError)
        isMatch = isWithinAbs;
    else
        isMatch = isWithinAbs || (comparison.percentageError <= relTolPercent);
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
