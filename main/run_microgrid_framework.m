function run_microgrid_framework()
% RUN_MICROGRID_FRAMEWORK - 交互式微电网DRL框架菜单
% 
% 提供用户友好的交互式界面来使用微电网DRL系统

fprintf('\n');
fprintf('========================================\n');
fprintf('    微电网深度强化学习框架\n');
fprintf('    Microgrid Deep Reinforcement Learning Framework\n');
fprintf('========================================\n');
fprintf('版本: 优化版 v2.0\n');
fprintf('时间: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

% 设置路径
try
    setup_project_paths();
    fprintf('? 项目路径设置完成\n\n');
catch ME
    fprintf('? 路径设置失败: %s\n', ME.message);
    return;
end

while true
    fprintf('请选择操作:\n\n');
    
    fprintf('=== ? 系统检查 ===\n');
    fprintf('1. 系统测试 (验证所有功能)\n');
    fprintf('2. 基本功能测试\n');
    fprintf('3. 综合修复 (解决常见问题)\n\n');
    
    fprintf('=== ? 快速开始 ===\n');
    fprintf('4. 创建环境和智能体\n');
    fprintf('5. 快速训练测试 (5回合)\n');
    fprintf('6. 简化DDPG训练 (20回合，推荐)\n\n');
    
    fprintf('=== ? 完整训练 ===\n');
    fprintf('7. DDPG训练 (2000回合)\n');
    fprintf('8. TD3训练 (2000回合)\n');
    fprintf('9. SAC训练 (2000回合)\n\n');
    
    fprintf('=== ? 评估和分析 ===\n');
    fprintf('10. 评估训练好的智能体\n');
    fprintf('11. 使用示例演示\n');
    fprintf('12. 查看训练结果\n\n');
    
    fprintf('=== ?? 信息 ===\n');
    fprintf('13. 查看系统状态\n');
    fprintf('14. 查看文件结构\n');
    fprintf('15. 帮助信息\n\n');
    
    fprintf('0. 退出\n\n');
    
    choice = input('请输入选择 (0-15): ', 's');
    
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
            fprintf('感谢使用微电网DRL框架！再见！\n');
            break;
        otherwise
            fprintf('? 无效选择，请重新输入。\n\n');
            continue;
    end
    
    fprintf('\n按任意键继续...\n');
    pause;
    fprintf('\n');
end

end

%% 辅助函数

function run_system_test()
fprintf('=== 运行系统测试 ===\n');
try
    system_test();
catch ME
    fprintf('? 系统测试失败: %s\n', ME.message);
end
end

function run_basic_functionality_test()
fprintf('=== 运行基本功能测试 ===\n');
try
    test_basic_functionality();
catch ME
    fprintf('? 基本功能测试失败: %s\n', ME.message);
end
end

function run_comprehensive_fix()
fprintf('=== 运行综合修复 ===\n');
try
    complete_fix();
catch ME
    fprintf('? 综合修复失败: %s\n', ME.message);
end
end

function create_environment_and_agent()
fprintf('=== 创建环境和智能体 ===\n');
try
    [env, obs_info, action_info] = create_simple_matlab_environment();
    agent = create_ddpg_agent(obs_info, action_info, training_config_ddpg());
    assignin('base', 'env', env);
    assignin('base', 'agent', agent);
    fprintf('? 环境和智能体已创建并保存到工作空间\n');
    fprintf('   变量名: env, agent\n');
catch ME
    fprintf('? 创建失败: %s\n', ME.message);
end
end

function run_quick_training()
fprintf('=== 运行快速训练 ===\n');
try
    quick_train_test();
catch ME
    fprintf('? 快速训练失败: %s\n', ME.message);
end
end

function run_simple_ddpg_training()
fprintf('=== 运行简化DDPG训练 ===\n');
try
    train_simple_ddpg();
catch ME
    fprintf('? 简化DDPG训练失败: %s\n', ME.message);
end
end

function run_full_ddpg_training()
fprintf('=== 运行完整DDPG训练 ===\n');
try
    train_ddpg_microgrid();
catch ME
    fprintf('? 完整DDPG训练失败: %s\n', ME.message);
end
end

function run_td3_training()
fprintf('=== 运行TD3训练 ===\n');
try
    train_td3_microgrid();
catch ME
    fprintf('? TD3训练失败: %s\n', ME.message);
end
end

function run_sac_training()
fprintf('=== 运行SAC训练 ===\n');
try
    train_sac_microgrid();
catch ME
    fprintf('? SAC训练失败: %s\n', ME.message);
end
end

function evaluate_agent()
fprintf('=== 评估智能体 ===\n');
try
    evaluate_trained_agent();
catch ME
    fprintf('? 智能体评估失败: %s\n', ME.message);
end
end

function run_usage_example()
fprintf('=== 运行使用示例 ===\n');
try
    example_usage_main();
catch ME
    fprintf('? 使用示例失败: %s\n', ME.message);
end
end

function view_training_results()
fprintf('=== 查看训练结果 ===\n');
mat_files = dir('*.mat');
if isempty(mat_files)
    fprintf('? 未找到训练结果文件\n');
    return;
end

fprintf('找到的训练结果文件:\n');
for i = 1:length(mat_files)
    fprintf('  %d. %s\n', i, mat_files(i).name);
end

choice = input('选择要查看的文件编号: ');
if choice >= 1 && choice <= length(mat_files)
    try
        data = load(mat_files(choice).name);
        fprintf('文件内容:\n');
        disp(data);
    catch ME
        fprintf('? 加载文件失败: %s\n', ME.message);
    end
else
    fprintf('? 无效选择\n');
end
end

function show_system_status()
fprintf('=== 系统状态 ===\n');
fprintf('MATLAB版本: %s\n', version);
fprintf('当前目录: %s\n', pwd);
fprintf('工作空间变量:\n');
evalin('base', 'whos');
end

function show_file_structure()
fprintf('=== 文件结构 ===\n');
fprintf('主要文件:\n');
files = dir('*.m');
for i = 1:length(files)
    fprintf('  %s\n', files(i).name);
end
end

function show_help()
fprintf('=== 帮助信息 ===\n');
fprintf('微电网深度强化学习框架使用指南:\n\n');
fprintf('1. 首次使用建议:\n');
fprintf('   - 运行"系统测试"验证功能\n');
fprintf('   - 运行"基本功能测试"了解系统\n');
fprintf('   - 如有问题运行"综合修复"\n\n');
fprintf('2. 训练建议:\n');
fprintf('   - 新手推荐"简化DDPG训练"\n');
fprintf('   - 快速测试使用"快速训练测试"\n');
fprintf('   - 完整训练需要较长时间\n\n');
fprintf('3. 环境类型:\n');
fprintf('   - 简化MATLAB环境(推荐): 无Simulink依赖\n');
fprintf('   - 兼容性环境: 支持Simulink仿真\n\n');
fprintf('4. 文件说明:\n');
fprintf('   - train_simple_ddpg.m: 推荐的训练脚本\n');
fprintf('   - MicrogridEnvironment.m: 环境类\n');
fprintf('   - scripts/: 配置和工具模块\n\n');
fprintf('5. 问题排查:\n');
fprintf('   - 查看OPTIMIZATION_COMPLETE.md\n');
fprintf('   - 运行综合修复解决常见问题\n');
fprintf('   - 检查工作空间数据是否存在\n');
end
