function train_simple_ddpg()
% TRAIN_SIMPLE_DDPG - ʹ�ü�MATLAB����ѵ��DDPG������
% 
% ��ȫ����Simulink������ʹ�ô�MATLABʵ��

fprintf('=== ��DDPGѵ�� ===\n');
fprintf('ʱ��: %s\n', string(datetime('now')));
fprintf('ʹ�ô�MATLAB��������Simulink����\n');
fprintf('========================================\n\n');

%% ����1: ���û���
fprintf('����1: ������Ŀ����...\n');
try
    setup_project_paths();
    fprintf('? ��Ŀ·���������\n');
catch ME
    fprintf('? ��������ʧ��: %s\n', ME.message);
    return;
end

%% ����2: ��������
fprintf('\n����2: ��������...\n');
try
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    fprintf('? ���ü������\n');
    fprintf('   ���: %d kW / %d kWh\n', model_cfg.battery.rated_power_kW, model_cfg.battery.rated_capacity_kWh);
catch ME
    fprintf('? ���ü���ʧ��: %s\n', ME.message);
    return;
end

%% ����3: ��������
fprintf('\n����3: ������MATLAB����...\n');
try
    [env, obs_info, action_info] = create_simple_matlab_environment();
    fprintf('? ���������ɹ�\n');
    fprintf('   �۲�ռ�: %dά\n', obs_info.Dimension(1));
    fprintf('   �����ռ�: %dά, ��Χ: [%.0f, %.0f] W\n', ...
            action_info.Dimension(1), action_info.LowerLimit, action_info.UpperLimit);
catch ME
    fprintf('? ��������ʧ��: %s\n', ME.message);
    return;
end

%% ����4: ����DDPG������
fprintf('\n����4: ����DDPG������...\n');
try
    agent = create_ddpg_agent(obs_info, action_info, training_cfg);
    fprintf('? DDPG�����崴���ɹ�\n');
catch ME
    fprintf('? �����崴��ʧ��: %s\n', ME.message);
    return;
end

%% ����5: ��������
fprintf('\n����5: ���Ի�������...\n');
try
    % ���Ի�������
    obs = reset(env);
    fprintf('? �������óɹ�\n');
    fprintf('   ��ʼ�۲�: [PV=%.1f, Load=%.1f, SOC=%.2f, SOH=%.2f, Price=%.3f]\n', ...
            obs(1), obs(2), obs(3), obs(4), obs(5));
    
    % ���Ի�������
    test_action = 0;  % 0 W
    [next_obs, reward, is_done, info] = env.step(test_action);
    fprintf('? ���������ɹ�������: %.4f\n', reward);
    
catch ME
    fprintf('? ��������ʧ��: %s\n', ME.message);
    return;
end

%% ����6: ����ѵ��ѡ��
fprintf('\n����6: ����ѵ��ѡ��...\n');
try
    % ʹ�ý϶̵�ѵ��������ʾ
    training_options = rlTrainingOptions(...
        'MaxEpisodes', 20, ...
        'MaxStepsPerEpisode', 24, ...
        'Verbose', true, ...
        'Plots', 'training-progress', ...
        'StopTrainingCriteria', 'AverageReward', ...
        'StopTrainingValue', -30, ...
        'ScoreAveragingWindow', 5);
    
    fprintf('? ѵ��ѡ���������\n');
    fprintf('   ���غ���: %d\n', training_options.MaxEpisodes);
    fprintf('   ÿ�غ������: %d\n', training_options.MaxStepsPerEpisode);
    fprintf('   Ŀ��ƽ������: %.1f\n', training_options.StopTrainingValue);
catch ME
    fprintf('? ѵ��ѡ������ʧ��: %s\n', ME.message);
    return;
end

%% ����7: ��ʼѵ��
fprintf('\n����7: ��ʼDDPGѵ��...\n');
fprintf('�������Ҫ������ʱ��...\n');
try
    % ��ʼѵ��
    tic;
    training_stats = train(agent, env, training_options);
    training_time = toc;
    
    fprintf('? ѵ����ɣ���ʱ: %.1f ��\n', training_time);
    
    % ��ʾѵ�����
    if ~isempty(training_stats.EpisodeReward)
        final_reward = training_stats.EpisodeReward(end);
        avg_reward = mean(training_stats.EpisodeReward(max(1, end-4):end));
        fprintf('   ���ջغϽ���: %.2f\n', final_reward);
        fprintf('   ���5�غ�ƽ������: %.2f\n', avg_reward);
        fprintf('   ��ѵ���غ���: %d\n', length(training_stats.EpisodeReward));
        
        % ����Ƿ�ﵽĿ��
        if avg_reward >= training_options.StopTrainingValue
            fprintf('? �ﵽѵ��Ŀ�꣡\n');
        else
            fprintf('?? δ�ﵽѵ��Ŀ�꣬������Ҫ����ѵ��\n');
        end
    end
    
catch ME
    fprintf('? ѵ��ʧ��: %s\n', ME.message);
    fprintf('���ܵ�ԭ��:\n');
    fprintf('1. ����ܹ�����\n');
    fprintf('2. ��������������\n');
    fprintf('3. ����������������\n');
    return;
end

%% ����8: ����ѵ�����
fprintf('\n����8: ����ѵ�����...\n');
try
    % ����ѵ���õ�������
    save('trained_agent_simple.mat', 'agent', 'training_stats');
    
    % ���浽�����ռ�
    assignin('base', 'trained_agent', agent);
    assignin('base', 'training_stats', training_stats);
    
    fprintf('? ѵ������ѱ���\n');
    fprintf('   �ļ�: trained_agent_simple.mat\n');
    fprintf('   �����ռ����: trained_agent, training_stats\n');
    
catch ME
    fprintf('?? ����ʧ��: %s\n', ME.message);
end

%% ����9: ����ѵ���õ�������
fprintf('\n����9: ����ѵ���õ�������...\n');
try
    % ���û���
    obs = reset(env);
    total_reward = 0;
    episode_data = [];
    
    fprintf('����һ�������غ�...\n');
    for step = 1:24
        % ʹ��ѵ���õ�������ѡ����
        action = getAction(agent, obs);
        
        % ִ�ж���
        [obs, reward, is_done, info] = env.step(action);
        total_reward = total_reward + reward;
        
        % ��¼����
        episode_data(step, :) = [step, action/1000, reward, obs(3), obs(4), info.economic_cost];
        
        if mod(step, 6) == 0 || step == 24
            fprintf('   ���� %d: ����=%.1f kW, ����=%.2f, SOC=%.2f, SOH=%.3f\n', ...
                    step, action/1000, reward, obs(3), obs(4));
        end
        
        if is_done
            fprintf('   �غ���ǰ�����ڲ��� %d\n', step);
            break;
        end
    end
    
    fprintf('? ������ɣ��ܽ���: %.2f\n', total_reward);
    
    % �����������
    assignin('base', 'episode_data', episode_data);
    fprintf('   ���������ѱ��浽�����ռ����: episode_data\n');
    
catch ME
    fprintf('?? ����ʧ��: %s\n', ME.message);
end

%% �ܽ�
fprintf('\n========================================\n');
fprintf('=== ��DDPGѵ����� ===\n');
fprintf('? �ɹ�ʹ�ô�MATLAB�������ѵ����\n');

fprintf('\n��Ҫ����:\n');
fprintf('? ��ȫ����Simulink����\n');
fprintf('? ѵ���ٶȿ�\n');
fprintf('? ���ڵ��Ժ��޸�\n');
fprintf('? ����������\n');

fprintf('\nѵ������ļ�:\n');
fprintf('? trained_agent_simple.mat - ѵ���õ�������\n');
fprintf('? episode_data - ���Իغ�����\n');

fprintf('\n��һ������:\n');
fprintf('1. �������������Ի�ø��õ�����\n');
fprintf('2. ����ѵ���غ������и���ֵ�ѵ��\n');
fprintf('3. ���Բ�ͬ������ܹ��ͳ�����\n');
fprintf('4. ����episode_data�������������Ϊ\n');

fprintf('\nʹ��ʾ��:\n');
fprintf('load(''trained_agent_simple.mat'')  %% ����������\n');
fprintf('[env, ~, ~] = create_simple_matlab_environment()  %% ��������\n');
fprintf('obs = reset(env); action = getAction(agent, obs)  %% ʹ��������\n');

end
