function secondaryCurrent_A = convertPrimaryToSecondaryCurrent( ...
    primaryCurrent_A, CTprimary_A, CTsecondary_A)
% convertPrimaryToSecondaryCurrent Convert ideal CT primary current.
% Inputs and output are RMS currents in amperes.
%
% The conversion uses the ideal rated CT ratio:
%   Is = Ip * CTsecondary_A / CTprimary_A
%
% This model does not include CT saturation, burden, phase error, or
% transient response.

validateCurrent(primaryCurrent_A, 'primaryCurrent_A');
validateRating(CTprimary_A, 'CTprimary_A');
validateRating(CTsecondary_A, 'CTsecondary_A');

secondaryCurrent_A = primaryCurrent_A * CTsecondary_A / CTprimary_A;
end

function validateCurrent(value, name)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value < 0
    error('convertPrimaryToSecondaryCurrent:InvalidCurrent', ...
        '%s must be a finite, real, nonnegative numeric scalar.', name);
end
end

function validateRating(value, name)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value <= 0
    error('convertPrimaryToSecondaryCurrent:InvalidCTRating', ...
        '%s must be a finite, real, positive numeric scalar.', name);
end
end
