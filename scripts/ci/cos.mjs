import crypto from "node:crypto";

function sha1(value) {
    return crypto.createHash("sha1").update(value).digest("hex");
}

function hmacSha1(key, value) {
    return crypto.createHmac("sha1", key).update(value).digest("hex");
}

function encodeRfc3986(value) {
    return encodeURIComponent(value).replace(/[!'()*]/g, char => `%${char.charCodeAt(0).toString(16).toUpperCase()}`);
}

function encodeKey(key) {
    return key.split("/").map(encodeRfc3986).join("/");
}

function requiredEnv(name) {
    const value = process.env[name];
    if (!value) throw new Error(`缺少环境变量 ${name}`);
    return value;
}

function cosConfig() {
    return {
        bucket: requiredEnv("COS_BUCKET"),
        region: requiredEnv("COS_REGION"),
        secretId: requiredEnv("COS_SECRET_ID"),
        secretKey: requiredEnv("COS_SECRET_KEY"),
    };
}

/**
 * 生成腾讯云 COS 的预签名 PUT 地址。
 * 只签名 host，Content-Type / Cache-Control 作为未签名头发送。
 */
function presignedPutUrl(key, expires = 3600) {
    const {bucket, region, secretId, secretKey} = cosConfig();
    const host = `${bucket}.cos.${region}.myqcloud.com`;
    const pathname = `/${encodeKey(key)}`;
    const start = Math.floor(Date.now() / 1000) - 60;
    const end = start + expires;
    const keyTime = `${start};${end}`;
    const signKey = hmacSha1(secretKey, keyTime);
    const headerList = "host";
    const headerString = `host=${encodeRfc3986(host)}`;
    const urlParamList = "";
    const httpString = `put\n${pathname}\n${urlParamList}\n${headerString}\n`;
    const stringToSign = `sha1\n${keyTime}\n${sha1(httpString)}\n`;
    const signature = hmacSha1(signKey, stringToSign);
    const query = [
        "q-sign-algorithm=sha1",
        `q-ak=${encodeRfc3986(secretId)}`,
        `q-sign-time=${keyTime}`,
        `q-key-time=${keyTime}`,
        `q-header-list=${headerList}`,
        `q-url-param-list=${urlParamList}`,
        `q-signature=${signature}`,
    ].join("&");

    return `https://${host}${pathname}?${query}`;
}

export async function putObject({key, body, contentType, cacheControl}) {
    const url = presignedPutUrl(key);
    const headers = {"Content-Type": contentType};
    if (cacheControl) headers["Cache-Control"] = cacheControl;

    const response = await fetch(url, {
        method: "PUT",
        headers,
        body,
    });

    if (!response.ok) {
        const text = await response.text();
        throw new Error(`PUT ${key} 失败 (${response.status}): ${text.slice(0, 500)}`);
    }
}
