# Microgrid Deep Reinforcement Learning Framework

[![MATLAB](https://img.shields.io/badge/MATLAB-R2022b+-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Simulink](https://img.shields.io/badge/Simulink-Required-orange.svg)](https://www.mathworks.com/products/simulink.html)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive framework for developing and evaluating deep reinforcement learning (DRL) agents for microgrid energy management. Built using MATLAB and Simulink, this project focuses on the **joint optimization of economic benefits and battery state of health (SOH)**.

## 🎯 Project Overview

This framework enables intelligent energy management for microgrids through deep reinforcement learning, addressing the critical challenge of balancing:

- **Short-term Economic Benefits**: Minimize electricity costs through intelligent charging/discharging strategies
- **Long-term Battery Health**: Preserve battery lifespan by reducing SOH degradation
- **Digital Twin Platform**: Provide a research-ready simulation environment for academic and industrial applications

## ✨ Key Features

- **Multi-Algorithm Support**: DDPG, TD3, SAC implementations for continuous action spaces
- **SOC-SOH Joint Optimization**: Specialized reward functions for battery management
- **Modular Design**: Easy to extend and modify for different scenarios
- **Comprehensive Evaluation**: Multiple metrics and visualization tools
- **Realistic Data Generation**: PV, load, and price profiles with seasonal variations
- **Experiment Management**: Tools for managing multiple training experiments

## 🛠️ Prerequisites

### Required Software
- **MATLAB** (R2022b or newer recommended)
- **Simulink**
- **Deep Learning Toolbox**
- **Reinforcement Learning Toolbox**

### Optional Toolboxes
- Control System Toolbox (for advanced control features)
- Signal Processing Toolbox (for data preprocessing)

## 🚀 Quick Start

### Step 1: Environment Setup

This step only needs to be done **once per MATLAB session**.

1. Open MATLAB
2. Navigate to the project main directory:
   ```matlab
   cd 'path/to/your/Simple_Microgrid/proj/main'
   ```
3. Run the path setup script:
   ```matlab
   setup_project_paths
   ```
   You should see a confirmation message that paths have been set up successfully.

### Step 2: Run Training

Once paths are configured, you can run any training script:

```matlab
% Train using DDPG algorithm
train_ddpg_microgrid

% Or train using TD3 algorithm
train_td3_microgrid

% Or train using SAC algorithm
train_sac_microgrid
```

### Step 3: Evaluate Results

After training, evaluate the trained agent:

```matlab
% Load and evaluate trained agent
evaluate_trained_agent
```

## 📁 Project Structure

```
main/
├── Microgrid.slx                    # Main Simulink model
├── setup_project_paths.m           # Path configuration script
├── scripts/                        # Core functionality
│   ├── config/                     # Configuration files
│   │   ├── model_config.m          # Model parameters
│   │   ├── training_config_ddpg.m  # DDPG training config
│   │   ├── training_config_td3.m   # TD3 training config
│   │   └── training_config_sac.m   # SAC training config
│   ├── agents/                     # RL agent implementations
│   │   ├── ddpg/                   # DDPG agent
│   │   ├── td3/                    # TD3 agent
│   │   └── sac/                    # SAC agent
│   ├── environments/               # Environment creation
│   ├── training/                   # Training scripts
│   ├── evaluation/                 # Evaluation and testing
│   ├── data_generation/            # Data generation tools
│   ├── rewards/                    # Reward function implementations
│   └── models/                     # Battery and system models
├── data/                           # Generated data storage
└── models/                         # Trained model storage
```

## ⚙️ Configuration

### Model Configuration

Edit `scripts/config/model_config.m` to customize:
- Battery specifications (capacity, power rating, efficiency)
- PV system parameters
- Load characteristics
- Simulation settings

### Training Configuration

Choose and edit the appropriate training configuration:
- `training_config_ddpg.m` for DDPG algorithm
- `training_config_td3.m` for TD3 algorithm
- `training_config_sac.m` for SAC algorithm

Key parameters include:
- Network architecture
- Learning rates
- Training episodes
- Exploration strategies

## 🔬 Algorithms Supported

### DDPG (Deep Deterministic Policy Gradient)
- Suitable for continuous action spaces
- Actor-critic architecture
- Good baseline performance

### TD3 (Twin Delayed Deep Deterministic Policy Gradient)
- Improved version of DDPG
- Twin critic networks reduce overestimation bias
- Delayed policy updates for stability

### SAC (Soft Actor-Critic)
- Maximum entropy reinforcement learning
- Better exploration capabilities
- More robust to hyperparameter choices

## 📊 Evaluation Metrics

The framework provides comprehensive evaluation including:
- **Economic Performance**: Total electricity cost, peak shaving effectiveness
- **Battery Health**: SOH preservation, cycle life extension
- **Operational Metrics**: SOC management, constraint violations
- **Visualization**: Training curves, simulation results, power flow analysis

## 🎛️ Advanced Usage

### Custom Reward Functions

Implement custom reward functions in `scripts/rewards/`:
```matlab
function reward = custom_reward(observation, action, next_observation, config)
    % Your custom reward logic here
end
```

### Hyperparameter Tuning

Use the hyperparameter tuning script:
```matlab
scripts/training/hyperparameter_tuning
```

### Parallel Training

Enable parallel training in configuration files:
```matlab
config.options.use_parallel = true;
config.options.parallel_workers = 4;
```

## 📈 Results and Visualization

After training, the framework provides:
- Training progress plots
- Simulation result visualization
- SOC-SOH analysis charts
- Economic performance metrics
- Power flow diagrams

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines for:
- Code style conventions
- Testing requirements
- Documentation standards

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📚 Citation

If you use this framework in your research, please cite:
```bibtex
@misc{microgrid_drl_framework,
  title={Microgrid Deep Reinforcement Learning Framework},
  author={Your Name},
  year={2025},
  url={https://github.com/your-repo/microgrid-drl}
}
```

## 🆘 Support

For questions and support:
- Check the [documentation](docs/)
- Open an [issue](https://github.com/your-repo/issues)
- Contact the development team

## 🔄 Version History

- **v1.0.0** - Initial release with DDPG, TD3, SAC support
- **v0.9.0** - Beta release with core functionality

---

**Note**: This framework is designed for research and educational purposes. For production deployment, additional safety and reliability measures should be implemented.
