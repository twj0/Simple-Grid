% =========================================================================
%                  quick_training_test.m
% -------------------------------------------------------------------------
% Description:
%   Quick test script to verify the DRL training setup works correctly.
%   This runs a short training session with only a few episodes.
% =========================================================================

clear; clc; close all;

fprintf('================================================================\n');
fprintf('   Quick DRL Training Test\n');
fprintf('================================================================\n\n');

%% 1. Load Data
fprintf('>> Loading simulation data...\n');
try
    % Move up one directory to access the data files
    data_path = fullfile('..', 'simulation_data_10days_random.mat');
    load(data_path);
    fprintf('   Data loaded successfully for %d days.\n', simulationDays);
catch
    % If not found, try current directory
    try
        load('simulation_data_10days_random.mat');
        fprintf('   Data loaded from current directory.\n');
    catch ME
        error('Could not find simulation data file. Please ensure simulation_data_10days_random.mat exists.');
    end
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

% System parameters
Ts = 3600; % Sample time (1 hour)
Pnom = 500e3; % Nominal power (500 kW)
num_observations = 7;

% Define observation and action spaces
obsInfo = rlNumericSpec([num_observations 1], 'Name', 'Microgrid State');
actInfo = rlNumericSpec([1 1], 'LowerLimit', -Pnom, 'UpperLimit', Pnom, 'Name', 'Battery Power');

% Create simple DDPG agent (simplified for quick test)
fprintf('   Creating DDPG agent...\n');

% Actor network
actorNetwork = [
    featureInputLayer(num_observations, 'Name', 'obs')
    fullyConnectedLayer(64, 'Name', 'fc1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(32, 'Name', 'fc2')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'fc_out')
    tanhLayer('Name', 'tanh')
    scalingLayer('Name', 'scaling', 'Scale', Pnom)
];

actorNet = dlnetwork(actorNetwork);
actor = rlDeterministicActorRepresentation(actorNet, obsInfo, actInfo, ...
    'Observation', {'obs'}, 'Action', {'scaling'});

% Critic network (simplified)
% State path
statePath = [
    featureInputLayer(num_observations, 'Name', 'state')
    fullyConnectedLayer(64, 'Name', 'fc_state')
];

% Action path
actionPath = [
    featureInputLayer(1, 'Name', 'action')
    fullyConnectedLayer(64, 'Name', 'fc_action')
];

% Common path
commonPath = [
    additionLayer(2, 'Name', 'add')
    reluLayer('Name', 'relu')
    fullyConnectedLayer(32, 'Name', 'fc_common')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'q_value')
];

% Build critic network
criticNetwork = layerGraph(statePath);
criticNetwork = addLayers(criticNetwork, actionPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, 'fc_state', 'add/in1');
criticNetwork = connectLayers(criticNetwork, 'fc_action', 'add/in2');

criticNet = dlnetwork(criticNetwork);
critic = rlQValueRepresentation(criticNet, obsInfo, actInfo, ...
    'Observation', {'state'}, 'Action', {'action'});

% Create DDPG agent
agentOpts = rlDDPGAgentOptions(...
    'SampleTime', Ts, ...
    'DiscountFactor', 0.99, ...
    'MiniBatchSize', 64, ...
    'ExperienceBufferLength', 1e5);

agent = rlDDPGAgent(actor, critic, agentOpts);

% Assign agent to base workspace
assignin('base', 'agentObj', agent);
fprintf('   DDPG agent created and assigned to workspace.\n');

% Create Simulink environment
agent_block_path = [model_name, '/RL Agent'];
env = rlSimulinkEnv(model_name, agent_block_path, obsInfo, actInfo);

% Reset function for random initial SOC
env.ResetFcn = @(in) localResetFcn(in, model_name, 30, 80);

fprintf('   Environment created successfully.\n');

%% 4. Quick Training Test
fprintf('\n>> Starting quick training test...\n');
fprintf('   This will run 5 episodes with 24 steps each.\n');
fprintf('   Expected duration: 2-5 minutes.\n\n');

% Training options for quick test
trainOpts = rlTrainingOptions(...
    'MaxEpisodes', 5, ...
    'MaxStepsPerEpisode', 24, ...
    'Verbose', true, ...
    'Plots', 'training-progress', ...
    'StopTrainingCriteria', 'EpisodeCount', ...
    'StopTrainingValue', 5);

% Start training
try
    fprintf('   Training started at: %s\n', datestr(now));
    trainingStats = train(agent, env, trainOpts);
    fprintf('\n   Training completed successfully!\n');
    
    % Display results
    fprintf('\n>> Training Results:\n');
    fprintf('   Episodes completed: %d\n', length(trainingStats.EpisodeReward));
    fprintf('   Average reward: %.2f\n', mean(trainingStats.EpisodeReward));
    fprintf('   Final reward: %.2f\n', trainingStats.EpisodeReward(end));
    
    % Save the test agent
    save('quick_test_agent.mat', 'agent', 'trainingStats');
    fprintf('\n   Test agent saved to: quick_test_agent.mat\n');
    
catch ME
    fprintf('\n   ERROR during training: %s\n', ME.message);
    fprintf('   Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
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
