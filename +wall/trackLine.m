function [lineXY, score] = trackLine(previous, current, previousLine, radius)
% Bounded 2D translation matching; not deformable/3D tissue tracking.
lineXY = previousLine; score = -inf;
pad = 5;
lo = max([1 1], floor(min(previousLine,[],1))-pad);
hi = min([size(previous,2) size(previous,1)], ceil(max(previousLine,[],1))+pad);
template = double(previous(lo(2):hi(2),lo(1):hi(1)));
template = template-mean(template(:));
den = norm(template(:));
if den <= eps, return; end
for dy = -radius:radius
    for dx = -radius:radius
        l = lo+[dx dy]; h = hi+[dx dy];
        if any(l < 1) || h(1)>size(current,2) || h(2)>size(current,1), continue; end
        patch = double(current(l(2):h(2),l(1):h(1)));
        patch = patch-mean(patch(:));
        value = sum(template(:).*patch(:))/(den*norm(patch(:))+eps);
        if value > score, score = value; lineXY = previousLine+[dx dy]; end
    end
end
end
