type AccessRuntimeEnv = Env & {
  ENVIRONMENT?: string;
  ACCESS_AUD?: string;
  ACCESS_TEAM_DOMAIN?: string;
  ACCESS_ALLOWED_EMAILS?: string;
  ACCESS_PROTECTED_HOSTS?: string;
  ACCESS_TRUST_EMAIL_HEADER?: string;
};

type AccessJWTHeader = {
  alg?: string;
  kid?: string;
};

type AccessJWTPayload = {
  aud?: string | string[];
  email?: string;
  exp?: number;
  iat?: number;
  iss?: string;
  nbf?: number;
};

type AccessJWKS = {
  keys?: AccessJWK[];
};

type AccessJWK = JsonWebKey & {
  kid?: string;
};

export async function canViewAutoLedgerDashboard(request: Request, env: Env): Promise<boolean> {
  const runtime = env as AccessRuntimeEnv;
  if (runtime.ENVIRONMENT !== "production") {
    return true;
  }
  if (isCloudflareAccessEmailHeaderAllowed(request, env)) {
    return true;
  }
  return isCloudflareAccessJWTAllowed(request, env);
}

export async function isCloudflareAccessJWTAllowed(request: Request, env: Env): Promise<boolean> {
  const runtime = env as AccessRuntimeEnv;
  const expectedAudience = runtime.ACCESS_AUD?.trim();
  const teamDomain = normalizeTeamDomain(runtime.ACCESS_TEAM_DOMAIN);
  if (!expectedAudience || !teamDomain) {
    return false;
  }

  const token = request.headers.get("cf-access-jwt-assertion")?.trim();
  if (!token) {
    return false;
  }

  const parts = token.split(".");
  if (parts.length !== 3) {
    return false;
  }
  const [headerPart, payloadPart, signaturePart] = parts as [string, string, string];

  try {
    const header = decodeJSON<AccessJWTHeader>(headerPart);
    const payload = decodeJSON<AccessJWTPayload>(payloadPart);
    if (header.alg !== "RS256" || !header.kid) {
      return false;
    }
    if (!hasExpectedAudience(payload.aud, expectedAudience)) {
      return false;
    }
    if (payload.iss !== `https://${teamDomain}`) {
      return false;
    }
    if (!isTokenTimeValid(payload)) {
      return false;
    }
    if (!isAllowedEmail(payload.email, runtime.ACCESS_ALLOWED_EMAILS)) {
      return false;
    }

    const jwk = await accessPublicKey(teamDomain, header.kid);
    if (!jwk) {
      return false;
    }
    const key = await crypto.subtle.importKey(
      "jwk",
      jwk,
      {
        name: "RSASSA-PKCS1-v1_5",
        hash: "SHA-256"
      },
      false,
      ["verify"]
    );
    return await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      key,
      decodeBase64URL(signaturePart),
      new TextEncoder().encode(`${headerPart}.${payloadPart}`)
    );
  } catch {
    return false;
  }
}

export function isCloudflareAccessEmailHeaderAllowed(request: Request, env: Env): boolean {
  const runtime = env as AccessRuntimeEnv;
  if (runtime.ACCESS_TRUST_EMAIL_HEADER !== "true") {
    return false;
  }
  const url = new URL(request.url);
  const protectedHosts = splitList(runtime.ACCESS_PROTECTED_HOSTS);
  if (protectedHosts.length === 0 || !protectedHosts.includes(url.hostname.toLowerCase())) {
    return false;
  }
  return isAllowedEmail(request.headers.get("cf-access-authenticated-user-email") ?? undefined, runtime.ACCESS_ALLOWED_EMAILS);
}

async function accessPublicKey(teamDomain: string, keyID: string): Promise<AccessJWK | null> {
  const response = await fetch(`https://${teamDomain}/cdn-cgi/access/certs`, {
    headers: {
      accept: "application/json"
    }
  });
  if (!response.ok) {
    return null;
  }
  const jwks = (await response.json()) as AccessJWKS;
  return (jwks.keys ?? []).find((key) => key.kid === keyID) ?? null;
}

function normalizeTeamDomain(value: string | undefined): string | null {
  const trimmed = value?.trim().replace(/^https?:\/\//i, "").replace(/\/+$/, "");
  return trimmed || null;
}

function hasExpectedAudience(audience: string | string[] | undefined, expected: string): boolean {
  return Array.isArray(audience) ? audience.includes(expected) : audience === expected;
}

function isTokenTimeValid(payload: AccessJWTPayload): boolean {
  const now = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== "number" || payload.exp <= now) {
    return false;
  }
  if (typeof payload.nbf === "number" && payload.nbf > now) {
    return false;
  }
  if (typeof payload.iat === "number" && payload.iat > now + 60) {
    return false;
  }
  return true;
}

function isAllowedEmail(email: string | undefined, allowedEmails: string | undefined): boolean {
  const normalizedEmail = email?.trim().toLowerCase();
  if (!normalizedEmail) {
    return false;
  }
  const allowed = splitList(allowedEmails);
  return allowed.length === 0 || allowed.includes(normalizedEmail);
}

function splitList(value: string | undefined): string[] {
  return (value ?? "")
    .split(",")
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

function decodeJSON<T>(input: string | undefined): T {
  return JSON.parse(new TextDecoder().decode(decodeBase64URL(input ?? ""))) as T;
}

function decodeBase64URL(input: string): ArrayBuffer {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(input.length / 4) * 4, "=");
  const binary = atob(padded);
  const buffer = new ArrayBuffer(binary.length);
  const bytes = new Uint8Array(buffer);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return buffer;
}
