% =========================================================================
%                  train_microgrid_drl.m
% -------------------------------------------------------------------------
% Description:
%   Full DRL training script for microgrid energy management.
%   This script trains a DDPG agent to optimize battery control.
% =========================================================================

clear; clc; close all;

fprintf('================================================================\n');
fprintf('   Microgrid DRL Training - Full Version\n');
fprintf('================================================================\n');
fprintf('   Start time: %s\n', datestr(now));
fprintf('================================================================\n\n');

%% Configuration
TRAIN_EPISODES = 100;  % Number of training episodes (reduce for testing)
USE_PARALLEL = false;  % Set to true if you have Parallel Computing Toolbox
SAVE_AGENT = true;     % Save trained agent after training

%% 1. Load Simulation Data
fprintf('STEP 1: Loading simulation data...\n');
try
    % Load the pre-generated data
    data_file = fullfile('..', 'simulation_data_10days_random.mat');
    if ~exist(data_file, 'file')
        data_file = 'simulation_data_10days_random.mat';
    end
    
    load(data_file);
    fprintf('   ?? Data loaded: %d days of simulation data\n', simulationDays);
    
    % Assign to base workspace for Simulink
    assignin('base', 'pv_power_profile', pv_power_profile);
    assignin('base', 'load_power_profile', load_power_profile);
    assignin('base', 'price_profile', price_profile);
    assignin('base', 'Ts', Ts);
    
    fprintf('   ?? Data assigned to workspace\n');
    
catch ME
    error('Failed to load simulation data: %s', ME.message);
end

%% 2. Configure Simulink Model
fprintf('\nSTEP 2: Configuring Simulink model...\n');

model_name = 'Microgrid2508020734';

% Close any existing model instance
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end

% Load the model
try
    load_system(model_name);
    fprintf('   ?? Model loaded: %s\n', model_name);
catch ME
    error('Failed to load Simulink model: %s', ME.message);
end

% Configure model parameters
set_param(model_name, 'StopTime', num2str(24*3600));  % 24 hours per episode
set_param(model_name, 'SolverType', 'Variable-step');
set_param(model_name, 'Solver', 'ode23tb');
set_param(model_name, 'SimulationMode', 'normal');  % Can be 'accelerator' for speed

fprintf('   ?? Model configured for 24-hour episodes\n');

%% 3. Define System Parameters
fprintf('\nSTEP 3: Setting system parameters...\n');

% Time and power parameters
Ts = 3600;              % Sample time (1 hour)
Pnom = 500e3;          % Nominal power (500 kW)
PnomkW = 500;          % Nominal power in kW

% Battery parameters
kWh_Rated = 100;        % Battery capacity in kWh
Efficiency = 96;        % Battery efficiency (%)
Initial_SOC_pc_MIN = 30; % Min initial SOC (%)
Initial_SOC_pc_MAX = 80; % Max initial SOC (%)

% Cost parameters
COST_PER_AH_LOSS = 0.25;  % Cost for battery degradation
SOC_UPPER_LIMIT = 95.0;   % Upper SOC limit (%)
SOC_LOWER_LIMIT = 15.0;   % Lower SOC limit (%)

fprintf('   Battery: %.0f kW / %.0f kWh\n', PnomkW, kWh_Rated);
fprintf('   SOC limits: %.0f%% - %.0f%%\n', SOC_LOWER_LIMIT, SOC_UPPER_LIMIT);

%% 4. Create RL Environment
fprintf('\nSTEP 4: Creating RL environment...\n');

% Define observation and action specifications
num_observations = 7;  % [PV, Load, SOC, SOH, Price, Hour, Day]

obsInfo = rlNumericSpec([num_observations 1], 'Name', 'Microgrid State');
obsInfo.Description = 'PV power, Load power, SOC, SOH, Price, Hour, Day';
obsInfo.LowerLimit = [0; 0; 0.1; 0.5; 0; 1; 1];
obsInfo.UpperLimit = [1000e3; 1000e3; 0.9; 1.0; 2.0; 24; 365];

actInfo = rlNumericSpec([1 1], ...
    'LowerLimit', -Pnom, ...
    'UpperLimit', Pnom, ...
    'Name', 'Battery Power Command');
actInfo.Description = 'Battery charge/discharge power in Watts';

fprintf('   Observation: %d dimensions\n', num_observations);
fprintf('   Action: 1 dimension (Battery power: ¡À%.0f kW)\n', PnomkW);

%% 5. Create DDPG Agent
fprintf('\nSTEP 5: Creating DDPG agent...\n');

% === Actor Network ===
actorNetwork = [
    featureInputLayer(num_observations, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(128, 'Name', 'fc1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(64, 'Name', 'fc2')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'fc_action')
    tanhLayer('Name', 'tanh')
    scalingLayer('Name', 'action_scaling', 'Scale', Pnom)
];

actorNet = dlnetwork(actorNetwork, 'Initialize', false);
actor_options = rlRepresentationOptions(...
    'LearnRate', 1e-4, ...
    'GradientThreshold', 1, ...
    'L2RegularizationFactor', 1e-4);

actor = rlDeterministicActorRepresentation(actorNet, obsInfo, actInfo, ...
    'Observation', {'obs'}, ...
    'Action', {'action_scaling'}, ...
    actor_options);

fprintf('   ?? Actor network created (128-64-1 architecture)\n');

% === Critic Network ===
% State path
statePath = [
    featureInputLayer(num_observations, 'Normalization', 'zscore', 'Name', 'state')
    fullyConnectedLayer(128, 'Name', 'fc_state')
];

% Action path
actionPath = [
    featureInputLayer(1, 'Normalization', 'none', 'Name', 'action')
    fullyConnectedLayer(128, 'Name', 'fc_action')
];

% Common path (after merge)
commonPath = [
    additionLayer(2, 'Name', 'add')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(64, 'Name', 'fc_common')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'q_value')
];

% Build critic network
criticNetwork = layerGraph(statePath);
criticNetwork = addLayers(criticNetwork, actionPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, 'fc_state', 'add/in1');
criticNetwork = connectLayers(criticNetwork, 'fc_action', 'add/in2');

criticNet = dlnetwork(criticNetwork, 'Initialize', false);
critic_options = rlRepresentationOptions(...
    'LearnRate', 1e-3, ...
    'GradientThreshold', 1, ...
    'L2RegularizationFactor', 1e-4);

critic = rlQValueRepresentation(criticNet, obsInfo, actInfo, ...
    'Observation', {'state'}, ...
    'Action', {'action'}, ...
    critic_options);

fprintf('   ?? Critic network created (dual-path 128-64-1 architecture)\n');

% === DDPG Agent Options ===
agentOpts = rlDDPGAgentOptions(...
    'SampleTime', Ts, ...
    'TargetSmoothFactor', 1e-3, ...
    'DiscountFactor', 0.99, ...
    'MiniBatchSize', 128, ...
    'ExperienceBufferLength', 1e6);

% Configure noise for exploration (with stability check)
agentOpts.NoiseOptions.MeanAttractionConstant = 1e-4;  % Must be < 2/Ts
agentOpts.NoiseOptions.Variance = 0.1 * Pnom;
agentOpts.NoiseOptions.VarianceDecayRate = 1e-5;

% Verify noise stability
stability = abs(1 - agentOpts.NoiseOptions.MeanAttractionConstant * Ts);
if stability > 1
    error('Noise parameters are unstable! Adjust MeanAttractionConstant.');
end
fprintf('   ?? Noise stability verified: %.4f (< 1.0)\n', stability);

% Create the agent
agent = rlDDPGAgent(actor, critic, agentOpts);
assignin('base', 'agentObj', agent);

fprintf('   ?? DDPG agent created and assigned to workspace\n');

%% 6. Setup Simulink Environment
fprintf('\nSTEP 6: Setting up Simulink environment...\n');

% Create the environment
agent_block_path = [model_name, '/RL Agent'];
env = rlSimulinkEnv(model_name, agent_block_path, obsInfo, actInfo);

% Set reset function for random initial SOC
env.ResetFcn = @(in) localResetFcn(in, model_name, Initial_SOC_pc_MIN, Initial_SOC_pc_MAX);

fprintf('   ?? Environment created with random SOC reset\n');

%% 7. Configure Training Options
fprintf('\nSTEP 7: Configuring training options...\n');

trainOpts = rlTrainingOptions(...
    'MaxEpisodes', TRAIN_EPISODES, ...
    'MaxStepsPerEpisode', 24, ...  % 24 hours
    'ScoreAveragingWindow', 20, ...
    'Verbose', true, ...
    'Plots', 'training-progress', ...
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', -100, ...  % Stop if average reward > -100
    'StopOnError', 'off');

% Configure parallel training if requested
if USE_PARALLEL && ~isempty(ver('parallel'))
    trainOpts.UseParallel = true;
    trainOpts.ParallelizationOptions.Mode = 'async';
    fprintf('   ?? Parallel training ENABLED\n');
else
    trainOpts.UseParallel = false;
    fprintf('   ?? Sequential training mode\n');
end

fprintf('   Training episodes: %d\n', TRAIN_EPISODES);
fprintf('   Steps per episode: %d (hours)\n', 24);

%% 8. Start Training
fprintf('\n================================================================\n');
fprintf('STARTING TRAINING\n');
fprintf('================================================================\n');
fprintf('Expected duration: %.1f - %.1f minutes\n', ...
    TRAIN_EPISODES * 0.5, TRAIN_EPISODES * 2);
fprintf('\nTraining progress will be displayed below and in a separate window.\n');
fprintf('Press Ctrl+C to stop training early.\n\n');

% Train the agent
training_start = tic;
try
    trainingStats = train(agent, env, trainOpts);
    training_success = true;
catch ME
    fprintf('\nTraining interrupted or failed: %s\n', ME.message);
    training_success = false;
    trainingStats = [];
end
training_time = toc(training_start);

%% 9. Post-Training Analysis
fprintf('\n================================================================\n');
fprintf('TRAINING COMPLETED\n');
fprintf('================================================================\n');

if training_success && ~isempty(trainingStats)
    % Calculate statistics
    num_episodes = length(trainingStats.EpisodeReward);
    avg_reward = mean(trainingStats.EpisodeReward);
    final_reward = trainingStats.EpisodeReward(end);
    
    fprintf('\nTraining Summary:\n');
    fprintf('   Total time: %.1f minutes\n', training_time/60);
    fprintf('   Episodes completed: %d\n', num_episodes);
    fprintf('   Average reward: %.2f\n', avg_reward);
    fprintf('   Final episode reward: %.2f\n', final_reward);
    
    if num_episodes >= 10
        last10_avg = mean(trainingStats.EpisodeReward(end-9:end));
        fprintf('   Last 10 episodes average: %.2f\n', last10_avg);
    end
    
    % Save the trained agent
    if SAVE_AGENT
        timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        filename = sprintf('trained_agent_%s.mat', timestamp);
        save(filename, 'agent', 'trainingStats', 'obsInfo', 'actInfo');
        fprintf('\n   ?? Trained agent saved to: %s\n', filename);
    end
    
    % Plot training results
    figure('Name', 'Training Results', 'Position', [100 100 1200 400]);
    
    subplot(1,2,1);
    plot(trainingStats.EpisodeReward, 'b-', 'LineWidth', 1.5);
    hold on;
    if num_episodes > 20
        window = min(20, floor(num_episodes/5));
        avg_curve = movmean(trainingStats.EpisodeReward, window);
        plot(avg_curve, 'r-', 'LineWidth', 2);
        legend('Episode Reward', sprintf('%d-Episode Moving Average', window));
    end
    xlabel('Episode');
    ylabel('Reward');
    title('Training Progress');
    grid on;
    
    subplot(1,2,2);
    if isfield(trainingStats, 'EpisodeQ0')
        plot(trainingStats.EpisodeQ0, 'g-', 'LineWidth', 1.5);
        xlabel('Episode');
        ylabel('Episode Q0');
        title('Estimated Q-Value');
        grid on;
    else
        histogram(trainingStats.EpisodeReward, 20);
        xlabel('Reward');
        ylabel('Frequency');
        title('Reward Distribution');
        grid on;
    end
    
else
    fprintf('\nNo training statistics available.\n');
end

fprintf('\n================================================================\n');
fprintf('Script completed at: %s\n', datestr(now));
fprintf('================================================================\n');

%% Local Functions
function in = localResetFcn(in, modelName, soc_min, soc_max)
    % Reset function with random initial SOC
    random_soc = rand() * (soc_max - soc_min) + soc_min;
    block_path = [modelName, '/Energy Storage'];
    in = setBlockParameter(in, block_path, 'Initial_kWh_pc', num2str(random_soc));
end
