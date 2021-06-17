function plot_significant_clusters(mask, cluster_p)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here


    figure;
    sgtitle('Significant clusters for each coefficient.')
    tiledlayout(1, 3, 'TileSpacing', 'compact')


    for current_beta = 1:size(mask, 3)
        clusters = unique(mask(:, :, current_beta))';
        clusters(clusters == 0) = []; % Remove 0, 0 is no significant cluster

        ax = nexttile;
        title(string(current_beta));

        hold on;
        xlim([1, size(mask, 2)]);
        ylim([1, size(mask, 1)]);

        this_beta_cluster_ps = {};

        for current_cluster = clusters
            cluster_indices = squeeze(mask(:, :, current_beta)) == current_cluster;
            [cluster_pos_x, cluster_pos_y] = find(cluster_indices');

            hold on;
            scatter(cluster_pos_x, cluster_pos_y);

            %title(string(current_cluster));

            %significant_betas = mean(squeeze(betas(:, :, current_beta, :)), 3);
            %significant_betas(cluster_indices) = significant_betas(cluster_indices)

            %length(significant_betas(~cluster_indices))

            this_cluster_p = squeeze(cluster_p(:, :, current_beta));
            this_beta_cluster_ps{current_cluster} = string(max(this_cluster_p(cluster_indices)));
        end

        legend(this_beta_cluster_ps);
    end
end

