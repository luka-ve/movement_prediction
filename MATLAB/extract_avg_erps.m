% Extracts average ERPs from files

DATA_ROOT_PATH = "/media/Storage/User_Specific_Data_Storage/luka/EEG_STUDY/FS_event/";
set_files = dir(fullfile(DATA_ROOT_PATH, "/**/*.set"));

avg_activation = zeros(64, 3500, size(set_files, 1));

for ppt = 1:size(set_files, 1)
    EEG1 = pop_loadset(set_files(ppt).name, set_files(ppt).folder);    
    avg_activation(:, :, ppt) = mean(EEG1.data, 3);
end

save('avg_activation.mat', 'avg_activation');



