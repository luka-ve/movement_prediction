# Effects of Behavioral Temporal Dynamics on Premotor Potentials (working title)

This repository contains all the code used for data preprocessing and analysis for my [thesis].
This readme outlines the data handling processes of data reading and validation, preprocessing, linear modelling, and plotting.

## Software Dependencies

- [EEGLAB 2021.0 website](https://eeglab.org/) or on [GitHub](https://github.com/sccn/eeglab)
- [LIMO EEG](https://github.com/LIMO-EEG-Toolbox/limo_tools)
- [Kock, Ruchella; Master thesis](https://github.com/rushkock/master_thesis_IS-DS/)
- [Neubee](https://github.com/codelableidenvelux/neubee/)
- [Codelab Tap Data Processing](https://github.com/codelableidenvelux/CodelabTapDataProcessing)
- [numSubplots](https://www.mathworks.com/matlabcentral/fileexchange/26310-numsubplots-neatly-arrange-subplots) for automatic plot arrangement.

# Preprocessing ([inspect_ica_epochs.m](MATLAB/inspect_ICA_epochs.m))

Three sources of data are most important for this thesis:

- 64-channel continuous EEG recordings
- Time-stamps of phone tap interactions
- Force-sensor information (FS)


## Data channel misalignment
For technical reasons, the EEG recordings, tap data and force-/bend-sensor data were recorded on separate clocks. Thus, the three data streams are inherently misaligned and must first be temporally aligned. Data alignment was done using a long-short term memory network (LSTM). The exact process details and implementation can be found [in this repository](https://github.com/codelableidenvelux/neubee/tree/rush/lstm).


## Data selection 
Out of all participants, only a small subset were recorded with force sensor data (This was done automatically by finding participants belonging to the `DS*` series). We decided that for this study we would only include participants that also had force sensor recordings. In addition to interacting with their phone, those participants were also asked to touch a box with a pressure-sensitive surface the same way they would touch their phone screen. The FS data later allowed us to select independent components that likely related to pre-motor signals (See [independent component selection](#ICA-Selection)).
Next, each participant's data is checked for whether RNN-based alignment was successful using an automated [alignment decision tree](https://github.com/rushkock/master_thesis_IS-DS/tree/master/src/alignment/moving_averages/decision_tree) => *Add decision parameters here as soon as I get new version from Ruchella*
If the model-based alignment was successful, the alignment shift is applied to the data. Else, the participant is discarded. Furthermore, if a target file in the save folder is detected, the script will skip to the next participant.

Here is a list of all the ways a participant might fail and be skipped:
- The target file under which to save the processed data alread exists
- The source data file does not contain any FS data
- The temporal alignment did not work according to the decision tree
- EEG cleaning throws any exception (e.g., missing blink channel)
- ICA throws any exception

All skipped participants are logged to the `MATLAB/Log/` folder.


## Independent Component Analysis
After the alignment check, the data is prepared to be processed with ICA. First, both tap and FS time stamps are extracted from the data in order to remove subsequences of EEG data in which there were neither taps nor FS interactions. Furthermore FS event and Tap event times are added as events to the `EEG.event` struct. This allows for easier epoching later on.

MATLAB's pulsewidth function is used to extract force sensor touches, as FS data can be simplified to be a binary value of either touch or no touch. Furthermore, FS touch intervals that are < 500ms were ignored, such quick touches are likely the results of noise/unintentional thumb lifts off the sensor. Smartphone tap data is simply taken from the existing aligned data.

Next, EEG data is cleaned from eye blinks using ICA based artifact rejection using already computed ICA weights. Then filtering is applied with a first order bandpass filter between 0.1 Hz and 30 Hz using a Hamming window.

We then found all time regions in which there were neither phone nor FS touches for 100 seconds. We then added padding of 15 seconds to the first and last tap of the activity regions, removed all data in between and concatenated the remaining data using `pop_select()`.

Next, the script runs independent component analysis with standard settings, using the MATLAB implementation that is shipped with EEGLAB. After ICA, the data is saved to a new folder (set by the `SAVE_PATH` variable) and a participant subfolder. The process is repeated for each participant file that is found at the beginning of the file.


# Selection of independent components 

Following ICA, we decided to manually select independent components that may resemble pre-motor potentials.
Pre-motor potentials in this case refer to **any** signal that reliably precedes a motor action.
I do not make the assumption that pre-motor signals are necessarily signals that directly prepare for motor action.

For each individual participant, we selected independent components based on the following set of rules which were validated visually using averaged component ERP plots and topographical plots. In order for a component to be selected, it must fulfill both of the following requirements:

- Exhibit some sense of pre-tap deviation
- Not be topologically dominated by ocular electrodes

Since eye movements may be synchronised to some extent with motor actions, ocular-dominated components were ignored in the component selection, even when they exhibited strong pre-tap deviation. (Add some more detail here)

For each participant, we then compiled a list of selected components which can be found in [Component Selection.xlsx](MATLAB/Component%20Selection.xlsx)


# Linear Model ([linear_model.m](MATLAB/linear_model.m))
For each of the previously preprocessed participant files, we then run the linear modelling pipeline. Despite the name, the pipeline also includes generation of tap timings, epoch extraction, and component reprojection.

For each of the previously processed participants, we first reject all components that were not selected in the previous component selection process. After rejecting unwanted components, any missing channels are interpolated using spherical interpolation.

Next, $\Delta$ times are calculated between each tap and the two surrounding taps. $\Delta$ times are the intervals between taps. For a given tap, $\Delta t_{+1}$ may refer to the interval in milliseconds to the next tap. Equally, for a tap $\Delta t_{-1}$ referes to the interval in ms to the previous tap. These delta times are then added as fields to each tap that occurred in the `EEG.event` struct of a participant. From these events, the EEG data is then epoched around 'Tap' events, which were marked previously during preprocessing.

Next, since epoching adds lots of seemingly duplicate occurences of events, the continuous predictors are extracted from each event, along with the correct indices. *Note: This part also includes a handler which deals with edge cases in which multiple events happen to fall on the exact same sample latency.*
Processed EEG files are then saved as new copies of the EEG data.

## Step 1
Before step 1 of the LIMO pipeline, any trials with NaN are removed from the data. NaNs may be introduced by the tap distance extraction method. After NaN removal, a GLM is run on each each frame of the epoched data. The output of this operation is list of linear model parameters. This process is then repeated for each EEG channel. The number of models = the number of frames in an epoch * number of channels. In our case, an epoch is 3500 frames (= ms) long and our EEG data contains 64 channels. For each participant, this mass-univariate analysis generates 224,000 models. The model weights are trained using ordinary least squares. Relevant files are automatically saved into the participant folder. While LIMO EEG automatically generates files in the participant folder, these files can be ignored, since we are not using the default behavior exhibited by the `limo_glm` function. Instead, all models are saved into a struct array called `LIMOs`. This struct contains a list of models for each participant. The file is also saved in the root folder of the project under `LIMOs.mat`. *Note: I will add a section in this readme that describes file dimensions and formats.*

## Step 2.1
Step 2 of the LIMO pipeline is concerned with between participant analysis. In our case, we are interested in figuring out whether the parameters of each model are significantly affected by the temporal dynamics described by $\Delta t_{-1}$ and $\Delta t_{+1}$. To answer this question, we run a simple one-sample t-test on the model coefficients acquired in step 1. A t-test is run for each frame and each channel using the beta values from all participants for the given channel/frame using 1000 bootstrap samples. Moreover, the t-test uses an 80% trimmed mean and [Windsorized standard error](https://www.itl.nist.gov/div898/software/dataplot/refman2/auxillar/winssd.htm).

### Multiple Comparisons Correction - Clustering
The result of these computations is a t-test result for each channel, each frame, and each model coefficient. The latter is 3 in our case, since we are looking at one tap distance in each direction + intercept. However, p-values at this stage cannot be trusted due to multiple comparisons (64 * 3500 * 3 = 672,000 comparisons). At the same time, with this number of comparisons a traditional multiple comparisons correction -- such as Bonferroni correction -- would not be feasible, as the significane threshold would be pepenalized too severely. It would be nearly impossible to find any significant effect, leading to many Type II errors. To mitigate this problem, we can use spatio-temporal clustering to instead find significant clusters of betas, rather than electrodes and time points.

Spatio-temporal clustering considers clusters of Betas in both space and time. This step allows us to instead consider the effects of temporal dynamics not at specific time points or electrodes, but instead in spatio-temporal "areas" over an epoch and across the scalp.

Here, I use `limo_cluster_correction()` with an alpha of 0.05. Furthermore, clusters must reach across at least 2 channels, i.e., temporal-only clusters are not possible.

## Plots
In addition to the analysis, the `linear_model` script also produces two plots:
1. A collection of line graphs for either all electrodes or a selection of electrodes, showing the averaged beta values for those electrodes.
2. A scatter plot showing displaying all significant clusters returned by the clustering process, as well as p-values for each cluster.


