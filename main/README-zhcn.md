# 微电网深度强化学习框架

[![MATLAB](https://img.shields.io/badge/MATLAB-R2022b+-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Simulink](https://img.shields.io/badge/Simulink-必需-orange.svg)](https://www.mathworks.com/products/simulink.html)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

一个用于开发和评估微电网能源管理深度强化学习（DRL）智能体的综合框架。基于 MATLAB 和 Simulink 构建，专注于**经济效益和电池健康状态（SOH）的联合优化**。

## 🎯 项目概述

本框架通过深度强化学习实现微电网的智能能源管理，解决以下关键挑战的平衡：

- **短期经济效益**：通过智能充放电策略最小化电力成本
- **长期电池健康**：通过减少SOH衰减来保护电池寿命
- **数字孪生平台**：为学术和工业应用提供研究就绪的仿真环境

## ✨ 主要特性

- **多算法支持**：支持连续动作空间的DDPG、TD3、SAC算法实现
- **SOC-SOH联合优化**：专门针对电池管理的奖励函数
- **模块化设计**：易于扩展和修改以适应不同场景
- **全面评估**：多种指标和可视化工具
- **真实数据生成**：具有季节变化的光伏、负荷和电价曲线
- **实验管理**：管理多个训练实验的工具

## 🛠️ 系统要求

### 必需软件
- **MATLAB**（推荐 R2022b 或更新版本）
- **Simulink**
- **Deep Learning Toolbox**（深度学习工具箱）
- **Reinforcement Learning Toolbox**（强化学习工具箱）

### 可选工具箱
- Control System Toolbox（用于高级控制功能）
- Signal Processing Toolbox（用于数据预处理）

## 🚀 快速开始

### 第一步：环境设置

此步骤在**每个 MATLAB 会话中只需执行一次**。

1. 打开 MATLAB
2. 导航到项目主目录：
   ```matlab
   cd 'path/to/your/Simple_Microgrid/proj/main'
   ```
3. 运行路径设置脚本：
   ```matlab
   setup_project_paths
   ```
   您应该看到路径设置成功的确认消息。

### 第二步：运行训练

路径配置完成后，您可以运行任何训练脚本：

```matlab
% 使用 DDPG 算法训练（推荐初学者）
train_ddpg_microgrid

% 或使用 TD3 算法训练（改进的DDPG）
train_td3_microgrid

% 或使用 SAC 算法训练（最大熵强化学习）
train_sac_microgrid

% 快速测试模式（10轮训练，每轮100步）
train_ddpg_microgrid('QuickTest', true)

% 自定义训练轮数
train_ddpg_microgrid('Episodes', 500)
```

**注意**：
- 完整训练可能需要30-60分钟
- 训练过程中会显示进度窗口和学习曲线
- 训练好的智能体会自动保存到 `models/` 目录

### 第三步：评估结果

训练完成后，评估训练好的智能体：

```matlab
% 评估最新训练的DDPG智能体
evaluate_trained_agent

% 评估特定算法的智能体
evaluate_trained_agent('Algorithm', 'td3')

% 运行更长时间的评估（30天）
evaluate_trained_agent('SimulationDays', 30)

% 加载特定的智能体文件
evaluate_trained_agent('AgentFile', 'models/ddpg/trained_ddpg_agent_20250101_120000.mat')
```

## 📁 项目结构

```
main/
├── Microgrid.slx                    # 主 Simulink 模型
├── setup_project_paths.m           # 路径配置脚本
├── scripts/                        # 核心功能
│   ├── config/                     # 配置文件
│   │   ├── model_config.m          # 模型参数
│   │   ├── training_config_ddpg.m  # DDPG 训练配置
│   │   ├── training_config_td3.m   # TD3 训练配置
│   │   └── training_config_sac.m   # SAC 训练配置
│   ├── agents/                     # 强化学习智能体实现
│   │   ├── ddpg/                   # DDPG 智能体
│   │   ├── td3/                    # TD3 智能体
│   │   └── sac/                    # SAC 智能体
│   ├── environments/               # 环境创建
│   ├── training/                   # 训练脚本
│   ├── evaluation/                 # 评估和测试
│   ├── data_generation/            # 数据生成工具
│   ├── rewards/                    # 奖励函数实现
│   └── models/                     # 电池和系统模型
├── data/                           # 生成数据存储
└── models/                         # 训练模型存储
```

## ⚙️ 配置说明

### 模型配置

编辑 `scripts/config/model_config.m` 来自定义：
- 电池规格（容量、功率额定值、效率）
- 光伏系统参数
- 负荷特性
- 仿真设置

### 训练配置

选择并编辑相应的训练配置文件：
- `training_config_ddpg.m` 用于 DDPG 算法
- `training_config_td3.m` 用于 TD3 算法
- `training_config_sac.m` 用于 SAC 算法

关键参数包括：
- 网络架构
- 学习率
- 训练轮数
- 探索策略

## 🔬 支持的算法

### DDPG（深度确定性策略梯度）
- 适用于连续动作空间
- Actor-Critic 架构
- 良好的基线性能

### TD3（双延迟深度确定性策略梯度）
- DDPG 的改进版本
- 双评论家网络减少过估计偏差
- 延迟策略更新提高稳定性

### SAC（软演员-评论家）
- 最大熵强化学习
- 更好的探索能力
- 对超参数选择更加鲁棒

## 📊 评估指标

框架提供全面的评估，包括：
- **经济性能**：总电力成本、削峰效果
- **电池健康**：SOH保护、循环寿命延长
- **运行指标**：SOC管理、约束违反
- **可视化**：训练曲线、仿真结果、功率流分析

## 🎛️ 高级用法

### 自定义奖励函数

在 `scripts/rewards/` 中实现自定义奖励函数：
```matlab
function reward = custom_reward(observation, action, next_observation, config)
    % 您的自定义奖励逻辑
end
```

### 超参数调优

使用超参数调优脚本：
```matlab
scripts/training/hyperparameter_tuning
```

### 并行训练

在配置文件中启用并行训练：
```matlab
config.options.use_parallel = true;
config.options.parallel_workers = 4;
```

## 📈 结果和可视化

训练完成后，框架提供：
- 训练进度图表
- 仿真结果可视化
- SOC-SOH 分析图表
- 经济性能指标
- 功率流图

## 🤝 贡献

我们欢迎贡献！请查看我们的贡献指南：
- 代码风格约定
- 测试要求
- 文档标准

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 📚 引用

如果您在研究中使用此框架，请引用：
```bibtex
@misc{microgrid_drl_framework,
  title={微电网深度强化学习框架},
  author={您的姓名},
  year={2025},
  url={https://github.com/your-repo/microgrid-drl}
}
```

## 🔧 故障排除

### 常见问题

#### 问题1：运行 `training_config_ddpg` 只显示配置信息，没有开始训练
**原因**：您运行的是配置文件，不是训练脚本。
**解决方案**：
```matlab
% 错误的做法
training_config_ddpg  % 这只是加载配置

% 正确的做法
train_ddpg_microgrid  % 这才是训练脚本
```

#### 问题2："找不到函数"错误
**解决方案**：确保您从 `/main` 目录运行了 `setup_project_paths`。

#### 问题3：Simulink 模型无法打开
**解决方案**：
1. 检查 MATLAB 版本兼容性（需要 R2022b+）
2. 确保安装了所有必需的工具箱
3. 尝试手动打开模型：`open('Microgrid.slx')`

#### 问题4：训练非常慢或内存不足
**解决方案**：
```matlab
% 使用快速测试模式
train_ddpg_microgrid('QuickTest', true)

% 或减少训练轮数
train_ddpg_microgrid('Episodes', 100)
```

#### 问题5：训练中断或失败
**解决方案**：
1. 检查 Simulink 模型是否正确加载
2. 确保数据文件存在且格式正确
3. 查看 MATLAB 命令窗口的错误信息

### 验证安装

运行以下代码验证安装：
```matlab
% 检查工具箱
required_toolboxes = {'simulink', 'nnet', 'rl'};
for i = 1:length(required_toolboxes)
    if license('test', required_toolboxes{i})
        fprintf('✓ %s 可用\n', required_toolboxes{i});
    else
        fprintf('✗ %s 不可用\n', required_toolboxes{i});
    end
end

% 检查 Simulink 模型
try
    load_system('Microgrid.slx');
    fprintf('✓ Simulink 模型加载成功\n');
    close_system('Microgrid', 0);
catch ME
    fprintf('✗ Simulink 模型加载失败: %s\n', ME.message);
end
```

## 🆘 支持

如有问题和支持需求：
- 查看[文档](docs/)
- 提交[问题](https://github.com/your-repo/issues)
- 联系开发团队

## 🔄 版本历史

- **v1.0.0** - 支持 DDPG、TD3、SAC 的初始版本
- **v0.9.0** - 具有核心功能的测试版

---

**注意**：本框架专为研究和教育目的设计。用于生产部署时，应实施额外的安全性和可靠性措施。