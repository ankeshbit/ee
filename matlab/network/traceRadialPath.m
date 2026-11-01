function [path, Z1, Z2, Z0, hasGroundedNeutral, deltaWyeIndex] = traceRadialPath(network, busId)
% TRACERADIALPATH Trace radial path from source to busId and compute sequence impedances.
%
% Returns:
%   path: Struct array of elements from source to busId with fields:
%         type ('transformer'|'branch'), id, fromBus, toBus,
%         windingConnection, grounding, Z ([Z0; Z1; Z2])
%   Z1: Total positive-sequence impedance including source
%   Z2: Total negative-sequence impedance including source
%   Z0: Total zero-sequence impedance seen from busId
%   hasGroundedNeutral: Boolean indicating whether a return path to ground exists
%   deltaWyeIndex: Index of delta-grounded-wye transformer in path (0 if none)

path = struct('type', {}, 'id', {}, 'fromBus', {}, 'toBus', {}, ...
    'windingConnection', {}, 'grounding', {}, 'Z', {});
Z1 = network.source.Z1_pu;
Z2 = network.source.Z2_pu;

currentBus = busId;
rawElements = struct('type', {}, 'id', {}, 'fromBus', {}, 'toBus', {}, ...
    'windingConnection', {}, 'grounding', {}, 'Z', {});

while ~strcmp(currentBus, char(network.sourceBus))
    branchIndex = find(strcmp({network.branches.toBus}, currentBus), 1);
    transformerIndex = [];
    if isfield(network, 'transformers')
        transformerIndex = find(strcmp( ...
            {network.transformers.lowVoltageBus}, currentBus), 1);
    end
    if isempty(branchIndex) && isempty(transformerIndex)
        error('traceRadialPath:UnreachableBus', ...
            'Faulted bus %s is not reachable from the source.', busId);
    end

    if ~isempty(transformerIndex)
        tx = network.transformers(transformerIndex);
        item.type = 'transformer';
        item.id = char(tx.id);
        item.fromBus = char(tx.highVoltageBus);
        item.toBus = char(tx.lowVoltageBus);
        item.windingConnection = char(tx.windingConnection);
        item.grounding = '';
        if isfield(tx, 'grounding')
            item.grounding = char(tx.grounding);
        end
        item.Z = [tx.Z0_pu; tx.Z1_pu; tx.Z2_pu];
        rawElements = [item, rawElements]; %#ok<AGROW>
        Z1 = Z1 + tx.Z1_pu;
        Z2 = Z2 + tx.Z2_pu;
        currentBus = item.fromBus;
    else
        br = network.branches(branchIndex);
        item.type = 'branch';
        item.id = char(br.id);
        item.fromBus = char(br.fromBus);
        item.toBus = char(br.toBus);
        item.windingConnection = '';
        item.grounding = '';
        item.Z = [br.Z0_pu; br.Z1_pu; br.Z2_pu];
        rawElements = [item, rawElements]; %#ok<AGROW>
        Z1 = Z1 + br.Z1_pu;
        Z2 = Z2 + br.Z2_pu;
        currentBus = item.fromBus;
    end
end

path = rawElements;

% Determine zero-sequence path and grounded neutral presence
deltaWyeIndex = 0;
for idx = 1:numel(path)
    if strcmp(path(idx).type, 'transformer') && ...
            strcmpi(strtrim(path(idx).windingConnection), 'delta-grounded-wye')
        deltaWyeIndex = idx;
        break;
    end
end

if deltaWyeIndex > 0
    tx = path(deltaWyeIndex);
    % Check if wye neutral is grounded
    isGrounded = ~contains(lower(tx.grounding), 'ungrounded') && ...
        (contains(lower(tx.grounding), 'grounded') || ...
         contains(lower(tx.grounding), 'low') || ...
         contains(lower(tx.grounding), 'both'));
    if isGrounded
        hasGroundedNeutral = true;
        % Z0 seen from fault is transformer Z0 + downstream elements Z0
        Z0 = tx.Z(1);
        for idx = (deltaWyeIndex + 1):numel(path)
            Z0 = Z0 + path(idx).Z(1);
        end
    else
        hasGroundedNeutral = false;
        Z0 = Inf;
    end
else
    % No delta-grounded-wye transformer on path.
    % Check if any transformer on path blocks zero-sequence path to ground
    blocksZeroSequence = false;
    for idx = 1:numel(path)
        if strcmp(path(idx).type, 'transformer')
            conn = lower(strtrim(path(idx).windingConnection));
            grd  = lower(strtrim(path(idx).grounding));
            if contains(conn, 'delta-delta') || contains(conn, 'wye-delta')
                % Delta on LV blocks zero-sequence return path to ground
                blocksZeroSequence = true;
                break;
            elseif contains(conn, 'wye-wye') || contains(conn, 'grounded-wye-grounded-wye') || ...
                   contains(conn, 'yg-yg') || contains(conn, 'ynyn')
                % Wye-Wye requires both neutrals to be grounded to pass zero sequence
                isBothGrounded = ~contains(grd, 'ungrounded') && ...
                                 ~contains(grd, 'floating') && ...
                                 ~contains(grd, 'none') && ...
                                 (contains(grd, 'both') || ...
                                  (contains(grd, 'grounded') && ~contains(grd, 'primary ungrounded') && ~contains(grd, 'secondary ungrounded')) || ...
                                  contains(grd, 'solidly'));
                if ~isBothGrounded
                    blocksZeroSequence = true;
                    break;
                end
            end
        end
    end

    if blocksZeroSequence
        hasGroundedNeutral = false;
        Z0 = Inf;
    else
        hasSourceNeutral = isfield(network.source, 'Z0_pu') && isfinite(network.source.Z0_pu);
        if hasSourceNeutral
            hasGroundedNeutral = true;
            Z0 = network.source.Z0_pu;
            for idx = 1:numel(path)
                Z0 = Z0 + path(idx).Z(1);
            end
        else
            hasGroundedNeutral = false;
            Z0 = Inf;
        end
    end
end
end
