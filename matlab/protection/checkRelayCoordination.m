function result = checkRelayCoordination( ...
    faultCurrentPrimary_A, primaryRelay, backupRelay, minimumCTI_s)
% checkRelayCoordination Evaluate primary and backup relay coordination.
% faultCurrentPrimary_A is the fault RMS current in primary amperes.
% Relay pickupCurrent_A is the RMS pickup setting on each CT secondary.
% Each relay must contain pickupCurrent_A, TMS, curveType, CTprimary_A,
% and CTsecondary_A.
%
% The coordination interval is:
%   CTI = backup operating time - primary operating time
%
% CTI is calculated only when both relays operate. If either relay does not
% operate, coordinationInterval_s is Inf and isCoordinated is false.

validateFaultCurrent(faultCurrentPrimary_A);
validateRelay(primaryRelay, 'primaryRelay');
validateRelay(backupRelay, 'backupRelay');
validateMinimumCTI(minimumCTI_s);

primarySecondaryCurrent_A = convertPrimaryToSecondaryCurrent( ...
    faultCurrentPrimary_A, primaryRelay.CTprimary_A, ...
    primaryRelay.CTsecondary_A);
backupSecondaryCurrent_A = convertPrimaryToSecondaryCurrent( ...
    faultCurrentPrimary_A, backupRelay.CTprimary_A, ...
    backupRelay.CTsecondary_A);

primaryTime_s = calculateRelayOperatingTime( ...
    primarySecondaryCurrent_A, primaryRelay.pickupCurrent_A, ...
    primaryRelay.TMS, primaryRelay.curveType);
backupTime_s = calculateRelayOperatingTime( ...
    backupSecondaryCurrent_A, backupRelay.pickupCurrent_A, ...
    backupRelay.TMS, backupRelay.curveType);

primaryOperates = isfinite(primaryTime_s);
backupOperates = isfinite(backupTime_s);

if primaryOperates && backupOperates
    coordinationInterval_s = backupTime_s - primaryTime_s;
    isCoordinated = coordinationInterval_s >= minimumCTI_s;
    coordinationStatus = 'Both relays operate';
elseif ~primaryOperates && ~backupOperates
    coordinationInterval_s = Inf;
    isCoordinated = false;
    coordinationStatus = 'Neither relay operates';
elseif ~primaryOperates
    coordinationInterval_s = Inf;
    isCoordinated = false;
    coordinationStatus = 'Primary relay does not operate';
else
    coordinationInterval_s = Inf;
    isCoordinated = false;
    coordinationStatus = 'Backup relay does not operate';
end

result.primarySecondaryCurrent_A = primarySecondaryCurrent_A;
result.backupSecondaryCurrent_A = backupSecondaryCurrent_A;
result.primaryOperatingTime_s = primaryTime_s;
result.backupOperatingTime_s = backupTime_s;
result.coordinationInterval_s = coordinationInterval_s;
result.minimumCTI_s = minimumCTI_s;
result.isCoordinated = isCoordinated;
result.primaryOperates = primaryOperates;
result.backupOperates = backupOperates;
result.coordinationStatus = coordinationStatus;
end

function validateFaultCurrent(value)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value < 0
    error('checkRelayCoordination:InvalidFaultCurrent', ...
        'faultCurrentPrimary_A must be a finite, real, nonnegative numeric scalar.');
end
end

function validateRelay(relay, name)
requiredFields = {'pickupCurrent_A', 'TMS', 'curveType', ...
    'CTprimary_A', 'CTsecondary_A'};

if ~isstruct(relay) || ~isscalar(relay)
    error('checkRelayCoordination:InvalidRelayConfiguration', ...
        '%s must be a scalar structure.', name);
end

for fieldIndex = 1:numel(requiredFields)
    fieldName = requiredFields{fieldIndex};
    if ~isfield(relay, fieldName)
        error('checkRelayCoordination:MissingRelayField', ...
            '%s is missing required field %s.', name, fieldName);
    end
end
end

function validateMinimumCTI(value)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value < 0
    error('checkRelayCoordination:InvalidMinimumCTI', ...
        'minimumCTI_s must be a finite, real, nonnegative numeric scalar.');
end
end
