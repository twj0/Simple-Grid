function agent = create_cpu_optimized_ddpg_agent(obs_info, action_info, Ts, Pnom)
% CREATE_CPU_OPTIMIZED_DDPG_AGENT - ����CPU�Ż���DDPG������
% 
% ���CPUѵ���Ż���DDPG�����壬�������縴�ӶȺ��ڴ�ʹ��

fprintf('����CPU�Ż���DDPG������...\n');

if nargin < 3
    Ts = 3600; % 1Сʱ
end
if nargin < 4
    Pnom = 500000; % 500 kW in W
end

%% 1. �����򻯵�Critic����
fprintf('����CPU�Ż���Critic����...\n');

% ״̬����·�� (������Ԫ����)
statePath = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(64, 'Name', 'fc_obs') % ��128���ٵ�64
];

% ��������·�� (������Ԫ����)
actionPath = [
    featureInputLayer(1, 'Normalization', 'none', 'Name', 'act')
    fullyConnectedLayer(64, 'Name', 'fc_act') % ��128���ٵ�64
];

% ��������·�� (������Ԫ����)
commonPath = [
    additionLayer(2, 'Name', 'add')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(32, 'Name', 'fc_common') % ��64���ٵ�32
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'q_value')
];

% ����Critic����ܹ�
criticNetwork = layerGraph(statePath);
criticNetwork = addLayers(criticNetwork, actionPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, 'fc_obs', 'add/in1');
criticNetwork = connectLayers(criticNetwork, 'fc_act', 'add/in2');

% ����dlnetwork
criticdlnetwork = dlnetwork(criticNetwork, 'Initialize', false);

% ����Critic��ʾѡ�� (CPU�Ż�)
critic_options = rlRepresentationOptions(...
    'LearnRate', 1e-3, ...
    'GradientThreshold', 1);

% ����Critic��ʾ
critic = rlQValueRepresentation(criticdlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'act'}, ...
    critic_options);

fprintf('? CPU�Ż�Critic���紴�����: State(7)+Action(1) �� [64,32] �� Q-value\n');

%% 2. �����򻯵�Actor����
fprintf('����CPU�Ż���Actor����...\n');

% �򻯵�Actor����ܹ�
actorNetwork = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(64, 'Name', 'fc1') % ��128���ٵ�64
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(32, 'Name', 'fc2') % ��64���ٵ�32
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'fc_action')
    tanhLayer('Name','tanh')
    scalingLayer('Name','action_scaling', 'Scale', Pnom)
];

actordlnetwork = dlnetwork(actorNetwork, 'Initialize', false);

% ����Actor��ʾѡ�� (CPU�Ż�)
actor_options = rlRepresentationOptions(...
    'LearnRate', 1e-4, ...
    'GradientThreshold', 1);

% ����Actor��ʾ
actor = rlDeterministicActorRepresentation(actordlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'action_scaling'}, ...
    actor_options);

fprintf('? CPU�Ż�Actor���紴�����: State(7) �� [64,32] �� Action(1)\n');

%% 3. ����CPU�Ż���DDPG������ѡ��
fprintf('����CPU�Ż���DDPG������ѡ��...\n');

% CPU�Ż���������ѡ��
agentOpts = rlDDPGAgentOptions(...
    'SampleTime', Ts, ...
    'TargetSmoothFactor', 1e-3, ...
    'DiscountFactor', 0.99, ...
    'MiniBatchSize', 64, ...        % ��128���ٵ�64
    'ExperienceBufferLength', 5e5); % ��1e6���ٵ�5e5

% ���ü򻯵���������
fprintf('����CPU�Ż���̽������...\n');

agentOpts.NoiseOptions.MeanAttractionConstant = 1e-4;
agentOpts.NoiseOptions.Variance = 0.1 * Pnom;
agentOpts.NoiseOptions.VarianceDecayRate = 0.995;
agentOpts.NoiseOptions.VarianceMin = 0.01 * Pnom;

fprintf('? CPU�Ż������������:\n');
fprintf('   С������С: %d (CPU�Ż�)\n', agentOpts.MiniBatchSize);
fprintf('   ���黺����: %.0e (CPU�Ż�)\n', agentOpts.ExperienceBufferLength);
fprintf('   ��ʼ����: %.0f W\n', agentOpts.NoiseOptions.Variance);

%% 4. ����DDPG������
fprintf('��װCPU�Ż���DDPG������...\n');

agent = rlDDPGAgent(actor, critic, agentOpts);

fprintf('? CPU�Ż�DDPG�����崴���ɹ�\n');

%% 5. ��֤��������
fprintf('��֤��������...\n');

try
    agent_obs_info = getObservationInfo(agent);
    agent_action_info = getActionInfo(agent);
    
    obs_dim_match = isequal(agent_obs_info.Dimension, obs_info.Dimension);
    action_dim_match = isequal(agent_action_info.Dimension, action_info.Dimension);
    
    if obs_dim_match && action_dim_match
        fprintf('? ����������֤ͨ��\n');
        fprintf('   �۲�ά��: %s\n', mat2str(agent_obs_info.Dimension));
        fprintf('   ����ά��: %s\n', mat2str(agent_action_info.Dimension));
        fprintf('   ������Χ: [%.0f, %.0f] W\n', ...
                agent_action_info.LowerLimit, agent_action_info.UpperLimit);
    else
        warning('����������֤ʧ��');
    end
    
catch ME
    warning('����������֤����: %s', ME.message);
end

%% 6. ������ժҪ
fprintf('\n=== CPU�Ż�DDPG������ժҪ ===\n');
fprintf('�㷨: DDPG (Deep Deterministic Policy Gradient)\n');
fprintf('�Ż�: CPUѵ���Ż�\n');
fprintf('\nActor���� (CPU�Ż�):\n');
fprintf('  �ܹ�: 7 �� [64, 32] �� 1\n');
fprintf('  ѧϰ��: %.1e\n', actor_options.LearnRate);
fprintf('  ��������: ~2.5K (���GPU�汾����60%%)\n');
fprintf('\nCritic���� (CPU�Ż�):\n');
fprintf('  �ܹ�: State(7) + Action(1) �� [64, 32] �� Q-value\n');
fprintf('  ѧϰ��: %.1e\n', critic_options.LearnRate);
fprintf('  ��������: ~3K (���GPU�汾����60%%)\n');
fprintf('\n������ѡ�� (CPU�Ż�):\n');
fprintf('  ����ʱ��: %d �� (%.1f Сʱ)\n', Ts, Ts/3600);
fprintf('  �ۿ�����: %.3f\n', agentOpts.DiscountFactor);
fprintf('  Ŀ���������������: %.1e\n', agentOpts.TargetSmoothFactor);
fprintf('  С������С: %d (����50%%)\n', agentOpts.MiniBatchSize);
fprintf('  ���黺������С: %.0e (����50%%)\n', agentOpts.ExperienceBufferLength);
fprintf('\n�ڴ��Ż�:\n');
fprintf('  �������: ~5.5K (���GPU�汾����60%%)\n');
fprintf('  ���黺����: %.1f MB (���GPU�汾����50%%)\n', ...
        agentOpts.ExperienceBufferLength * 8 * 9 / 1024^2); % �����ڴ�ʹ��
fprintf('  С�����ڴ�: %.1f KB\n', agentOpts.MiniBatchSize * 8 * 9 / 1024);
fprintf('================================\n');

fprintf('?? CPU�Ż�DDPG�����崴����ɣ��ʺϳ�ʱ��CPUѵ����\n');

end
