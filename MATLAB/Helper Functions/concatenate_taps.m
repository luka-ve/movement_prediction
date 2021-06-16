function taps_all = concatenate_taps(taps_in)
    taps_all = [];
    for i = taps_in
        taps_all = vertcat(taps_all, i{1});
    end
end
