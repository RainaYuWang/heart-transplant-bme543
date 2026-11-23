function [img, planeSpacing] = contourImage(ds, dimension, slice, frame, spacing)
% Return a fixed data-axis plane with explicit column/row physical spacing.
switch dimension
    case 1
        img=double(squeeze(ds.data(slice,:,:,frame)).');
        planeSpacing=spacing([2 3]);
    case 2
        img=double(squeeze(ds.data(:,slice,:,frame)).');
        planeSpacing=spacing([1 3]);
    case 3
        img=double(ds.data(:,:,slice,frame).');
        planeSpacing=spacing([1 2]);
    otherwise
        error('wall:Plane','Plane dimension must be 1, 2 or 3.');
end
assert(all(isfinite(img(:))),'wall:Data','The selected image contains NaN or Inf values.');
end
