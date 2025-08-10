function run_microgrid_framework()
% RUN_MICROGRID_FRAMEWORK - ����ʽ΢����DRL��ܲ˵�
% 
% �ṩ�û��ѺõĽ���ʽ������ʹ��΢����DRLϵͳ

fprintf('\n');
fprintf('========================================\n');
fprintf('    ΢�������ǿ��ѧϰ���\n');
fprintf('    Microgrid Deep Reinforcement Learning Framework\n');
fprintf('========================================\n');
fprintf('�汾: �Ż��� v2.0\n');
fprintf('ʱ��: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

% ����·��
try
    setup_project_paths();
    fprintf('? ��Ŀ·���������\n\n');
catch ME
    fprintf('? ·������ʧ��: %s\n', ME.message);
    return;
end

while true
    fprintf('��ѡ�����:\n\n');
    
    fprintf('=== ? ϵͳ��� ===\n');
    fprintf('1. ϵͳ���� (��֤���й���)\n');
    fprintf('2. �������ܲ���\n');
    fprintf('3. �ۺ��޸� (�����������)\n\n');
    
    fprintf('=== ? ���ٿ�ʼ ===\n');
    fprintf('4. ����������������\n');
    fprintf('5. ����ѵ������ (5�غ�)\n');
    fprintf('6. ��DDPGѵ�� (20�غϣ��Ƽ�)\n\n');
    
    fprintf('=== ? ����ѵ�� ===\n');
    fprintf('7. DDPGѵ�� (2000�غ�)\n');
    fprintf('8. TD3ѵ�� (2000�غ�)\n');
    fprintf('9. SACѵ�� (2000�غ�)\n\n');
    
    fprintf('=== ? �����ͷ��� ===\n');
    fprintf('10. ����ѵ���õ�������\n');
    fprintf('11. ʹ��ʾ����ʾ\n');
    fprintf('12. �鿴ѵ�����\n\n');
    
    fprintf('=== ?? ��Ϣ ===\n');
    fprintf('13. �鿴ϵͳ״̬\n');
    fprintf('14. �鿴�ļ��ṹ\n');
    fprintf('15. ������Ϣ\n\n');
    
    fprintf('0. �˳�\n\n');
    
    choice = input('������ѡ�� (0-15): ', 's');
    
    fprintf('\n');
    
    switch choice
        case '1'
            run_system_test();
        case '2'
            run_basic_functionality_test();
        case '3'
            run_comprehensive_fix();
        case '4'
            create_environment_and_agent();
        case '5'
            run_quick_training();
        case '6'
            run_simple_ddpg_training();
        case '7'
            run_full_ddpg_training();
        case '8'
            run_td3_training();
        case '9'
            run_sac_training();
        case '10'
            evaluate_agent();
        case '11'
            run_usage_example();
        case '12'
            view_training_results();
        case '13'
            show_system_status();
        case '14'
            show_file_structure();
        case '15'
            show_help();
        case '0'
            fprintf('��лʹ��΢����DRL��ܣ��ټ���\n');
            break;
        otherwise
            fprintf('? ��Чѡ�����������롣\n\n');
            continue;
    end
    
    fprintf('\n�����������...\n');
    pause;
    fprintf('\n');
end

end

%% ��������

function run_system_test()
fprintf('=== ����ϵͳ���� ===\n');
try
    system_test();
catch ME
    fprintf('? ϵͳ����ʧ��: %s\n', ME.message);
end
end

function run_basic_functionality_test()
fprintf('=== ���л������ܲ��� ===\n');
try
    test_basic_functionality();
catch ME
    fprintf('? �������ܲ���ʧ��: %s\n', ME.message);
end
end

function run_comprehensive_fix()
fprintf('=== �����ۺ��޸� ===\n');
try
    complete_fix();
catch ME
    fprintf('? �ۺ��޸�ʧ��: %s\n', ME.message);
end
end

function create_environment_and_agent()
fprintf('=== ���������������� ===\n');
try
    [env, obs_info, action_info] = create_simple_matlab_environment();
    agent = create_ddpg_agent(obs_info, action_info, training_config_ddpg());
    assignin('base', 'env', env);
    assignin('base', 'agent', agent);
    fprintf('? �������������Ѵ��������浽�����ռ�\n');
    fprintf('   ������: env, agent\n');
catch ME
    fprintf('? ����ʧ��: %s\n', ME.message);
end
end

function run_quick_training()
fprintf('=== ���п���ѵ�� ===\n');
try
    quick_train_test();
catch ME
    fprintf('? ����ѵ��ʧ��: %s\n', ME.message);
end
end

function run_simple_ddpg_training()
fprintf('=== ���м�DDPGѵ�� ===\n');
try
    train_simple_ddpg();
catch ME
    fprintf('? ��DDPGѵ��ʧ��: %s\n', ME.message);
end
end

function run_full_ddpg_training()
fprintf('=== ��������DDPGѵ�� ===\n');
try
    train_ddpg_microgrid();
catch ME
    fprintf('? ����DDPGѵ��ʧ��: %s\n', ME.message);
end
end

function run_td3_training()
fprintf('=== ����TD3ѵ�� ===\n');
try
    train_td3_microgrid();
catch ME
    fprintf('? TD3ѵ��ʧ��: %s\n', ME.message);
end
end

function run_sac_training()
fprintf('=== ����SACѵ�� ===\n');
try
    train_sac_microgrid();
catch ME
    fprintf('? SACѵ��ʧ��: %s\n', ME.message);
end
end

function evaluate_agent()
fprintf('=== ���������� ===\n');
try
    evaluate_trained_agent();
catch ME
    fprintf('? ����������ʧ��: %s\n', ME.message);
end
end

function run_usage_example()
fprintf('=== ����ʹ��ʾ�� ===\n');
try
    example_usage_main();
catch ME
    fprintf('? ʹ��ʾ��ʧ��: %s\n', ME.message);
end
end

function view_training_results()
fprintf('=== �鿴ѵ����� ===\n');
mat_files = dir('*.mat');
if isempty(mat_files)
    fprintf('? δ�ҵ�ѵ������ļ�\n');
    return;
end

fprintf('�ҵ���ѵ������ļ�:\n');
for i = 1:length(mat_files)
    fprintf('  %d. %s\n', i, mat_files(i).name);
end

choice = input('ѡ��Ҫ�鿴���ļ����: ');
if choice >= 1 && choice <= length(mat_files)
    try
        data = load(mat_files(choice).name);
        fprintf('�ļ�����:\n');
        disp(data);
    catch ME
        fprintf('? �����ļ�ʧ��: %s\n', ME.message);
    end
else
    fprintf('? ��Чѡ��\n');
end
end

function show_system_status()
fprintf('=== ϵͳ״̬ ===\n');
fprintf('MATLAB�汾: %s\n', version);
fprintf('��ǰĿ¼: %s\n', pwd);
fprintf('�����ռ����:\n');
evalin('base', 'whos');
end

function show_file_structure()
fprintf('=== �ļ��ṹ ===\n');
fprintf('��Ҫ�ļ�:\n');
files = dir('*.m');
for i = 1:length(files)
    fprintf('  %s\n', files(i).name);
end
end

function show_help()
fprintf('=== ������Ϣ ===\n');
fprintf('΢�������ǿ��ѧϰ���ʹ��ָ��:\n\n');
fprintf('1. �״�ʹ�ý���:\n');
fprintf('   - ����"ϵͳ����"��֤����\n');
fprintf('   - ����"�������ܲ���"�˽�ϵͳ\n');
fprintf('   - ������������"�ۺ��޸�"\n\n');
fprintf('2. ѵ������:\n');
fprintf('   - �����Ƽ�"��DDPGѵ��"\n');
fprintf('   - ���ٲ���ʹ��"����ѵ������"\n');
fprintf('   - ����ѵ����Ҫ�ϳ�ʱ��\n\n');
fprintf('3. ��������:\n');
fprintf('   - ��MATLAB����(�Ƽ�): ��Simulink����\n');
fprintf('   - �����Ի���: ֧��Simulink����\n\n');
fprintf('4. �ļ�˵��:\n');
fprintf('   - train_simple_ddpg.m: �Ƽ���ѵ���ű�\n');
fprintf('   - MicrogridEnvironment.m: ������\n');
fprintf('   - scripts/: ���ú͹���ģ��\n\n');
fprintf('5. �����Ų�:\n');
fprintf('   - �鿴OPTIMIZATION_COMPLETE.md\n');
fprintf('   - �����ۺ��޸������������\n');
fprintf('   - ��鹤���ռ������Ƿ����\n');
end
