function [positions, strength, profile] = profileEdges(img, lineXY, spacingXY, limits)
% Sample a directed cavity-to-outside line. Return NaNs for weak/no edges.
% Coordinates are image pixel centers [column row]; spacingXY is mm/pixel.
lengthMM = norm(diff(lineXY,1,1) .* spacingXY);
count = max(16, ceil(norm(diff(lineXY,1,1))*4)+1);
t = linspace(0,1,count);
xy = lineXY(1,:) + t(:) .* diff(lineXY,1,1);
raw = interp2(double(img), xy(:,1), xy(:,2), 'linear', nan);
profile.distance = t(:)*lengthMM;
profile.intensity = movmean(raw, 5);
positions = nan(2,2); strength = 0;
if lengthMM <= 0 || any(~isfinite(raw)), return; end
range = max(raw)-min(raw);
if range <= eps(max(abs(raw))+1), return; end
y = (profile.intensity-min(raw))/range;
g = gradient(y, lengthMM/(count-1));
% A wall is a brighter band: rising inner edge followed by falling outer edge.
best = -inf; pair = [];
for a = 3:count-3
    distances = profile.distance - profile.distance(a);
    candidates = find(distances >= limits(1) & distances <= limits(2));
    candidates = candidates(candidates > a & candidates < count-1);
    if isempty(candidates) || g(a) <= 0, continue; end
    [fall, idx] = max(-g(candidates));
    if fall <= 0, continue; end
    b = candidates(idx);
    score = min(g(a), fall);
    if score > best, best = score; pair = [a b]; end
end
if isempty(pair), return; end
strength = best;
% Contrast threshold is a heuristic, not a calibrated confidence measure.
contrast = mean(y(pair(1):pair(2))) - mean([y(1:pair(1)); y(pair(2):end)]);
if contrast < 0.08, return; end
positions = xy(pair,:);
end
