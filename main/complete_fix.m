function complete_fix()
% COMPLETE_FIX - �ۺ��޸��ű�
% 
% �Զ��޸��������⣺
% - ���ɺ��޸����ݱ���
% - �޸�ģ������
% - �޸���������ƥ��
% - ���Ի�������

fprintf('=== �ۺ��޸��ű� ===\n');
fprintf('ʱ��: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

%% ����1: ����·��
fprintf('����1: ������Ŀ·��...\n');
try
    setup_project_paths();
    fprintf('? ·�����óɹ�\n');
catch ME
    fprintf('? ·������ʧ��: %s\n', ME.message);
    return;
end

%% ����2: ������������
fprintf('\n����2: ������������...\n');
try
    if ~load_workspace_data()
        fprintf('�����µĹ����ռ�����...\n');
        model_cfg = model_config();
        demo_config = model_cfg;
        demo_config.simulation.simulation_days = 1;
        [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(demo_config);
        assignin('base', 'pv_power_profile', pv_profile);
        assignin('base', 'load_power_profile', load_profile);
        assignin('base', 'price_profile', price_profile);
        fprintf('? ���������ɳɹ�\n');
    else
        fprintf('? �����ռ������Ѵ���\n');
    end
catch ME
    fprintf('? ��������ʧ��: %s\n', ME.message);
    return;
end

%% ����3: ��������
fprintf('\n����3: ��������...\n');
try
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    fprintf('? ���ò���ͨ��\n');
    fprintf('   ���: %d kW / %d kWh\n', model_cfg.battery.rated_power_kW, model_cfg.battery.rated_capacity_kWh);
catch ME
    fprintf('? ���ò���ʧ��: %s\n', ME.message);
    return;
end

%% ����4: ���Ի�������
fprintf('\n����4: ���Ի�������...\n');
try
    % ����ʹ�ü򻯵�MATLAB����
    [env, obs_info, action_info] = create_simple_matlab_environment();
    fprintf('? ��MATLAB���������ɹ�\n');
    
    % ���Ի�������
    obs = reset(env);
    [next_obs, reward, done, info] = env.step(0);
    fprintf('? �������ܲ���ͨ��\n');
    
catch ME
    fprintf('?? �򻯻�������ʧ��: %s\n', ME.message);
    
    % ���Լ����Ի���
    try
        [env, obs_info, action_info] = create_environment_with_specs(model_cfg);
        fprintf('? �����Ի��������ɹ�\n');
    catch ME2
        fprintf('? ���л���������ʧ��\n');
        fprintf('   �򻯻�������: %s\n', ME.message);
        fprintf('   ���ݻ�������: %s\n', ME2.message);
        return;
    end
end

%% ����5: ���������崴��
fprintf('\n����5: ���������崴��...\n');
try
    agent = create_ddpg_agent(obs_info, action_info, training_cfg);
    fprintf('? DDPG�����崴���ɹ�\n');
catch ME
    fprintf('? �����崴��ʧ��: %s\n', ME.message);
    return;
end

%% ����6: ���Simulinkģ��
fprintf('\n����6: ���Simulinkģ��...\n');
try
    model_path = fullfile(pwd, 'simulinkmodel', 'Microgrid.slx');
    if exist(model_path, 'file')
        fprintf('? Simulinkģ���ļ�����: %s\n', model_path);
        
        % ���Լ���ģ��
        try
            load_system(model_path);
            fprintf('? Simulinkģ�ͼ��سɹ�\n');
            close_system('Microgrid', 0);
        catch ME_sim
            fprintf('?? Simulinkģ�ͼ���ʧ��: %s\n', ME_sim.message);
        end
    else
        fprintf('?? Simulinkģ���ļ�������: %s\n', model_path);
    end
catch ME
    fprintf('? Simulinkģ�ͼ��ʧ��: %s\n', ME.message);
end

%% �ܽ�
fprintf('\n========================================\n');
fprintf('=== �ۺ��޸���� ===\n');

fprintf('\n? �ɹ��޸������:\n');
fprintf('  - ��Ŀ·������\n');
fprintf('  - �����ռ�����\n');
fprintf('  - �����ļ�\n');
fprintf('  - ��������\n');
fprintf('  - �����崴��\n');

fprintf('\n? �Ƽ�����һ������:\n');
fprintf('1. ���п��ٲ���: system_test\n');
fprintf('2. ���п���ѵ��: train_simple_ddpg\n');
fprintf('3. ���й��ܲ���: test_basic_functionality\n');

fprintf('\n? ʹ�ý���:\n');
fprintf('- ����ʹ�ü򻯵�MATLAB���� (create_simple_matlab_environment)\n');
fprintf('- �����ҪSimulink���棬����ģ������\n');
fprintf('- ���к��Ĺ��ܶ�����֤����\n');

fprintf('\n�޸���ɣ�ϵͳ��׼��������\n');

end
