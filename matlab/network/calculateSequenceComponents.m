
function seq = calculateSequenceComponents(phasePhasors)
% calculateSequenceComponents Convert phase phasors to sequence components.
% Input:
%   phasePhasors - [Va; Vb; Vc], complex phase-to-neutral phasors.
% Output:
%   seq.V0 - zero-sequence component
%   seq.V1 - positive-sequence component
%   seq.V2 - negative-sequence component

validateattributes(phasePhasors, {'numeric'}, ...
    {'vector', 'numel', 3, 'finite'});

phasePhasors = phasePhasors(:);

a = exp(1i * 2*pi/3);

T = (1/3) * [ ...
    1,   1,   1;
    1,   a,   a^2;
    1,   a^2, a];

components = T * phasePhasors;

seq.V0 = components(1);
seq.V1 = components(2);
seq.V2 = components(3);
end
