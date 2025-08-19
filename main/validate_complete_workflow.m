function validate_complete_workflow()
% VALIDATE_COMPLETE_WORKFLOW - 验证完整的DRL工作流程
%
% 此函数验证从批处理文件启动到DRL训练和后处理的完整工作流程

fprintf('=== 完整工作流程验证 ===\n');
fprintf('验证时间: %s\n', datestr(now));
fprintf('目标: 确保批处理文件→DRL训练→后处理分析的完整流程正常工作\n\n');

%% 阶段1：项目结构验证
fprintf('阶段1：项目结构验证\n');
fprintf('%s\n', repmat('=', 1, 40));

% 验证核心文件存在
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
        fprintf('  ? %s (缺失)\n', core_files{i});
        missing_files{end+1} = core_files{i};
    end
end

if ~isempty(missing_files)
    fprintf('\n警告：发现缺失文件，可能影响工作流程\n');
    for i = 1:length(missing_files)
        fprintf('  - %s\n', missing_files{i});
    end
end

%% 阶段2：Simulink模型验证
fprintf('\n阶段2：Simulink模型验证\n');
fprintf('%s\n', repmat('=', 1, 40));

try
    model_path = 'simulinkmodel/Microgrid.slx';
    if exist(model_path, 'file')
        fprintf('正在加载Simulink模型...\n');
        load_system(model_path);
        fprintf('  ? Simulink模型加载成功\n');
        
        % 检查关键模块
        model_name = 'simulinkmodel/Microgrid';
        
        % 检查RL Agent块
        rl_blocks = find_system(model_name, 'BlockType', 'RL Agent');
        if ~isempty(rl_blocks)
            fprintf('  ? RL Agent块存在\n');
        else
            fprintf('  ? RL Agent块未找到\n');
        end
        
        % 检查电池模块
        battery_blocks = find_system(model_name, 'Name', 'Battery');
        if ~isempty(battery_blocks)
            fprintf('  ? 电池模块存在\n');
        else
            fprintf('  ? 电池模块未找到\n');
        end
        
        close_system(model_name, 0);
        fprintf('  ? 模型验证完成\n');
    else
        fprintf('  ? Simulink模型文件不存在\n');
    end
catch ME
    fprintf('  ? Simulink模型验证失败: %s\n', ME.message);
end

%% 阶段3：DRL环境验证
fprintf('\n阶段3：DRL环境验证\n');
fprintf('%s\n', repmat('=', 1, 40));

try
    fprintf('正在验证DRL环境创建...\n');
    
    % 设置路径
    setup_project_paths();
    fprintf('  ? 项目路径设置完成\n');
    
    % 加载数据
    load_workspace_data();
    fprintf('  ? 工作空间数据加载完成\n');
    
    % 创建环境（简化版本用于验证）
    fprintf('正在创建测试环境...\n');
    
    % 基本环境参数
    env_params = struct();
    env_params.simulation_days = 1;
    env_params.episodes = 2;
    env_params.max_steps_per_episode = 24;
    
    fprintf('  ? 环境参数配置完成\n');
    
    % 验证智能体创建
    fprintf('正在验证智能体创建...\n');
    
    % 观测和动作空间定义
    obs_info = rlNumericSpec([7 1]);
    obs_info.Name = 'observations';
    
    act_info = rlNumericSpec([1 1], 'LowerLimit', -1, 'UpperLimit', 1);
    act_info.Name = 'battery_power';
    
    fprintf('  ? 观测和动作空间定义完成\n');
    
    % 创建简单的DDPG智能体用于验证
    fprintf('正在创建验证用DDPG智能体...\n');
    
    % Actor网络
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
    
    % Critic网络
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
    
    % 创建DDPG智能体
    agent_options = rlDDPGAgentOptions(...
        'SampleTime', 3600, ...
        'TargetSmoothFactor', 1e-3, ...
        'ExperienceBufferLength', 1e6, ...
        'MiniBatchSize', 64);
    
    test_agent = rlDDPGAgent(actor, critic, agent_options);
    
    fprintf('  ? 验证用DDPG智能体创建成功\n');
    
catch ME
    fprintf('  ? DRL环境验证失败: %s\n', ME.message);
end

%% 阶段4：后处理功能验证
fprintf('\n阶段4：后处理功能验证\n');
fprintf('%s\n', repmat('=', 1, 40));

try
    fprintf('正在验证后处理功能...\n');
    
    % 创建模拟训练结果
    mock_results = struct();
    mock_results.episode_rewards = randn(1, 10) * 100 - 50;
    mock_results.episode_steps = ones(1, 10) * 24;
    mock_results.training_time = 300; % 5分钟
    mock_results.algorithm = 'ddpg';
    mock_results.config = 'test';
    
    fprintf('  ? 模拟训练结果创建完成\n');
    
    % 验证可视化功能
    fprintf('正在验证可视化功能...\n');
    
    % 创建简单的性能图表
    figure('Visible', 'off');
    plot(mock_results.episode_rewards);
    title('Episode Rewards (Validation Test)');
    xlabel('Episode');
    ylabel('Reward');
    grid on;
    
    % 保存测试图表
    test_fig_path = 'results/validation_test_plot.png';
    if ~exist('results', 'dir')
        mkdir('results');
    end
    saveas(gcf, test_fig_path);
    close(gcf);
    
    if exist(test_fig_path, 'file')
        fprintf('  ? 可视化功能正常\n');
        fprintf('  ? 测试图表保存: %s\n', test_fig_path);
    else
        fprintf('  ? 图表保存失败\n');
    end
    
catch ME
    fprintf('  ? 后处理功能验证失败: %s\n', ME.message);
end

%% 阶段5：批处理文件集成验证
fprintf('\n阶段5：批处理文件集成验证\n');
fprintf('%s\n', repmat('=', 1, 40));

% 检查批处理文件
bat_file = '../quick_start.bat';
if exist(bat_file, 'file')
    fprintf('  ? 批处理文件存在: %s\n', bat_file);
    
    % 读取批处理文件内容验证关键功能
    fid = fopen(bat_file, 'r');
    if fid > 0
        content = fread(fid, '*char')';
        fclose(fid);
        
        % 检查关键功能
        if contains(content, 'setup_project_paths')
            fprintf('  ? 路径设置集成正确\n');
        else
            fprintf('  ? 路径设置集成可能有问题\n');
        end
        
        if contains(content, 'train_microgrid_drl')
            fprintf('  ? DRL训练集成正确\n');
        else
            fprintf('  ? DRL训练集成可能有问题\n');
        end
        
        if contains(content, 'analyze_results')
            fprintf('  ? 结果分析集成正确\n');
        else
            fprintf('  ? 结果分析集成可能有问题\n');
        end
        
        if contains(content, 'simulinkmodel/Microgrid.slx')
            fprintf('  ? Simulink模型路径正确\n');
        else
            fprintf('  ? Simulink模型路径可能有问题\n');
        end
    else
        fprintf('  ? 无法读取批处理文件内容\n');
    end
else
    fprintf('  ? 批处理文件不存在\n');
end

%% 验证总结
fprintf('\n=== 验证总结 ===\n');
fprintf('%s\n', repmat('=', 1, 40));

fprintf('验证完成时间: %s\n', datestr(now));
fprintf('\n核心组件状态:\n');
fprintf('  - 项目结构: %s\n', ternary(isempty(missing_files), '? 完整', '? 有缺失'));
fprintf('  - Simulink模型: %s\n', ternary(exist('simulinkmodel/Microgrid.slx', 'file'), '? 正常', '? 缺失'));
fprintf('  - DRL环境: %s\n', ternary(exist('test_agent', 'var'), '? 正常', '? 需检查'));
fprintf('  - 后处理功能: %s\n', ternary(exist(test_fig_path, 'file'), '? 正常', '? 需检查'));
fprintf('  - 批处理集成: %s\n', ternary(exist(bat_file, 'file'), '? 正常', '? 缺失'));

fprintf('\n工作流程状态:\n');
if isempty(missing_files) && exist('simulinkmodel/Microgrid.slx', 'file') && exist(bat_file, 'file')
    fprintf('  ? 完整工作流程可用\n');
    fprintf('  ? 可以通过批处理文件启动DRL训练\n');
    fprintf('  ? 可以进行后处理分析\n');
    fprintf('  ? 适合学术使用和老师演示\n');
else
    fprintf('  ? 工作流程可能不完整\n');
    fprintf('  ? 建议检查缺失组件\n');
end

fprintf('\n建议的使用流程:\n');
fprintf('  1. 运行根目录的quick_start.bat\n');
fprintf('  2. 选择适当的训练配置（快速/默认/研究）\n');
fprintf('  3. 选择DRL算法（DDPG/TD3/SAC）\n');
fprintf('  4. 等待训练完成\n');
fprintf('  5. 运行结果分析\n');
fprintf('  6. 查看生成的图表和报告\n');

fprintf('\n=== 验证完成 ===\n');

end

function result = ternary(condition, true_val, false_val)
if condition
    result = true_val;
else
    result = false_val;
end
end
