import { WorkerEntrypoint } from "cloudflare:workers";
import { autoLedgerDashboardDataResponse } from "./dashboard";

const adminMetricsPath = "/internal/admin/metrics";
const jsonContentType = "application/json; charset=utf-8";

type InternalAPIError = {
  error: {
    code: string;
    message: string;
  };
};

export class AdminMetricsEntrypoint extends WorkerEntrypoint<Env> {
  override async fetch(request: Request): Promise<Response> {
    if (new URL(request.url).pathname !== adminMetricsPath) {
      return errorResponse(404, "not_found", "The requested internal endpoint does not exist.");
    }

    if (request.method !== "GET") {
      return errorResponse(
        405,
        "method_not_allowed",
        "This internal endpoint accepts GET requests only.",
        { allow: "GET" }
      );
    }

    return autoLedgerDashboardDataResponse(this.env);
  }
}

function errorResponse(
  status: number,
  code: string,
  message: string,
  extraHeaders: Record<string, string> = {}
): Response {
  const body: InternalAPIError = { error: { code, message } };
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": jsonContentType,
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      ...extraHeaders
    }
  });
}
