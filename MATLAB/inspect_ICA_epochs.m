EEG_paths = dir("/media/Storage/User_Specific_Data_Storage/luka/EEG_ICA/**/*_ICA.set");

%% Import, epoch, and correct baseline
ppt = 32;


EEG_IN = pop_loadset(EEG_paths(ppt).name, EEG_paths(ppt).folder);

EEG_taps = pop_epoch(EEG_IN, {'Tap'}, [-4 1]);
EEG_FS = pop_epoch(EEG_IN, {'FS_event'}, [-4 1]);

EEG_taps = pop_rmbase(EEG_taps, [-4000, -3200]);
EEG_FS = pop_rmbase(EEG_FS, [-4000, -3200]);


% Basic plots
pop_topoplot(EEG_FS, 0);


pop_plotdata(EEG_FS, 0);
sgtitle([EEG_paths(ppt).folder(end-4:end), '/', EEG_paths(ppt).name]);
 
%pop_plotdata(EEG_taps, 0);
%sgtitle('Taps Component ERPs');


% The results of this inspection are saved in a spreadsheet containing a
% column that states the component IDs

%% Reproject selected independent components
DATA_ROOT = "/media/Storage/User_Specific_Data_Storage/luka/EEG_ICA/";

% Load table form excel file
component_selection_path = "MATLAB/Component Selection.xlsx";
component_selection = readtable(component_selection_path, 'Range', 'A:F');

% Convert comma-separated string to numeric array
component_selection.SelectedComponentsNum = cellfun(@(x) [str2num(char(x))], component_selection.SelectedComponents, 'UniformOutput', false);


electrodes = [1, 2, 6, 10, 16]; % Which electrodes to observe

for ppt_no = 1:size(component_selection, 1)
    ppt_info = table2struct(component_selection(ppt_no, :));
    
    % Load ppt file
    EEG = pop_loadset(ppt_info.Filename, convertStringsToChars(fullfile(DATA_ROOT, ppt_info.Participant)));
    
    % Select component to keep/reject
    comps_to_keep = ppt_info.SelectedComponentsNum;
    comps_to_reject = 1:size(EEG.icachansind, 2);
    comps_to_reject(comps_to_keep) = [];
    
    % Reject non-selected components
    pop_subcomp(EEG, comps_to_reject);
    
    % Interpolate missing channels
    pop_interp(EEG,EEG.Orignalchanlocs,'spherical');
    
    % Do something with newly reprojected data 
    
    EEG_taps = pop_epoch(EEG, {'Tap'}, [-4 1]);
    EEG_taps = pop_rmbase(EEG_taps, [-4000, -3500]);
    pop_plotdata(EEG_taps, 1, electrodes);
    sgtitle(sprintf('Tap Electrode ERPs after comp rej. Retained comps: %s', strjoin({num2str(comps_to_keep)})));
end


%% Old

pop_plotdata(EEG, 1, electrodes);
sgtitle(sprintf('FS Electrode ERPs after comp rej. Retained comps: %s', strjoin({num2str(comps_to_keep)})));

pop_plotdata(EEG, 1, electrodes);
sgtitle(sprintf('Taps Electrode ERPs after comp rej. Retained comps: %s', strjoin({num2str(comps_to_keep)})));


std_limo

disp([EEG_paths(ppt).folder((end-4):end), '/', EEG_paths(ppt).name]);
