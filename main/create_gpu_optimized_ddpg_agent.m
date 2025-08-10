function agent = create_gpu_optimized_ddpg_agent(obs_info, action_info, training_device, Ts, Pnom)
% CREATE_GPU_OPTIMIZED_DDPG_AGENT - 创建GPU优化的DDPG智能体
% 
% 基于Integrated文件夹的成功架构，针对30天长期训练优化
% 
% 输入:
%   obs_info - 观测空间信息
%   action_info - 动作空间信息  
%   training_device - 训练设备 ("gpu" 或 "cpu")
%   Ts - 采样时间
%   Pnom - 标称功率

fprintf('创建GPU优化的DDPG智能体...\n');

if nargin < 3
    training_device = "cpu";
end
if nargin < 4
    Ts = 3600; % 1小时
end
if nargin < 5
    Pnom = 500000; % 500 kW in W
end

%% 1. 创建Critic网络 (基于Integrated的成功架构)
fprintf('构建Critic网络...\n');

% 状态处理路径
statePath = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(128, 'Name', 'fc_obs')
];

% 动作处理路径  
actionPath = [
    featureInputLayer(1, 'Normalization', 'none', 'Name', 'act')
    fullyConnectedLayer(128, 'Name', 'fc_act')
];

% 公共处理路径
commonPath = [
    additionLayer(2, 'Name', 'add')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(64, 'Name', 'fc_common')
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

% 配置Critic表示选项
critic_options = rlRepresentationOptions(...
    'LearnRate', 1e-3, ...
    'GradientThreshold', 1);

% GPU优化
if strcmp(training_device, "gpu")
    critic_options.UseDevice = "gpu";
    fprintf('? Critic网络配置为GPU训练\n');
end

% 创建Critic表示
critic = rlQValueRepresentation(criticdlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'act'}, ...
    critic_options);

fprintf('? Critic网络创建完成: State(7)+Action(1) → [128,64] → Q-value\n');

%% 2. 创建Actor网络 (基于Integrated的成功架构)
fprintf('构建Actor网络...\n');

actorNetwork = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(128, 'Name', 'fc1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(64, 'Name', 'fc2')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'fc_action')
    tanhLayer('Name','tanh')
    scalingLayer('Name','action_scaling', 'Scale', Pnom)
];

actordlnetwork = dlnetwork(actorNetwork, 'Initialize', false);

% 配置Actor表示选项
actor_options = rlRepresentationOptions(...
    'LearnRate', 1e-4, ...
    'GradientThreshold', 1);

% GPU优化
if strcmp(training_device, "gpu")
    actor_options.UseDevice = "gpu";
    fprintf('? Actor网络配置为GPU训练\n');
end

% 创建Actor表示
actor = rlDeterministicActorRepresentation(actordlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'action_scaling'}, ...
    actor_options);

fprintf('? Actor网络创建完成: State(7) → [128,64] → Action(1)\n');

%% 3. 配置DDPG智能体选项 (针对30天长期训练优化)
fprintf('配置DDPG智能体选项...\n');

% 基于Integrated的成功配置，但针对30天训练优化
agentOpts = rlDDPGAgentOptions(...
    'SampleTime', Ts, ...
    'TargetSmoothFactor', 1e-3, ...  % 目标网络软更新因子
    'DiscountFactor', 0.99, ...      % 折扣因子
    'MiniBatchSize', 128, ...        % 小批量大小
    'ExperienceBufferLength', 1e6);  % 经验回放缓冲区大小

% 配置Ornstein-Uhlenbeck噪声过程 (针对长期训练优化)
% 噪声参数必须针对大采样时间(Ts=3600)进行调整以确保稳定性
fprintf('配置探索噪声...\n');

% 确保噪声过程稳定: abs(1 - MeanAttractionConstant*Ts) <= 1
agentOpts.NoiseOptions.MeanAttractionConstant = 1e-4; % 从0.15缩放以保证稳定性
agentOpts.NoiseOptions.Variance = 0.1 * Pnom;         % 初始方差
agentOpts.NoiseOptions.VarianceDecayRate = 0.995;     % 方差衰减率
agentOpts.NoiseOptions.VarianceMin = 0.01 * Pnom;     % 最小方差

fprintf('? 噪声配置完成:\n');
fprintf('   均值吸引常数: %.1e (稳定性优化)\n', agentOpts.NoiseOptions.MeanAttractionConstant);
fprintf('   初始方差: %.0f W\n', agentOpts.NoiseOptions.Variance);
fprintf('   方差衰减率: %.3f\n', agentOpts.NoiseOptions.VarianceDecayRate);

%% 4. 创建DDPG智能体
fprintf('组装DDPG智能体...\n');

agent = rlDDPGAgent(actor, critic, agentOpts);

fprintf('? DDPG智能体创建成功\n');

%% 5. 验证智能体规格
fprintf('验证智能体规格...\n');

try
    % 获取智能体信息
    agent_obs_info = getObservationInfo(agent);
    agent_action_info = getActionInfo(agent);
    
    % 验证维度
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

%% 6. GPU内存优化
if strcmp(training_device, "gpu")
    fprintf('GPU内存优化...\n');
    try
        % 清理GPU内存
        if gpuDeviceCount > 0
            gpu_device = gpuDevice();
            fprintf('   GPU内存使用: %.1f GB / %.1f GB\n', ...
                    (gpu_device.TotalMemory - gpu_device.AvailableMemory)/1024^3, ...
                    gpu_device.TotalMemory/1024^3);
            
            % 如果内存使用过高，进行清理
            memory_usage_ratio = (gpu_device.TotalMemory - gpu_device.AvailableMemory) / gpu_device.TotalMemory;
            if memory_usage_ratio > 0.8
                fprintf('   GPU内存使用率过高(%.1f%%)，执行清理...\n', memory_usage_ratio*100);
                reset(gpu_device);
            end
        end
        fprintf('? GPU内存优化完成\n');
    catch ME
        warning('GPU内存优化失败: %s', ME.message);
    end
end

%% 7. 智能体摘要
fprintf('\n=== GPU优化DDPG智能体摘要 ===\n');
fprintf('算法: DDPG (Deep Deterministic Policy Gradient)\n');
fprintf('训练设备: %s\n', upper(training_device));
fprintf('\nActor网络:\n');
fprintf('  架构: 7 → [128, 64] → 1\n');
fprintf('  学习率: %.1e\n', actor_options.LearnRate);
fprintf('  激活函数: ReLU + Tanh + Scaling\n');
fprintf('\nCritic网络:\n');
fprintf('  架构: State(7) + Action(1) → [128, 64] → Q-value\n');
fprintf('  学习率: %.1e\n', critic_options.LearnRate);
fprintf('  激活函数: ReLU\n');
fprintf('\n智能体选项:\n');
fprintf('  采样时间: %d 秒 (%.1f 小时)\n', Ts, Ts/3600);
fprintf('  折扣因子: %.3f\n', agentOpts.DiscountFactor);
fprintf('  目标网络软更新因子: %.1e\n', agentOpts.TargetSmoothFactor);
fprintf('  小批量大小: %d\n', agentOpts.MiniBatchSize);
fprintf('  经验缓冲区大小: %.0e\n', agentOpts.ExperienceBufferLength);
fprintf('\n探索噪声 (Ornstein-Uhlenbeck):\n');
fprintf('  均值吸引常数: %.1e\n', agentOpts.NoiseOptions.MeanAttractionConstant);
fprintf('  初始方差: %.0f W (%.0f kW)\n', ...
        agentOpts.NoiseOptions.Variance, agentOpts.NoiseOptions.Variance/1000);
fprintf('  方差衰减率: %.3f\n', agentOpts.NoiseOptions.VarianceDecayRate);
fprintf('  最小方差: %.0f W (%.0f kW)\n', ...
        agentOpts.NoiseOptions.VarianceMin, agentOpts.NoiseOptions.VarianceMin/1000);
fprintf('================================\n');

fprintf('? GPU优化DDPG智能体创建完成，准备进行30天高性能训练！\n');

end
