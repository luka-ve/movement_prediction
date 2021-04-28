all_taps = concatenate_taps(ALLEEG(2));
all_taps = all_taps(:, 2);

tap_string = repmat("Tap", size(all_taps));

tap_epochs = table(tap_string, all_taps, zeros(size(all_taps)));
