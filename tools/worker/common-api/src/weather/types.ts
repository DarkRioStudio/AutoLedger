export type WeatherProviderName = "mock" | "openweathermap" | "weatherkit";

export type WeatherQuery = {
  lat: number;
  lon: number;
  locale: string;
  timezone: string;
};

export type WeatherUnits = "metric" | "imperial";

export type HotelStayWeatherQuery = WeatherQuery & {
  checkIn: string;
  checkOut: string;
  units: WeatherUnits;
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

export type HotelStayWeatherDay = {
  date: string;
  tempMin: number | null;
  tempMax: number | null;
  precipitationAmount: number | null;
  snowfallAmount: number | null;
  description: string;
  icon: string;
};

export type HotelStayWeatherSummary = {
  location: {
    lat: number;
    lon: number;
  };
  checkIn: string;
  checkOut: string;
  timezone: string;
  units: WeatherUnits;
  days: HotelStayWeatherDay[];
  unavailableReason?: string;
};

export type WeatherProvider = {
  name: WeatherProviderName;
  getCurrentWeather(query: WeatherQuery): Promise<CurrentWeather>;
  getForecast(query: WeatherQuery): Promise<ForecastWeather>;
  getHotelStaySummary?(query: HotelStayWeatherQuery): Promise<HotelStayWeatherSummary>;
};
