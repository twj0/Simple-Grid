function agent = create_td3_agent(obs_info, action_info, training_config)
% CREATE_TD3_AGENT - Create TD3 agent for microgrid control
% ?????????????TD3??????
%
% TD3 (Twin Delayed Deep Deterministic Policy Gradient) improves upon DDPG by:
% TD3?????????????DDPG??
% 1. Twin critic networks to reduce overestimation bias ?????????????????????
% 2. Delayed policy updates to reduce variance ???????????????
% 3. Target policy smoothing for robustness ?????????????????
%
% Inputs:
%   obs_info - Observation space information
%   action_info - Action space information  
%   training_config - TD3 training configuration
%
% Outputs:
%   agent - TD3 agent object
%
% Author: Microgrid DRL Team
% Date: 2025-01-XX

fprintf('Creating TD3 agent for microgrid control...\n');

%% === Validate Inputs ===
% ??????? (?????MATLAB?????????)
assert(isa(obs_info, 'rlNumericSpec') || isa(obs_info, 'rl.util.rlNumericSpec'), ...
    'obs_info must be rlNumericSpec or rl.util.rlNumericSpec');
assert(isa(action_info, 'rlNumericSpec') || isa(action_info, 'rl.util.rlNumericSpec'), ...
    'action_info must be rlNumericSpec or rl.util.rlNumericSpec');
assert(isstruct(training_config), 'training_config must be a structure');
assert(strcmp(training_config.algorithm, 'TD3'), 'Configuration must be for TD3 algorithm');

%% === Create Actor Network ===
% ????Actor????
fprintf('Creating actor network...\n');
actor_network = create_actor_network(obs_info, action_info, training_config);

%% === Create Twin Critic Networks ===
% ?????Critic????
fprintf('Creating twin critic networks...\n');
critic1_network = create_critic_network(obs_info, action_info, training_config, 1);
critic2_network = create_critic_network(obs_info, action_info, training_config, 2);

%% === Configure Actor Options ===
% ????Actor???
actor_options = rlRepresentationOptions(...
    'LearnRate', training_config.network.actor.learning_rate, ...
    'GradientThreshold', training_config.regularization.gradient_threshold, ...
    'L2RegularizationFactor', training_config.regularization.l2_regularization_factor);

%% === Configure Critic Options ===
% ????Critic???
critic_options = rlRepresentationOptions(...
    'LearnRate', training_config.network.critic.learning_rate, ...
    'GradientThreshold', training_config.regularization.gradient_threshold, ...
    'L2RegularizationFactor', training_config.regularization.l2_regularization_factor);

%% === Create Representations ===
% ???????
actor = rlDeterministicActorRepresentation(actor_network, obs_info, action_info, ...
    'Observation', {'observation'}, 'Action', {'action'}, actor_options);

critic1 = rlQValueRepresentation(critic1_network, obs_info, action_info, ...
    'Observation', {'state'}, 'Action', {'action'}, critic_options);

critic2 = rlQValueRepresentation(critic2_network, obs_info, action_info, ...
    'Observation', {'state'}, 'Action', {'action'}, critic_options);

%% === Configure TD3 Agent Options ===
% ????TD3?????????
agent_options = rlTD3AgentOptions(...
    'SampleTime', training_config.td3.sample_time, ...
    'TargetSmoothFactor', training_config.td3.target_smooth_factor, ...
    'DiscountFactor', training_config.td3.discount_factor, ...
    'MiniBatchSize', training_config.td3.mini_batch_size, ...
    'ExperienceBufferLength', training_config.td3.experience_buffer_length, ...
    'PolicyUpdateFrequency', training_config.td3.policy_update_frequency);

%% === Configure Exploration Noise ===
% ??????????? - ??จน??????????
try
    % ?????????????
    agent_options.ExplorationModel = rl.option.GaussianActionNoise(...
        'Variance', training_config.exploration.noise_variance);
catch
    % ?????????????????
    fprintf('?? ??????????????\n');
end

%% === Create TD3 Agent ===
% ????TD3??????
fprintf('Assembling TD3 agent...\n');
agent = rlTD3Agent(actor, [critic1, critic2], agent_options);

%% === Agent Summary ===
% ????????
fprintf('\n=== TD3 Agent Summary ===\n');
fprintf('Algorithm: %s\n', training_config.algorithm);
fprintf('Actor Network:\n');
fprintf('  Hidden Layers: %s\n', mat2str(training_config.network.actor.hidden_layers));
fprintf('  Learning Rate: %.2e\n', training_config.network.actor.learning_rate);
fprintf('Twin Critic Networks:\n');
fprintf('  Hidden Layers: %s\n', mat2str(training_config.network.critic.hidden_layers));
fprintf('  Learning Rate: %.2e\n', training_config.network.critic.learning_rate);
fprintf('Agent Options:\n');
fprintf('  Discount Factor: %.3f\n', training_config.td3.discount_factor);
fprintf('  Target Smooth Factor: %.2e\n', training_config.td3.target_smooth_factor);
fprintf('  Policy Update Frequency: %d\n', training_config.td3.policy_update_frequency);
fprintf('  Mini-batch Size: %d\n', training_config.td3.mini_batch_size);
fprintf('  Experience Buffer: %.0e\n', training_config.td3.experience_buffer_length);
fprintf('  Target Policy Noise: %.2f\n', training_config.td3.target_policy_noise);
fprintf('TD3 agent creation completed\n');

end

%% === Helper Functions ===
% ????????

function actor_network = create_actor_network(obs_info, action_info, config)
% Create actor network architecture Actor??????
% Actor???????? -> ????(????????)

obs_dim = obs_info.Dimension(1);
action_dim = action_info.Dimension(1);
hidden_layers = config.network.actor.hidden_layers;

% Build network layers ?????????
% Preallocate layers array for better performance ???????????????????
num_layers = 1 + 2*length(hidden_layers) + 3; % input + (fc+relu)*hidden + output+tanh+scaling
layers = cell(num_layers, 1);
layer_idx = 1;

% Input layer ?????
layers{layer_idx} = featureInputLayer(obs_dim, 'Normalization', 'none', 'Name', 'observation');
layer_idx = layer_idx + 1;

% Add hidden layers ?????????
for i = 1:length(hidden_layers)
    layer_name = sprintf('actor_fc%d', i);
    layers{layer_idx} = fullyConnectedLayer(hidden_layers(i), 'Name', layer_name);
    layer_idx = layer_idx + 1;
    layers{layer_idx} = reluLayer('Name', sprintf('actor_relu%d', i));
    layer_idx = layer_idx + 1;
end

% Output layer with tanh activation ??tanh??????????
layers{layer_idx} = fullyConnectedLayer(action_dim, 'Name', 'actor_output');
layer_idx = layer_idx + 1;
layers{layer_idx} = tanhLayer('Name', 'action_tanh');  % Output in [-1, 1] ?????[-1,1]
layer_idx = layer_idx + 1;
layers{layer_idx} = scalingLayer('Name', 'action_scaling', ...
    'Scale', action_info.UpperLimit, ...
    'Bias', (action_info.UpperLimit + action_info.LowerLimit)/2);  % Scale to action range ?????????????

% Convert cell array to layer array ???????????????????
layers = [layers{:}];

actor_network = layerGraph(layers);

fprintf('Actor network: %d -> %s -> %d\n', obs_dim, mat2str(hidden_layers), action_dim);
end

function critic_network = create_critic_network(obs_info, action_info, config, critic_id)
% Create critic network architecture Critic??????
% Critic???????-?????? -> Q?

obs_dim = obs_info.Dimension(1);
action_dim = action_info.Dimension(1);
hidden_layers = config.network.critic.hidden_layers;

% State pathway ??????
state_path = [
    featureInputLayer(obs_dim, 'Normalization', 'none', 'Name', 'state')
    fullyConnectedLayer(hidden_layers(1), 'Name', sprintf('critic%d_state_fc1', critic_id))
    reluLayer('Name', sprintf('critic%d_state_relu1', critic_id))
];

% Action pathway ????????
action_path = [
    featureInputLayer(action_dim, 'Normalization', 'none', 'Name', 'action')
    fullyConnectedLayer(hidden_layers(1), 'Name', sprintf('critic%d_action_fc1', critic_id))
];

% Common pathway after concatenation ?????????????
common_path = [
    additionLayer(2, 'Name', sprintf('critic%d_state_action_add', critic_id))
    reluLayer('Name', sprintf('critic%d_common_relu1', critic_id))
];

% Add remaining hidden layers ????????????
% Preallocate for better performance ??????????????
if length(hidden_layers) > 1
    num_additional_layers = 2*(length(hidden_layers)-1) + 1; % (fc+relu)*(remaining) + output
    additional_layers = cell(num_additional_layers, 1);
    layer_idx = 1;
    
    for i = 2:length(hidden_layers)
        additional_layers{layer_idx} = fullyConnectedLayer(hidden_layers(i), 'Name', sprintf('critic%d_fc%d', critic_id, i));
        layer_idx = layer_idx + 1;
        additional_layers{layer_idx} = reluLayer('Name', sprintf('critic%d_relu%d', critic_id, i));
        layer_idx = layer_idx + 1;
    end
    
    % Q-value output Q????
    additional_layers{layer_idx} = fullyConnectedLayer(1, 'Name', sprintf('critic%d_q_value', critic_id));
    
    % Convert cell array to layer array and concatenate
    % Ensure proper orientation for concatenation
    for i = 1:length(additional_layers)
        if ~isempty(additional_layers{i})
            common_path = [common_path; additional_layers{i}];
        end
    end
else
    % Q-value output Q????
    common_path = [common_path
        fullyConnectedLayer(1, 'Name', sprintf('critic%d_q_value', critic_id))
    ];
end

% Assemble the network ???????
critic_network = layerGraph();
critic_network = addLayers(critic_network, state_path);
critic_network = addLayers(critic_network, action_path);
critic_network = addLayers(critic_network, common_path);

% Connect the pathways ????????
critic_network = connectLayers(critic_network, sprintf('critic%d_state_relu1', critic_id), sprintf('critic%d_state_action_add/in1', critic_id));
critic_network = connectLayers(critic_network, sprintf('critic%d_action_fc1', critic_id), sprintf('critic%d_state_action_add/in2', critic_id));

fprintf('Critic %d network: State(%d) + Action(%d) -> %s -> Q-value\n', ...
    critic_id, obs_dim, action_dim, mat2str(hidden_layers));
end