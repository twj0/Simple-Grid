function test_all_training_scripts()
% TEST_ALL_TRAINING_SCRIPTS - ��������ѵ���ű�
% 
% ���ٲ�������ѵ���ű��Ƿ�����������

fprintf('=== ��������ѵ���ű� ===\n');
fprintf('ʱ��: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

%% ���û���
fprintf('������Ŀ����...\n');
try
    setup_project_paths();
    fprintf('? ��Ŀ·���������\n');
catch ME
    fprintf('? ·������ʧ��: %s\n', ME.message);
    return;
end

%% ���Խ����¼
test_results = struct();
test_count = 0;
success_count = 0;

%% ����1: train_simple_ddpg
fprintf('\n=== ����1: train_simple_ddpg ===\n');
test_count = test_count + 1;
try
    % ���м�DDPGѵ��������ģʽ��
    fprintf('���м�DDPGѵ��...\n');
    tic;
    train_simple_ddpg();
    training_time = toc;
    
    fprintf('? train_simple_ddpg ����ͨ��\n');
    fprintf('   ѵ��ʱ��: %.1f ��\n', training_time);
    test_results.train_simple_ddpg = true;
    success_count = success_count + 1;
    
catch ME
    fprintf('? train_simple_ddpg ����ʧ��: %s\n', ME.message);
    test_results.train_simple_ddpg = false;
end

%% ����2: quick_train_test
fprintf('\n=== ����2: quick_train_test ===\n');
test_count = test_count + 1;
try
    fprintf('���п���ѵ������...\n');
    tic;
    quick_train_test();
    training_time = toc;
    
    fprintf('? quick_train_test ����ͨ��\n');
    fprintf('   ѵ��ʱ��: %.1f ��\n', training_time);
    test_results.quick_train_test = true;
    success_count = success_count + 1;
    
catch ME
    fprintf('? quick_train_test ����ʧ��: %s\n', ME.message);
    test_results.quick_train_test = false;
end

%% ����3: train_ddpg_microgrid (����ģʽ)
fprintf('\n=== ����3: train_ddpg_microgrid (����ģʽ) ===\n');
test_count = test_count + 1;
try
    fprintf('����DDPG΢����ѵ��������ģʽ��...\n');
    tic;
    train_ddpg_microgrid('QuickTest', true);
    training_time = toc;
    
    fprintf('? train_ddpg_microgrid ����ͨ��\n');
    fprintf('   ѵ��ʱ��: %.1f ��\n', training_time);
    test_results.train_ddpg_microgrid = true;
    success_count = success_count + 1;
    
catch ME
    fprintf('? train_ddpg_microgrid ����ʧ��: %s\n', ME.message);
    test_results.train_ddpg_microgrid = false;
end

%% ����4: train_td3_microgrid (����ģʽ)
fprintf('\n=== ����4: train_td3_microgrid (����ģʽ) ===\n');
test_count = test_count + 1;
try
    fprintf('����TD3΢����ѵ��������ģʽ��...\n');
    tic;
    train_td3_microgrid('QuickTest', true);
    training_time = toc;
    
    fprintf('? train_td3_microgrid ����ͨ��\n');
    fprintf('   ѵ��ʱ��: %.1f ��\n', training_time);
    test_results.train_td3_microgrid = true;
    success_count = success_count + 1;
    
catch ME
    fprintf('? train_td3_microgrid ����ʧ��: %s\n', ME.message);
    fprintf('   ��������: %s\n', ME.message);
    test_results.train_td3_microgrid = false;
end

%% ����5: train_sac_microgrid (����ģʽ)
fprintf('\n=== ����5: train_sac_microgrid (����ģʽ) ===\n');
test_count = test_count + 1;
try
    fprintf('����SAC΢����ѵ��������ģʽ��...\n');
    tic;
    train_sac_microgrid('QuickTest', true);
    training_time = toc;
    
    fprintf('? train_sac_microgrid ����ͨ��\n');
    fprintf('   ѵ��ʱ��: %.1f ��\n', training_time);
    test_results.train_sac_microgrid = true;
    success_count = success_count + 1;
    
catch ME
    fprintf('? train_sac_microgrid ����ʧ��: %s\n', ME.message);
    fprintf('   ��������: %s\n', ME.message);
    test_results.train_sac_microgrid = false;
end

%% �ܽᱨ��
fprintf('\n========================================\n');
fprintf('=== ѵ���ű����Խ�� ===\n');
fprintf('�ܲ�����: %d\n', test_count);
fprintf('�ɹ�����: %d\n', success_count);
fprintf('�ɹ���: %.1f%%\n', (success_count/test_count)*100);
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

%% �Ƽ�ʹ��
fprintf('\n�Ƽ�ʹ�õ�ѵ���ű�:\n');
if test_results.train_simple_ddpg
    fprintf('? train_simple_ddpg - �Ƽ���ѡ����MATLAB�����ȶ���\n');
end
if test_results.quick_train_test
    fprintf('? quick_train_test - ������֤��5�غϲ��ԣ�\n');
end
if test_results.train_ddpg_microgrid
    fprintf('? train_ddpg_microgrid - ����DDPGѵ��\n');
end

%% �������
if success_count < test_count
    fprintf('\n�������:\n');
    if ~test_results.train_td3_microgrid
        fprintf('?? TD3ѵ��ʧ�� - ������������������\n');
        fprintf('   ����: ʹ��DDPGѵ������\n');
    end
    if ~test_results.train_sac_microgrid
        fprintf('?? SACѵ��ʧ�� - ��������������������\n');
        fprintf('   ����: ʹ��DDPGѵ������\n');
    end
end

%% ������Խ��
assignin('base', 'training_script_test_results', test_results);
fprintf('\n���Խ���ѱ��浽�����ռ����: training_script_test_results\n');

%% ʹ�ý���
fprintf('\n========================================\n');
fprintf('=== ʹ�ý��� ===\n');

if success_count == test_count
    fprintf('? ����ѵ���ű�������������\n');
    fprintf('�Ƽ�ʹ��˳��:\n');
    fprintf('1. train_simple_ddpg - �ճ�ʹ��\n');
    fprintf('2. quick_train_test - ������֤\n');
    fprintf('3. train_ddpg_microgrid - ����ѵ��\n');
    fprintf('4. train_td3_microgrid - �߼��㷨\n');
    fprintf('5. train_sac_microgrid - �߼��㷨\n');
else
    fprintf('����ѵ���ű������⣬�Ƽ�ʹ��:\n');
    if test_results.train_simple_ddpg
        fprintf('? train_simple_ddpg - ���ȶ���ѡ��\n');
    end
    if test_results.quick_train_test
        fprintf('? quick_train_test - ���ٲ���\n');
    end
    if test_results.train_ddpg_microgrid
        fprintf('? train_ddpg_microgrid - ����ѵ��\n');
    end
end

fprintf('\n������������:\n');
fprintf('train_simple_ddpg  %% �Ƽ�\n');
fprintf('quick_train_test   %% ������֤\n');

end
