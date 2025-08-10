function agent = create_gpu_optimized_ddpg_agent(obs_info, action_info, training_device, Ts, Pnom)
% CREATE_GPU_OPTIMIZED_DDPG_AGENT - ����GPU�Ż���DDPG������
% 
% ����Integrated�ļ��еĳɹ��ܹ������30�쳤��ѵ���Ż�
% 
% ����:
%   obs_info - �۲�ռ���Ϣ
%   action_info - �����ռ���Ϣ  
%   training_device - ѵ���豸 ("gpu" �� "cpu")
%   Ts - ����ʱ��
%   Pnom - ��ƹ���

fprintf('����GPU�Ż���DDPG������...\n');

if nargin < 3
    training_device = "cpu";
end
if nargin < 4
    Ts = 3600; % 1Сʱ
end
if nargin < 5
    Pnom = 500000; % 500 kW in W
end

%% 1. ����Critic���� (����Integrated�ĳɹ��ܹ�)
fprintf('����Critic����...\n');

% ״̬����·��
statePath = [
    featureInputLayer(7, 'Normalization', 'zscore', 'Name', 'obs')
    fullyConnectedLayer(128, 'Name', 'fc_obs')
];

% ��������·��  
actionPath = [
    featureInputLayer(1, 'Normalization', 'none', 'Name', 'act')
    fullyConnectedLayer(128, 'Name', 'fc_act')
];

% ��������·��
commonPath = [
    additionLayer(2, 'Name', 'add')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(64, 'Name', 'fc_common')
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

% ����Critic��ʾѡ��
critic_options = rlRepresentationOptions(...
    'LearnRate', 1e-3, ...
    'GradientThreshold', 1);

% GPU�Ż�
if strcmp(training_device, "gpu")
    critic_options.UseDevice = "gpu";
    fprintf('? Critic��������ΪGPUѵ��\n');
end

% ����Critic��ʾ
critic = rlQValueRepresentation(criticdlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'act'}, ...
    critic_options);

fprintf('? Critic���紴�����: State(7)+Action(1) �� [128,64] �� Q-value\n');

%% 2. ����Actor���� (����Integrated�ĳɹ��ܹ�)
fprintf('����Actor����...\n');

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

% ����Actor��ʾѡ��
actor_options = rlRepresentationOptions(...
    'LearnRate', 1e-4, ...
    'GradientThreshold', 1);

% GPU�Ż�
if strcmp(training_device, "gpu")
    actor_options.UseDevice = "gpu";
    fprintf('? Actor��������ΪGPUѵ��\n');
end

% ����Actor��ʾ
actor = rlDeterministicActorRepresentation(actordlnetwork, obs_info, action_info, ...
    'Observation', {'obs'}, ...
    'Action', {'action_scaling'}, ...
    actor_options);

fprintf('? Actor���紴�����: State(7) �� [128,64] �� Action(1)\n');

%% 3. ����DDPG������ѡ�� (���30�쳤��ѵ���Ż�)
fprintf('����DDPG������ѡ��...\n');

% ����Integrated�ĳɹ����ã������30��ѵ���Ż�
agentOpts = rlDDPGAgentOptions(...
    'SampleTime', Ts, ...
    'TargetSmoothFactor', 1e-3, ...  % Ŀ���������������
    'DiscountFactor', 0.99, ...      % �ۿ�����
    'MiniBatchSize', 128, ...        % С������С
    'ExperienceBufferLength', 1e6);  % ����طŻ�������С

% ����Ornstein-Uhlenbeck�������� (��Գ���ѵ���Ż�)
% ��������������Դ����ʱ��(Ts=3600)���е�����ȷ���ȶ���
fprintf('����̽������...\n');

% ȷ�����������ȶ�: abs(1 - MeanAttractionConstant*Ts) <= 1
agentOpts.NoiseOptions.MeanAttractionConstant = 1e-4; % ��0.15�����Ա�֤�ȶ���
agentOpts.NoiseOptions.Variance = 0.1 * Pnom;         % ��ʼ����
agentOpts.NoiseOptions.VarianceDecayRate = 0.995;     % ����˥����
agentOpts.NoiseOptions.VarianceMin = 0.01 * Pnom;     % ��С����

fprintf('? �����������:\n');
fprintf('   ��ֵ��������: %.1e (�ȶ����Ż�)\n', agentOpts.NoiseOptions.MeanAttractionConstant);
fprintf('   ��ʼ����: %.0f W\n', agentOpts.NoiseOptions.Variance);
fprintf('   ����˥����: %.3f\n', agentOpts.NoiseOptions.VarianceDecayRate);

%% 4. ����DDPG������
fprintf('��װDDPG������...\n');

agent = rlDDPGAgent(actor, critic, agentOpts);

fprintf('? DDPG�����崴���ɹ�\n');

%% 5. ��֤��������
fprintf('��֤��������...\n');

try
    % ��ȡ��������Ϣ
    agent_obs_info = getObservationInfo(agent);
    agent_action_info = getActionInfo(agent);
    
    % ��֤ά��
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

%% 6. GPU�ڴ��Ż�
if strcmp(training_device, "gpu")
    fprintf('GPU�ڴ��Ż�...\n');
    try
        % ����GPU�ڴ�
        if gpuDeviceCount > 0
            gpu_device = gpuDevice();
            fprintf('   GPU�ڴ�ʹ��: %.1f GB / %.1f GB\n', ...
                    (gpu_device.TotalMemory - gpu_device.AvailableMemory)/1024^3, ...
                    gpu_device.TotalMemory/1024^3);
            
            % ����ڴ�ʹ�ù��ߣ���������
            memory_usage_ratio = (gpu_device.TotalMemory - gpu_device.AvailableMemory) / gpu_device.TotalMemory;
            if memory_usage_ratio > 0.8
                fprintf('   GPU�ڴ�ʹ���ʹ���(%.1f%%)��ִ������...\n', memory_usage_ratio*100);
                reset(gpu_device);
            end
        end
        fprintf('? GPU�ڴ��Ż����\n');
    catch ME
        warning('GPU�ڴ��Ż�ʧ��: %s', ME.message);
    end
end

%% 7. ������ժҪ
fprintf('\n=== GPU�Ż�DDPG������ժҪ ===\n');
fprintf('�㷨: DDPG (Deep Deterministic Policy Gradient)\n');
fprintf('ѵ���豸: %s\n', upper(training_device));
fprintf('\nActor����:\n');
fprintf('  �ܹ�: 7 �� [128, 64] �� 1\n');
fprintf('  ѧϰ��: %.1e\n', actor_options.LearnRate);
fprintf('  �����: ReLU + Tanh + Scaling\n');
fprintf('\nCritic����:\n');
fprintf('  �ܹ�: State(7) + Action(1) �� [128, 64] �� Q-value\n');
fprintf('  ѧϰ��: %.1e\n', critic_options.LearnRate);
fprintf('  �����: ReLU\n');
fprintf('\n������ѡ��:\n');
fprintf('  ����ʱ��: %d �� (%.1f Сʱ)\n', Ts, Ts/3600);
fprintf('  �ۿ�����: %.3f\n', agentOpts.DiscountFactor);
fprintf('  Ŀ���������������: %.1e\n', agentOpts.TargetSmoothFactor);
fprintf('  С������С: %d\n', agentOpts.MiniBatchSize);
fprintf('  ���黺������С: %.0e\n', agentOpts.ExperienceBufferLength);
fprintf('\n̽������ (Ornstein-Uhlenbeck):\n');
fprintf('  ��ֵ��������: %.1e\n', agentOpts.NoiseOptions.MeanAttractionConstant);
fprintf('  ��ʼ����: %.0f W (%.0f kW)\n', ...
        agentOpts.NoiseOptions.Variance, agentOpts.NoiseOptions.Variance/1000);
fprintf('  ����˥����: %.3f\n', agentOpts.NoiseOptions.VarianceDecayRate);
fprintf('  ��С����: %.0f W (%.0f kW)\n', ...
        agentOpts.NoiseOptions.VarianceMin, agentOpts.NoiseOptions.VarianceMin/1000);
fprintf('================================\n');

fprintf('? GPU�Ż�DDPG�����崴����ɣ�׼������30�������ѵ����\n');

end
