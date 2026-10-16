function status = computeOverallCoordinationStatus(coordinationResults)
% computeOverallCoordinationStatus Compute overall coordination status across relay pairs.
%
% Handles isCoordinated = NaN gracefully for non-applicable pairs.
%
% Return values:
%   'NOT_APPLICABLE' - When there are no pairs or only non-applicable pairs
%   'COORDINATED'    - When at least one applicable pair exists and all applicable pairs pass (isCoordinated == 1)
%   'MISCOORDINATED' - When one or more applicable pairs fail (isCoordinated == 0)

    if nargin < 1 || isempty(coordinationResults)
        status = 'NOT_APPLICABLE';
        return;
    end

    if istable(coordinationResults)
        if height(coordinationResults) == 0
            status = 'NOT_APPLICABLE';
            return;
        end
        if ismember('isApplicable', coordinationResults.Properties.VariableNames)
            app = coordinationResults(coordinationResults.isApplicable, :);
        elseif ismember('isCoordinated', coordinationResults.Properties.VariableNames)
            app = coordinationResults(~isnan(coordinationResults.isCoordinated), :);
        else
            status = 'NOT_APPLICABLE';
            return;
        end

        if height(app) == 0
            status = 'NOT_APPLICABLE';
        elseif all(app.isCoordinated == 1)
            status = 'COORDINATED';
        else
            status = 'MISCOORDINATED';
        end
        return;
    end

    if isstruct(coordinationResults)
        if isfield(coordinationResults, 'isApplicable')
            appMask = [coordinationResults.isApplicable];
            app = coordinationResults(appMask);
        elseif isfield(coordinationResults, 'isCoordinated')
            coordVals = [coordinationResults.isCoordinated];
            app = coordinationResults(~isnan(coordVals));
        else
            status = 'NOT_APPLICABLE';
            return;
        end

        if isempty(app)
            status = 'NOT_APPLICABLE';
        else
            coordVals = [app.isCoordinated];
            if all(coordVals == 1)
                status = 'COORDINATED';
            else
                status = 'MISCOORDINATED';
            end
        end
        return;
    end

    status = 'NOT_APPLICABLE';
end
