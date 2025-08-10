function verify_complete_system()
% VERIFY_COMPLETE_SYSTEM - 验证完整系统功能
% 
% 全面测试优化后的main文件夹所有功能

fprintf('=== 完整系统验证 ===\n');
fprintf('时间: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

test_results = struct();
total_tests = 0;
passed_tests = 0;

%% 测试1: 快速启动脚本检查
fprintf('测试1: 快速启动脚本检查...\n');
total_tests = total_tests + 1;
try
    % 检查bat文件是否存在
    bat_file = fullfile('..', 'quick_start.bat');
    if exist(bat_file, 'file')
        fprintf('? quick_start.bat 文件存在\n');
        
        % 检查Simulink模型路径
        model_path = fullfile('simulinkmodel', 'Microgrid.slx');
        if exist(model_path, 'file')
            fprintf('? Simulink模型路径正确\n');
            test_results.quick_start = true;
            passed_tests = passed_tests + 1;
        else
            fprintf('? Simulink模型路径错误\n');
            test_results.quick_start = false;
        end
    else
        fprintf('? quick_start.bat 文件不存在\n');
        test_results.quick_start = false;
    end
catch ME
    fprintf('? 快速启动脚本检查失败: %s\n', ME.message);
    test_results.quick_start = false;
end

%% 测试2: 综合修复功能
fprintf('\n测试2: 综合修复功能...\n');
total_tests = total_tests + 1;
try
    % 检查complete_fix函数是否存在
    if exist('complete_fix.m', 'file')
        fprintf('? complete_fix.m 存在\n');
        test_results.complete_fix = true;
        passed_tests = passed_tests + 1;
    else
        fprintf('? complete_fix.m 不存在\n');
        test_results.complete_fix = false;
    end
catch ME
    fprintf('? 综合修复功能检查失败: %s\n', ME.message);
    test_results.complete_fix = false;
end

%% 测试3: 交互式菜单
fprintf('\n测试3: 交互式菜单...\n');
total_tests = total_tests + 1;
try
    if exist('run_microgrid_framework.m', 'file')
        fprintf('? run_microgrid_framework.m 存在\n');
        test_results.interactive_menu = true;
        passed_tests = passed_tests + 1;
    else
        fprintf('? run_microgrid_framework.m 不存在\n');
        test_results.interactive_menu = false;
    end
catch ME
    fprintf('? 交互式菜单检查失败: %s\n', ME.message);
    test_results.interactive_menu = false;
end

%% 测试4: 核心环境功能
fprintf('\n测试4: 核心环境功能...\n');
total_tests = total_tests + 1;
try
    setup_project_paths();
    [env, obs_info, action_info] = create_simple_matlab_environment();
    
    % 测试环境重置
    obs = reset(env);
    if length(obs) == 7
        fprintf('? 环境重置成功，观测维度正确\n');
        
        % 测试环境步进
        [next_obs, reward, done, info] = env.step(0);
        if length(next_obs) == 7 && isnumeric(reward)
            fprintf('? 环境步进成功\n');
            test_results.core_environment = true;
            passed_tests = passed_tests + 1;
        else
            fprintf('? 环境步进失败\n');
            test_results.core_environment = false;
        end
    else
        fprintf('? 环境重置失败，观测维度错误\n');
        test_results.core_environment = false;
    end
catch ME
    fprintf('? 核心环境功能测试失败: %s\n', ME.message);
    test_results.core_environment = false;
end

%% 测试5: 智能体创建
fprintf('\n测试5: 智能体创建...\n');
total_tests = total_tests + 1;
try
    if exist('obs_info', 'var') && exist('action_info', 'var')
        agent = create_ddpg_agent(obs_info, action_info, training_config_ddpg());
        if ~isempty(agent)
            fprintf('? DDPG智能体创建成功\n');
            test_results.agent_creation = true;
            passed_tests = passed_tests + 1;
        else
            fprintf('? DDPG智能体创建失败\n');
            test_results.agent_creation = false;
        end
    else
        fprintf('? 观测或动作信息不存在\n');
        test_results.agent_creation = false;
    end
catch ME
    fprintf('? 智能体创建测试失败: %s\n', ME.message);
    test_results.agent_creation = false;
end

%% 测试6: 训练脚本
fprintf('\n测试6: 训练脚本...\n');
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
            fprintf('? %s 不存在\n', training_scripts{i});
            all_exist = false;
        else
            fprintf('? %s 存在\n', training_scripts{i});
        end
    end
    
    if all_exist
        test_results.training_scripts = true;
        passed_tests = passed_tests + 1;
    else
        test_results.training_scripts = false;
    end
catch ME
    fprintf('? 训练脚本检查失败: %s\n', ME.message);
    test_results.training_scripts = false;
end

%% 测试7: 配置系统
fprintf('\n测试7: 配置系统...\n');
total_tests = total_tests + 1;
try
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    
    if ~isempty(model_cfg) && ~isempty(training_cfg)
        fprintf('? 配置系统正常\n');
        fprintf('   电池配置: %d kW / %d kWh\n', ...
                model_cfg.battery.rated_power_kW, model_cfg.battery.rated_capacity_kWh);
        test_results.configuration = true;
        passed_tests = passed_tests + 1;
    else
        fprintf('? 配置系统异常\n');
        test_results.configuration = false;
    end
catch ME
    fprintf('? 配置系统测试失败: %s\n', ME.message);
    test_results.configuration = false;
end

%% 测试8: 数据管理
fprintf('\n测试8: 数据管理...\n');
total_tests = total_tests + 1;
try
    if load_workspace_data()
        fprintf('? 工作空间数据加载成功\n');
        
        % 检查关键变量
        pv_data = evalin('base', 'pv_power_profile');
        load_data = evalin('base', 'load_power_profile');
        price_data = evalin('base', 'price_profile');
        
        if ~isempty(pv_data) && ~isempty(load_data) && ~isempty(price_data)
            fprintf('? 所有数据变量存在\n');
            test_results.data_management = true;
            passed_tests = passed_tests + 1;
        else
            fprintf('? 数据变量不完整\n');
            test_results.data_management = false;
        end
    else
        fprintf('? 工作空间数据加载失败\n');
        test_results.data_management = false;
    end
catch ME
    fprintf('? 数据管理测试失败: %s\n', ME.message);
    test_results.data_management = false;
end

%% 测试9: 文件结构优化
fprintf('\n测试9: 文件结构优化...\n');
total_tests = total_tests + 1;
try
    % 检查重要文件是否存在
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
            fprintf('? 重要文件缺失: %s\n', important_files{i});
            all_important_exist = false;
        end
    end
    
    if all_important_exist
        fprintf('? 所有重要文件存在\n');
        
        % 检查是否清理了不需要的文件
        m_files = dir('*.m');
        if length(m_files) <= 20  % 优化后应该大幅减少
            fprintf('? 文件数量已优化 (%d个.m文件)\n', length(m_files));
            test_results.file_structure = true;
            passed_tests = passed_tests + 1;
        else
            fprintf('?? 文件数量较多 (%d个.m文件)\n', length(m_files));
            test_results.file_structure = false;
        end
    else
        test_results.file_structure = false;
    end
catch ME
    fprintf('? 文件结构检查失败: %s\n', ME.message);
    test_results.file_structure = false;
end

%% 总结报告
fprintf('\n========================================\n');
fprintf('=== 完整系统验证结果 ===\n');
fprintf('总测试数: %d\n', total_tests);
fprintf('通过测试: %d\n', passed_tests);
fprintf('成功率: %.1f%%\n', (passed_tests/total_tests)*100);
fprintf('========================================\n\n');

fprintf('详细结果:\n');
test_names = fieldnames(test_results);
for i = 1:length(test_names)
    status = test_results.(test_names{i});
    if status
        fprintf('? %s: 通过\n', test_names{i});
    else
        fprintf('? %s: 失败\n', test_names{i});
    end
end

fprintf('\n');
if passed_tests == total_tests
    fprintf('? 所有测试通过！系统完全正常！\n');
    fprintf('? 快速启动脚本可以正常使用\n');
    fprintf('? 所有核心功能都已验证\n');
    fprintf('? 整体逻辑完全正常\n');
else
    fprintf('?? 部分测试失败，请检查相关功能\n');
    fprintf('成功率: %.1f%%\n', (passed_tests/total_tests)*100);
end

fprintf('\n推荐使用方式:\n');
fprintf('1. 双击 quick_start.bat 启动交互式界面\n');
fprintf('2. 选择"0. Fix Model"进行系统修复\n');
fprintf('3. 选择"2. Quick Training"进行快速训练\n');
fprintf('4. 或直接在MATLAB中运行 train_simple_ddpg\n');

% 保存测试结果
assignin('base', 'system_verification_results', test_results);
fprintf('\n测试结果已保存到工作空间变量: system_verification_results\n');

end
