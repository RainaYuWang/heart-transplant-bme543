% Generate one 2D long axis image, cut in the height dimension through col,
% through all frames of the volume and output to a directory.
function generateSingleLongAxisSeries(dataset_number, subdir, VolumesDataStruct, VolumesData, col)

    load('map.mat', 'map');
    colormap(map);

    delete(sprintf('./Output_%d/%s/*.jpg', dataset_number, subdir));
    mkdir(sprintf('./Output_%d/%s', dataset_number, subdir));

    for frame = 1:VolumesDataStruct.NumVolumes
        fig = figure;
        imagesc(fliplr(rot90(squeeze(VolumesData(:, round(col), :, frame)), 3)));
        colormap(map);

        outfile = sprintf('./Output_%d/%s/col%03d_frame%02d', dataset_number, subdir, col, frame);
        print(fig, '-djpeg85', '-r150', outfile);
        close;
    end

end