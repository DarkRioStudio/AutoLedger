type WeatherKitJWTConfig = {
  teamID: string;
  serviceID: string;
  keyID: string;
  privateKeyPEM: string;
};

export async function generateWeatherKitToken(config: WeatherKitJWTConfig): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: "ES256",
    kid: config.keyID,
    id: `${config.teamID}.${config.serviceID}`
  };
  const payload = {
    iss: config.teamID,
    iat: now,
    exp: now + 3600,
    sub: config.serviceID
  };

  const encodedHeader = base64URLEncode(JSON.stringify(header));
  const encodedPayload = base64URLEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const key = await importPrivateKey(config.privateKeyPEM);
  const signature = await sign(key, signingInput);
  return `${signingInput}.${signature}`;
}

function base64URLEncode(value: string): string {
  return bytesToBase64URL(new TextEncoder().encode(value));
}

function bytesToBase64URL(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const normalized = pem.replace(/\\n/g, "\n");
  const body = normalized
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }

  return crypto.subtle.importKey("pkcs8", bytes.buffer, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

async function sign(key: CryptoKey, data: string): Promise<string> {
  const encoded = new TextEncoder().encode(data);
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoded);
  return bytesToBase64URL(derToRawSignature(new Uint8Array(signature)));
}

function derToRawSignature(der: Uint8Array): Uint8Array {
  if (der.length === 64) {
    return der;
  }
  if (der[0] !== 0x30) {
    throw new Error("Invalid DER signature.");
  }

  let offset = 2;
  if (der[offset] !== 0x02) {
    throw new Error("Invalid DER signature r marker.");
  }
  offset += 1;
  const rLength = der[offset] ?? 0;
  offset += 1;
  const r = der.slice(offset, offset + rLength);
  offset += rLength;

  if (der[offset] !== 0x02) {
    throw new Error("Invalid DER signature s marker.");
  }
  offset += 1;
  const sLength = der[offset] ?? 0;
  offset += 1;
  const s = der.slice(offset, offset + sLength);

  const raw = new Uint8Array(64);
  raw.set(padOrTrim(r, 32), 0);
  raw.set(padOrTrim(s, 32), 32);
  return raw;
}

function padOrTrim(bytes: Uint8Array, length: number): Uint8Array {
  if (bytes.length === length) {
    return bytes;
  }
  if (bytes.length > length) {
    return bytes.slice(bytes.length - length);
  }
  const padded = new Uint8Array(length);
  padded.set(bytes, length - bytes.length);
  return padded;
}
