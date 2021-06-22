function [] = plot_FS_info(set_file)
%PLOT_FS_INFO Summary of this function goes here
%   Detailed explanation goes here
%   set-file: Location to an EEG .set file

[filepath, filename, ext] = fileparts(set_file);

EEG = pop_loadset([char(filename), char(ext)], char(filepath));

figure;
hold on;

plot(EEG.Aligned.BS.Data(:, 2));
plot(EEG.Aligned.BS.Model);

scatter(EEG.Aligned.Phone.Model(:, 2), ones(length(EEG.Aligned.Phone.Model(:, 2)), 1));


end

