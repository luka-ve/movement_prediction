% Requires:
% github.com/codelableidenvelux/neubee/master
% EEGLAB

script_start_time = tic();

DATA_ROOT_PATH = "D:/Coding/Thesis/Data/EEG";
%PPT_FILES = ["DS99/08_05_25_04_19.set"];
PPT_FILES = ["DS99/08_05_25_04_19.set", "DS99/10_19_25_04_19.set", "DS95/12_02_11_04_19.set"];

opts = struct();

opts.lowpass_freq = 45;
opts.highpass_freq = [];
opts.max_dist_between_sections = 30000;
opts.activity_windows_padding = 30000;

opts.stft_FFTLength = 256;
opts.stft_window = hann(opts.stft_FFTLength, "periodic");
opts.hopsize = 128;
opts.stft_overlap = opts.stft_FFTLength - opts.hopsize;


opts.h5_save_path = fullfile("D:/Coding/Thesis/Data/STFT Output");


for ppt_file = PPT_FILES
    ppt_time_start = tic();
    
    EEG = pop_loadset('filename', convertStringsToChars(fullfile(DATA_ROOT_PATH, ppt_file)));
    EEG_clean = gettechnicallycleanEEG(EEG, opts.highpass_freq, opts.lowpass_freq);
    
    opts.srate = EEG.srate;
    
    taps_all = concatenate_taps(EEG);
    
    clear EEG;
    
    EEG_data_split = split_EEG(EEG_clean, taps_all, opts);
    
    clear EEG_clean;
    
    EEG_data_split_stft = perform_STFT(EEG_data_split, opts.srate, opts);
    
    clear EEG_data_split
    
    ppt_info = split(ppt_file, "/");
    
    
    export_as_h5(EEG_data_split_stft, ppt_info(1), ppt_info(2), opts);
    
    fprintf("""%s"" exported to ""%s"" in %.2f seconds.\n", ppt_file, opts.h5_save_path, toc(ppt_time_start));
    
    clear EEG_data_split_stft
end

fprintf("Finished in %.2f seconds.\n", toc(script_start_time));
