import { describe, expect, it } from "vitest";
import { AdminMetricsEntrypoint } from "../src/admin-metrics-entrypoint";
import { routeFetch } from "../src/index";

class EmptyAnalyticsD1Database {
  prepare(): EmptyAnalyticsD1PreparedStatement {
    return new EmptyAnalyticsD1PreparedStatement();
  }
}

class EmptyAnalyticsD1PreparedStatement {
  bind(): EmptyAnalyticsD1PreparedStatement {
    return this;
  }

  async all<T>(): Promise<{ results: T[] }> {
    return { results: [] };
  }
}

const env = {
  ANALYTICS_RETENTION_DAYS: "90",
  COMMON_API_DB: new EmptyAnalyticsD1Database() as unknown as D1Database
} as unknown as Env;

function entrypoint(testEnv: Env = env): AdminMetricsEntrypoint {
  return new AdminMetricsEntrypoint({} as ExecutionContext, testEnv);
}

async function jsonBody(response: Response): Promise<Record<string, unknown>> {
  return await response.json<Record<string, unknown>>();
}

describe("AdminMetricsEntrypoint", () => {
  it("returns the existing privacy-safe AutoLedger aggregate for the exact internal GET path", async () => {
    const response = await entrypoint().fetch(
      new Request("https://service-binding.local/internal/admin/metrics")
    );
    const body = await jsonBody(response);
    const serialized = JSON.stringify(body);

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("application/json");
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(body).toMatchObject({
      schemaVersion: 1,
      app: "autoledger",
      windowDays: 30,
      retentionDays: 90,
      privacy: {
        linked: false,
        tracking: false
      }
    });
    expect(body).not.toHaveProperty("events");
    expect(body).not.toHaveProperty("rows");
    expect(serialized).not.toContain("payload_json");
  });

  it("preserves the dashboard database-unconfigured response", async () => {
    const response = await entrypoint({} as Env).fetch(
      new Request("https://service-binding.local/internal/admin/metrics")
    );

    expect(response.status).toBe(503);
    expect(await jsonBody(response)).toMatchObject({
      error: { code: "analytics_database_unconfigured" }
    });
  });

  it.each(["HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])(
    "rejects %s on the internal metrics path",
    async (method) => {
      const response = await entrypoint().fetch(
        new Request("https://service-binding.local/internal/admin/metrics", { method })
      );

      expect(response.status).toBe(405);
      expect(response.headers.get("allow")).toBe("GET");
      expect(await jsonBody(response)).toMatchObject({
        error: { code: "method_not_allowed" }
      });
    }
  );

  it.each([
    "/",
    "/dashboard/data",
    "/internal/admin/metrics/",
    "/internal/admin/Metrics"
  ])("returns 404 for non-matching path %s", async (path) => {
    const response = await entrypoint().fetch(
      new Request(`https://service-binding.local${path}`)
    );

    expect(response.status).toBe(404);
    expect(await jsonBody(response)).toMatchObject({
      error: { code: "not_found" }
    });
  });

  it("keeps the internal path absent from the public fetch router", async () => {
    const response = await routeFetch(
      new Request("https://api.darkrio326.top/internal/admin/metrics"),
      env
    );

    expect(response.status).toBe(404);
    expect(await jsonBody(response)).toMatchObject({
      error: { code: "not_found" }
    });
  });
});
