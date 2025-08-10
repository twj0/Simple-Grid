function train_30day_gpu_simulation()
% TRAIN_30DAY_GPU_SIMULATION - 30���������������GPU����ѵ��
% 
% ����Integrated�ļ��еĳɹ�ʵ�֣�����������30����������ģ�����
% ����:
% - 30�������������
% - GPU����ѵ��
% - �����ʱ�䲽������
% - �������Ż�����
% - �����Ľ������ͷ���

fprintf('=========================================================================\n');
fprintf('                30���������������GPU����ѵ��\n');
fprintf('                30-Day Physical World High-Performance GPU Simulation\n');
fprintf('=========================================================================\n');
fprintf('��ʼʱ��: %s\n', string(datetime('now')));
fprintf('=========================================================================\n\n');

%% 1. ϵͳ���ú�GPU���
fprintf('����1: ϵͳ���ú�GPU���...\n');

% ǿ��ʹ�������Ⱦ����GPU��������
opengl('software');
fprintf('? ͼ����Ⱦ������Ϊ���ģʽ��ȷ���ȶ���\n');

% GPU��������
trainingDevice = "cpu";
if ~isempty(ver('parallel')) && gpuDeviceCount > 0
    try
        gpu_info = gpuDevice(1);
        trainingDevice = "gpu";
        fprintf('? GPU���ɹ���ѵ����ʹ��GPU����\n');
        fprintf('   GPU�ͺ�: %s\n', gpu_info.Name);
        fprintf('   GPU�ڴ�: %.1f GB\n', gpu_info.AvailableMemory/1024^3);
        fprintf('   ��������: %.1f\n', gpu_info.ComputeCapability);
    catch ME
        fprintf('?? GPU���ʧ�ܣ�ʹ��CPUѵ��: %s\n', ME.message);
        trainingDevice = "cpu";
    end
else
    fprintf('?? δ��⵽����GPU��ȱ�ٲ��м��㹤���䣬ʹ��CPUѵ��\n');
end

%% 2. ��Ŀ·��������׼��
fprintf('\n����2: ��Ŀ·��������׼��...\n');
try
    setup_project_paths();
    fprintf('? ��Ŀ·���������\n');
catch ME
    fprintf('? ·������ʧ��: %s\n', ME.message);
    return;
end

% ����30���������
fprintf('����30�������������...\n');
try
    model_cfg = model_config();
    % ����Ϊ30�����
    simulation_config = model_cfg;
    simulation_config.simulation.simulation_days = 30;
    simulation_config.simulation.sample_time_hours = 1; % 1Сʱ����
    
    [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(simulation_config);
    
    % ���浽�����ռ�
    assignin('base', 'pv_power_profile', pv_profile);
    assignin('base', 'load_power_profile', load_profile);
    assignin('base', 'price_profile', price_profile);
    
    fprintf('? 30����������������\n');
    fprintf('   PV���ݵ�: %d (%.1f��)\n', length(pv_profile.Data), length(pv_profile.Data)/24);
    fprintf('   �������ݵ�: %d (%.1f��)\n', length(load_profile.Data), length(load_profile.Data)/24);
    fprintf('   ������ݵ�: %d (%.1f��)\n', length(price_profile.Data), length(price_profile.Data)/24);
    
catch ME
    fprintf('? ��������ʧ��: %s\n', ME.message);
    return;
end

%% 3. ����ϵͳ��������
fprintf('\n����3: ����ϵͳ��������...\n');

% ����Integrated�ļ��еĳɹ�����
PnomkW = 500; % ��ƹ��� kW
Pnom = PnomkW * 1e3; % ת��Ϊ����
kWh_Rated = 100; % ������� kWh
Ts = 3600; % ����ʱ�� 1Сʱ (��)
simulationDays = 30; % ��������

% ��ز���
C_rated_Ah = kWh_Rated * 1000 / 5000; % ת��Ϊ��ʱ������5000V��Ƶ�ѹ
Efficiency = 96; % ���Ч�ʰٷֱ�
Initial_SOC_pc = 50; % ��ʼSOC�ٷֱ�
Initial_SOC_pc_MIN = 30; % ��С��ʼSOC
Initial_SOC_pc_MAX = 80; % ����ʼSOC
COST_PER_AH_LOSS = 0.25; % ����˻��ɱ��ͷ�
SOC_UPPER_LIMIT = 95.0; % SOC����
SOC_LOWER_LIMIT = 15.0; % SOC����
SOH_FAILURE_THRESHOLD = 0.8; % SOHʧЧ��ֵ

fprintf('? ����ϵͳ�����������\n');
fprintf('   ��ƹ���: %d kW\n', PnomkW);
fprintf('   �������: %d kWh\n', kWh_Rated);
fprintf('   ����ʱ��: %d �� (%.1f Сʱ)\n', Ts, Ts/3600);
fprintf('   ��������: %d ��\n', simulationDays);

%% 4. ����������MATLAB����
fprintf('\n����4: ����������MATLAB����...\n');
try
    % ʹ�������Ż���MATLAB������������Ϊ30�����
    [env, obs_info, action_info] = create_30day_simulation_environment(simulation_config);
    
    fprintf('? 30����滷�������ɹ�\n');
    fprintf('   �۲�ռ�: %dά\n', obs_info.Dimension(1));
    fprintf('   �����ռ�: %dά, ��Χ: [%.0f, %.0f] W\n', ...
            action_info.Dimension(1), action_info.LowerLimit, action_info.UpperLimit);
    
catch ME
    fprintf('? ��������ʧ��: %s\n', ME.message);
    return;
end

%% 5. ����������GPU�Ż���DDPG������
fprintf('\n����5: ����������GPU�Ż���DDPG������...\n');
try
    % ����Integrated�ļ��еĳɹ�����ܹ�
    agent = create_gpu_optimized_ddpg_agent(obs_info, action_info, trainingDevice, Ts, Pnom);
    
    % ���䵽���������ռ�
    assignin('base', 'agentObj', agent);
    
    fprintf('? GPU�Ż�DDPG�����崴���ɹ�\n');
    fprintf('   ѵ���豸: %s\n', upper(trainingDevice));
    fprintf('   ����ܹ�: Actor[7��128��64��1], Critic[7+1��128��64��1]\n');
    
catch ME
    fprintf('? �����崴��ʧ��: %s\n', ME.message);
    return;
end

%% 6. ���ø�����ѵ��ѡ��
fprintf('\n����6: ���ø�����ѵ��ѡ��...\n');

% ����30������ѵ������
max_episodes = 1000; % ����ѵ���غ���
max_steps_per_episode = 24 * 30; % ÿ�غ�30�� = 720Сʱ
score_averaging_window = 20; % ƽ������

trainOpts = rlTrainingOptions(...
    'MaxEpisodes', max_episodes, ...
    'MaxStepsPerEpisode', max_steps_per_episode, ...
    'ScoreAveragingWindow', score_averaging_window, ...
    'Verbose', true, ...
    'Plots', 'training-progress', ...
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', -10000, ... % 30���Ŀ�꽱��
    'SaveAgentCriteria', 'EpisodeReward', ...
    'SaveAgentValue', -15000, ... % ����������õ�������
    'SaveAgentDirectory', 'trained_agents_30day');

fprintf('? ������ѵ��ѡ���������\n');
fprintf('   ���غ���: %d\n', max_episodes);
fprintf('   ÿ�غ������: %d (30��)\n', max_steps_per_episode);
fprintf('   Ŀ��ƽ������: %.0f\n', trainOpts.StopTrainingValue);

%% 7. Ԥѵ����֤
fprintf('\n����7: Ԥѵ����֤...\n');
try
    % ���Ի�������
    fprintf('���Ի�������...\n');
    test_obs = reset(env);
    fprintf('? �������óɹ����۲�ά��: %s\n', mat2str(size(test_obs)));
    
    % ���Ի�������
    fprintf('���Ի�������...\n');
    test_action = 0; % 0 W
    [next_obs, reward, done, info] = env.step(test_action);
    fprintf('? ���������ɹ�������: %.4f\n', reward);
    
    fprintf('? Ԥѵ����֤ͨ��\n');
    
catch ME
    fprintf('? Ԥѵ����֤ʧ��: %s\n', ME.message);
    return;
end

%% 8. ��ʼ30�������ѵ��
fprintf('\n����8: ��ʼ30�������ѵ��...\n');
fprintf('? �⽫��һ����ʱ���ѵ�����̣�Ԥ����Ҫ��Сʱ...\n');
fprintf('ѵ������:\n');
fprintf('   - �������: 30��/�غ�\n');
fprintf('   - ʱ�䲽��: 1Сʱ\n');
fprintf('   - ѵ���豸: %s\n', upper(trainingDevice));
fprintf('   - ���غ���: %d\n', max_episodes);
fprintf('\n��ʼѵ��...\n');

training_start_time = tic;
try
    % ��ʼѵ��
    trainingStats = train(agent, env, trainOpts);
    training_time = toc(training_start_time);
    
    fprintf('? 30�������ѵ����ɣ�\n');
    fprintf('   ��ѵ��ʱ��: %.1f ���� (%.2f Сʱ)\n', training_time/60, training_time/3600);
    
    % ��ʾѵ��ͳ��
    if ~isempty(trainingStats.EpisodeReward)
        final_reward = trainingStats.EpisodeReward(end);
        avg_reward = mean(trainingStats.EpisodeReward(max(1, end-19):end)); % ���20�غ�ƽ��
        total_episodes = length(trainingStats.EpisodeReward);
        
        fprintf('   ѵ���غ���: %d\n', total_episodes);
        fprintf('   ���ջغϽ���: %.2f\n', final_reward);
        fprintf('   ���20�غ�ƽ������: %.2f\n', avg_reward);
        
        if avg_reward >= trainOpts.StopTrainingValue
            fprintf('? �ﵽѵ��Ŀ�꣡\n');
        else
            fprintf('?? δ�ﵽѵ��Ŀ�꣬��ѵ�������\n');
        end
    end
    
catch ME
    training_time = toc(training_start_time);
    fprintf('? ѵ��ʧ��: %s\n', ME.message);
    fprintf('   ѵ��ʱ��: %.1f ����\n', training_time/60);
    return;
end

%% 9. ����ѵ�����
fprintf('\n����9: ����ѵ�����...\n');
try
    % ��������ļ���
    timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    agent_filename = sprintf('trained_agent_30day_gpu_%s.mat', timestamp);
    stats_filename = sprintf('training_stats_30day_gpu_%s.mat', timestamp);
    
    % ����������
    save(agent_filename, 'agent', 'trainingStats', 'simulation_config');
    
    % ����ѵ��ͳ��
    save(stats_filename, 'trainingStats', 'training_time', 'simulation_config', 'trainOpts');
    
    % ���浽�����ռ�
    assignin('base', 'trained_agent_30day', agent);
    assignin('base', 'training_stats_30day', trainingStats);
    
    fprintf('? ѵ������������\n');
    fprintf('   �������ļ�: %s\n', agent_filename);
    fprintf('   ͳ���ļ�: %s\n', stats_filename);
    
catch ME
    fprintf('?? �������ʧ��: %s\n', ME.message);
end

%% 10. ��������
fprintf('\n����10: ��������...\n');
try
    % ����һ��������30������
    fprintf('����30����������...\n');
    obs = reset(env);
    total_reward = 0;
    episode_length = 24 * 30; % 30��
    
    for step = 1:episode_length
        % ʹ��ѵ���õ�������
        action = getAction(agent, obs);
        [obs, reward, done, info] = env.step(action);
        total_reward = total_reward + reward;
        
        if mod(step, 24*5) == 0 % ÿ5����ʾһ��
            fprintf('   ��%d��: �ۼƽ���=%.2f, SOC=%.2f, SOH=%.3f\n', ...
                    step/24, total_reward, obs(3), obs(4));
        end
        
        if done
            fprintf('   �����ڵ�%d����ǰ����\n', step);
            break;
        end
    end
    
    fprintf('? 30�������������\n');
    fprintf('   �ܽ���: %.2f\n', total_reward);
    fprintf('   ƽ���ս���: %.2f\n', total_reward/30);
    
catch ME
    fprintf('?? ��������ʧ��: %s\n', ME.message);
end

%% �ܽᱨ��
fprintf('\n=========================================================================\n');
fprintf('=== 30���������������GPU����ѵ����� ===\n');
fprintf('=========================================================================\n');

fprintf('? ѵ���ɹ���ɣ�\n\n');

fprintf('ѵ������:\n');
fprintf('  ? ����ʱ��: 30����������\n');
fprintf('  ?? ʱ�䲽��: 1Сʱ\n');
fprintf('  ?? ѵ���豸: %s\n', upper(trainingDevice));
fprintf('  ? ѵ���غ�: %d\n', max_episodes);

if exist('training_time', 'var')
    fprintf('\n����ָ��:\n');
    fprintf('  ? ѵ��ʱ��: %.1f ���� (%.2f Сʱ)\n', training_time/60, training_time/3600);
    if exist('trainingStats', 'var') && ~isempty(trainingStats.EpisodeReward)
        fprintf('  ? ��ɻغ�: %d\n', length(trainingStats.EpisodeReward));
        fprintf('  ? ���ս���: %.2f\n', trainingStats.EpisodeReward(end));
    end
end

fprintf('\n�ļ����:\n');
if exist('agent_filename', 'var')
    fprintf('  ? ѵ��������: %s\n', agent_filename);
end
if exist('stats_filename', 'var')
    fprintf('  ? ѵ��ͳ��: %s\n', stats_filename);
end

fprintf('\n��һ������:\n');
fprintf('  1. ����ѵ�����ߺ�������\n');
fprintf('  2. ���и���ʱ�����������\n');
fprintf('  3. �������������н�һ���Ż�\n');
fprintf('  4. ���׼���Խ��жԱȷ���\n');

fprintf('\n? 30��������������ܷ���ѵ����ɣ�\n');
fprintf('=========================================================================\n');

end
