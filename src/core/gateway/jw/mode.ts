export type JwMode = "remote_first" | "remote_only" | "local_only";

let mode: JwMode = "remote_first";

export function getJwMode() {
    return mode;
}

export function setJwMode(next: JwMode) {
    mode = next;
}
