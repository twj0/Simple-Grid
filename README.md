# Simple Microgrid - Deep Reinforcement Learning Framework

[![MATLAB](https://img.shields.io/badge/MATLAB-R2022b+-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Simulink](https://img.shields.io/badge/Simulink-Required-orange.svg)](https://www.mathworks.com/products/simulink.html)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[English](README.md) | [中文](README-zhcn.md)

## Overview

This project implements a comprehensive deep reinforcement learning framework for microgrid energy management, focusing on the joint optimization of economic benefits and battery state of health (SOH). The framework is built using MATLAB and Simulink, providing a digital twin platform for research and industrial applications.

## Key Features

🎯 **SOC-SOH Joint Optimization** - Balance short-term economic benefits with long-term battery health  
🤖 **Multi-Algorithm Support** - DDPG, TD3, SAC implementations for continuous action spaces  
🔧 **Modular Design** - Easy to extend and customize for different scenarios  
📊 **Comprehensive Evaluation** - Multiple metrics and visualization tools  
🌱 **Realistic Data Generation** - PV, load, and price profiles with seasonal variations  
⚡ **Digital Twin Platform** - Research-ready simulation environment  

## Quick Start

### Prerequisites
- MATLAB (R2022b or newer)
- Simulink
- Deep Learning Toolbox
- Reinforcement Learning Toolbox

### Installation & Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-repo/Simple_Microgrid.git
   cd Simple_Microgrid/proj
   ```

2. **Open MATLAB and navigate to main directory**
   ```matlab
   cd 'path/to/Simple_Microgrid/proj/main'
   ```

3. **Setup project paths**
   ```matlab
   setup_project_paths
   ```

4. **One-Click Launch (Recommended)**
   ```bash
   # Double-click the main launcher
   quick_start.bat
   ```

   **Or use MATLAB commands:**
   ```matlab
   system_test           % Verify system functionality
   train_ddpg_microgrid  % Start DDPG training
   ```

### 🚀 One-Click Menu Options

The `quick_start.bat` provides an interactive menu:

```
=== Microgrid DRL Framework Main Menu ===
1. System Test (Verify functionality)
2. Quick Training (5 episodes, ~3 minutes)
3. DDPG Training (2000 episodes, ~60 minutes)
4. TD3 Training (2000 episodes, ~60 minutes)
5. SAC Training (2000 episodes, ~60 minutes)
6. Evaluate Agents
7. Interactive MATLAB Menu
8. Exit
```

### 🔧 Troubleshooting Tools

If you encounter issues, use our diagnostic tools:

```bash
# Auto-fix common problems
tools/batch_scripts/complete_fix.bat

# Detailed training diagnosis
tools/batch_scripts/debug_training.bat

# System functionality test
tools/batch_scripts/system_test.bat
```

## Project Structure

```
proj/
├── main/                           # Main project directory
│   ├── Microgrid.slx              # Simulink model
│   ├── README.md                  # Detailed English documentation
│   ├── README-zhcn.md             # Detailed Chinese documentation
│   └── scripts/                   # Core functionality
├── docs/                          # Technical documentation
├── backup/                        # Backup files
└── prompt/                        # Development prompts
```

## Algorithms Supported

- **DDPG** (Deep Deterministic Policy Gradient) - Baseline continuous control
- **TD3** (Twin Delayed DDPG) - Improved stability and performance
- **SAC** (Soft Actor-Critic) - Maximum entropy RL with better exploration

## Documentation

- **[English Documentation](main/README.md)** - Complete setup and usage guide
- **[中文文档](main/README-zhcn.md)** - 完整的设置和使用指南
- **[Technical Notes](docs/)** - Detailed technical documentation

## Research Applications

This framework is designed for:
- Academic research in microgrid optimization
- Battery management system development
- Renewable energy integration studies
- Smart grid control strategies
- Digital twin development for energy systems

## Results & Performance

The framework provides comprehensive evaluation including:
- Economic performance metrics
- Battery health preservation analysis
- Operational constraint satisfaction
- Training convergence visualization
- Simulation result analysis

## Contributing

We welcome contributions! Please see our contributing guidelines for:
- Code style conventions
- Testing requirements
- Documentation standards

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Citation

If you use this framework in your research, please cite:
```bibtex
@misc{simple_microgrid_drl,
  title={Simple Microgrid: Deep Reinforcement Learning Framework for Energy Management},
  author={Your Name},
  year={2025},
  url={https://github.com/your-repo/Simple_Microgrid}
}
```

## Support

For questions and support:
- 📖 Check the [detailed documentation](main/README.md)
- 🐛 Open an [issue](https://github.com/your-repo/issues)
- 💬 Contact the development team

## Acknowledgments

This project was developed as part of an innovation and entrepreneurship program, focusing on advancing microgrid energy management through artificial intelligence.

---

**Get Started**: Navigate to the [`main/`](main/) directory for detailed setup instructions and usage examples.
