type APIError = {
  error: {
    code: string;
    message: string;
  };
};

type AnalyticsDashboardRow = {
  event_name: string;
  event_id: string | null;
  app_version: string | null;
  build_number: string | null;
  os_major: string | null;
  device_class: string | null;
  payload_json: string;
  received_at: string;
};

type PrimitivePayload = Record<string, string | number | boolean | null>;

type DashboardMetric = {
  metricID: string;
  label: string;
  value: number | null;
  unit: "count" | "percent";
  numerator: number;
  denominator: number;
  status: "available" | "insufficient_data";
  breakdown?: Record<string, number>;
};

const dashboardWindowDays = 30;
const dashboardMaxRows = 5000;
const jsonContentType = "application/json; charset=utf-8";
const htmlContentType = "text/html; charset=utf-8";

export async function autoLedgerDashboardDataResponse(env: Env): Promise<Response> {
  if (!env.COMMON_API_DB) {
    return json(error("analytics_database_unconfigured", "Analytics database is not configured."), 503);
  }

  const rowsResult = await env.COMMON_API_DB.prepare(`
    SELECT
      event_name,
      event_id,
      app_version,
      build_number,
      os_major,
      device_class,
      payload_json,
      received_at
    FROM autoledger_analytics_events
    WHERE received_at >= strftime('%Y-%m-%dT%H:%M:%fZ', 'now', ?)
    ORDER BY received_at DESC
    LIMIT ?
  `).bind(`-${dashboardWindowDays} days`, dashboardMaxRows).all<AnalyticsDashboardRow>();
  const rows = rowsResult.results ?? [];
  const events = rows.map((row) => ({
    eventName: row.event_name,
    payload: parsePayload(row.payload_json),
    appVersion: row.app_version ?? "unknown",
    buildNumber: row.build_number ?? "unknown",
    receivedAt: row.received_at
  }));

  return json({
    schemaVersion: 1,
    app: "autoledger",
    generatedAt: new Date().toISOString(),
    windowDays: dashboardWindowDays,
    rowLimit: dashboardMaxRows,
    source: "autoledger_analytics_events",
    privacy: {
      summary: "此面板只展示聚合计数和比率，不返回原始事件行或 payload JSON。",
      dataCategories: ["Diagnostics", "Usage Data"],
      linked: false,
      tracking: false
    },
    metrics: buildMetrics(events),
    eventBreakdown: eventBreakdown(events),
    appVersionBreakdown: breakdown(events.map((event) => event.appVersion)),
    latestReceivedAt: events[0]?.receivedAt ?? null
  });
}

export function autoLedgerDashboardHTMLResponse(): Response {
  return new Response(dashboardHTML, {
    status: 200,
    headers: {
      "content-type": htmlContentType,
      "cache-control": "no-store",
      "referrer-policy": "no-referrer",
      "x-robots-tag": "noindex",
      "content-security-policy": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'"
    }
  });
}

function buildMetrics(events: Array<{ eventName: string; payload: PrimitivePayload }>): DashboardMetric[] {
  const launchEvents = events.filter((event) => event.eventName === "al_perf_app_launch");
  const importStarts = events.filter((event) => event.eventName === "al_import_flow_started");
  const importCompletions = events.filter((event) => event.eventName === "al_import_flow_completed");
  const confirmationEvents = events.filter((event) => event.eventName === "al_confirmation_state");
  const currencyEvents = events.filter((event) => event.eventName === "al_currency_lookup_status");
  const purchaseEvents = events.filter((event) => event.eventName === "al_purchase_flow_status");
  const privacyEvents = events.filter((event) => event.eventName === "al_privacy_payload_guard_violation");

  return [
    countMetric("total_events_count", "已接收匿名事件总数", events.length),
    percentMetric(
      "launch_success_rate",
      "启动成功率",
      launchEvents.filter((event) => stringPayload(event.payload, "result") === "success").length,
      launchEvents.length
    ),
    percentMetric(
      "import_completion_rate",
      "导入完成率",
      importCompletions.filter((event) => stringPayload(event.payload, "status") === "success").length,
      importStarts.length
    ),
    countMetric(
      "import_error_code_top_n",
      "导入错误码分布",
      importCompletions.length,
      breakdown(importCompletions.map((event) => stringPayload(event.payload, "error_code") ?? "unknown"))
    ),
    percentMetric(
      "confirmation_discard_rate",
      "确认页放弃率",
      confirmationEvents.filter((event) => stringPayload(event.payload, "confirm_status") === "discarded").length,
      confirmationEvents.length
    ),
    percentMetric(
      "currency_lookup_success_rate",
      "汇率查询成功率",
      currencyEvents.filter((event) => stringPayload(event.payload, "rate_lookup_status") === "success").length,
      currencyEvents.length
    ),
    percentMetric(
      "purchase_flow_failure_rate",
      "购买流程失败率",
      purchaseEvents.filter((event) => isPurchaseFailure(stringPayload(event.payload, "storekit_status"))).length,
      purchaseEvents.length
    ),
    countMetric(
      "privacy_payload_violation_count",
      "隐私 payload 拦截次数",
      privacyEvents.length,
      breakdown(privacyEvents.map((event) => stringPayload(event.payload, "blocked_field_category") ?? "unknown"))
    )
  ];
}

function percentMetric(metricID: string, label: string, numerator: number, denominator: number): DashboardMetric {
  return {
    metricID,
    label,
    value: denominator > 0 ? roundPercent(numerator, denominator) : null,
    unit: "percent",
    numerator,
    denominator,
    status: denominator > 0 ? "available" : "insufficient_data"
  };
}

function countMetric(
  metricID: string,
  label: string,
  value: number,
  metricBreakdown?: Record<string, number>
): DashboardMetric {
  return {
    metricID,
    label,
    value,
    unit: "count",
    numerator: value,
    denominator: 1,
    status: "available",
    ...(metricBreakdown ? { breakdown: metricBreakdown } : {})
  };
}

function eventBreakdown(events: Array<{ eventName: string; receivedAt?: string }>): Array<{ eventName: string; count: number; latestReceivedAt: string | null }> {
  const byEventName = new Map<string, { count: number; latestReceivedAt: string | null }>();
  for (const event of events) {
    const current = byEventName.get(event.eventName) ?? { count: 0, latestReceivedAt: null };
    current.count += 1;
    if (!current.latestReceivedAt || (event.receivedAt && event.receivedAt > current.latestReceivedAt)) {
      current.latestReceivedAt = event.receivedAt ?? current.latestReceivedAt;
    }
    byEventName.set(event.eventName, current);
  }
  return [...byEventName.entries()]
    .map(([eventName, value]) => ({ eventName, ...value }))
    .sort((a, b) => b.count - a.count || a.eventName.localeCompare(b.eventName));
}

function breakdown(values: string[]): Record<string, number> {
  return values.reduce<Record<string, number>>((result, value) => {
    result[value] = (result[value] ?? 0) + 1;
    return result;
  }, {});
}

function parsePayload(payloadJSON: string): PrimitivePayload {
  try {
    const parsed = JSON.parse(payloadJSON) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return {};
    }
    return Object.entries(parsed).reduce<PrimitivePayload>((result, [key, value]) => {
      if (typeof value === "string" || typeof value === "number" || typeof value === "boolean" || value === null) {
        result[key] = value;
      }
      return result;
    }, {});
  } catch {
    return {};
  }
}

function stringPayload(payload: PrimitivePayload, key: string): string | null {
  const value = payload[key];
  return typeof value === "string" ? value : null;
}

function isPurchaseFailure(status: string | null): boolean {
  return status === "failed" || status === "cancelled" || status === "canceled" || status === "unknown";
}

function roundPercent(numerator: number, denominator: number): number {
  return Math.round((numerator / denominator) * 1000) / 10;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": jsonContentType,
      "cache-control": "no-store"
    }
  });
}

function error(code: string, message: string): APIError {
  return { error: { code, message } };
}

const dashboardHTML = `<!doctype html>
<html lang="zh-Hans">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AutoLedger 运营观测面板</title>
  <style>
    :root {
      color-scheme: light;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f6f7f9;
      color: #152238;
    }
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; }
    main { width: min(1120px, calc(100vw - 32px)); margin: 0 auto; padding: 32px 0 48px; }
    header { display: flex; align-items: flex-end; justify-content: space-between; gap: 24px; margin-bottom: 24px; }
    h1 { margin: 0 0 8px; font-size: clamp(28px, 4vw, 44px); line-height: 1.05; letter-spacing: 0; }
    p { margin: 0; color: #526173; line-height: 1.55; }
    .badge { display: inline-flex; align-items: center; min-height: 32px; border: 1px solid #cbd5e1; border-radius: 999px; padding: 0 12px; color: #334155; background: #fff; font-size: 13px; white-space: nowrap; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; }
    .metric, .panel { border: 1px solid #d9e0ea; border-radius: 8px; background: #fff; box-shadow: 0 1px 2px rgb(15 23 42 / 5%); }
    .metric { padding: 18px; min-height: 136px; display: flex; flex-direction: column; justify-content: space-between; gap: 18px; }
    .metric h2 { margin: 0; font-size: 14px; font-weight: 650; color: #334155; letter-spacing: 0; }
    .value { font-size: 34px; line-height: 1; font-weight: 760; color: #0f172a; }
    .detail { font-size: 13px; color: #64748b; }
    .section-grid { display: grid; grid-template-columns: minmax(0, 1.2fr) minmax(280px, .8fr); gap: 16px; margin-top: 16px; }
    .panel { padding: 18px; }
    .panel h2 { margin: 0 0 14px; font-size: 18px; letter-spacing: 0; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th, td { padding: 10px 8px; border-bottom: 1px solid #e2e8f0; text-align: left; }
    th { color: #475569; font-weight: 650; }
    .muted { color: #64748b; }
    .error { color: #b42318; }
    @media (max-width: 760px) {
      header, .section-grid { display: block; }
      header .badge { margin-top: 16px; }
      .panel { margin-top: 16px; overflow-x: auto; }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <div>
        <h1>AutoLedger 运营观测面板</h1>
        <p>匿名聚合指标，用于上线前检查。这里不展示账本金额、商户名、截图、PDF、邮箱、酒店标识、房号、精确位置、OCR 文本、StoreKit 交易标识、票据或支付数据。</p>
      </div>
      <span class="badge" id="status">正在加载</span>
    </header>
    <section class="grid" id="metrics"></section>
    <section class="section-grid">
      <div class="panel">
        <h2>事件分布</h2>
        <table>
          <thead><tr><th>事件</th><th>次数</th><th>最近接收</th></tr></thead>
          <tbody id="eventBreakdown"><tr><td colspan="3" class="muted">正在加载</td></tr></tbody>
        </table>
      </div>
      <div class="panel">
        <h2>隐私边界</h2>
        <p id="privacy" class="muted">正在加载</p>
      </div>
    </section>
  </main>
  <script>
    const metricOrder = [
      "total_events_count",
      "launch_success_rate",
      "import_completion_rate",
      "purchase_flow_failure_rate",
      "privacy_payload_violation_count",
      "currency_lookup_success_rate",
      "confirmation_discard_rate",
      "import_error_code_top_n"
    ];

    function formatMetric(metric) {
      if (metric.value === null) return "暂无数据";
      return metric.unit === "percent" ? metric.value + "%" : String(metric.value);
    }

    function statusText(status) {
      switch (status) {
        case "available": return "可用";
        case "insufficient_data": return "数据不足";
        default: return status || "-";
      }
    }

    function escapeHTML(value) {
      return String(value).replace(/[&<>"']/g, (char) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;"
      }[char]));
    }

    async function loadDashboard() {
      const status = document.getElementById("status");
      try {
        const response = await fetch("/dashboard/data", { cache: "no-store" });
        if (!response.ok) throw new Error("Dashboard data unavailable");
        const data = await response.json();
        status.textContent = "最近更新 " + new Date(data.generatedAt).toLocaleString("zh-CN", { hour12: false });
        document.getElementById("privacy").textContent = data.privacy.summary + " 数据" + (data.privacy.linked ? "会关联用户" : "不关联用户") + "，" + (data.privacy.tracking ? "用于追踪。" : "不用于追踪。");

        const byID = new Map(data.metrics.map((metric) => [metric.metricID, metric]));
        document.getElementById("metrics").innerHTML = metricOrder
          .map((metricID) => byID.get(metricID))
          .filter(Boolean)
          .map((metric) => '<article class="metric"><h2>' + escapeHTML(metric.label) + '</h2><div><div class="value">' + escapeHTML(formatMetric(metric)) + '</div><div class="detail">' + escapeHTML(metric.numerator + ' / ' + metric.denominator + ' · ' + statusText(metric.status)) + '</div></div></article>')
          .join("");

        document.getElementById("eventBreakdown").innerHTML = data.eventBreakdown.length
          ? data.eventBreakdown.map((row) => '<tr><td>' + escapeHTML(row.eventName) + '</td><td>' + escapeHTML(row.count) + '</td><td class="muted">' + escapeHTML(row.latestReceivedAt || "暂无数据") + '</td></tr>').join("")
          : '<tr><td colspan="3" class="muted">当前窗口内没有事件。</td></tr>';
      } catch (error) {
        status.textContent = "暂不可用";
        status.className = "badge error";
        document.getElementById("metrics").innerHTML = '<article class="metric"><h2>面板暂不可用</h2><div class="detail">请在 Worker 和 D1 绑定恢复后刷新。</div></article>';
      }
    }

    loadDashboard();
  </script>
</body>
</html>`;
