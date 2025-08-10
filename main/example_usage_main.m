function example_usage_main()
% EXAMPLE_USAGE_MAIN - չʾ���ʹ���޸����main�ļ���
% 
% ���ʾ��չʾ��main�ļ��е����п��ù���
% �������ù����������ɡ����������������崴����

fprintf('=== Main�ļ���ʹ��ʾ�� ===\n');
fprintf('ʱ��: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

%% ����1: ��������
fprintf('����1: ������Ŀ����...\n');
try
    % ������Ŀ·��
    setup_project_paths();
    fprintf('? ��Ŀ·���������\n');
    
    % ��������
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    fprintf('? �����ļ��������\n');
    
catch ME
    fprintf('? ��������ʧ��: %s\n', ME.message);
    return;
end

%% ����2: ����׼��
fprintf('\n����2: ׼��ѵ������...\n');
try
    % ����Ƿ�����������
    if load_workspace_data()
        fprintf('? ʹ�����й����ռ�����\n');
    else
        fprintf('�����µ�ѵ������...\n');
        % ����Ϊ1�������������ʾ
        demo_config = model_cfg;
        demo_config.simulation.simulation_days = 1;
        
        % ��������
        [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(demo_config);
        
        % ���浽�����ռ�
        assignin('base', 'pv_profile', pv_profile);
        assignin('base', 'load_profile', load_profile);
        assignin('base', 'price_profile', price_profile);
        
        fprintf('? �������������\n');
    end
    
catch ME
    fprintf('? ����׼��ʧ��: %s\n', ME.message);
    return;
end

%% ����3: ����RL����
fprintf('\n����3: ����ǿ��ѧϰ����...\n');
try
    % ʹ�ü���Integratedϵͳ�ķ�����������
    [env, obs_info, action_info] = create_environment_with_specs(model_cfg);
    
    fprintf('? RL���������ɹ�\n');
    fprintf('   �۲�ռ�: %dά %s\n', obs_info.Dimension(1), mat2str(obs_info.Dimension));
    fprintf('   �����ռ�: %dά %s\n', action_info.Dimension(1), mat2str(action_info.Dimension));
    fprintf('   ������Χ: [%.0f, %.0f] W\n', action_info.LowerLimit, action_info.UpperLimit);
    
catch ME
    fprintf('? ��������ʧ��: %s\n', ME.message);
    return;
end

%% ����4: ����DDPG������
fprintf('\n����4: ����DDPG������...\n');
try
    % ����DDPG������
    agent = create_ddpg_agent(obs_info, action_info, training_cfg);
    
    % ����������䵽���������ռ䣨Simulink��Ҫ��
    assignin('base', 'agentObj', agent);
    
    fprintf('? DDPG�����崴���ɹ�\n');
    fprintf('   �㷨: DDPG\n');
    fprintf('   Actorѧϰ��: %.2e\n', training_cfg.agent.actor_lr);
    fprintf('   Criticѧϰ��: %.2e\n', training_cfg.agent.critic_lr);
    
catch ME
    fprintf('? �����崴��ʧ��: %s\n', ME.message);
    return;
end

%% ����5: ����ѵ��ѡ��
fprintf('\n����5: ����ѵ��ѡ��...\n');
try
    % ������ʾ�õ�ѵ��ѡ���ʱ��ѵ����
    demo_training_options = rlTrainingOptions(...
        'MaxEpisodes', 10, ...
        'MaxStepsPerEpisode', 24, ...
        'Verbose', true, ...
        'Plots', 'training-progress', ...
        'StopTrainingCriteria', 'AverageReward', ...
        'StopTrainingValue', -100);
    
    fprintf('? ѵ��ѡ���������\n');
    fprintf('   ���غ���: %d\n', demo_training_options.MaxEpisodes);
    fprintf('   ÿ�غ������: %d\n', demo_training_options.MaxStepsPerEpisode);
    
catch ME
    fprintf('? ѵ��ѡ������ʧ��: %s\n', ME.message);
    return;
end

%% ����6: ϵͳ��֤
fprintf('\n����6: ��֤ϵͳ������...\n');
try
    % ��֤�������
    fprintf('��֤���:\n');
    
    % �������
    assert(~isempty(model_cfg), 'ģ������Ϊ��');
    fprintf('  ? ģ������: ����\n');
    
    % �������
    pv_data = evalin('base', 'pv_profile');
    load_data = evalin('base', 'load_profile');
    price_data = evalin('base', 'price_profile');
    assert(~isempty(pv_data) && ~isempty(load_data) && ~isempty(price_data), '���ݲ�����');
    fprintf('  ? ѵ������: ����\n');
    
    % ��黷��
    assert(~isempty(env), '����Ϊ��');
    fprintf('  ? RL����: ����\n');
    
    % ���������
    workspace_agent = evalin('base', 'agentObj');
    assert(~isempty(workspace_agent), '�����ռ���������Ϊ��');
    fprintf('  ? DDPG������: ����\n');
    
    % ���ѵ��ѡ��
    assert(~isempty(demo_training_options), 'ѵ��ѡ��Ϊ��');
    fprintf('  ? ѵ��ѡ��: ����\n');
    
    fprintf('? ϵͳ��֤ͨ��\n');
    
catch ME
    fprintf('? ϵͳ��֤ʧ��: %s\n', ME.message);
    return;
end

%% ����7: ʹ�ý���
fprintf('\n����7: ʹ�ý������һ��...\n');
fprintf('? Main�ļ���������ɣ�\n\n');

fprintf('���õĹ���:\n');
fprintf('  ? ���ù��� - model_config(), training_config_ddpg()\n');
fprintf('  ? �������� - generate_microgrid_profiles()\n');
fprintf('  ? �������� - create_environment_with_specs()\n');
fprintf('  ? �����崴�� - create_ddpg_agent()\n');
fprintf('  ? ѵ������ - rlTrainingOptions()\n');

fprintf('\n�Ƽ�����һ������:\n');
fprintf('1. ? ���Թ���: test_basic_functionality\n');
fprintf('2. ? ����ѵ��: quick_train_test (������Ҫ����)\n');
fprintf('3. ? ����ѵ��: train_ddpg_microgrid (������Ҫ����)\n');
fprintf('4. ? ʹ��Integrated: cd(''../Integrated''); run_drl_experiment\n');

fprintf('\nע������:\n');
fprintf('??  Simulink���������Ҫ��һ������\n');
fprintf('? ����׼����������ɣ����Կ�ʼ����\n');
fprintf('? ��Integratedϵͳ��ȫ����\n');

fprintf('\n����״̬:\n');
fprintf('  env: RL��������\n');
fprintf('  agent: DDPG���������\n');
fprintf('  agentObj: �����ռ��е������壨Simulink�ã�\n');
fprintf('  demo_training_options: ��ʾѵ��ѡ��\n');

fprintf('\n========================================\n');
fprintf('=== Main�ļ���ʹ��ʾ����� ===\n');

% ���ش����Ķ��󹩺���ʹ��
if nargout > 0
    varargout{1} = struct('env', env, 'agent', agent, 'training_options', demo_training_options);
end

end
