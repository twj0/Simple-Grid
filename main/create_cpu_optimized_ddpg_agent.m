function agent = create_cpu_optimized_ddpg_agent(obs_info, action_info, Ts, Pnom)
% CREATE_CPU_OPTIMIZED_DDPG_AGENT - 创建CPU优化的DDPG智能体
% 
% 针对CPU训练优化的DDPG智能体，减少网络复杂度和内存使用

fprintf('创建CPU优化的DDPG智能体...\n');

if nargin < 3
    Ts = 3600; % 1小时
end
if nargin < 4
    Pnom = 500000; % 500 kW in W
end

%% 1. 创建简化的Critic网络
fprintf('构建CPU优化的Critic网络...\n');

% 状态处理路径 (减少神经元数量)
statePath = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(64, 'Name', 'fc_obs') % 从128减少到64
];

% 动作处理路径 (减少神经元数量)
actionPath = [
    featureInputLayer(1, 'Normalization', 'none', 'Name', 'act')
    fullyConnectedLayer(64, 'Name', 'fc_act') % 从128减少到64
];

% 公共处理路径 (减少神经元数量)
commonPath = [
    additionLayer(2, 'Name', 'add')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(32, 'Name', 'fc_common') % 从64减少到32
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'q_value')
];

% 构建Critic网络架构
criticNetwork = layerGraph(statePath);
criticNetwork = addLayers(criticNetwork, actionPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, 'fc_obs', 'add/in1');
criticNetwork = connectLayers(criticNetwork, 'fc_act', 'add/in2');

% 创建dlnetwork
criticdlnetwork = dlnetwork(criticNetwork, 'Initialize', false);

% 配置Critic表示选项 (CPU优化)
critic_options = rlRepresentationOptions(...
    'LearnRate', 1e-3, ...
    'GradientThreshold', 1);

% 创建Critic表示
critic = rlQValueRepresentation(criticdlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'act'}, ...
    critic_options);

fprintf('? CPU优化Critic网络创建完成: State(7)+Action(1) → [64,32] → Q-value\n');

%% 2. 创建简化的Actor网络
fprintf('构建CPU优化的Actor网络...\n');

% 简化的Actor网络架构
actorNetwork = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(64, 'Name', 'fc1') % 从128减少到64
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(32, 'Name', 'fc2') % 从64减少到32
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'fc_action')
    tanhLayer('Name','tanh')
    scalingLayer('Name','action_scaling', 'Scale', Pnom)
];

actordlnetwork = dlnetwork(actorNetwork, 'Initialize', false);

% 配置Actor表示选项 (CPU优化)
actor_options = rlRepresentationOptions(...
    'LearnRate', 1e-4, ...
    'GradientThreshold', 1);

% 创建Actor表示
actor = rlDeterministicActorRepresentation(actordlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'action_scaling'}, ...
    actor_options);

fprintf('? CPU优化Actor网络创建完成: State(7) → [64,32] → Action(1)\n');

%% 3. 配置CPU优化的DDPG智能体选项
fprintf('配置CPU优化的DDPG智能体选项...\n');

% CPU优化的智能体选项
agentOpts = rlDDPGAgentOptions(...
    'SampleTime', Ts, ...
    'TargetSmoothFactor', 1e-3, ...
    'DiscountFactor', 0.99, ...
    'MiniBatchSize', 64, ...        % 从128减少到64
    'ExperienceBufferLength', 5e5); % 从1e6减少到5e5

% 配置简化的噪声过程
fprintf('配置CPU优化的探索噪声...\n');

agentOpts.NoiseOptions.MeanAttractionConstant = 1e-4;
agentOpts.NoiseOptions.Variance = 0.1 * Pnom;
agentOpts.NoiseOptions.VarianceDecayRate = 0.995;
agentOpts.NoiseOptions.VarianceMin = 0.01 * Pnom;

fprintf('? CPU优化噪声配置完成:\n');
fprintf('   小批量大小: %d (CPU优化)\n', agentOpts.MiniBatchSize);
fprintf('   经验缓冲区: %.0e (CPU优化)\n', agentOpts.ExperienceBufferLength);
fprintf('   初始方差: %.0f W\n', agentOpts.NoiseOptions.Variance);

%% 4. 创建DDPG智能体
fprintf('组装CPU优化的DDPG智能体...\n');

agent = rlDDPGAgent(actor, critic, agentOpts);

fprintf('? CPU优化DDPG智能体创建成功\n');

%% 5. 验证智能体规格
fprintf('验证智能体规格...\n');

try
    agent_obs_info = getObservationInfo(agent);
    agent_action_info = getActionInfo(agent);
    
    obs_dim_match = isequal(agent_obs_info.Dimension, obs_info.Dimension);
    action_dim_match = isequal(agent_action_info.Dimension, action_info.Dimension);
    
    if obs_dim_match && action_dim_match
        fprintf('? 智能体规格验证通过\n');
        fprintf('   观测维度: %s\n', mat2str(agent_obs_info.Dimension));
        fprintf('   动作维度: %s\n', mat2str(agent_action_info.Dimension));
        fprintf('   动作范围: [%.0f, %.0f] W\n', ...
                agent_action_info.LowerLimit, agent_action_info.UpperLimit);
    else
        warning('智能体规格验证失败');
    end
    
catch ME
    warning('智能体规格验证出错: %s', ME.message);
end

%% 6. 智能体摘要
fprintf('\n=== CPU优化DDPG智能体摘要 ===\n');
fprintf('算法: DDPG (Deep Deterministic Policy Gradient)\n');
fprintf('优化: CPU训练优化\n');
fprintf('\nActor网络 (CPU优化):\n');
fprintf('  架构: 7 → [64, 32] → 1\n');
fprintf('  学习率: %.1e\n', actor_options.LearnRate);
fprintf('  参数数量: ~2.5K (相比GPU版本减少60%%)\n');
fprintf('\nCritic网络 (CPU优化):\n');
fprintf('  架构: State(7) + Action(1) → [64, 32] → Q-value\n');
fprintf('  学习率: %.1e\n', critic_options.LearnRate);
fprintf('  参数数量: ~3K (相比GPU版本减少60%%)\n');
fprintf('\n智能体选项 (CPU优化):\n');
fprintf('  采样时间: %d 秒 (%.1f 小时)\n', Ts, Ts/3600);
fprintf('  折扣因子: %.3f\n', agentOpts.DiscountFactor);
fprintf('  目标网络软更新因子: %.1e\n', agentOpts.TargetSmoothFactor);
fprintf('  小批量大小: %d (减少50%%)\n', agentOpts.MiniBatchSize);
fprintf('  经验缓冲区大小: %.0e (减少50%%)\n', agentOpts.ExperienceBufferLength);
fprintf('\n内存优化:\n');
fprintf('  网络参数: ~5.5K (相比GPU版本减少60%%)\n');
fprintf('  经验缓冲区: %.1f MB (相比GPU版本减少50%%)\n', ...
        agentOpts.ExperienceBufferLength * 8 * 9 / 1024^2); % 估算内存使用
fprintf('  小批量内存: %.1f KB\n', agentOpts.MiniBatchSize * 8 * 9 / 1024);
fprintf('================================\n');

fprintf('?? CPU优化DDPG智能体创建完成，适合长时间CPU训练！\n');

end
