function validate_complete_workflow()
% VALIDATE_COMPLETE_WORKFLOW - ��֤������DRL��������
%
% �˺�����֤���������ļ�������DRLѵ���ͺ����������������

fprintf('=== ��������������֤ ===\n');
fprintf('��֤ʱ��: %s\n', datestr(now));
fprintf('Ŀ��: ȷ���������ļ���DRLѵ�����������������������������\n\n');

%% �׶�1����Ŀ�ṹ��֤
fprintf('�׶�1����Ŀ�ṹ��֤\n');
fprintf('%s\n', repmat('=', 1, 40));

% ��֤�����ļ�����
core_files = {
    'train_microgrid_drl.m';
    'run_quick_training.m';
    'run_scientific_drl_menu.m';
    'analyze_results.m';
    'setup_project_paths.m';
    'load_workspace_data.m';
    'simulinkmodel/Microgrid.slx';
    'config/simulation_config.m';
    'data/microgrid_workspace.mat';
};

missing_files = {};
for i = 1:length(core_files)
    if exist(core_files{i}, 'file')
        fprintf('  ? %s\n', core_files{i});
    else
        fprintf('  ? %s (ȱʧ)\n', core_files{i});
        missing_files{end+1} = core_files{i};
    end
end

if ~isempty(missing_files)
    fprintf('\n���棺����ȱʧ�ļ�������Ӱ�칤������\n');
    for i = 1:length(missing_files)
        fprintf('  - %s\n', missing_files{i});
    end
end

%% �׶�2��Simulinkģ����֤
fprintf('\n�׶�2��Simulinkģ����֤\n');
fprintf('%s\n', repmat('=', 1, 40));

try
    model_path = 'simulinkmodel/Microgrid.slx';
    if exist(model_path, 'file')
        fprintf('���ڼ���Simulinkģ��...\n');
        load_system(model_path);
        fprintf('  ? Simulinkģ�ͼ��سɹ�\n');
        
        % ���ؼ�ģ��
        model_name = 'simulinkmodel/Microgrid';
        
        % ���RL Agent��
        rl_blocks = find_system(model_name, 'BlockType', 'RL Agent');
        if ~isempty(rl_blocks)
            fprintf('  ? RL Agent�����\n');
        else
            fprintf('  ? RL Agent��δ�ҵ�\n');
        end
        
        % �����ģ��
        battery_blocks = find_system(model_name, 'Name', 'Battery');
        if ~isempty(battery_blocks)
            fprintf('  ? ���ģ�����\n');
        else
            fprintf('  ? ���ģ��δ�ҵ�\n');
        end
        
        close_system(model_name, 0);
        fprintf('  ? ģ����֤���\n');
    else
        fprintf('  ? Simulinkģ���ļ�������\n');
    end
catch ME
    fprintf('  ? Simulinkģ����֤ʧ��: %s\n', ME.message);
end

%% �׶�3��DRL������֤
fprintf('\n�׶�3��DRL������֤\n');
fprintf('%s\n', repmat('=', 1, 40));

try
    fprintf('������֤DRL��������...\n');
    
    % ����·��
    setup_project_paths();
    fprintf('  ? ��Ŀ·���������\n');
    
    % ��������
    load_workspace_data();
    fprintf('  ? �����ռ����ݼ������\n');
    
    % �����������򻯰汾������֤��
    fprintf('���ڴ������Ի���...\n');
    
    % ������������
    env_params = struct();
    env_params.simulation_days = 1;
    env_params.episodes = 2;
    env_params.max_steps_per_episode = 24;
    
    fprintf('  ? ���������������\n');
    
    % ��֤�����崴��
    fprintf('������֤�����崴��...\n');
    
    % �۲�Ͷ����ռ䶨��
    obs_info = rlNumericSpec([7 1]);
    obs_info.Name = 'observations';
    
    act_info = rlNumericSpec([1 1], 'LowerLimit', -1, 'UpperLimit', 1);
    act_info.Name = 'battery_power';
    
    fprintf('  ? �۲�Ͷ����ռ䶨�����\n');
    
    % �����򵥵�DDPG������������֤
    fprintf('���ڴ�����֤��DDPG������...\n');
    
    % Actor����
    actor_net = [
        featureInputLayer(7, 'Normalization', 'none', 'Name', 'state')
        fullyConnectedLayer(64, 'Name', 'fc1')
        reluLayer('Name', 'relu1')
        fullyConnectedLayer(32, 'Name', 'fc2')
        reluLayer('Name', 'relu2')
        fullyConnectedLayer(1, 'Name', 'action')
        tanhLayer('Name', 'tanh')
    ];
    
    actor_options = rlRepresentationOptions('LearnRate', 1e-3, 'GradientThreshold', 1);
    actor = rlDeterministicActorRepresentation(actor_net, obs_info, act_info, ...
        'Observation', {'state'}, 'Action', {'tanh'}, actor_options);
    
    % Critic����
    state_path = [
        featureInputLayer(7, 'Normalization', 'none', 'Name', 'state')
        fullyConnectedLayer(64, 'Name', 'state_fc1')
        reluLayer('Name', 'state_relu1')
    ];
    
    action_path = [
        featureInputLayer(1, 'Normalization', 'none', 'Name', 'action')
        fullyConnectedLayer(64, 'Name', 'action_fc1')
        reluLayer('Name', 'action_relu1')
    ];
    
    common_path = [
        additionLayer(2, 'Name', 'add')
        fullyConnectedLayer(32, 'Name', 'common_fc1')
        reluLayer('Name', 'common_relu1')
        fullyConnectedLayer(1, 'Name', 'q_value')
    ];
    
    critic_net = layerGraph(state_path);
    critic_net = addLayers(critic_net, action_path);
    critic_net = addLayers(critic_net, common_path);
    critic_net = connectLayers(critic_net, 'state_relu1', 'add/in1');
    critic_net = connectLayers(critic_net, 'action_relu1', 'add/in2');
    
    critic_options = rlRepresentationOptions('LearnRate', 1e-3, 'GradientThreshold', 1);
    critic = rlQValueRepresentation(critic_net, obs_info, act_info, ...
        'Observation', {'state'}, 'Action', {'action'}, critic_options);
    
    % ����DDPG������
    agent_options = rlDDPGAgentOptions(...
        'SampleTime', 3600, ...
        'TargetSmoothFactor', 1e-3, ...
        'ExperienceBufferLength', 1e6, ...
        'MiniBatchSize', 64);
    
    test_agent = rlDDPGAgent(actor, critic, agent_options);
    
    fprintf('  ? ��֤��DDPG�����崴���ɹ�\n');
    
catch ME
    fprintf('  ? DRL������֤ʧ��: %s\n', ME.message);
end

%% �׶�4����������֤
fprintf('\n�׶�4����������֤\n');
fprintf('%s\n', repmat('=', 1, 40));

try
    fprintf('������֤������...\n');
    
    % ����ģ��ѵ�����
    mock_results = struct();
    mock_results.episode_rewards = randn(1, 10) * 100 - 50;
    mock_results.episode_steps = ones(1, 10) * 24;
    mock_results.training_time = 300; % 5����
    mock_results.algorithm = 'ddpg';
    mock_results.config = 'test';
    
    fprintf('  ? ģ��ѵ������������\n');
    
    % ��֤���ӻ�����
    fprintf('������֤���ӻ�����...\n');
    
    % �����򵥵�����ͼ��
    figure('Visible', 'off');
    plot(mock_results.episode_rewards);
    title('Episode Rewards (Validation Test)');
    xlabel('Episode');
    ylabel('Reward');
    grid on;
    
    % �������ͼ��
    test_fig_path = 'results/validation_test_plot.png';
    if ~exist('results', 'dir')
        mkdir('results');
    end
    saveas(gcf, test_fig_path);
    close(gcf);
    
    if exist(test_fig_path, 'file')
        fprintf('  ? ���ӻ���������\n');
        fprintf('  ? ����ͼ����: %s\n', test_fig_path);
    else
        fprintf('  ? ͼ����ʧ��\n');
    end
    
catch ME
    fprintf('  ? ��������֤ʧ��: %s\n', ME.message);
end

%% �׶�5���������ļ�������֤
fprintf('\n�׶�5���������ļ�������֤\n');
fprintf('%s\n', repmat('=', 1, 40));

% ����������ļ�
bat_file = '../quick_start.bat';
if exist(bat_file, 'file')
    fprintf('  ? �������ļ�����: %s\n', bat_file);
    
    % ��ȡ�������ļ�������֤�ؼ�����
    fid = fopen(bat_file, 'r');
    if fid > 0
        content = fread(fid, '*char')';
        fclose(fid);
        
        % ���ؼ�����
        if contains(content, 'setup_project_paths')
            fprintf('  ? ·�����ü�����ȷ\n');
        else
            fprintf('  ? ·�����ü��ɿ���������\n');
        end
        
        if contains(content, 'train_microgrid_drl')
            fprintf('  ? DRLѵ��������ȷ\n');
        else
            fprintf('  ? DRLѵ�����ɿ���������\n');
        end
        
        if contains(content, 'analyze_results')
            fprintf('  ? �������������ȷ\n');
        else
            fprintf('  ? ����������ɿ���������\n');
        end
        
        if contains(content, 'simulinkmodel/Microgrid.slx')
            fprintf('  ? Simulinkģ��·����ȷ\n');
        else
            fprintf('  ? Simulinkģ��·������������\n');
        end
    else
        fprintf('  ? �޷���ȡ�������ļ�����\n');
    end
else
    fprintf('  ? �������ļ�������\n');
end

%% ��֤�ܽ�
fprintf('\n=== ��֤�ܽ� ===\n');
fprintf('%s\n', repmat('=', 1, 40));

fprintf('��֤���ʱ��: %s\n', datestr(now));
fprintf('\n�������״̬:\n');
fprintf('  - ��Ŀ�ṹ: %s\n', ternary(isempty(missing_files), '? ����', '? ��ȱʧ'));
fprintf('  - Simulinkģ��: %s\n', ternary(exist('simulinkmodel/Microgrid.slx', 'file'), '? ����', '? ȱʧ'));
fprintf('  - DRL����: %s\n', ternary(exist('test_agent', 'var'), '? ����', '? ����'));
fprintf('  - ������: %s\n', ternary(exist(test_fig_path, 'file'), '? ����', '? ����'));
fprintf('  - ��������: %s\n', ternary(exist(bat_file, 'file'), '? ����', '? ȱʧ'));

fprintf('\n��������״̬:\n');
if isempty(missing_files) && exist('simulinkmodel/Microgrid.slx', 'file') && exist(bat_file, 'file')
    fprintf('  ? �����������̿���\n');
    fprintf('  ? ����ͨ���������ļ�����DRLѵ��\n');
    fprintf('  ? ���Խ��к������\n');
    fprintf('  ? �ʺ�ѧ��ʹ�ú���ʦ��ʾ\n');
else
    fprintf('  ? �������̿��ܲ�����\n');
    fprintf('  ? ������ȱʧ���\n');
end

fprintf('\n�����ʹ������:\n');
fprintf('  1. ���и�Ŀ¼��quick_start.bat\n');
fprintf('  2. ѡ���ʵ���ѵ�����ã�����/Ĭ��/�о���\n');
fprintf('  3. ѡ��DRL�㷨��DDPG/TD3/SAC��\n');
fprintf('  4. �ȴ�ѵ�����\n');
fprintf('  5. ���н������\n');
fprintf('  6. �鿴���ɵ�ͼ��ͱ���\n');

fprintf('\n=== ��֤��� ===\n');

end

function result = ternary(condition, true_val, false_val)
if condition
    result = true_val;
else
    result = false_val;
end
end
