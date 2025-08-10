# 简单微电网 - 深度强化学习框架

[![MATLAB](https://img.shields.io/badge/MATLAB-R2022b+-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Simulink](https://img.shields.io/badge/Simulink-必需-orange.svg)](https://www.mathworks.com/products/simulink.html)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[English](README.md) | [中文](README-zhcn.md)

## 项目概述

本项目实现了一个用于微电网能源管理的综合深度强化学习框架，专注于经济效益和电池健康状态（SOH）的联合优化。该框架基于 MATLAB 和 Simulink 构建，为研究和工业应用提供数字孪生平台。

## 主要特性

🎯 **SOC-SOH联合优化** - 平衡短期经济效益与长期电池健康  
🤖 **多算法支持** - 支持连续动作空间的DDPG、TD3、SAC算法实现  
🔧 **模块化设计** - 易于扩展和定制以适应不同场景  
📊 **全面评估** - 多种指标和可视化工具  
🌱 **真实数据生成** - 具有季节变化的光伏、负荷和电价曲线  
⚡ **数字孪生平台** - 研究就绪的仿真环境  

## 快速开始

### 系统要求
- MATLAB（R2022b 或更新版本）
- Simulink
- Deep Learning Toolbox（深度学习工具箱）
- Reinforcement Learning Toolbox（强化学习工具箱）

### 安装与设置

1. **克隆仓库**
   ```bash
   git clone https://github.com/your-repo/Simple_Microgrid.git
   cd Simple_Microgrid/proj
   ```

2. **打开 MATLAB 并导航到主目录**
   ```matlab
   cd 'path/to/Simple_Microgrid/proj/main'
   ```

3. **设置项目路径**
   ```matlab
   setup_project_paths
   ```

4. **一键启动（推荐）**
   ```bash
   # 双击主启动器
   quick_start.bat
   ```

   **或使用MATLAB命令：**
   ```matlab
   system_test           % 验证系统功能
   train_ddpg_microgrid  % 开始DDPG训练
   ```

### 🚀 一键菜单选项

`quick_start.bat` 提供交互式菜单：

```
=== 微电网DRL框架主菜单 ===
1. 系统测试 (验证功能)
2. 快速训练 (5回合, ~3分钟)
3. DDPG训练 (2000回合, ~60分钟)
4. TD3训练 (2000回合, ~60分钟)
5. SAC训练 (2000回合, ~60分钟)
6. 评估智能体
7. 交互式MATLAB菜单
8. 退出
```

### 🔧 故障排除工具

如果遇到问题，使用我们的诊断工具：

```bash
# 自动修复常见问题
tools/batch_scripts/complete_fix.bat

# 详细训练诊断
tools/batch_scripts/debug_training.bat

# 系统功能测试
tools/batch_scripts/system_test.bat
```

## 项目结构

```
proj/
├── main/                           # 主项目目录
│   ├── Microgrid.slx              # Simulink 模型
│   ├── README.md                  # 详细英文文档
│   ├── README-zhcn.md             # 详细中文文档
│   └── scripts/                   # 核心功能
├── docs/                          # 技术文档
├── backup/                        # 备份文件
└── prompt/                        # 开发提示
```

## 支持的算法

- **DDPG**（深度确定性策略梯度）- 连续控制基线算法
- **TD3**（双延迟DDPG）- 改进的稳定性和性能
- **SAC**（软演员-评论家）- 具有更好探索能力的最大熵强化学习

## 文档

- **[英文文档](main/README.md)** - 完整的设置和使用指南
- **[中文文档](main/README-zhcn.md)** - 完整的设置和使用指南
- **[技术笔记](docs/)** - 详细的技术文档

## 研究应用

本框架适用于：
- 微电网优化的学术研究
- 电池管理系统开发
- 可再生能源集成研究
- 智能电网控制策略
- 能源系统数字孪生开发

## 结果与性能

框架提供全面的评估，包括：
- 经济性能指标
- 电池健康保护分析
- 运行约束满足度
- 训练收敛可视化
- 仿真结果分析

## 贡献

我们欢迎贡献！请查看我们的贡献指南：
- 代码风格约定
- 测试要求
- 文档标准

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 引用

如果您在研究中使用此框架，请引用：
```bibtex
@misc{simple_microgrid_drl,
  title={简单微电网：用于能源管理的深度强化学习框架},
  author={您的姓名},
  year={2025},
  url={https://github.com/your-repo/Simple_Microgrid}
}
```

## 支持

如有问题和支持需求：
- 📖 查看[详细文档](main/README-zhcn.md)
- 🐛 提交[问题](https://github.com/your-repo/issues)
- 💬 联系开发团队

## 致谢

本项目作为创新创业计划的一部分开发，专注于通过人工智能推进微电网能源管理。

---

**开始使用**：导航到 [`main/`](main/) 目录查看详细的设置说明和使用示例。
