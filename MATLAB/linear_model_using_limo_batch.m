%% Construct model specs

model = struct();

model.set_files = set_files;
model.cat_files = [];
model.cont_files = cont_files;

model.defaults.type = 'Channels';  
model.defaults.analysis = 'Time';  
model.defaults.method = 'WLS'; 
model.defaults.type_of_analysis = 'univariate';  
model.defaults.fullfactorial = 0;  
model.defaults.zscore = 0;  
model.defaults.start = -450; % starting time in ms  
model.defaults.end = 10; % ending time in ms  
model.defaults.bootstrap = 0;  
model.defaults.tfce = 0;  
[neighbours, channeighbstructmat] = limo_get_channeighbstructmat(EEG1, 0.74); % neighbor distance value taken from LIMO EEG 1st level scripting tutorial
model.defaults.neighbouring_matrix = neighbours; 


%% Run limo batch
[LIMO_files, procstatus] = limo_batch('model_specification', model, []);

EEG_cont = eeg_epoch2continuous(EEG1);

%% Using limo_glm

directory = pwd();

Y = EEG1.data;
Cat = [];
Cont = log10(abs(continuous));

[X, nb_conditions, nb_interactions, nb_continuous] = limo_design_matrix(Y, Cat, Cont(:, 2:3), directory, 1, 0, 1);

method = 'OLS';
analysis_type = 'Time';

% Remove trials of data where predictors have NaN
Y(:, :, any(isnan(continuous), 2)) = [];

model = cell(size(Y, 1), 1);

for current_electrode = 7:size(Y, 1)
    Y_now = squeeze(Y(current_electrode, :, :))';
    model{current_electrode} = limo_glm(Y_now, X, nb_conditions, nb_interactions, nb_continuous, method, analysis_type);
end

model = [model{:}];



electrode = 1;

f = figure;
hold on;

p = plot(mean(squeeze(Y(electrode, :, :)), 2));
p.LineWidth = 5;
xline(4000);

plot(model(electrode).betas');

legend(["ERP", fliplr(["t-2", "t-1", "t+1", "t+2", "bias"])]);
f.GraphicsSmoothing  = 'on';










