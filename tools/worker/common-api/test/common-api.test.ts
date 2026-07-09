import { describe, expect, it } from "vitest";
import { currencies, currenciesCatalog, defaultCurrencyCode } from "../src/currencies-catalog";
import { exchangeRateEndpoint } from "../src/exchange-rates/routes";
import { cities, countries, placesCatalog, supportedLocales } from "../src/places-catalog";
import { routeFetch, testInternals } from "../src/index";
import { isCloudflareAccessEmailHeaderAllowed } from "../src/security/cloudflareAccess";
import { weatherProviderTestInternals } from "../src/weather/providers";

type ReleaseNoteFixture = {
  app_id: string;
  app_version: string;
  locale: string;
  schema_version: number;
  resource_version: string;
  current_title: string;
  current_body: string;
  upcoming_title: string;
  upcoming_body: string;
  status: "published" | "draft" | "archived";
};

type AnalyticsDashboardFixture = {
  event_name: string;
  event_id: string;
  app_version: string;
  build_number: string;
  os_major: string;
  device_class: string;
  payload_json: string;
  received_at: string;
};

const releaseNotesFixtures: ReleaseNoteFixture[] = [
  {
    app_id: "autoledger",
    app_version: "1.5.0",
    locale: "zh-Hans",
    schema_version: 1,
    resource_version: "2026.07.06.2",
    current_title: "当前版本",
    current_body: "这个版本加入了 AutoLedger Pro 的第一批自动化能力。",
    upcoming_title: "后续计划",
    upcoming_body: "后续版本会加入更强的搜索、订阅异常提醒、月结导出和自动规则整理。",
    status: "published"
  },
  {
    app_id: "autoledger",
    app_version: "1.5.0",
    locale: "en",
    schema_version: 1,
    resource_version: "2026.07.06.2",
    current_title: "Current Version",
    current_body: "This version adds the first AutoLedger Pro automations.",
    upcoming_title: "Coming Next",
    upcoming_body: "Later releases will add stronger search and smarter rules automation.",
    status: "published"
  },
  {
    app_id: "autoledger",
    app_version: "1.6.0",
    locale: "zh-Hans",
    schema_version: 1,
    resource_version: "2026.07.06.2",
    current_title: "当前版本",
    current_body: "这个版本让记账更适合真实票据场景：票据扫描升级为实时 OCR，并新增韩语界面和韩语账单识别。",
    upcoming_title: "后续计划",
    upcoming_body: "接下来会继续补齐更多地区票据样本，并推进 Pro 自动化里的搜索、月结导出和规则整理。",
    status: "published"
  },
  {
    app_id: "autoledger",
    app_version: "1.6.0",
    locale: "en",
    schema_version: 1,
    resource_version: "2026.07.06.2",
    current_title: "Current Version",
    current_body: "This version makes AutoLedger better for real receipt workflows with live OCR and Korean receipt recognition.",
    upcoming_title: "Coming Next",
    upcoming_body: "Next we will add more regional receipt samples and continue Pro automations for search, month-end exports, and rules.",
    status: "published"
  },
  {
    app_id: "autonotice",
    app_version: "0.1.0",
    locale: "zh-Hans",
    schema_version: 1,
    resource_version: "2026.07.06.3",
    current_title: "当前版本",
    current_body: "0.1.0 是 AutoNotice 的第一个 App Store 发布版本，打通了天气提醒闭环。",
    upcoming_title: "后续计划",
    upcoming_body: "0.2.0 会继续完善天气提醒，扩展为五个天气提醒开关。",
    status: "published"
  },
  {
    app_id: "autonotice",
    app_version: "0.2.0",
    locale: "zh-Hans",
    schema_version: 1,
    resource_version: "2026.07.06.3",
    current_title: "当前版本",
    current_body: "0.2.0 是 AutoNotice 的内部开发线，正在升级 WeatherSnapshot 和多天气规则条件判断。",
    upcoming_title: "后续计划",
    upcoming_body: "下一步会落地降雨、降温、升温、大风和天气预警五个开关。",
    status: "published"
  },
  {
    app_id: "autonotice",
    app_version: "0.2.0",
    locale: "en",
    schema_version: 1,
    resource_version: "2026.07.06.3",
    current_title: "Current Version",
    current_body: "0.2.0 is the internal AutoNotice development line.",
    upcoming_title: "Coming Next",
    upcoming_body: "Next we will implement five Weather Notice switches.",
    status: "published"
  }
];

class MemoryD1Database {
  constructor(private readonly rows: ReleaseNoteFixture[]) {}

  prepare(sql: string): MemoryD1PreparedStatement {
    return new MemoryD1PreparedStatement(sql, this.rows);
  }
}

class AnalyticsCaptureD1Database {
  readonly analyticsInserts: unknown[][] = [];

  constructor(private readonly rows: ReleaseNoteFixture[]) {}

  prepare(sql: string): MemoryD1PreparedStatement | AnalyticsCaptureD1PreparedStatement {
    if (sql.includes("autoledger_analytics_events")) {
      return new AnalyticsCaptureD1PreparedStatement(sql, this.analyticsInserts);
    }
    return new MemoryD1PreparedStatement(sql, this.rows);
  }
}

class AnalyticsDashboardD1Database {
  constructor(
    private readonly rows: ReleaseNoteFixture[],
    private readonly analyticsRows: AnalyticsDashboardFixture[]
  ) {}

  prepare(sql: string): MemoryD1PreparedStatement | AnalyticsDashboardD1PreparedStatement {
    if (sql.includes("autoledger_analytics_events")) {
      return new AnalyticsDashboardD1PreparedStatement(sql, this.analyticsRows);
    }
    return new MemoryD1PreparedStatement(sql, this.rows);
  }
}

class AnalyticsCaptureD1PreparedStatement {
  private readonly params: unknown[];

  constructor(
    private readonly sql: string,
    private readonly inserts: unknown[][],
    params: unknown[] = []
  ) {
    this.params = params;
  }

  bind(...params: unknown[]): AnalyticsCaptureD1PreparedStatement {
    return new AnalyticsCaptureD1PreparedStatement(this.sql, this.inserts, params);
  }

  async run(): Promise<{ success: boolean }> {
    this.inserts.push(this.params);
    return { success: true };
  }
}

class AnalyticsDashboardD1PreparedStatement {
  constructor(
    private readonly sql: string,
    private readonly rows: AnalyticsDashboardFixture[],
    private readonly params: unknown[] = []
  ) {}

  bind(...params: unknown[]): AnalyticsDashboardD1PreparedStatement {
    return new AnalyticsDashboardD1PreparedStatement(this.sql, this.rows, params);
  }

  async all<T>(): Promise<{ results: T[] }> {
    return { results: this.rows as T[] };
  }
}

class MemoryD1PreparedStatement {
  private readonly params: unknown[];

  constructor(
    private readonly sql: string,
    private readonly rows: ReleaseNoteFixture[],
    params: unknown[] = []
  ) {
    this.params = params;
  }

  bind(...params: unknown[]): MemoryD1PreparedStatement {
    return new MemoryD1PreparedStatement(this.sql, this.rows, params);
  }

  async first<T>(): Promise<T | null> {
    const [appID, version, locale] = this.params.map(String);
    const row = this.rows.find((candidate) =>
      candidate.app_id === appID &&
      candidate.app_version === version &&
      candidate.locale === locale &&
      candidate.status === "published"
    );
    return (row ?? null) as T | null;
  }

  async all<T>(): Promise<{ results: T[] }> {
    if (this.sql.includes("SELECT DISTINCT app_version")) {
      const [appID] = this.params.map(String);
      const versions = Array.from(new Set(
        this.rows
          .filter((row) => row.app_id === appID && row.status === "published")
          .map((row) => row.app_version)
      ))
        .sort()
        .map((app_version) => ({ app_version }));
      return { results: versions as T[] };
    }

    const manifestRows = this.rows
      .filter((row) => row.status === "published")
      .map((row) => ({
        app_id: row.app_id,
        app_version: row.app_version,
        locale: row.locale,
        resource_version: row.resource_version,
        schema_version: row.schema_version
      }));
    return { results: manifestRows as T[] };
  }
}

const releaseNotesDB = new MemoryD1Database(releaseNotesFixtures) as unknown as D1Database;

const env = {
  PUBLIC_API_ORIGIN: "https://api.darkrio326.top",
  EXCHANGE_RATE_PROVIDER: "mock",
  EXCHANGE_RATE_BASE_URL: "https://api.frankfurter.dev/v2",
  WEATHER_PROVIDER: "disabled",
  COMMON_API_DB: releaseNotesDB
} as unknown as Env;
const disabledExchangeEnv = {
  PUBLIC_API_ORIGIN: "https://api.darkrio326.top",
  EXCHANGE_RATE_PROVIDER: "disabled",
  EXCHANGE_RATE_BASE_URL: "https://api.frankfurter.dev/v2",
  WEATHER_PROVIDER: "disabled",
  COMMON_API_DB: releaseNotesDB
} as unknown as Env;
const mockWeatherEnv = {
  PUBLIC_API_ORIGIN: "https://api.darkrio326.top",
  EXCHANGE_RATE_PROVIDER: "mock",
  EXCHANGE_RATE_BASE_URL: "https://api.frankfurter.dev/v2",
  WEATHER_PROVIDER: "mock",
  COMMON_API_DB: releaseNotesDB
} as unknown as Env;

async function jsonBody(response: Response): Promise<Record<string, unknown>> {
  return (await response.json()) as Record<string, unknown>;
}

class MemoryCache {
  private readonly records = new Map<string, Response>();

  async match(request: Request): Promise<Response | undefined> {
    return this.records.get(request.url)?.clone();
  }

  async put(request: Request, response: Response): Promise<void> {
    this.records.set(request.url, response.clone());
  }
}

describe("common api worker contract", () => {
  it("serves a health response", async () => {
    const response = await routeFetch(new Request("https://example.test/health"), env);
    const body = await jsonBody(response);

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.service).toBe("darkrio-common-api");
  });

  it("accepts privacy-safe AutoLedger analytics events into D1", async () => {
    const analyticsDB = new AnalyticsCaptureD1Database(releaseNotesFixtures);
    const analyticsEnv = {
      ...env,
      COMMON_API_DB: analyticsDB as unknown as D1Database
    } as unknown as Env;
    const response = await routeFetch(new Request("https://example.test/v1/analytics/events", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        schemaVersion: 1,
        app: "autoledger",
        events: [
          {
            eventName: "al_import_flow_completed",
            appVersion: "1.6.0",
            buildNumber: "160",
            osMajor: "26",
            deviceClass: "phone",
            payload: {
              event_id: "event-1",
              app_version: "1.6.0",
              flow_type: "receipt_scan",
              input_type: "camera",
              status: "success",
              duration_ms_bucket: "1s_3s",
              retry_count_bucket: "0",
              error_code: "none"
            }
          }
        ]
      })
    }), analyticsEnv);
    const body = await jsonBody(response);

    expect(response.status).toBe(202);
    expect(body).toMatchObject({ ok: true, accepted: 1 });
    expect(analyticsDB.analyticsInserts).toHaveLength(1);
    const insert = analyticsDB.analyticsInserts[0];
    expect(insert).toBeDefined();
    expect(insert![1]).toBe("autoledger");
    expect(insert![2]).toBe("al_import_flow_completed");
    const payloadJSON = String(insert![8]);
    expect(payloadJSON).toContain("receipt_scan");
    expect(payloadJSON).not.toContain("amount");
    expect(payloadJSON).not.toContain("merchant");
  });

  it("rejects analytics payloads with financial or document fields", async () => {
    const analyticsDB = new AnalyticsCaptureD1Database(releaseNotesFixtures);
    const analyticsEnv = {
      ...env,
      COMMON_API_DB: analyticsDB as unknown as D1Database
    } as unknown as Env;
    const response = await routeFetch(new Request("https://example.test/v1/analytics/events", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        schemaVersion: 1,
        app: "autoledger",
        events: [
          {
            eventName: "al_import_flow_completed",
            payload: {
              event_id: "event-2",
              app_version: "1.6.0",
              flow_type: "receipt_scan",
              input_type: "camera",
              status: "success",
              duration_ms_bucket: "1s_3s",
              retry_count_bucket: "0",
              error_code: "none",
              amount: 88.8,
              merchant: "Cafe Example"
            }
          }
        ]
      })
    }), analyticsEnv);
    const body = await jsonBody(response);

    expect(response.status).toBe(400);
    expect(body).toMatchObject({ error: { code: "analytics_forbidden_field" } });
    expect(analyticsDB.analyticsInserts).toEqual([]);
  });

  it("serves AutoLedger dashboard data as aggregate metrics without raw event rows", async () => {
    const dashboardDB = new AnalyticsDashboardD1Database(releaseNotesFixtures, [
      {
        event_name: "al_perf_app_launch",
        event_id: "launch-success",
        app_version: "1.6.0",
        build_number: "160",
        os_major: "26",
        device_class: "ios",
        payload_json: JSON.stringify({ result: "success", duration_ms_bucket: "not_measured" }),
        received_at: "2026-07-08T08:08:39.470Z"
      },
      {
        event_name: "al_perf_app_launch",
        event_id: "launch-failed",
        app_version: "1.6.0",
        build_number: "160",
        os_major: "26",
        device_class: "ios",
        payload_json: JSON.stringify({ result: "failed", error_code: "timeout" }),
        received_at: "2026-07-08T08:09:39.470Z"
      },
      {
        event_name: "al_import_flow_started",
        event_id: "import-started",
        app_version: "1.6.0",
        build_number: "160",
        os_major: "26",
        device_class: "ios",
        payload_json: JSON.stringify({ flow_type: "receipt_scan", input_type: "camera" }),
        received_at: "2026-07-08T08:10:39.470Z"
      },
      {
        event_name: "al_import_flow_completed",
        event_id: "import-completed",
        app_version: "1.6.0",
        build_number: "160",
        os_major: "26",
        device_class: "ios",
        payload_json: JSON.stringify({ status: "success", flow_type: "receipt_scan" }),
        received_at: "2026-07-08T08:11:39.470Z"
      },
      {
        event_name: "al_purchase_flow_status",
        event_id: "purchase-failed",
        app_version: "1.6.0",
        build_number: "160",
        os_major: "26",
        device_class: "ios",
        payload_json: JSON.stringify({ product_tier: "pro", storekit_status: "failed", error_code: "network_error" }),
        received_at: "2026-07-08T08:12:39.470Z"
      },
      {
        event_name: "al_privacy_payload_guard_violation",
        event_id: "privacy-violation",
        app_version: "1.6.0",
        build_number: "160",
        os_major: "26",
        device_class: "ios",
        payload_json: JSON.stringify({ violation_type: "forbidden_field", blocked_field_category: "financial" }),
        received_at: "2026-07-08T08:13:39.470Z"
      }
    ]);
    const dashboardEnv = {
      ...env,
      COMMON_API_DB: dashboardDB as unknown as D1Database
    } as unknown as Env;

    const response = await routeFetch(new Request("https://getautoledger.app/dashboard/data"), dashboardEnv);
    const body = await jsonBody(response);
    const metrics = body.metrics as Array<Record<string, unknown>>;
    const byID = new Map(metrics.map((metric) => [metric.metricID, metric]));
    const serialized = JSON.stringify(body);

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      schemaVersion: 1,
      app: "autoledger",
      windowDays: 30,
      retentionDays: 90
    });
    expect(body.access).toMatchObject({
      protection: "cloudflare_access",
      emailHeaderTrustedOnlyOnProtectedHosts: true
    });
    expect(byID.get("total_events_count")).toMatchObject({ value: 6, unit: "count" });
    expect(byID.get("total_events_count")).toMatchObject({ label: "已接收匿名事件总数" });
    expect(byID.get("launch_success_rate")).toMatchObject({ value: 50, unit: "percent", numerator: 1, denominator: 2 });
    expect(byID.get("launch_success_rate")).toMatchObject({ label: "启动成功率" });
    expect(byID.get("import_completion_rate")).toMatchObject({ value: 100, unit: "percent", numerator: 1, denominator: 1 });
    expect(byID.get("purchase_flow_failure_rate")).toMatchObject({ value: 100, unit: "percent", numerator: 1, denominator: 1 });
    expect(byID.get("privacy_payload_violation_count")).toMatchObject({ value: 1, unit: "count" });
    expect(body.privacy).toMatchObject({
      summary: "此面板只展示聚合计数和比率，不返回原始事件行或 payload JSON。"
    });
    expect(body).not.toHaveProperty("events");
    expect(body).not.toHaveProperty("rows");
    expect(serialized).not.toContain("payload_json");
    expect(serialized).not.toContain("amount");
    expect(serialized).not.toContain("merchant");
  });

  it("allows Cloudflare Access email headers only on protected AutoLedger dashboard hosts", () => {
    const accessEnv = {
      ENVIRONMENT: "production",
      ACCESS_ALLOWED_EMAILS: "darkrio326@gmail.com",
      ACCESS_PROTECTED_HOSTS: "getautoledger.app",
      ACCESS_TRUST_EMAIL_HEADER: "true"
    } as unknown as Env;
    const defaultEnv = {
      ENVIRONMENT: "production",
      ACCESS_ALLOWED_EMAILS: "darkrio326@gmail.com",
      ACCESS_PROTECTED_HOSTS: "getautoledger.app"
    } as unknown as Env;
    const allowedRequest = new Request("https://getautoledger.app/dashboard/data", {
      headers: {
        "cf-access-authenticated-user-email": "darkrio326@gmail.com"
      }
    });
    const wrongHostRequest = new Request("https://api.darkrio326.top/dashboard/data", {
      headers: {
        "cf-access-authenticated-user-email": "darkrio326@gmail.com"
      }
    });
    const wrongEmailRequest = new Request("https://getautoledger.app/dashboard/data", {
      headers: {
        "cf-access-authenticated-user-email": "someone@example.com"
      }
    });

    expect(isCloudflareAccessEmailHeaderAllowed(allowedRequest, accessEnv)).toBe(true);
    expect(isCloudflareAccessEmailHeaderAllowed(allowedRequest, defaultEnv)).toBe(false);
    expect(isCloudflareAccessEmailHeaderAllowed(wrongHostRequest, accessEnv)).toBe(false);
    expect(isCloudflareAccessEmailHeaderAllowed(wrongEmailRequest, accessEnv)).toBe(false);
  });

  it("blocks production AutoLedger dashboard data without a verified Access identity", async () => {
    const dashboardDB = new AnalyticsDashboardD1Database(releaseNotesFixtures, []);
    const dashboardEnv = {
      ...env,
      ENVIRONMENT: "production",
      ACCESS_ALLOWED_EMAILS: "darkrio326@gmail.com",
      ACCESS_PROTECTED_HOSTS: "getautoledger.app",
      ACCESS_TRUST_EMAIL_HEADER: "true",
      COMMON_API_DB: dashboardDB as unknown as D1Database
    } as unknown as Env;

    const unprotectedResponse = await routeFetch(new Request("https://api.darkrio326.top/dashboard/data", {
      headers: {
        "cf-access-authenticated-user-email": "darkrio326@gmail.com"
      }
    }), dashboardEnv);
    const allowedResponse = await routeFetch(new Request("https://getautoledger.app/dashboard/data", {
      headers: {
        "cf-access-authenticated-user-email": "darkrio326@gmail.com"
      }
    }), dashboardEnv);

    expect(unprotectedResponse.status).toBe(403);
    expect(await jsonBody(unprotectedResponse)).toMatchObject({ error: { code: "forbidden" } });
    expect(allowedResponse.status).toBe(200);
  });

  it("serves an AutoLedger dashboard HTML shell", async () => {
    const response = await routeFetch(new Request("https://getautoledger.app/dashboard"), env);
    const html = await response.text();

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("text/html");
    expect(html).toContain("AutoLedger 运营观测面板");
    expect(html).toContain("匿名聚合指标，用于上线前检查");
    expect(html).toContain("事件分布");
    expect(html).toContain("隐私边界");
    expect(html).toContain("/dashboard/data");
    expect(html).not.toContain("AutoLedger Ops Dashboard");
    expect(html).not.toContain("Anonymous aggregate metrics");
    expect(html).not.toContain("payload_json");
  });

  it("publishes a manifest for the five-locale places catalog", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/manifest"), env);
    const body = await jsonBody(response);
    const capabilities = body.capabilities as Record<string, Record<string, unknown>>;
    const placesCatalogCapability = capabilities.placesCatalog;
    const currencyCatalogCapability = capabilities.currencyCatalog;
    const exchangeRatesCapability = capabilities.exchangeRates;
    const releaseNotesCapability = capabilities.releaseNotes;
    const weatherForecastCapability = capabilities.weatherForecast;
    const hotelWeatherCapability = capabilities.hotelWeather;

    expect(response.status).toBe(200);
    expect(body.supportedLocales).toEqual(supportedLocales);
    expect(placesCatalogCapability).toBeDefined();
    expect(currencyCatalogCapability).toBeDefined();
    expect(exchangeRatesCapability).toBeDefined();
    expect(releaseNotesCapability).toBeDefined();
    expect(weatherForecastCapability).toBeDefined();
    expect(hotelWeatherCapability).toBeDefined();
    if (!placesCatalogCapability) {
      throw new Error("placesCatalog capability is missing");
    }
    if (!currencyCatalogCapability) {
      throw new Error("currencyCatalog capability is missing");
    }
    if (!weatherForecastCapability) {
      throw new Error("weatherForecast capability is missing");
    }
    if (!hotelWeatherCapability) {
      throw new Error("hotelWeather capability is missing");
    }
    if (!exchangeRatesCapability) {
      throw new Error("exchangeRates capability is missing");
    }
    if (!releaseNotesCapability) {
      throw new Error("releaseNotes capability is missing");
    }
    expect(placesCatalogCapability.status).toBe("available");
    expect(placesCatalogCapability.url).toBe("https://api.darkrio326.top/v1/locations/catalog");
    expect(placesCatalogCapability.sha256).toMatch(/^[a-f0-9]{64}$/);
    expect(placesCatalogCapability.countryCount).toBe(countries.length);
    expect(placesCatalogCapability.cityCount).toBe(cities.length);
    expect(currencyCatalogCapability.status).toBe("available");
    expect(currencyCatalogCapability.url).toBe("https://api.darkrio326.top/v1/currencies/catalog");
    expect(currencyCatalogCapability.sha256).toMatch(/^[a-f0-9]{64}$/);
    expect(currencyCatalogCapability.currencyCount).toBe(currencies.length);
    expect(currencyCatalogCapability.defaultCurrencyCode).toBe(defaultCurrencyCode);
    expect(exchangeRatesCapability.status).toBe("available");
    expect(exchangeRatesCapability.endpoint).toBe("https://api.darkrio326.top/v1/exchange-rates/rate");
    expect(exchangeRatesCapability.supportedCurrencyCodes).toEqual(currencies.map((record) => record.code));
    expect(releaseNotesCapability.status).toBe("available");
    expect(releaseNotesCapability.endpoint).toBe("https://api.darkrio326.top/v1/release-notes");
    expect(releaseNotesCapability.supportedApps).toContain("autoledger");
    expect(releaseNotesCapability.supportedApps).toContain("autonotice");
    expect(releaseNotesCapability.supportedVersions).toMatchObject({
      autoledger: ["1.5.0", "1.6.0"],
      autonotice: ["0.1.0", "0.2.0"]
    });
    expect(releaseNotesCapability.resourceVersion).toBe("2026.07.06.3");
    expect(weatherForecastCapability.status).toBe("configuration_required");
    expect(weatherForecastCapability.currentEndpoint).toBe("https://api.darkrio326.top/v1/weather/current");
    expect(hotelWeatherCapability.status).toBe("configuration_required");
    expect(hotelWeatherCapability.endpoint).toBe("https://api.darkrio326.top/v1/weather/hotel-stay-summary");
  });

  it("serves the full places catalog with an etag", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/locations/catalog"), env);
    const body = await response.json();
    const etag = response.headers.get("etag");

    expect(response.status).toBe(200);
    expect(etag).toMatch(/^W\/"sha256-[a-f0-9]{64}"$/);
    expect(body).toMatchObject({
      schemaVersion: placesCatalog.schemaVersion,
      resourceVersion: placesCatalog.resourceVersion,
      supportedLocales
    });

    const cached = await routeFetch(
      new Request("https://example.test/v1/locations/catalog", {
        headers: { "if-none-match": etag ?? "" }
      }),
      env
    );
    expect(cached.status).toBe(304);
  });

  it("serves the full currency catalog with an etag", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/currencies/catalog"), env);
    const body = await response.json();
    const etag = response.headers.get("etag");

    expect(response.status).toBe(200);
    expect(etag).toMatch(/^W\/"sha256-[a-f0-9]{64}"$/);
    expect(body).toMatchObject({
      schemaVersion: currenciesCatalog.schemaVersion,
      resourceVersion: currenciesCatalog.resourceVersion,
      defaultCurrencyCode,
      supportedLocales
    });

    const cached = await routeFetch(
      new Request("https://example.test/v1/currencies/catalog", {
        headers: { "if-none-match": etag ?? "" }
      }),
      env
    );
    expect(cached.status).toBe(304);
  });

  it("supports HEAD probes for cacheable read endpoints", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/locations/catalog", { method: "HEAD" }), env);

    expect(response.status).toBe(200);
    expect(response.headers.get("etag")).toMatch(/^W\/"sha256-[a-f0-9]{64}"$/);
    expect(response.headers.get("access-control-allow-methods")).toContain("HEAD");
    expect(await response.text()).toBe("");

    const currenciesResponse = await routeFetch(new Request("https://example.test/v1/currencies/catalog", { method: "HEAD" }), env);

    expect(currenciesResponse.status).toBe(200);
    expect(currenciesResponse.headers.get("etag")).toMatch(/^W\/"sha256-[a-f0-9]{64}"$/);
    expect(await currenciesResponse.text()).toBe("");
  });

  it("keeps every country, city, and currency name filled for all supported locales", () => {
    expect(testInternals.validateCatalogLocales()).toEqual([]);
  });

  it("normalizes locale aliases and unknown locales safely", () => {
    expect(testInternals.normalizeLocale("zh-CN")).toBe("zh-Hans");
    expect(testInternals.normalizeLocale("zh-HK")).toBe("zh-Hant");
    expect(testInternals.normalizeLocale("ja-JP")).toBe("ja");
    expect(testInternals.normalizeLocale("ko-KR")).toBe("ko");
    expect(testInternals.normalizeLocale("en-GB")).toBe("en");
    expect(testInternals.normalizeLocale("fr-FR")).toBe("en");
  });

  it("localizes countries and filters cities after a country is selected", async () => {
    const countryResponse = await routeFetch(new Request("https://example.test/v1/locations/countries?locale=ko"), env);
    const countryBody = await jsonBody(countryResponse);
    const localizedCountries = countryBody.countries as Array<Record<string, unknown>>;
    const japan = localizedCountries.find((record) => record.countryCode === "JP");

    expect(japan?.displayName).toBe("일본");

    const cityResponse = await routeFetch(new Request("https://example.test/v1/locations/cities?country=JP&locale=zh-Hans"), env);
    const cityBody = await jsonBody(cityResponse);
    const localizedCities = cityBody.cities as Array<Record<string, unknown>>;
    const tokyo = localizedCities.find((record) => record.id === "city.jp.tokyo");

    expect(localizedCities.map((record) => record.countryCode)).toEqual(localizedCities.map(() => "JP"));
    expect(tokyo?.displayName).toBe("东京");
    expect(tokyo?.latitude).toBe(35.6762);
    expect(tokyo?.longitude).toBe(139.6503);
    expect(tokyo?.timezone).toBe("Asia/Tokyo");
  });

  it("uses country/region compliance names without changing city names", async () => {
    const zhCountryResponse = await routeFetch(new Request("https://example.test/v1/locations/countries?locale=zh-Hans"), env);
    const zhCountryBody = await jsonBody(zhCountryResponse);
    const zhCountries = zhCountryBody.countries as Array<Record<string, unknown>>;

    expect(zhCountries.find((record) => record.countryCode === "HK")?.displayName).toBe("香港（中国）");
    expect(zhCountries.find((record) => record.countryCode === "MO")?.displayName).toBe("澳门（中国）");
    expect(zhCountries.find((record) => record.countryCode === "TW")?.displayName).toBe("台湾（中国）");

    const enCountryResponse = await routeFetch(new Request("https://example.test/v1/locations/countries?locale=en"), env);
    const enCountryBody = await jsonBody(enCountryResponse);
    const enCountries = enCountryBody.countries as Array<Record<string, unknown>>;

    expect(enCountries.find((record) => record.countryCode === "HK")?.displayName).toBe("Hong Kong (China)");
    expect(enCountries.find((record) => record.countryCode === "MO")?.displayName).toBe("Macau (China)");
    expect(enCountries.find((record) => record.countryCode === "TW")?.displayName).toBe("Taiwan (China)");

    const hkCityResponse = await routeFetch(new Request("https://example.test/v1/locations/cities?country=HK&locale=en"), env);
    const hkCityBody = await jsonBody(hkCityResponse);
    const hkCities = hkCityBody.cities as Array<Record<string, unknown>>;

    expect(hkCities.find((record) => record.id === "city.hk.hong-kong")?.displayName).toBe("Hong Kong");

    const moCityResponse = await routeFetch(new Request("https://example.test/v1/locations/cities?country=MO&locale=zh-Hans"), env);
    const moCityBody = await jsonBody(moCityResponse);
    const moCities = moCityBody.cities as Array<Record<string, unknown>>;

    expect(moCities.find((record) => record.id === "city.mo.macau")?.displayName).toBe("澳门");
  });

  it("includes district-level choices for municipalities", async () => {
    const zhCityResponse = await routeFetch(new Request("https://example.test/v1/locations/cities?country=CN&locale=zh-Hans"), env);
    const zhCityBody = await jsonBody(zhCityResponse);
    const zhCities = zhCityBody.cities as Array<Record<string, unknown>>;
    const beijing = zhCities.find((record) => record.id === "city.cn.beijing");
    const hiddenHaidian = zhCities.find((record) => record.id === "city.cn.beijing.haidian");

    expect(beijing?.displayName).toBe("北京");
    expect(beijing?.tags).toContain("municipality");
    expect(hiddenHaidian).toBeUndefined();

    const zhDistrictResponse = await routeFetch(new Request("https://example.test/v1/locations/cities?country=CN&locale=zh-Hans&includeDistricts=true"), env);
    const zhDistrictBody = await jsonBody(zhDistrictResponse);
    const zhDistrictCities = zhDistrictBody.cities as Array<Record<string, unknown>>;
    const haidian = zhDistrictCities.find((record) => record.id === "city.cn.beijing.haidian");

    expect(zhDistrictBody.includeDistricts).toBe(true);
    expect(haidian?.displayName).toBe("北京 - 海淀区");
    expect(haidian?.parentId).toBe("city.cn.beijing");
    expect(haidian?.administrativeLevel).toBe("district");
    expect(haidian?.tags).toContain("district");
    expect(haidian?.latitude).toBe(39.9599);
    expect(haidian?.longitude).toBe(116.2981);

    const enCityResponse = await routeFetch(new Request("https://example.test/v1/locations/cities?country=CN&locale=en&includeDistricts=true"), env);
    const enCityBody = await jsonBody(enCityResponse);
    const enCities = enCityBody.cities as Array<Record<string, unknown>>;

    expect(enCities.find((record) => record.id === "city.cn.beijing.haidian")?.displayName).toBe("Beijing - Haidian District");

    const koCityResponse = await routeFetch(new Request("https://example.test/v1/locations/cities?country=CN&locale=ko&includeDistricts=true"), env);
    const koCityBody = await jsonBody(koCityResponse);
    const koCities = koCityBody.cities as Array<Record<string, unknown>>;

    expect(koCities.find((record) => record.id === "city.cn.beijing.haidian")?.displayName).toBe("베이징 - 하이뎬구");
    expect(koCities.find((record) => record.id === "city.cn.chongqing.yuzhong")?.displayName).toBe("충칭 - 위중구");
  });

  it("localizes currencies and publishes default conversion targets", async () => {
    const currencyResponse = await routeFetch(new Request("https://example.test/v1/currencies?locale=ko"), env);
    const currencyBody = await jsonBody(currencyResponse);
    const localizedCurrencies = currencyBody.currencies as Array<Record<string, unknown>>;
    const cny = localizedCurrencies.find((record) => record.code === "CNY");
    const jpy = localizedCurrencies.find((record) => record.code === "JPY");

    expect(currencyBody.defaultCurrencyCode).toBe("CNY");
    expect(cny?.displayName).toBe("중국 위안");
    expect(jpy?.decimalDigits).toBe(0);
  });

  it("serves versioned release notes by app version and locale", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/release-notes?app=autoledger&version=1.6.0&locale=zh-Hans"), env);
    const body = await jsonBody(response);
    const current = body.current as Record<string, unknown>;
    const upcoming = body.upcoming as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      schemaVersion: 1,
      app: "autoledger",
      version: "1.6.0",
      locale: "zh-Hans"
    });
    expect(current.title).toBe("当前版本");
    expect(current.body).toContain("实时 OCR");
    expect(upcoming.title).toBe("后续计划");
    expect(upcoming.body).toContain("Pro 自动化");
    expect(body.privacy).toContain("stay on device");
    expect(body).not.toHaveProperty("ledger");
    expect(response.headers.get("cache-control")).toBe("public, max-age=300");
  });

  it("keeps ASC 1.5.0 release notes available separately from the 1.6.0 draft", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/release-notes?app=autoledger&version=1.5.0&locale=zh-Hans"), env);
    const body = await jsonBody(response);
    const current = body.current as Record<string, unknown>;
    const upcoming = body.upcoming as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      schemaVersion: 1,
      app: "autoledger",
      version: "1.5.0",
      locale: "zh-Hans"
    });
    expect(current.body).toContain("AutoLedger Pro");
    expect(upcoming.body).toContain("订阅异常提醒");
  });

  it("serves AutoNotice release notes from the same Common API endpoint", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/release-notes?app=autonotice&version=0.2.0&locale=zh-Hans"), env);
    const body = await jsonBody(response);
    const current = body.current as Record<string, unknown>;
    const upcoming = body.upcoming as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      schemaVersion: 1,
      app: "autonotice",
      version: "0.2.0",
      locale: "zh-Hans",
      availableVersions: ["0.1.0", "0.2.0"]
    });
    expect(current.body).toContain("WeatherSnapshot");
    expect(upcoming.body).toContain("五个开关");
  });

  it("falls back locale aliases for release notes without changing the requested app version", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/release-notes?app=autoledger&version=1.6.0&locale=en-GB"), env);
    const body = await jsonBody(response);
    const current = body.current as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(body.locale).toBe("en");
    expect(body.version).toBe("1.6.0");
    expect(current.title).toBe("Current Version");
  });

  it("requires explicit release-note app and known version values", async () => {
    const missingApp = await routeFetch(new Request("https://example.test/v1/release-notes?version=1.6.0"), env);
    const missingVersion = await routeFetch(new Request("https://example.test/v1/release-notes?app=autoledger"), env);
    const unknownVersion = await routeFetch(new Request("https://example.test/v1/release-notes?app=autoledger&version=9.9.9"), env);

    expect(missingApp.status).toBe(400);
    expect(await jsonBody(missingApp)).toMatchObject({ error: { code: "missing_release_notes_app" } });
    expect(missingVersion.status).toBe(400);
    expect(await jsonBody(missingVersion)).toMatchObject({ error: { code: "missing_release_notes_version" } });
    expect(unknownVersion.status).toBe(404);
    expect(await jsonBody(unknownVersion)).toMatchObject({ error: { code: "release_notes_not_found" } });
  });

  it("serves exchange rate quotes without receiving transaction amounts", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=CNY&date=2026-07-01"), env);
    const body = await jsonBody(response);

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      schemaVersion: 1,
      provider: "mock",
      requestedDate: "2026-07-01",
      date: "2026-07-01",
      baseCurrencyCode: "USD",
      quoteCurrencyCode: "CNY",
      rate: 7.1111
    });
    expect(body).not.toHaveProperty("amount");
    expect(body.privacy).toContain("Transaction amounts stay on device");
    expect(response.headers.get("cache-control")).toBe("public, max-age=86400");
    expect(response.headers.get("x-common-api-cache")).toBe("bypass");
  });

  it("caches exchange rate quotes behind a normalized cache key", async () => {
    const cache = new MemoryCache();
    const request = new Request("https://example.test/v1/exchange-rates/rate?quote=CNY&base=USD&date=2026-07-01");

    const first = await exchangeRateEndpoint(request, env, { cache });
    const second = await exchangeRateEndpoint(request, env, { cache });
    const cacheKey = testInternals.exchangeRateTestInternals.exchangeRateCacheKey(env, "USD", "CNY", "2026-07-01");

    expect(first.status).toBe(200);
    expect(first.headers?.["x-common-api-cache"]).toBe("miss");
    expect(second.status).toBe(200);
    expect(second.headers?.["x-common-api-cache"]).toBe("hit");
    expect(second.body).toEqual(first.body);
    expect(cacheKey.url).toBe("https://darkrio-common-api.local/v1/exchange-rates/rate?provider=mock&base=USD&quote=CNY&date=2026-07-01");
  });

  it("handles same-currency exchange rates locally", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=CNY&quote=CNY"), env);
    const body = await jsonBody(response);

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      provider: "identity",
      baseCurrencyCode: "CNY",
      quoteCurrencyCode: "CNY",
      rate: 1,
      inverseRate: 1
    });
  });

  it("validates exchange rate parameters before provider calls", async () => {
    const missingBase = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?quote=CNY"), env);
    const unsupportedQuote = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=XXX"), env);
    const invalidDate = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=CNY&date=2026-02-31"), env);
    const futureDate = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=CNY&date=9999-01-01"), env);

    expect(missingBase.status).toBe(400);
    expect(await jsonBody(missingBase)).toMatchObject({ error: { code: "missing_base_currency" } });
    expect(unsupportedQuote.status).toBe(400);
    expect(await jsonBody(unsupportedQuote)).toMatchObject({ error: { code: "unsupported_quote_currency" } });
    expect(invalidDate.status).toBe(400);
    expect(await jsonBody(invalidDate)).toMatchObject({ error: { code: "invalid_rate_date" } });
    expect(futureDate.status).toBe(400);
    expect(await jsonBody(futureDate)).toMatchObject({ error: { code: "future_rate_date_not_supported" } });
  });

  it("keeps exchange rate provider configuration explicit", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=CNY"), disabledExchangeEnv);

    expect(response.status).toBe(503);
    expect(await jsonBody(response)).toMatchObject({ error: { code: "exchange_rate_provider_not_configured" } });
  });

  it("keeps hotel stay weather disabled until provider secrets are configured", async () => {
    const weather = await routeFetch(
      new Request("https://example.test/v1/weather/hotel-stay-summary?lat=35.6&lon=139.7&checkIn=2026-07-01&checkOut=2026-07-03"),
      env
    );

    expect(weather.status).toBe(503);
    expect(await jsonBody(weather)).toMatchObject({ error: { code: "weather_provider_not_configured" } });
  });

  it("serves hotel stay weather summaries when a provider is configured", async () => {
    const response = await routeFetch(
      new Request("https://example.test/v1/weather/hotel-stay-summary?lat=35.6&lon=139.7&checkIn=2026-07-01&checkOut=2026-07-03&locale=zh-Hans&timezone=Asia/Tokyo"),
      mockWeatherEnv
    );
    const body = await jsonBody(response);
    const data = body.data as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      provider: "mock",
      cached: false,
      privacy: expect.stringContaining("Only coordinates")
    });
    expect(data).toMatchObject({
      checkIn: "2026-07-01",
      checkOut: "2026-07-03",
      timezone: "Asia/Tokyo",
      units: "metric"
    });
    expect(data).not.toHaveProperty("hotelName");
    expect(data).not.toHaveProperty("amount");
    expect(data).not.toHaveProperty("folioText");
    expect(data.days as unknown[]).toHaveLength(2);
  });

  it("parses WeatherKit daily summary numeric day records", () => {
    const days = weatherProviderTestInternals.extractWeatherKitDailySummaryDays(
      {
        days: [
          {
            date: 20635,
            temperatureMin: 22.739359,
            temperatureMax: 27.76866,
            precipitationAmount: 0.899,
            snowfallAmount: 0
          }
        ]
      },
      {
        lat: 35.68,
        lon: 139.76,
        locale: "en",
        timezone: "Asia/Tokyo",
        checkIn: "2026-07-01",
        checkOut: "2026-07-02",
        units: "metric"
      }
    );

    expect(days).toEqual([
      {
        date: "2026-07-01",
        tempMin: 22.739359,
        tempMax: 27.76866,
        precipitationAmount: 0.899,
        snowfallAmount: 0,
        description: "Summary",
        icon: "Summary"
      }
    ]);
  });

  it("rejects hotel stay weather dates outside the supported historical window", async () => {
    const tooOld = await routeFetch(
      new Request("https://example.test/v1/weather/hotel-stay-summary?lat=35.6&lon=139.7&checkIn=2021-07-31&checkOut=2021-08-02"),
      mockWeatherEnv
    );
    const future = await routeFetch(
      new Request("https://example.test/v1/weather/hotel-stay-summary?lat=35.6&lon=139.7&checkIn=9999-01-01&checkOut=9999-01-03"),
      mockWeatherEnv
    );

    expect(tooOld.status).toBe(422);
    expect(await jsonBody(tooOld)).toMatchObject({ error: { code: "weather_history_out_of_range" } });
    expect(future.status).toBe(400);
    expect(await jsonBody(future)).toMatchObject({ error: { code: "future_stay_weather_not_supported" } });
  });

  it("keeps live weather disabled until provider secrets are configured", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/weather/current?lat=35.68&lon=139.76"), env);

    expect(response.status).toBe(503);
    expect(await jsonBody(response)).toMatchObject({ error: { code: "weather_provider_not_configured" } });
  });

  it("validates weather coordinates before calling providers", async () => {
    const missing = await routeFetch(new Request("https://example.test/v1/weather/current?lat=35.68"), mockWeatherEnv);
    const invalid = await routeFetch(new Request("https://example.test/v1/weather/forecast?lat=91&lon=139.76"), mockWeatherEnv);

    expect(missing.status).toBe(400);
    expect(await jsonBody(missing)).toMatchObject({ error: { code: "missing_coordinates" } });
    expect(invalid.status).toBe(400);
    expect(await jsonBody(invalid)).toMatchObject({ error: { code: "invalid_coordinates" } });
  });

  it("serves migrated current and forecast weather contracts when a provider is configured", async () => {
    const current = await routeFetch(
      new Request("https://example.test/v1/weather/current?lat=35.68&lon=139.76&locale=ja&timezone=Asia/Tokyo"),
      mockWeatherEnv
    );
    const forecast = await routeFetch(
      new Request("https://example.test/v1/weather/forecast?lat=35.68&lon=139.76&locale=ko&timezone=Asia/Seoul"),
      mockWeatherEnv
    );

    expect(current.status).toBe(200);
    expect(await jsonBody(current)).toMatchObject({
      provider: "mock",
      data: {
        location: { lat: 35.68, lon: 139.76, timezone: "Asia/Tokyo" },
        current: { icon: "MostlyCloudy" }
      }
    });
    expect(forecast.status).toBe(200);
    const forecastBody = await jsonBody(forecast);
    expect(forecastBody.provider).toBe("mock");
    expect(((forecastBody.data as Record<string, unknown>).hourly as unknown[])).toHaveLength(24);
    expect(((forecastBody.data as Record<string, unknown>).daily as unknown[])).toHaveLength(7);
  });

  it("handles CORS preflight and read-only method boundaries", async () => {
    const options = await routeFetch(new Request("https://example.test/v1/manifest", { method: "OPTIONS" }), env);
    const post = await routeFetch(new Request("https://example.test/v1/manifest", { method: "POST" }), env);

    expect(options.status).toBe(204);
    expect(options.headers.get("access-control-allow-origin")).toBe("*");
    expect(post.status).toBe(405);
  });
});
