function validateProtectionZones(zones, network, relays, breakers)
% validateProtectionZones Validate explicit protection-zone references.

if isempty(zones)
    return;
end
if ~isstruct(zones)
    error('validateProtectionZones:InvalidZones', ...
        'zones must be a structure array.');
end
relayIds = {relays.id};
branchIds = {network.branches.id};
transformerIds = {};
if isfield(network, 'transformers')
    transformerIds = {network.transformers.id};
end
breakerIds = {};
if nargin >= 4 && ~isempty(breakers)
    breakerIds = {breakers.id};
end
zoneIds = {zones.id};
if numel(unique(zoneIds)) ~= numel(zoneIds)
    error('validateProtectionZones:DuplicateZoneId', ...
        'Zone identifiers must be unique.');
end
required = {'id', 'protectedElementType', 'protectedElementId', ...
    'primaryRelayId', 'backupRelayIds', 'minimumCTI_s'};
for index = 1:numel(zones)
    zone = zones(index);
    for fieldIndex = 1:numel(required)
        if ~isfield(zone, required{fieldIndex})
            error('validateProtectionZones:MissingField', ...
                'Zone is missing required field %s.', required{fieldIndex});
        end
    end
    type = lower(strtrim(char(zone.protectedElementType)));
    elementId = char(zone.protectedElementId);
    if strcmp(type, 'branch')
        validElement = any(strcmp(branchIds, elementId));
    elseif strcmp(type, 'transformer')
        validElement = any(strcmp(transformerIds, elementId));
    else
        validElement = false;
    end
    if ~validElement
        error('validateProtectionZones:InvalidElement', ...
            'Zone %s references an unknown protected element.', zone.id);
    end
    if ~any(strcmp(relayIds, zone.primaryRelayId))
        error('validateProtectionZones:InvalidRelayReference', ...
            'Zone %s references an unknown primary relay.', zone.id);
    end
    backupIds = normalizeIds(zone.backupRelayIds);
    if any(~ismember(backupIds, relayIds))
        error('validateProtectionZones:InvalidRelayReference', ...
            'Zone %s references an unknown backup relay.', zone.id);
    end
    if ~isnumeric(zone.minimumCTI_s) || ~isscalar(zone.minimumCTI_s) || ...
            ~isfinite(zone.minimumCTI_s) || zone.minimumCTI_s < 0
        error('validateProtectionZones:InvalidCTI', ...
            'Zone %s minimumCTI_s must be nonnegative and finite.', zone.id);
    end
    if isfield(zone, 'breakerId') && ~isempty(breakerIds) && ...
            ~any(strcmp(breakerIds, zone.breakerId))
        error('validateProtectionZones:InvalidBreakerReference', ...
            'Zone %s references an unknown breaker.', zone.id);
    end
end
end

function ids = normalizeIds(value)
if ischar(value)
    ids = {value};
elseif isstring(value)
    ids = cellstr(value(:));
elseif iscell(value)
    ids = value;
else
    error('validateProtectionZones:InvalidBackupRelays', ...
        'backupRelayIds must be a character vector, string, or cell array.');
end
end
