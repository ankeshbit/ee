function validateRadialNetwork(network)
% validateRadialNetwork Validate the supported radial network schema.
% Branch impedances use the common MVA base and each bus voltage base.

if ~isstruct(network) || ~isscalar(network)
    error('validateRadialNetwork:InvalidNetwork', ...
        'network must be a scalar structure.');
end

requiredNetworkFields = {'base', 'sourceBus', 'source', 'buses', 'branches'};
requireFields(network, requiredNetworkFields, 'network');
requireFields(network.base, {'SbaseVA', 'VbaseV'}, 'network.base');
requireFields(network.source, {'Vth_pu', 'Z1_pu', 'Z2_pu', 'Z0_pu'}, ...
    'network.source');

validateattributes(network.base.SbaseVA, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(network.base.VbaseV, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(network.source.Vth_pu, {'numeric'}, ...
    {'scalar', 'finite'});
validateImpedance(network.source.Z1_pu, 'network.source.Z1_pu');
validateImpedance(network.source.Z2_pu, 'network.source.Z2_pu');
validateImpedance(network.source.Z0_pu, 'network.source.Z0_pu');

if ~isstruct(network.buses) || isempty(network.buses)
    error('validateRadialNetwork:InvalidBuses', ...
        'network.buses must be a nonempty structure array.');
end
requireFields(network.buses, {'id', 'VbaseV'}, 'network.buses');
busIds = {network.buses.id};
validateIdentifiers(busIds, 'bus');
if numel(unique(busIds)) ~= numel(busIds)
    error('validateRadialNetwork:DuplicateBusId', ...
        'Bus identifiers must be unique.');
end
if ~any(strcmp(busIds, char(network.sourceBus)))
    error('validateRadialNetwork:UnknownSourceBus', ...
        'network.sourceBus must identify a configured bus.');
end

busVoltages = [network.buses.VbaseV];
if any(~isfinite(busVoltages) | ~isreal(busVoltages) | busVoltages <= 0)
    error('validateRadialNetwork:InvalidVoltageBase', ...
        'Bus voltage bases must be finite, real, and positive.');
end
hasTransformers = isfield(network, 'transformers') && ...
    ~isempty(network.transformers);
if ~hasTransformers && any(abs(busVoltages - network.base.VbaseV) > 0)
    error('validateRadialNetwork:InconsistentVoltageBase', ...
        'Without transformers, all bus voltage bases must equal network.base.VbaseV.');
end

if hasTransformers
    transformerIds = {network.transformers.id};
    if numel(unique(transformerIds)) ~= numel(transformerIds)
        error('validateRadialNetwork:DuplicateTransformerId', ...
            'Transformer identifiers must be unique.');
    end
    allElementIds = [branchIdsFromNetwork(network), transformerIds];
    if numel(unique(allElementIds)) ~= numel(allElementIds)
        error('validateRadialNetwork:DuplicateElementId', ...
            'Branch and transformer identifiers must be unique across the network.');
    end
    for transformerIndex = 1:numel(network.transformers)
        transformer = network.transformers(transformerIndex);
        validateTransformerConfiguration(transformer, busIds);
        if abs(transformer.ratedSbaseVA - network.base.SbaseVA) > ...
                max(1, abs(network.base.SbaseVA)) * 1e-12
            error('validateRadialNetwork:InconsistentSbase', ...
                'Transformer %s ratedSbaseVA must match the network common base.', ...
                transformer.id);
        end
        highBus = network.buses(strcmp(busIds, transformer.highVoltageBus));
        lowBus = network.buses(strcmp(busIds, transformer.lowVoltageBus));
        if abs(highBus.VbaseV - transformer.ratedHighVoltageV) > 0 || ...
                abs(lowBus.VbaseV - transformer.ratedLowVoltageV) > 0
            error('validateRadialNetwork:TransformerVoltageMismatch', ...
                'Transformer %s ratings must match terminal bus bases.', ...
                transformer.id);
        end

    end
end

if ~isstruct(network.branches) || isempty(network.branches)
    error('validateRadialNetwork:InvalidBranches', ...
        'network.branches must be a nonempty structure array.');
end
requiredBranchFields = {'id', 'fromBus', 'toBus', 'Z1_pu', 'Z2_pu', 'Z0_pu'};
requireFields(network.branches, requiredBranchFields, 'network.branches');
branchIds = {network.branches.id};
validateIdentifiers(branchIds, 'branch');
if numel(unique(branchIds)) ~= numel(branchIds)
    error('validateRadialNetwork:DuplicateBranchId', ...
        'Branch identifiers must be unique.');
end

for branchIndex = 1:numel(network.branches)
    branch = network.branches(branchIndex);
    if ~any(strcmp(busIds, char(branch.fromBus))) || ...
            ~any(strcmp(busIds, char(branch.toBus)))
        error('validateRadialNetwork:InvalidBranchEndpoint', ...
            'Branch %s references an unknown bus.', char(branch.id));
    end
    if strcmp(char(branch.fromBus), char(branch.toBus))
        error('validateRadialNetwork:InvalidBranchEndpoint', ...
            'Branch %s cannot connect a bus to itself.', char(branch.id));
    end
    validateImpedance(branch.Z1_pu, 'branch.Z1_pu');
    validateImpedance(branch.Z2_pu, 'branch.Z2_pu');
    validateImpedance(branch.Z0_pu, 'branch.Z0_pu');
end

for busIndex = 1:numel(network.buses)
    busId = char(network.buses(busIndex).id);
    incoming = sum(strcmp({network.branches.toBus}, busId));
    outgoing = sum(strcmp({network.branches.fromBus}, busId));
    if hasTransformers
        incoming = incoming + sum(strcmp({network.transformers.lowVoltageBus}, busId));
        outgoing = outgoing + sum(strcmp({network.transformers.highVoltageBus}, busId));
    end
    if strcmp(busId, char(network.sourceBus))
        if incoming ~= 0
            error('validateRadialNetwork:SourceHasIncomingBranch', ...
                'The source bus cannot have incoming branches.');
        end
    elseif incoming > 1
        error('validateRadialNetwork:NonRadialTopology', ...
            'Each non-source bus must have at most one incoming element.');
    end
end

visited = false(size(network.buses));
sourceIndex = find(strcmp(busIds, char(network.sourceBus)), 1);
visited(sourceIndex) = true;
frontier = sourceIndex;
while ~isempty(frontier)
    busIndex = frontier(1);
    frontier(1) = [];
    busId = busIds{busIndex};
    downstreamBusIds = {network.branches(strcmp({network.branches.fromBus}, ...
        busId)).toBus};
    if hasTransformers
        downstreamBusIds = [downstreamBusIds, ...
            {network.transformers(strcmp({network.transformers.highVoltageBus}, ...
            busId)).lowVoltageBus}]; %#ok<AGROW>
    end
    for downstreamIndex = 1:numel(downstreamBusIds)
        downstreamIndexInNetwork = find(strcmp(busIds, ...
            downstreamBusIds{downstreamIndex}), 1);
        if visited(downstreamIndexInNetwork)
            error('validateRadialNetwork:NonRadialTopology', ...
                'The network contains a cycle or repeated downstream path.');
        end
        visited(downstreamIndexInNetwork) = true;
        frontier(end + 1) = downstreamIndexInNetwork; %#ok<AGROW>
    end
end
if any(~visited)
    error('validateRadialNetwork:DisconnectedNetwork', ...
        'Every configured bus must be connected to the source bus.');
end
end

function requireFields(value, fields, name)
if ~isstruct(value) || isempty(value)
    error('validateRadialNetwork:InvalidFieldContainer', ...
        '%s must be a nonempty structure.', name);
end
for fieldIndex = 1:numel(fields)
    if ~isfield(value, fields{fieldIndex})
        error('validateRadialNetwork:MissingField', ...
            '%s is missing required field %s.', name, fields{fieldIndex});
    end
end
end

function validateIdentifiers(values, name)
if any(~cellfun(@(value) ischar(value) && isrow(value) && ~isempty(value), values))
    error('validateRadialNetwork:InvalidIdentifier', ...
        '%s identifiers must be nonempty character vectors.', name);
end
end

function validateImpedance(value, name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    error('validateRadialNetwork:InvalidImpedance', ...
        '%s must be a finite numeric scalar.', name);
end
end

function ids = branchIdsFromNetwork(network)
if isfield(network, 'branches') && isstruct(network.branches)
    ids = {network.branches.id};
else
    ids = {};
end
end
