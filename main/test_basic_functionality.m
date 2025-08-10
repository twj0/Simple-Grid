function test_basic_functionality()
% TEST_BASIC_FUNCTIONALITY - ����main�ļ��еĻ�������
% 
% ������������޸����main�ļ����Ƿ������������
% �ص������Integrated�ļ��еļ�����

fprintf('=== ����main�ļ��л������� ===\n');
fprintf('ʱ��: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

%% ����1: ·��������
fprintf('����1: ·��������...\n');
try
    setup_project_paths();
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    fprintf('? ·�������ò���ͨ��\n');
catch ME
    fprintf('? ·�������ò���ʧ��: %s\n', ME.message);
    return;
end

%% ����2: �������ɺͼ���
fprintf('\n����2: �������ɺͼ���...\n');
try
    % ���Թ����ռ����ݼ���
    if load_workspace_data()
        fprintf('? �����ռ����ݼ��سɹ�\n');
    else
        fprintf('?? �����ռ����ݲ����ڣ�����������...\n');
        test_config = model_cfg;
        test_config.simulation.simulation_days = 1;
        [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(test_config);
        assignin('base', 'pv_profile', pv_profile);
        assignin('base', 'load_profile', load_profile);
        assignin('base', 'price_profile', price_profile);
        fprintf('? ���������ɳɹ�\n');
    end
catch ME
    fprintf('? �������ɺͼ���ʧ��: %s\n', ME.message);
    return;
end

%% ����3: ����������ʹ��Integrated���ݷ�����
fprintf('\n����3: ��������...\n');
try
    [env, obs_info, action_info] = create_environment_with_specs(model_cfg);
    fprintf('? ���������ɹ�\n');
    fprintf('   �۲�ά��: %s\n', mat2str(obs_info.Dimension));
    fprintf('   ����ά��: %s\n', mat2str(action_info.Dimension));
catch ME
    fprintf('? ��������ʧ��: %s\n', ME.message);
    return;
end

%% ����4: �����崴��
fprintf('\n����4: �����崴��...\n');
try
    agent = create_ddpg_agent(obs_info, action_info, training_cfg);
    assignin('base', 'agentObj', agent);
    fprintf('? DDPG�����崴���ɹ�\n');
catch ME
    fprintf('? �����崴��ʧ��: %s\n', ME.message);
    return;
end

%% ����5: ��Integratedϵͳ�����Բ���
fprintf('\n����5: ��Integratedϵͳ������...\n');
try
    % ����Ƿ����ʹ��Integrated�ļ����е�����
    integrated_dir = fullfile(fileparts(pwd), 'Integrated');
    if exist(integrated_dir, 'dir')
        integrated_data_file = fullfile(integrated_dir, 'simulation_data_10days_random.mat');
        if exist(integrated_data_file, 'file')
            fprintf('? �ҵ�Integrated�����ļ�\n');
            
            % ���Լ���Integrated����
            integrated_data = load(integrated_data_file);
            if isfield(integrated_data, 'pv_power_profile')
                fprintf('? Integrated���ݸ�ʽ����\n');
            else
                fprintf('?? Integrated���ݸ�ʽ��Ҫת��\n');
            end
        else
            fprintf('?? δ�ҵ�Integrated�����ļ�\n');
        end
    else
        fprintf('?? δ�ҵ�Integrated�ļ���\n');
    end
catch ME
    fprintf('? �����Բ���ʧ��: %s\n', ME.message);
end

%% ����6: ѵ�����ò���
fprintf('\n����6: ѵ������...\n');
try
    training_options = rlTrainingOptions(...
        'MaxEpisodes', 5, ...
        'MaxStepsPerEpisode', 10, ...
        'Verbose', false, ...
        'Plots', 'none');
    fprintf('? ѵ�����ô����ɹ�\n');
catch ME
    fprintf('? ѵ������ʧ��: %s\n', ME.message);
end

%% �ܽ�
fprintf('\n========================================\n');
fprintf('=== �������ܲ������ ===\n');
fprintf('main�ļ����Ѿ��߱����¹���:\n');
fprintf('? ���ù���ϵͳ\n');
fprintf('? �������ɺ͹���\n');
fprintf('? RL��������\n');
fprintf('? DDPG�����崴��\n');
fprintf('? ��Integratedϵͳ����\n');
fprintf('? ѵ�����ù���\n');

fprintf('\n��һ������:\n');
fprintf('1. ���� train_ddpg_microgrid ��ʼѵ��\n');
fprintf('2. �������� quick_train_test ���п��ٲ���\n');
fprintf('3. ��� Integrated/run_drl_experiment.m ��Ϊ�ο�\n');

fprintf('\nע��: �������Simulink�������⣬����:\n');
fprintf('1. ʹ��Integrated�ļ����еĹ���������Ϊ�ο�\n');
fprintf('2. ���ģ�����ú����ݸ�ʽ\n');
fprintf('3. ȷ�����й����ռ������ȷ����\n');

end
