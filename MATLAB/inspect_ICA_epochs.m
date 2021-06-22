%% Read ICA files
EEG_paths = dir("/media/Storage/User_Specific_Data_Storage/luka/EEG_ICA/**/*_ICA.set");

%%
ppt = 32;

EEG_IN = pop_loadset(EEG_paths(ppt).name, EEG_paths(ppt).folder);

EEG_FS = pop_epoch(EEG_IN, {'FS_event'}, [-3 0.5]);
EEG_FS = pop_rmbase(EEG_FS, [-3000, -2800]);

SASICA(EEG_FS);

disp([EEG_paths(ppt).folder(end-4:end), '/', EEG_paths(ppt).name]);
 
% The results of this inspection are saved in a spreadsheet containing a
% column that states the component IDs
