function data = generate_simulation_data(config)
% GENERATE_SIMULATION_DATA - Generate configurable simulation data
%
% This function generates PV, load, and price profiles based on
% configuration parameters, eliminating hardcoded values.
%
% Inputs:
%   config      - Configuration structure from simulation_config()
%
% Outputs:
%   data        - Structure containing:
%                 .pv_power    - PV power profile (kW)
%                 .load_power  - Load power profile (kW)
%                 .price       - Electricity price profile (CNY/kWh)
%                 .hours_total - Total simulation hours

% Calculate total hours from configuration
hours_total = config.simulation.days * 24;

% Set random seed for reproducibility
rng(config.data.random_seed);

% Generate PV power profile
pv_power = generate_pv_profile(hours_total, config);

% Generate load power profile
load_power = generate_load_profile(hours_total, config);

% Generate electricity price profile
price = generate_price_profile(hours_total, config);

% Package data into output structure
data = struct();
data.pv_power = pv_power;
data.load_power = load_power;
data.price = price;
data.hours_total = hours_total;

end

function pv_power = generate_pv_profile(hours_total, config)
% Generate PV power profile with enhanced physical realism

pv_power = zeros(hours_total, 1);
pv_capacity = config.system.pv.capacity_kw;

for h = 1:hours_total
    hour_of_day = mod(h-1, 24) + 1;
    day_of_year = ceil(h/24);

    % Enhanced solar irradiance model with realistic physics
    if hour_of_day >= 6 && hour_of_day <= 18
        % Daylight hours with realistic solar angle calculation
        % Solar elevation angle (simplified model)
        hour_angle = 15 * (hour_of_day - 12); % degrees from solar noon
        declination = 23.45 * sin(2*pi * (284 + day_of_year) / 365); % solar declination
        latitude = 39.9; % Beijing latitude (degrees)

        % Solar elevation angle
        elevation = asind(sind(declination) * sind(latitude) + ...
                         cosd(declination) * cosd(latitude) * cosd(hour_angle));

        % Base irradiance based on solar elevation (more realistic)
        if elevation > 0
            base_irradiance = max(0, sind(elevation)) * 0.9; % Atmospheric losses
        else
            base_irradiance = 0;
        end
    else
        % Night hours
        base_irradiance = 0;
    end
    
    % Seasonal variation
    if config.data.seasonal_variation
        seasonal_factor = 0.8 + 0.4 * sin(2*pi * (day_of_year - 80) / 365);
    else
        seasonal_factor = 1.0;
    end
    
    % Enhanced weather pattern effects with realistic cloud intermittency
    switch config.data.weather_pattern
        case 'sunny'
            weather_factor = 0.92 + 0.06 * rand(); % Clear sky conditions
        case 'cloudy'
            weather_factor = 0.25 + 0.35 * rand(); % Overcast conditions
        case 'mixed'
            weather_factor = 0.55 + 0.4 * rand(); % Variable cloudiness
        case 'seasonal'
            % Realistic seasonal cloud patterns for Beijing climate
            % Summer: less clouds, Winter: more clouds
            seasonal_cloud = 0.8 + 0.2 * sin(2*pi * (day_of_year - 172) / 365); % Peak in summer

            % Add realistic cloud intermittency
            if config.data.cloud_intermittency
                % Markov chain for cloud state transitions
                cloud_persistence = 0.7; % Probability of maintaining cloud state
                if h > 1
                    prev_cloudy = pv_power(h-1) < 0.5 * pv_capacity * base_irradiance * seasonal_cloud;
                    if prev_cloudy
                        is_cloudy = rand() < cloud_persistence;
                    else
                        is_cloudy = rand() < (1 - cloud_persistence) * 0.3;
                    end
                else
                    is_cloudy = rand() < 0.3;
                end

                if is_cloudy
                    weather_factor = seasonal_cloud * (0.2 + 0.3 * rand());
                else
                    weather_factor = seasonal_cloud * (0.8 + 0.15 * rand());
                end
            else
                weather_factor = seasonal_cloud * (0.7 + 0.25 * rand());
            end
        otherwise
            weather_factor = 0.7 + 0.25 * rand();
    end

    % Temperature effects on PV efficiency (realistic)
    if config.data.temperature_variation
        % Simplified temperature model (Beijing climate)
        avg_temp = 15 + 15 * sin(2*pi * (day_of_year - 80) / 365); % Annual temperature cycle
        daily_temp_var = 8 * sin(2*pi * (hour_of_day - 6) / 24); % Daily temperature cycle
        temperature = avg_temp + daily_temp_var + 3 * randn(); % Add noise

        % PV temperature coefficient effect
        temp_effect = 1 + config.system.pv.temperature_coeff * (temperature - 25);
        weather_factor = weather_factor * max(0.7, temp_effect); % Limit minimum efficiency
    end
    
    % Calculate PV power
    pv_power(h) = pv_capacity * base_irradiance * seasonal_factor * weather_factor;
end

end

function load_power = generate_load_profile(hours_total, config)
% Generate load power profile based on configuration

load_power = zeros(hours_total, 1);

for h = 1:hours_total
    hour_of_day = mod(h-1, 24) + 1;
    day_of_week = mod(ceil(h/24) - 1, 7) + 1; % 1=Monday, 7=Sunday
    day_of_year = ceil(h/24);
    
    % Realistic microgrid load patterns (scaled to PV capacity)
    pv_capacity = config.system.pv.capacity_kw; % 120 kW

    switch config.data.load_pattern
        case 'residential'
            % Chinese residential community load pattern
            if hour_of_day >= 6 && hour_of_day <= 8
                daily_factor = 0.65; % Morning peak (breakfast, preparation)
            elseif hour_of_day >= 18 && hour_of_day <= 22
                daily_factor = 0.85; % Evening peak (dinner, entertainment)
            elseif hour_of_day >= 9 && hour_of_day <= 17
                daily_factor = 0.30; % Daytime low (most people at work)
            else
                daily_factor = 0.20; % Night low (sleep)
            end
            base_load = pv_capacity * 0.50; % 50% of PV capacity as base

        case 'commercial'
            % Chinese commercial building load pattern
            if hour_of_day >= 8 && hour_of_day <= 12
                daily_factor = 0.75; % Morning business hours
            elseif hour_of_day >= 13 && hour_of_day <= 18
                daily_factor = 0.80; % Afternoon business hours
            elseif hour_of_day >= 19 && hour_of_day <= 21
                daily_factor = 0.45; % Evening activities
            else
                daily_factor = 0.25; % Night/early morning (security, basic systems)
            end
            base_load = pv_capacity * 0.60; % 60% of PV capacity as base

        case 'industrial'
            % Chinese industrial facility load pattern
            if hour_of_day >= 8 && hour_of_day <= 17
                daily_factor = 0.85; % Production hours
            elseif hour_of_day >= 18 && hour_of_day <= 22
                daily_factor = 0.60; % Reduced production/maintenance
            else
                daily_factor = 0.35; % Night shift/standby
            end
            base_load = pv_capacity * 0.70; % 70% of PV capacity as base

        otherwise
            % Default mixed commercial pattern
            if hour_of_day >= 8 && hour_of_day <= 18
                daily_factor = 0.70; % Business hours
            elseif hour_of_day >= 19 && hour_of_day <= 22
                daily_factor = 0.40; % Evening
            else
                daily_factor = 0.25; % Night
            end
            base_load = pv_capacity * 0.55; % 55% of PV capacity as base
    end
    
    % Weekend effect (for commercial/industrial)
    if ismember(config.data.load_pattern, {'commercial', 'industrial'})
        if day_of_week >= 6 % Weekend
            weekend_factor = 0.7;
        else
            weekend_factor = 1.0;
        end
    else
        weekend_factor = 1.0;
    end
    
    % Seasonal variation
    if config.data.seasonal_variation
        % Higher load in summer (cooling) and winter (heating)
        seasonal_factor = 0.9 + 0.2 * abs(sin(2*pi * (day_of_year - 80) / 365));
    else
        seasonal_factor = 1.0;
    end
    
    % Random variation
    random_factor = 0.9 + 0.2 * rand();
    
    % Calculate load power
    load_power(h) = base_load * daily_factor * weekend_factor * seasonal_factor * random_factor;
end

end

function price = generate_price_profile(hours_total, config)
% Generate electricity price profile based on Chinese market reality and FIS compatibility
% Output range: [0, 2] for FIS compatibility
% Based on actual Chinese electricity prices: 0.48-1.8 CNY/kWh

price = zeros(hours_total, 1);

for h = 1:hours_total
    hour_of_day = mod(h-1, 24) + 1;
    day_of_week = mod(ceil(h/24) - 1, 7) + 1;
    day_of_year = ceil(h/24);

    % Chinese electricity pricing structure (CNY/kWh)
    switch config.data.price_pattern
        case 'flat'
            % Flat commercial pricing
            base_price_cny = 0.86; % Commercial flat rate
            time_factor = 1.0;

        case 'time_of_use'
            % Chinese time-of-use pricing (realistic structure)
            if (hour_of_day >= 8 && hour_of_day <= 11) || (hour_of_day >= 18 && hour_of_day <= 21)
                % Peak hours: 8-11am, 6-9pm
                base_price_cny = 1.2; % Peak rate
                time_factor = 1.0;
            elseif (hour_of_day >= 12 && hour_of_day <= 17) || (hour_of_day >= 22 && hour_of_day <= 23) || hour_of_day == 7
                % Standard hours: 12-5pm, 10-11pm, 7am
                base_price_cny = 0.86; % Standard rate
                time_factor = 1.0;
            else
                % Valley hours: 11pm-7am
                base_price_cny = 0.48; % Valley rate (residential minimum)
                time_factor = 1.0;
            end

        case 'real_time'
            % Real-time pricing with Chinese market characteristics
            base_price_cny = 0.86; % Base commercial rate
            % Demand-based fluctuation
            demand_factor = 0.8 + 0.4 * sin(2*pi * hour_of_day / 24) + 0.2 * rand();
            time_factor = demand_factor;

        otherwise
            % Default Chinese commercial pricing
            if (hour_of_day >= 8 && hour_of_day <= 11) || (hour_of_day >= 18 && hour_of_day <= 21)
                base_price_cny = 1.2; % Peak
                time_factor = 1.0;
            elseif hour_of_day >= 23 || hour_of_day <= 6
                base_price_cny = 0.48; % Valley
                time_factor = 1.0;
            else
                base_price_cny = 0.86; % Standard
                time_factor = 1.0;
            end
    end

    % Weekend effect (lower industrial demand)
    if day_of_week >= 6 % Weekend
        weekend_factor = 0.85; % 15% reduction on weekends
    else
        weekend_factor = 1.0;
    end

    % Seasonal variation (Chinese climate patterns)
    if config.data.seasonal_variation
        % Summer: higher AC demand, Winter: higher heating demand
        seasonal_factor = 0.9 + 0.25 * sin(2*pi * (day_of_year - 80) / 365) + ...
                         0.15 * sin(2*pi * (day_of_year - 355) / 365); % Winter peak
    else
        seasonal_factor = 1.0;
    end

    % Market volatility (limited in regulated Chinese market)
    market_factor = 0.95 + 0.1 * rand();

    % Calculate actual price in CNY/kWh
    actual_price_cny = base_price_cny * time_factor * weekend_factor * seasonal_factor * market_factor;

    % Ensure realistic bounds (Chinese market range: 0.48-1.8 CNY/kWh)
    actual_price_cny = max(0.48, min(1.8, actual_price_cny));

    % Normalize to [0, 2] range for FIS compatibility
    % Map [0.48, 1.8] CNY/kWh to [0, 2] FIS range
    price(h) = 2 * (actual_price_cny - 0.48) / (1.8 - 0.48);

    % Ensure strict bounds for FIS
    price(h) = max(0, min(2, price(h)));
end

fprintf('INFO: Price profile generated for FIS compatibility\n');
fprintf('   CNY/kWh range: [%.3f, %.3f]\n', 0.48, 1.8);
fprintf('   FIS range: [%.3f, %.3f]\n', min(price), max(price));

end
