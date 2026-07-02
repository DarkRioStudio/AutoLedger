export type WeatherProviderName = "mock" | "openweathermap" | "weatherkit";

export type WeatherQuery = {
  lat: number;
  lon: number;
  locale: string;
  timezone: string;
};

export type CurrentWeather = {
  location: {
    name: string;
    lat: number;
    lon: number;
    country: string;
    timezone: string;
  };
  current: {
    temp: number;
    feelsLike: number;
    humidity: number;
    pressure: number;
    windSpeed: number;
    windDeg: number;
    description: string;
    icon: string;
    dt: number;
  };
};

export type HourlyForecast = {
  dt: number;
  temp: number;
  humidity: number;
  windSpeed: number;
  description: string;
  icon: string;
};

export type DailyForecast = {
  dt: number;
  tempMin: number;
  tempMax: number;
  humidity: number;
  windSpeed: number;
  description: string;
  icon: string;
};

export type ForecastWeather = {
  location: {
    lat: number;
    lon: number;
  };
  hourly: HourlyForecast[];
  daily: DailyForecast[];
};

export type WeatherProvider = {
  name: WeatherProviderName;
  getCurrentWeather(query: WeatherQuery): Promise<CurrentWeather>;
  getForecast(query: WeatherQuery): Promise<ForecastWeather>;
};
