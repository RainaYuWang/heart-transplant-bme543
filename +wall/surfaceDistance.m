function [map, values, valid] = surfaceDistance(inner, outer, voxelMM, capSlices)
% Shortest Euclidean inner-to-outer surface distance on an isotropic grid.
% Closed ends are excluded from BOTH source and target surface sampling.
assert(isequal(size(inner),size(outer)) && ndims(inner)==3, 'wall:Masks','Mask sizes must match.');
assert(isscalar(voxelMM) && isfinite(voxelMM) && voxelMM>0, 'wall:Spacing','Invalid voxel spacing.');
assert(isscalar(capSlices) && isfinite(capSlices) && capSlices>=1 && ...
    capSlices==fix(capSlices),'wall:Caps','End-cap exclusion must be a positive integer.');
assert(~any(inner(:) & ~outer(:)), 'wall:Nesting','Inner mask must be inside outer mask.');
assert(any(inner(:)) && any(outer(:)), 'wall:Empty','Empty segmentation.');
innerSurface=bwperim(inner,26); outerSurface=bwperim(outer,26);
z=find(squeeze(any(any(outer,1),2)));
assert(numel(z)>2*capSlices, 'wall:Coverage','Too few slices after excluding end caps.');
excluded=[1:z(1)+capSlices-1, z(end)-capSlices+1:size(outer,3)];
innerSurface(:,:,excluded)=false; outerSurface(:,:,excluded)=false;
assert(any(innerSurface(:)) && any(outerSurface(:)), 'wall:Surface','No usable surface remains.');
distance=bwdist(outerSurface)*voxelMM;
map=nan(size(distance),'single'); valid=innerSurface;
map(valid)=distance(valid); values=double(map(valid));
end
