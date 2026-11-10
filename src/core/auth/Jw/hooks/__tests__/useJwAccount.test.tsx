import React from "react";
import TestRenderer, {act} from "react-test-renderer";
import {JwMachine} from "@/core/auth/Jw/JwMachine";
import {useJwAccount} from "../useJwAccount";

jest.mock("@/core/auth/Jw/JwMachine", () => {
    let state: unknown = {status: "no_account"};
    const listeners = new Set<(mockState: unknown) => void>();
    return {
        JwMachine: {
            getState: () => state,
            loadAccount: jest.fn(),
            saveAccount: jest.fn(),
            subscribe(listener: (mockState: unknown) => void) {
                listeners.add(listener);
                return () => listeners.delete(listener);
            },
            publish(next: unknown) {
                state = next;
                listeners.forEach(listener => listener(next));
            },
        },
    };
});

type Data = ReturnType<typeof useJwAccount>;
const publish = (JwMachine as unknown as {publish: (state: unknown) => void}).publish;
const alice = {username: "alice", password: "saved"};
const bob = {username: "bob", password: "new"};
let renderer: TestRenderer.ReactTestRenderer | null = null;
let latest: Data;

function Probe() {
    latest = useJwAccount();
    return null;
}

async function mount() {
    await act(async () => {
        renderer = TestRenderer.create(<Probe />);
    });
}

beforeEach(() => {
    jest.clearAllMocks();
    publish({status: "no_account"});
    (JwMachine.loadAccount as jest.Mock).mockResolvedValue(alice);
    (JwMachine.saveAccount as jest.Mock).mockResolvedValue(undefined);
});

afterEach(async () => {
    await act(async () => {
        renderer?.unmount();
    });
    renderer = null;
});

it("冷启动提供已保存账号，表单编辑不会改变查询使用的账号", async () => {
    await mount();
    expect(latest.account).toEqual(alice);
    expect(latest.hydrating).toBe(false);
    expect(latest.username).toBe("alice");
    await act(async () => {
        latest.setUsername("draft");
    });
    expect(latest.username).toBe("draft");
    expect(latest.account).toEqual(alice);
});

it("跟随状态机切换账号，退出后不复用冷启动账号", async () => {
    await mount();
    await act(async () => {
        publish({status: "authenticated", account: bob});
    });
    expect(latest.account).toEqual(bob);
    await act(async () => {
        publish({status: "no_account"});
    });
    expect(latest.account).toBeNull();
});

it("迟到的持久化读取不能覆盖状态机已切换的账号", async () => {
    let resolve!: (value: typeof alice) => void;
    (JwMachine.loadAccount as jest.Mock).mockReturnValue(
        new Promise(ok => {
            resolve = ok;
        }),
    );
    await mount();
    await act(async () => {
        publish({status: "authenticated", account: bob});
    });
    await act(async () => {
        resolve(alice);
    });
    expect(latest.account).toEqual(bob);
});
