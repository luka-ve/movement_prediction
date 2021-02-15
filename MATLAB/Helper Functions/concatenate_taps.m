function taps_all = concatenate_taps(EEG)
    taps_all = [];
    for i = EEG.Aligned.Phone.Corrected
        taps_all = vertcat(taps_all, i{1});
    end
end
