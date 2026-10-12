
function bases = calculateBaseValues(SbaseVA, VbaseV)
% calculateBaseValues Calculate three-phase base quantities.
% SbaseVA: Three-phase apparent power base in VA.
% VbaseV: Line-to-line voltage base in V.

validateattributes(SbaseVA, {'numeric'}, ...
    {'scalar','real','finite','positive'});
validateattributes(VbaseV, {'numeric'}, ...
    {'scalar','real','finite','positive'});

bases.SbaseVA = SbaseVA;
bases.VbaseV = VbaseV;
bases.IbaseA = SbaseVA / (sqrt(3) * VbaseV);
bases.ZbaseOhm = VbaseV^2 / SbaseVA;
end
