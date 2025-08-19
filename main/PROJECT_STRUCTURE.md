# Main文件夹结构说明

## 核心DRL训练文件
- `train_microgrid_drl.m` - 主要深度强化学习训练脚本
- `run_quick_training.m` - 快速训练和测试脚本
- `run_scientific_drl_menu.m` - 科学研究DRL菜单系统
- `MicrogridEnvironment.m` - 基础微电网环境定义
- `ResearchMicrogridEnvironment.m` - 高级研究环境
- `create_configurable_agent.m` - 可配置智能体创建

## 后处理和分析文件
- `analyze_results.m` - 训练结果分析和可视化
- `generate_simulation_data.m` - 仿真数据生成
- `visualize_soc_analysis.m` - SOC分析可视化
- `continuous_30day_simulation.m` - 30天连续仿真
- `execute_30day_challenge.m` - 30天挑战执行

## 配置和支持文件
- `setup_project_paths.m` - 项目路径配置
- `load_workspace_data.m` - 工作空间数据加载

## 目录结构
- `simulinkmodel/` - Simulink模型文件（必须保留）
- `config/` - 配置文件
- `data/` - 训练和仿真数据
- `results/` - 训练结果和分析图表
- `models/` - 保存的DRL模型
- `scripts/` - 辅助脚本

## 使用说明
1. 使用根目录的bat文件启动项目
2. 运行DRL训练：`train_microgrid_drl.m`
3. 快速测试：`run_quick_training.m`
4. 结果分析：`analyze_results.m`
5. 长期仿真：`continuous_30day_simulation.m`
