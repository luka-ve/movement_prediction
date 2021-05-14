EEG_paths = dir("/media/Storage/User_Specific_Data_Storage/luka/EEG_ICA/**/*.set");

%%
ppt = 27;


EEG = pop_loadset(EEG_paths(ppt).name, EEG_paths(ppt).folder);
EEG = pop_epoch(EEG, {'FS_event'}, [-4 1]);
EEG = pop_rmbase(EEG, [-4000, -3200]);




pop_topoplot(EEG, 0);

pop_spectopo(EEG, 0);

pop_plotdata(EEG, 0);
sgtitle('Component ERPs before comp rej');


comps_to_keep = [6, 8, 18];
comps_to_remove = 1:64;
comps_to_remove(comps_to_keep) = [];

electrodes = [1, 10, 16];

pop_plotdata(EEG, 1, electrodes);
sgtitle('Electrode ERPs before comp rej');

EEG = pop_subcomp(EEG, comps_to_remove);
pop_plotdata(EEG, 1, electrodes);
sgtitle(sprintf('Electrode ERPs after comp rej. Retained comps: %s', strjoin({num2str(comps_to_keep)})));




disp([EEG_paths(ppt).folder((end-4):end), '/', EEG_paths(ppt).name]);

%%
EEG = pop_loadset('/media/Storage/User_Specific_Data_Storage/luka/EEG_ICA/');