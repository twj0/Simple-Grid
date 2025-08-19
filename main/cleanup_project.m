function cleanup_project()
% CLEANUP_PROJECT - 清理main文件夹，保留核心功能文件
%
% 此函数将main文件夹整理为专业的项目结构，适合老师和学术使用

fprintf('=== 项目清理和组织 ===\n');
fprintf('开始时间: %s\n', datestr(now));

%% 1. 创建备份
fprintf('\n1. 创建备份...\n');
backup_folder = sprintf('backup_%s', datestr(now, 'yyyymmdd_HHMMSS'));
if ~exist(backup_folder, 'dir')
    mkdir(backup_folder);
end

% 备份重要的调查文件
backup_files = {
    'soc_investigation_final_report.md';
    'soc_simulation_investigation_report.m';
    'corrected_7day_continuous_simulation.m';
    'create_corrected_simulation_plots.m'
};

for i = 1:length(backup_files)
    if exist(backup_files{i}, 'file')
        copyfile(backup_files{i}, fullfile(backup_folder, backup_files{i}));
        fprintf('  备份: %s\n', backup_files{i});
    end
end

%% 2. 定义保留文件列表
fprintf('\n2. 定义核心文件结构...\n');

% 核心DRL训练文件
core_drl_files = {
    'train_microgrid_drl.m';           % 主要DRL训练脚本
    'run_quick_training.m';            % 快速训练脚本
    'run_scientific_drl_menu.m';       % 科学DRL菜单
    'MicrogridEnvironment.m';          % 基础环境
    'ResearchMicrogridEnvironment.m';  % 研究环境
    'create_configurable_agent.m';    % 智能体配置
};

% 后处理和分析文件
postprocess_files = {
    'analyze_results.m';               % 结果分析
    'generate_simulation_data.m';      % 仿真数据生成
    'visualize_soc_analysis.m';        % SOC可视化
    'continuous_30day_simulation.m';   % 30天连续仿真
    'execute_30day_challenge.m';       % 30天挑战
};

% 配置和数据文件
config_data_files = {
    'setup_project_paths.m';          % 路径设置
    'load_workspace_data.m';          % 工作空间数据加载
};

% 必要的模型和配置目录
essential_dirs = {
    'simulinkmodel';                   % Simulink模型（必须保留）
    'config';                         % 配置文件
    'data';                           % 数据文件
    'results';                        % 结果文件
    'models';                         % 训练模型
    'scripts';                        % 脚本目录
};

% 保留的训练模型（最新的）
keep_models = {
    'trained_agent_30day_gpu_20250811_071932.mat';
    'training_stats_30day_gpu_20250811_071932.mat';
};

%% 3. 移除过时文件
fprintf('\n3. 移除过时和重复文件...\n');

% 要删除的过时文件
obsolete_files = {
    'battery_soc_technical_analysis.m';      % 已被修正版本替代
    'comprehensive_7day_simulation.m';       % 过时的仿真
    'comprehensive_battery_soc_analysis.m';  % 重复功能
    'comprehensive_verification_test_english.m'; % 过时验证
    'verify_7day_episodes_days.m';          % 已验证完成
    'verify_30day_capability.m';            % 已验证完成
    'check_simulink_model.m';               % 一次性检查脚本
    'debug_price_signal.m';                 % 调试脚本
    'test_configuration_system.m';          % 测试脚本
    'fix_fis_input_protection.m';           % 一次性修复脚本
    'segmented_30day_simulation.m';         % 被连续仿真替代
    'rl_based_30day_analysis.m';            % 重复功能
    'soc_investigation_final_report.md';    % 移动到docs
    'soc_simulation_investigation_report.m'; % 移动到docs
    'corrected_7day_continuous_simulation.m'; % 集成到主脚本
    'create_corrected_simulation_plots.m';   % 集成到分析脚本
    'batch_matlab_integration_report.txt';   % 过时报告
    'verification_report.txt';               % 过时报告
    'main_README.md';                        % 重复文档
    'main_README_zhcn.md';                   % 重复文档
    'Microgrid.slxc';                        % 编译缓存
};

removed_count = 0;
for i = 1:length(obsolete_files)
    if exist(obsolete_files{i}, 'file')
        delete(obsolete_files{i});
        fprintf('  删除: %s\n', obsolete_files{i});
        removed_count = removed_count + 1;
    end
end

%% 4. 清理results目录
fprintf('\n4. 清理results目录...\n');
results_dir = 'results';
if exist(results_dir, 'dir')
    % 保留最新的结果文件
    keep_results = {
        'corrected_7day_simulation_20250819_184752.mat';
        'corrected_7day_simulation_20250819_184752.png';
        '30day_challenge_complete_20250819_173818.mat';
        '30day_challenge_report_20250819_173818.txt';
    };
    
    % 获取所有结果文件
    all_results = dir(fullfile(results_dir, '*.*'));
    all_results = all_results(~[all_results.isdir]);
    
    cleaned_results = 0;
    for i = 1:length(all_results)
        filename = all_results(i).name;
        if ~ismember(filename, keep_results)
            % 检查是否是最新的训练结果
            if contains(filename, '20250819') || contains(filename, 'latest')
                continue; % 保留最新结果
            end
            
            delete(fullfile(results_dir, filename));
            cleaned_results = cleaned_results + 1;
        end
    end
    fprintf('  清理results文件: %d个\n', cleaned_results);
end

%% 5. 清理编译缓存
fprintf('\n5. 清理编译缓存...\n');
cache_dirs = {'slprj'};
for i = 1:length(cache_dirs)
    if exist(cache_dirs{i}, 'dir')
        rmdir(cache_dirs{i}, 's');
        fprintf('  删除缓存目录: %s\n', cache_dirs{i});
    end
end

%% 6. 创建项目结构文档
fprintf('\n6. 创建项目结构文档...\n');
create_project_structure_doc();

%% 7. 验证核心功能
fprintf('\n7. 验证核心功能完整性...\n');
verify_core_functionality();

fprintf('\n=== 项目清理完成 ===\n');
fprintf('完成时间: %s\n', datestr(now));
fprintf('删除文件数: %d\n', removed_count);
fprintf('项目结构已优化，适合学术使用\n\n');

end

function create_project_structure_doc()
% 创建项目结构说明文档

doc_content = {
    '# Main文件夹结构说明';
    '';
    '## 核心DRL训练文件';
    '- `train_microgrid_drl.m` - 主要深度强化学习训练脚本';
    '- `run_quick_training.m` - 快速训练和测试脚本';
    '- `run_scientific_drl_menu.m` - 科学研究DRL菜单系统';
    '- `MicrogridEnvironment.m` - 基础微电网环境定义';
    '- `ResearchMicrogridEnvironment.m` - 高级研究环境';
    '- `create_configurable_agent.m` - 可配置智能体创建';
    '';
    '## 后处理和分析文件';
    '- `analyze_results.m` - 训练结果分析和可视化';
    '- `generate_simulation_data.m` - 仿真数据生成';
    '- `visualize_soc_analysis.m` - SOC分析可视化';
    '- `continuous_30day_simulation.m` - 30天连续仿真';
    '- `execute_30day_challenge.m` - 30天挑战执行';
    '';
    '## 配置和支持文件';
    '- `setup_project_paths.m` - 项目路径配置';
    '- `load_workspace_data.m` - 工作空间数据加载';
    '';
    '## 目录结构';
    '- `simulinkmodel/` - Simulink模型文件（必须保留）';
    '- `config/` - 配置文件';
    '- `data/` - 训练和仿真数据';
    '- `results/` - 训练结果和分析图表';
    '- `models/` - 保存的DRL模型';
    '- `scripts/` - 辅助脚本';
    '';
    '## 使用说明';
    '1. 使用根目录的bat文件启动项目';
    '2. 运行DRL训练：`train_microgrid_drl.m`';
    '3. 快速测试：`run_quick_training.m`';
    '4. 结果分析：`analyze_results.m`';
    '5. 长期仿真：`continuous_30day_simulation.m`';
};

fid = fopen('PROJECT_STRUCTURE.md', 'w', 'n', 'UTF-8');
for i = 1:length(doc_content)
    fprintf(fid, '%s\n', doc_content{i});
end
fclose(fid);

fprintf('  创建: PROJECT_STRUCTURE.md\n');
end

function verify_core_functionality()
% 验证核心功能文件存在

core_files = {
    'train_microgrid_drl.m';
    'run_quick_training.m';
    'analyze_results.m';
    'simulinkmodel/Microgrid.slx';
    'config/simulation_config.m';
    'data/microgrid_workspace.mat';
};

missing_files = {};
for i = 1:length(core_files)
    if ~exist(core_files{i}, 'file')
        missing_files{end+1} = core_files{i};
    end
end

if isempty(missing_files)
    fprintf('  ? 所有核心文件完整\n');
else
    fprintf('  ? 缺失文件:\n');
    for i = 1:length(missing_files)
        fprintf('    - %s\n', missing_files{i});
    end
end
end
