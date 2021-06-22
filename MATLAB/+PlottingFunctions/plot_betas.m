function plot_betas(betas, electrodes, epoch_size, use_trimmed_mean)
%PLOT_BETAS Plots beta values for
%   Detailed explanation goes here
% use_trimmed_mean: Whether or not to plot the mean line using an 80%
% trimmed mean.

if ~exist('electrodes', 'var') || isempty(electrodes)
    electrodes = 1:size(betas, 1);
end

if ~exist('epoch_size', 'var')
    epoch_size = [0, size(betas, 2)] / 1000;
end

if ~exist('use_trimmed_mean', 'var')
    use_trimmed_mean = true;
end

for beta = 1:size(betas, 3)
    figure;
    sgtitle(sprintf('Beta %d', beta));
    p = numSubplots(length(electrodes));
    
    for electrode_index = 1:length(electrodes)
        subplot(p(1), p(2), electrode_index);
        plot(epoch_size(1) * 1000 + 1:epoch_size(2) * 1000, squeeze(betas(electrodes(electrode_index), :, beta, :)));
        hold on;
        
        % Add mean line
        
        if use_trimmed_mean
            electrode_values = squeeze(betas(electrodes(electrode_index), :, beta, :));
            electrode_values = sort(electrode_values, 2);
            mean_indices = floor(size(electrode_values, 2) * 0.1):ceil(size(electrode_values, 2) * 0.9);
            mean_line = mean(electrode_values(:, mean_indices), 2);
        else
            mean_line = mean(squeeze(betas(electrodes(electrode_index), :, beta, :)), 2);
        end
        
        plot(epoch_size(1) * 1000 + 1:epoch_size(2) * 1000, mean_line, 'LineWidth', 5, 'color', [0, 0, 0]);
        
        
        title(string(electrodes(electrode_index)));
        xline(0);
        yline(0);
        xlim(epoch_size * 1000);
    end
end
end

