export type ExchangeRateProviderName = "disabled" | "frankfurter" | "identity" | "mock";

export type ExchangeRateProviderQuote = {
  provider: ExchangeRateProviderName;
  source: string;
  date: string;
  baseCurrencyCode: string;
  quoteCurrencyCode: string;
  rate: number;
};

export type ExchangeRateSuccessBody = {
  schemaVersion: 1;
  provider: ExchangeRateProviderName;
  source: string;
  requestedDate: string | null;
  date: string;
  baseCurrencyCode: string;
  quoteCurrencyCode: string;
  rate: number;
  inverseRate: number;
  fetchedAt: string;
  privacy: string;
};

export type ExchangeRateErrorBody = {
  error: {
    code: string;
    message: string;
  };
};

export type ExchangeRateEndpointResult = {
  status: number;
  body: ExchangeRateSuccessBody | ExchangeRateErrorBody;
  cacheControl?: string;
};
