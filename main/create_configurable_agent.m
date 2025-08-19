function agent = create_configurable_agent(algorithm, obs_info, action_info, config)
% CREATE_CONFIGURABLE_AGENT - Create DRL agent based on configuration
%
% This function creates different types of DRL agents (DDPG, TD3, SAC)
% using parameters from the configuration system.
%
% Inputs:
%   algorithm   - Algorithm type: 'ddpg', 'td3', 'sac'
%   obs_info    - Observation space specification
%   action_info - Action space specification
%   config      - Configuration structure from simulation_config()
%
% Output:
%   agent       - Configured DRL agent

fprintf('Creating %s agent with configurable parameters...\n', upper(algorithm));

% Extract power rating for scaling
power_rating = config.system.battery.power_kw * 1000; % Convert to W

switch lower(algorithm)
    case 'ddpg'
        agent = create_ddpg_agent(obs_info, action_info, config, power_rating);
    case 'td3'
        agent = create_td3_agent(obs_info, action_info, config, power_rating);
    case 'sac'
        agent = create_sac_agent(obs_info, action_info, config, power_rating);
    otherwise
        error('Unsupported algorithm: %s. Supported: ddpg, td3, sac', algorithm);
end

fprintf('INFO: %s agent created successfully.\n', upper(algorithm));

end

function agent = create_ddpg_agent(obs_info, action_info, config, power_rating)
% Create DDPG agent with configuration parameters

% Network architecture from config
actor_layers = config.network.actor_layers;
critic_layers = config.network.critic_layers;

% Create Actor Network
actorNetwork = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(actor_layers(1), 'Name', 'fc1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(actor_layers(2), 'Name', 'fc2')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'fc_action')
    tanhLayer('Name','tanh')
    scalingLayer('Name','action_scaling', 'Scale', power_rating)
];

actordlnetwork = dlnetwork(actorNetwork, 'Initialize', false);

actor_options = rlRepresentationOptions(...
    'LearnRate', config.network.actor_learning_rate, ...
    'GradientThreshold', config.advanced.gradient_threshold);

if config.hardware.use_gpu
    actor_options.UseDevice = "gpu";
end

actor = rlDeterministicActorRepresentation(actordlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'action_scaling'}, ...
    actor_options);

% Create Critic Network
statePath = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(critic_layers(1), 'Name', 'fc_obs')
];

actionPath = [
    featureInputLayer(1, 'Normalization', 'none', 'Name', 'act')
    fullyConnectedLayer(critic_layers(1), 'Name', 'fc_act')
];

commonPath = [
    additionLayer(2, 'Name', 'add')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(critic_layers(2), 'Name', 'fc_common')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'q_value')
];

criticNetwork = layerGraph(statePath);
criticNetwork = addLayers(criticNetwork, actionPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, 'fc_obs', 'add/in1');
criticNetwork = connectLayers(criticNetwork, 'fc_act', 'add/in2');

criticdlnetwork = dlnetwork(criticNetwork, 'Initialize', false);

critic_options = rlRepresentationOptions(...
    'LearnRate', config.network.critic_learning_rate, ...
    'GradientThreshold', config.advanced.gradient_threshold);

if config.hardware.use_gpu
    critic_options.UseDevice = "gpu";
end

critic = rlQValueRepresentation(criticdlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'act'}, ...
    critic_options);

% Create DDPG Agent
agentOpts = rlDDPGAgentOptions(...
    'SampleTime', config.simulation.time_step_hours * 3600, ...
    'TargetSmoothFactor', config.network.target_smooth_factor, ...
    'DiscountFactor', config.advanced.discount_factor, ...
    'MiniBatchSize', config.network.batch_size, ...
    'ExperienceBufferLength', config.network.buffer_size);

% Configure noise (fix stability issue)
agentOpts.NoiseOptions.Variance = config.advanced.noise_variance * power_rating;
agentOpts.NoiseOptions.VarianceDecayRate = config.advanced.exploration_decay;
% For stability: abs(1 - MeanAttractionConstant * SampleTime) <= 1
% For the Ornstein-Uhlenbeck process, stability requires that abs(1 - MeanAttractionConstant * SampleTime) <= 1.
% With SampleTime = 3600s, MeanAttractionConstant must be <= 2/3600 (approx. 0.00055).
agentOpts.NoiseOptions.MeanAttractionConstant = 0.0002;  % Very stable value
agentOpts.NoiseOptions.SampleTime = config.simulation.time_step_hours * 3600;

agent = rlDDPGAgent(actor, critic, agentOpts);

end

function agent = create_td3_agent(obs_info, action_info, config, power_rating)
% Create TD3 agent with configuration parameters

% Network architecture from config
actor_layers = config.network.actor_layers;
critic_layers = config.network.critic_layers;

% Create Actor Network (same as DDPG)
actorNetwork = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(actor_layers(1), 'Name', 'fc1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(actor_layers(2), 'Name', 'fc2')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'fc_action')
    tanhLayer('Name','tanh')
    scalingLayer('Name','action_scaling', 'Scale', power_rating)
];

actordlnetwork = dlnetwork(actorNetwork, 'Initialize', false);

actor_options = rlRepresentationOptions(...
    'LearnRate', config.network.actor_learning_rate, ...
    'GradientThreshold', config.advanced.gradient_threshold);

if config.hardware.use_gpu
    actor_options.UseDevice = "gpu";
end

actor = rlDeterministicActorRepresentation(actordlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'action_scaling'}, ...
    actor_options);

% Create Twin Critic Networks
statePath = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(critic_layers(1), 'Name', 'fc_obs')
];

actionPath = [
    featureInputLayer(1, 'Normalization', 'none', 'Name', 'act')
    fullyConnectedLayer(critic_layers(1), 'Name', 'fc_act')
];

commonPath = [
    additionLayer(2, 'Name', 'add')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(critic_layers(2), 'Name', 'fc_common')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'q_value')
];

criticNetwork = layerGraph(statePath);
criticNetwork = addLayers(criticNetwork, actionPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, 'fc_obs', 'add/in1');
criticNetwork = connectLayers(criticNetwork, 'fc_act', 'add/in2');

% Create twin critics
criticdlnetwork1 = dlnetwork(criticNetwork, 'Initialize', false);
criticdlnetwork2 = dlnetwork(criticNetwork, 'Initialize', false);

critic_options = rlRepresentationOptions(...
    'LearnRate', config.network.critic_learning_rate, ...
    'GradientThreshold', config.advanced.gradient_threshold);

if config.hardware.use_gpu
    critic_options.UseDevice = "gpu";
end

critic1 = rlQValueRepresentation(criticdlnetwork1, obs_info, action_info, ...
    'Observation', {'obs'}, 'Action', {'act'}, critic_options);
critic2 = rlQValueRepresentation(criticdlnetwork2, obs_info, action_info, ...
    'Observation', {'obs'}, 'Action', {'act'}, critic_options);

% Create TD3 Agent with simplified options
agentOpts = rlTD3AgentOptions(...
    'SampleTime', config.simulation.time_step_hours * 3600, ...
    'TargetSmoothFactor', config.network.target_smooth_factor, ...
    'DiscountFactor', config.advanced.discount_factor, ...
    'MiniBatchSize', config.network.batch_size, ...
    'ExperienceBufferLength', config.network.buffer_size, ...
    'PolicyUpdateFrequency', 2);

agent = rlTD3Agent(actor, [critic1, critic2], agentOpts);

end

function agent = create_sac_agent(obs_info, action_info, config, power_rating)
% Create SAC agent with configuration parameters

% Network architecture from config
actor_layers = config.network.actor_layers;
critic_layers = config.network.critic_layers;

% Create Stochastic Actor Network
commonLayers = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(actor_layers(1), 'Name', 'fc1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(actor_layers(2), 'Name', 'fc2')
    reluLayer('Name', 'relu2')
];

meanLayers = [
    fullyConnectedLayer(1, 'Name', 'fc_mean')
    tanhLayer('Name', 'tanh_mean')
    scalingLayer('Name', 'mean_scaling', 'Scale', power_rating)
];

stdLayers = [
    fullyConnectedLayer(1, 'Name', 'fc_std')
    softplusLayer('Name', 'softplus_std')
    scalingLayer('Name', 'std_scaling', 'Scale', 0.1*power_rating)
];

actorNetwork = layerGraph(commonLayers);
actorNetwork = addLayers(actorNetwork, meanLayers);
actorNetwork = addLayers(actorNetwork, stdLayers);
actorNetwork = connectLayers(actorNetwork, 'relu2', 'fc_mean');
actorNetwork = connectLayers(actorNetwork, 'relu2', 'fc_std');

actordlnetwork = dlnetwork(actorNetwork, 'Initialize', false);

% Create SAC actor using modern rlContinuousGaussianActor (recommended approach)
device = "cpu";
if config.hardware.use_gpu
    device = "gpu";
end

actor = rlContinuousGaussianActor(actordlnetwork, obs_info, action_info, ...
    'ActionMeanOutputNames', {'mean_scaling'}, ...
    'ActionStandardDeviationOutputNames', {'std_scaling'}, ...
    'ObservationInputNames', {'obs'}, ...
    'UseDevice', device);

% Create Twin Critic Networks (same as TD3)
statePath = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(critic_layers(1), 'Name', 'fc_obs')
];

actionPath = [
    featureInputLayer(1, 'Normalization', 'none', 'Name', 'act')
    fullyConnectedLayer(critic_layers(1), 'Name', 'fc_act')
];

commonPath = [
    additionLayer(2, 'Name', 'add')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(critic_layers(2), 'Name', 'fc_common')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'q_value')
];

criticNetwork = layerGraph(statePath);
criticNetwork = addLayers(criticNetwork, actionPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, 'fc_obs', 'add/in1');
criticNetwork = connectLayers(criticNetwork, 'fc_act', 'add/in2');

criticdlnetwork1 = dlnetwork(criticNetwork, 'Initialize', false);
criticdlnetwork2 = dlnetwork(criticNetwork, 'Initialize', false);

critic_options = rlRepresentationOptions(...
    'LearnRate', config.network.critic_learning_rate, ...
    'GradientThreshold', config.advanced.gradient_threshold);

if config.hardware.use_gpu
    critic_options.UseDevice = "gpu";
end

critic1 = rlQValueRepresentation(criticdlnetwork1, obs_info, action_info, ...
    'Observation', {'obs'}, 'Action', {'act'}, critic_options);
critic2 = rlQValueRepresentation(criticdlnetwork2, obs_info, action_info, ...
    'Observation', {'obs'}, 'Action', {'act'}, critic_options);

% Create SAC Agent with simplified options
agentOpts = rlSACAgentOptions(...
    'SampleTime', config.simulation.time_step_hours * 3600, ...
    'DiscountFactor', config.advanced.discount_factor, ...
    'MiniBatchSize', config.network.batch_size, ...
    'ExperienceBufferLength', config.network.buffer_size, ...
    'TargetSmoothFactor', config.network.target_smooth_factor);

agent = rlSACAgent(actor, [critic1, critic2], agentOpts);

end
