% =========================================================================
%                  quick_training_fixed.m
% -------------------------------------------------------------------------
% Description:
%   Fixed version of quick training test with stable noise parameters.
%   This script runs a short DRL training session to verify the setup.
% =========================================================================

clear; clc; close all;

fprintf('================================================================\n');
fprintf('   Quick DRL Training Test (Fixed Version)\n');
fprintf('================================================================\n\n');

%% 1. Load Data
fprintf('>> Loading simulation data...\n');
try
    % Move up one directory to access the data files
    data_path = fullfile('..', 'simulation_data_10days_random.mat');
    load(data_path);
    fprintf('   Data loaded successfully for %d days.\n', simulationDays);
    
    % Assign data to base workspace for Simulink
    assignin('base', 'pv_power_profile', pv_power_profile);
    assignin('base', 'load_power_profile', load_power_profile);
    assignin('base', 'price_profile', price_profile);
    assignin('base', 'Ts', Ts);
    assignin('base', 'simulationDays', simulationDays);
    
catch
    error('Could not find simulation data file. Please ensure simulation_data_10days_random.mat exists.');
end

%% 2. Setup Model
model_name = 'Microgrid2508020734';
fprintf('\n>> Setting up Simulink model: %s\n', model_name);

% Close any existing model
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end

% Load the model
try
    load_system(model_name);
    fprintf('   Model loaded successfully.\n');
catch ME
    error('Failed to load model: %s', ME.message);
end

% Configure model parameters
set_param(model_name, 'StopTime', num2str(24*3600)); % 24 hours
set_param(model_name, 'SolverType', 'Variable-step');
set_param(model_name, 'Solver', 'ode23tb');
fprintf('   Model configured: 24-hour episodes, variable-step solver.\n');

%% 3. Setup RL Environment
fprintf('\n>> Setting up RL environment...\n');

% System parameters (ensure they match the loaded data)
Ts = 3600; % Sample time (1 hour) - this should match the data
Pnom = 500e3; % Nominal power (500 kW)
num_observations = 7;

% Battery parameters
Initial_SOC_pc_MIN = 30; % Minimum initial SOC
Initial_SOC_pc_MAX = 80; % Maximum initial SOC

% Define observation and action spaces
obsInfo = rlNumericSpec([num_observations 1], 'Name', 'Microgrid State');
obsInfo.LowerLimit = [0; 0; 0.1; 0.5; 0; 1; 1];     % Min values for each observation
obsInfo.UpperLimit = [1000e3; 1000e3; 0.9; 1.0; 2.0; 24; 365]; % Max values

actInfo = rlNumericSpec([1 1], 'LowerLimit', -Pnom, 'UpperLimit', Pnom, 'Name', 'Battery Power');

% Create DDPG agent with FIXED noise parameters
fprintf('   Creating DDPG agent with stable noise parameters...\n');

% Create Actor Network
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
actor_options = rlRepresentationOptions('LearnRate', 1e-4, 'GradientThreshold', 1);
actor = rlDeterministicActorRepresentation(actorNet, obsInfo, actInfo, ...
    'Observation', {'obs'}, 'Action', {'action_scaling'}, actor_options);

% Create Critic Network
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

% Common path
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
critic_options = rlRepresentationOptions('LearnRate', 1e-3, 'GradientThreshold', 1);
critic = rlQValueRepresentation(criticNet, obsInfo, actInfo, ...
    'Observation', {'state'}, 'Action', {'action'}, critic_options);

% Create DDPG agent with FIXED stable noise parameters
agentOpts = rlDDPGAgentOptions(...
    'SampleTime', Ts, ...
    'TargetSmoothFactor', 1e-3, ...
    'DiscountFactor', 0.99, ...
    'MiniBatchSize', 128, ...
    'ExperienceBufferLength', 1e6);

% FIX: Set stable Ornstein-Uhlenbeck noise parameters
% The stability condition is: abs(1 - MeanAttractionConstant * SampleTime) <= 1
% With Ts = 3600, MeanAttractionConstant must be less than 2/3600 ≈ 0.000556
agentOpts.NoiseOptions.MeanAttractionConstant = 1e-4; % Safe value << 0.000556
agentOpts.NoiseOptions.Variance = 0.1 * Pnom; % 10% of nominal power
agentOpts.NoiseOptions.VarianceDecayRate = 1e-5; % Slow decay

% Verify stability condition
stability_check = abs(1 - agentOpts.NoiseOptions.MeanAttractionConstant * Ts);
fprintf('   Noise stability check: %.6f (must be <= 1.0) - %s\n', ...
    stability_check, iif(stability_check <= 1, 'STABLE', 'UNSTABLE'));

% Create the agent
agent = rlDDPGAgent(actor, critic, agentOpts);

% Assign agent to base workspace
assignin('base', 'agentObj', agent);
fprintf('   DDPG agent created and assigned to workspace.\n');

% Create Simulink environment
agent_block_path = [model_name, '/RL Agent'];
env = rlSimulinkEnv(model_name, agent_block_path, obsInfo, actInfo);

% Reset function for random initial SOC
env.ResetFcn = @(in) localResetFcn(in, model_name, Initial_SOC_pc_MIN, Initial_SOC_pc_MAX);

fprintf('   Environment created successfully.\n');

%% 4. Quick Training Test
fprintf('\n>> Starting quick training test...\n');
fprintf('   This will run 10 episodes with 24 steps each.\n');
fprintf('   Expected duration: 3-8 minutes.\n\n');

% Training options for quick test
trainOpts = rlTrainingOptions(...
    'MaxEpisodes', 10, ...
    'MaxStepsPerEpisode', 24, ...
    'ScoreAveragingWindow', 5, ...
    'Verbose', true, ...
    'Plots', 'training-progress', ...
    'StopTrainingCriteria', 'EpisodeCount', ...
    'StopTrainingValue', 10);

% Disable parallel computing for stability during test
trainOpts.UseParallel = false;

% Start training
try
    fprintf('   Training started at: %s\n', datestr(now));
    fprintf('   Please wait...\n\n');
    
    % Train the agent
    trainingStats = train(agent, env, trainOpts);
    
    fprintf('\n   Training completed successfully!\n');
    
    % Display results
    fprintf('\n>> Training Results:\n');
    fprintf('   Episodes completed: %d\n', length(trainingStats.EpisodeReward));
    fprintf('   Average reward: %.2f\n', mean(trainingStats.EpisodeReward));
    fprintf('   Final reward: %.2f\n', trainingStats.EpisodeReward(end));
    if length(trainingStats.EpisodeReward) >= 5
        fprintf('   Last 5 episodes average: %.2f\n', mean(trainingStats.EpisodeReward(end-4:end)));
    end
    
    % Save the test agent
    save('quick_test_agent.mat', 'agent', 'trainingStats');
    fprintf('\n   Test agent saved to: quick_test_agent.mat\n');
    
    % Plot simple results
    figure('Name', 'Quick Training Results');
    plot(trainingStats.EpisodeReward, 'b-o', 'LineWidth', 2);
    xlabel('Episode');
    ylabel('Episode Reward');
    title('Quick Training Test - Episode Rewards');
    grid on;
    
catch ME
    fprintf('\n   ERROR during training: %s\n', ME.message);
    fprintf('   Stack trace:\n');
    for i = 1:min(5, length(ME.stack))
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    
    % Additional debugging info
    fprintf('\n   Debugging info:\n');
    fprintf('     Sample time (Ts): %d seconds\n', Ts);
    fprintf('     Noise MeanAttractionConstant: %.6f\n', agentOpts.NoiseOptions.MeanAttractionConstant);
    fprintf('     Stability value: %.6f\n', stability_check);
end

fprintf('\n================================================================\n');
fprintf('   Quick training test completed.\n');
fprintf('================================================================\n');

%% Local Functions
function in = localResetFcn(in, modelName, soc_min, soc_max)
    % Random initial SOC between soc_min and soc_max
    random_soc = rand() * (soc_max - soc_min) + soc_min;
    block_path = [modelName, '/Energy Storage'];
    in = setBlockParameter(in, block_path, 'Initial_kWh_pc', num2str(random_soc));
end

function result = iif(condition, true_val, false_val)
    % Inline if function
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
