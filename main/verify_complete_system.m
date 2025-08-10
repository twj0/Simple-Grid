function verify_complete_system()
% VERIFY_COMPLETE_SYSTEM - ��֤����ϵͳ����
% 
% ȫ������Ż����main�ļ������й���

fprintf('=== ����ϵͳ��֤ ===\n');
fprintf('ʱ��: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

test_results = struct();
total_tests = 0;
passed_tests = 0;

%% ����1: ���������ű����
fprintf('����1: ���������ű����...\n');
total_tests = total_tests + 1;
try
    % ���bat�ļ��Ƿ����
    bat_file = fullfile('..', 'quick_start.bat');
    if exist(bat_file, 'file')
        fprintf('? quick_start.bat �ļ�����\n');
        
        % ���Simulinkģ��·��
        model_path = fullfile('simulinkmodel', 'Microgrid.slx');
        if exist(model_path, 'file')
            fprintf('? Simulinkģ��·����ȷ\n');
            test_results.quick_start = true;
            passed_tests = passed_tests + 1;
        else
            fprintf('? Simulinkģ��·������\n');
            test_results.quick_start = false;
        end
    else
        fprintf('? quick_start.bat �ļ�������\n');
        test_results.quick_start = false;
    end
catch ME
    fprintf('? ���������ű����ʧ��: %s\n', ME.message);
    test_results.quick_start = false;
end

%% ����2: �ۺ��޸�����
fprintf('\n����2: �ۺ��޸�����...\n');
total_tests = total_tests + 1;
try
    % ���complete_fix�����Ƿ����
    if exist('complete_fix.m', 'file')
        fprintf('? complete_fix.m ����\n');
        test_results.complete_fix = true;
        passed_tests = passed_tests + 1;
    else
        fprintf('? complete_fix.m ������\n');
        test_results.complete_fix = false;
    end
catch ME
    fprintf('? �ۺ��޸����ܼ��ʧ��: %s\n', ME.message);
    test_results.complete_fix = false;
end

%% ����3: ����ʽ�˵�
fprintf('\n����3: ����ʽ�˵�...\n');
total_tests = total_tests + 1;
try
    if exist('run_microgrid_framework.m', 'file')
        fprintf('? run_microgrid_framework.m ����\n');
        test_results.interactive_menu = true;
        passed_tests = passed_tests + 1;
    else
        fprintf('? run_microgrid_framework.m ������\n');
        test_results.interactive_menu = false;
    end
catch ME
    fprintf('? ����ʽ�˵����ʧ��: %s\n', ME.message);
    test_results.interactive_menu = false;
end

%% ����4: ���Ļ�������
fprintf('\n����4: ���Ļ�������...\n');
total_tests = total_tests + 1;
try
    setup_project_paths();
    [env, obs_info, action_info] = create_simple_matlab_environment();
    
    % ���Ի�������
    obs = reset(env);
    if length(obs) == 7
        fprintf('? �������óɹ����۲�ά����ȷ\n');
        
        % ���Ի�������
        [next_obs, reward, done, info] = env.step(0);
        if length(next_obs) == 7 && isnumeric(reward)
            fprintf('? ���������ɹ�\n');
            test_results.core_environment = true;
            passed_tests = passed_tests + 1;
        else
            fprintf('? ��������ʧ��\n');
            test_results.core_environment = false;
        end
    else
        fprintf('? ��������ʧ�ܣ��۲�ά�ȴ���\n');
        test_results.core_environment = false;
    end
catch ME
    fprintf('? ���Ļ������ܲ���ʧ��: %s\n', ME.message);
    test_results.core_environment = false;
end

%% ����5: �����崴��
fprintf('\n����5: �����崴��...\n');
total_tests = total_tests + 1;
try
    if exist('obs_info', 'var') && exist('action_info', 'var')
        agent = create_ddpg_agent(obs_info, action_info, training_config_ddpg());
        if ~isempty(agent)
            fprintf('? DDPG�����崴���ɹ�\n');
            test_results.agent_creation = true;
            passed_tests = passed_tests + 1;
        else
            fprintf('? DDPG�����崴��ʧ��\n');
            test_results.agent_creation = false;
        end
    else
        fprintf('? �۲������Ϣ������\n');
        test_results.agent_creation = false;
    end
catch ME
    fprintf('? �����崴������ʧ��: %s\n', ME.message);
    test_results.agent_creation = false;
end

%% ����6: ѵ���ű�
fprintf('\n����6: ѵ���ű�...\n');
total_tests = total_tests + 1;
try
    training_scripts = {
        'train_simple_ddpg.m',
        'train_ddpg_microgrid.m',
        'quick_train_test.m'
    };
    
    all_exist = true;
    for i = 1:length(training_scripts)
        if ~exist(training_scripts{i}, 'file')
            fprintf('? %s ������\n', training_scripts{i});
            all_exist = false;
        else
            fprintf('? %s ����\n', training_scripts{i});
        end
    end
    
    if all_exist
        test_results.training_scripts = true;
        passed_tests = passed_tests + 1;
    else
        test_results.training_scripts = false;
    end
catch ME
    fprintf('? ѵ���ű����ʧ��: %s\n', ME.message);
    test_results.training_scripts = false;
end

%% ����7: ����ϵͳ
fprintf('\n����7: ����ϵͳ...\n');
total_tests = total_tests + 1;
try
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    
    if ~isempty(model_cfg) && ~isempty(training_cfg)
        fprintf('? ����ϵͳ����\n');
        fprintf('   �������: %d kW / %d kWh\n', ...
                model_cfg.battery.rated_power_kW, model_cfg.battery.rated_capacity_kWh);
        test_results.configuration = true;
        passed_tests = passed_tests + 1;
    else
        fprintf('? ����ϵͳ�쳣\n');
        test_results.configuration = false;
    end
catch ME
    fprintf('? ����ϵͳ����ʧ��: %s\n', ME.message);
    test_results.configuration = false;
end

%% ����8: ���ݹ���
fprintf('\n����8: ���ݹ���...\n');
total_tests = total_tests + 1;
try
    if load_workspace_data()
        fprintf('? �����ռ����ݼ��سɹ�\n');
        
        % ���ؼ�����
        pv_data = evalin('base', 'pv_power_profile');
        load_data = evalin('base', 'load_power_profile');
        price_data = evalin('base', 'price_profile');
        
        if ~isempty(pv_data) && ~isempty(load_data) && ~isempty(price_data)
            fprintf('? �������ݱ�������\n');
            test_results.data_management = true;
            passed_tests = passed_tests + 1;
        else
            fprintf('? ���ݱ���������\n');
            test_results.data_management = false;
        end
    else
        fprintf('? �����ռ����ݼ���ʧ��\n');
        test_results.data_management = false;
    end
catch ME
    fprintf('? ���ݹ������ʧ��: %s\n', ME.message);
    test_results.data_management = false;
end

%% ����9: �ļ��ṹ�Ż�
fprintf('\n����9: �ļ��ṹ�Ż�...\n');
total_tests = total_tests + 1;
try
    % �����Ҫ�ļ��Ƿ����
    important_files = {
        'MicrogridEnvironment.m',
        'create_simple_matlab_environment.m',
        'setup_project_paths.m',
        'OPTIMIZATION_COMPLETE.md',
        'OPTIMIZED_STRUCTURE.md'
    };
    
    all_important_exist = true;
    for i = 1:length(important_files)
        if ~exist(important_files{i}, 'file')
            fprintf('? ��Ҫ�ļ�ȱʧ: %s\n', important_files{i});
            all_important_exist = false;
        end
    end
    
    if all_important_exist
        fprintf('? ������Ҫ�ļ�����\n');
        
        % ����Ƿ������˲���Ҫ���ļ�
        m_files = dir('*.m');
        if length(m_files) <= 20  % �Ż���Ӧ�ô������
            fprintf('? �ļ��������Ż� (%d��.m�ļ�)\n', length(m_files));
            test_results.file_structure = true;
            passed_tests = passed_tests + 1;
        else
            fprintf('?? �ļ������϶� (%d��.m�ļ�)\n', length(m_files));
            test_results.file_structure = false;
        end
    else
        test_results.file_structure = false;
    end
catch ME
    fprintf('? �ļ��ṹ���ʧ��: %s\n', ME.message);
    test_results.file_structure = false;
end

%% �ܽᱨ��
fprintf('\n========================================\n');
fprintf('=== ����ϵͳ��֤��� ===\n');
fprintf('�ܲ�����: %d\n', total_tests);
fprintf('ͨ������: %d\n', passed_tests);
fprintf('�ɹ���: %.1f%%\n', (passed_tests/total_tests)*100);
fprintf('========================================\n\n');

fprintf('��ϸ���:\n');
test_names = fieldnames(test_results);
for i = 1:length(test_names)
    status = test_results.(test_names{i});
    if status
        fprintf('? %s: ͨ��\n', test_names{i});
    else
        fprintf('? %s: ʧ��\n', test_names{i});
    end
end

fprintf('\n');
if passed_tests == total_tests
    fprintf('? ���в���ͨ����ϵͳ��ȫ������\n');
    fprintf('? ���������ű���������ʹ��\n');
    fprintf('? ���к��Ĺ��ܶ�����֤\n');
    fprintf('? �����߼���ȫ����\n');
else
    fprintf('?? ���ֲ���ʧ�ܣ�������ع���\n');
    fprintf('�ɹ���: %.1f%%\n', (passed_tests/total_tests)*100);
end

fprintf('\n�Ƽ�ʹ�÷�ʽ:\n');
fprintf('1. ˫�� quick_start.bat ��������ʽ����\n');
fprintf('2. ѡ��"0. Fix Model"����ϵͳ�޸�\n');
fprintf('3. ѡ��"2. Quick Training"���п���ѵ��\n');
fprintf('4. ��ֱ����MATLAB������ train_simple_ddpg\n');

% ������Խ��
assignin('base', 'system_verification_results', test_results);
fprintf('\n���Խ���ѱ��浽�����ռ����: system_verification_results\n');

end
