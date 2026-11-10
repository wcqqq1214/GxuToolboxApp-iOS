const API_URL_KEYS = ["CI_API_V4_URL", "GITLAB_API_URL"];

export function hasGitLabApi() {
    const apiUrl = API_URL_KEYS.map(key => process.env[key]).find(Boolean);
    const projectId = process.env.CI_PROJECT_ID ?? process.env.GITLAB_PROJECT_ID;
    const token = process.env.GITLAB_API_TOKEN ?? process.env.CI_JOB_TOKEN;
    return Boolean(apiUrl && projectId && token);
}

export async function gitLabRequest(method, resource, {body, allowNotFound = false} = {}) {
    const apiUrl = API_URL_KEYS.map(key => process.env[key])
        .find(Boolean)
        ?.replace(/\/+$/, "");
    const projectId = process.env.CI_PROJECT_ID ?? process.env.GITLAB_PROJECT_ID;
    const privateToken = process.env.GITLAB_API_TOKEN;
    const jobToken = process.env.CI_JOB_TOKEN;

    if (!apiUrl || !projectId) {
        throw new Error("缺少 CI_API_V4_URL 或 CI_PROJECT_ID，GitLab API 只能在 CI 中调用");
    }
    if (!privateToken && !jobToken) {
        throw new Error("缺少 GitLab API 凭证：GITLAB_API_TOKEN 或 CI_JOB_TOKEN");
    }

    const url = `${apiUrl}/projects/${encodeURIComponent(projectId)}${resource}`;
    const authHeaders = [
        ...(jobToken ? [{"JOB-TOKEN": jobToken}] : []),
        ...(privateToken ? [{"PRIVATE-TOKEN": privateToken}] : []),
    ];
    let response;
    for (let index = 0; index < authHeaders.length; index += 1) {
        const headers = {...authHeaders[index], ...(body ? {"Content-Type": "application/json"} : {})};
        response = await fetch(url, {
            method,
            headers,
            body: body ? JSON.stringify(body) : undefined,
        });
        const canRetry = [401, 403].includes(response.status) && index < authHeaders.length - 1;
        if (!canRetry) break;
    }

    if (allowNotFound && response.status === 404) return null;
    if (!response.ok) {
        const text = await response.text();
        throw new Error(`GitLab ${method} ${resource} 失败 (${response.status}): ${text.slice(0, 500)}`);
    }
    if (response.status === 204) return null;
    return response.json();
}
