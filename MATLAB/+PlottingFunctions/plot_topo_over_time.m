% Plot for single ppt ERP
EEG1 = pop_loadset('13_09_01_03_19_ICA.set', '/media/Storage/User_Specific_Data_Storage/luka/EEG_STUDY/Tap/DS01/');

data_size = size(EEG1.data);
time_step = 500;
epoch_center = 3000;

sample_times = unique([1, time_step:time_step:data_size(2), data_size(2)]);
sample_times_text = sample_times - epoch_center;

sampled_data = EEG1.data(:, sample_times, :);
sampled_data = mean(sampled_data, 3);


figure;
tiledlayout(2, 4);

for time_slice = 1:size(sampled_data, 2)
    nexttile;
    title(sprintf("%d ms", sample_times_text(time_slice)));
    topoplot(squeeze(sampled_data(:, time_slice)), EEG1.chanlocs);
end