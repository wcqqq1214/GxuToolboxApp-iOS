import {useCallback, useEffect, useRef, useState, useSyncExternalStore} from "react";
import {JwMachine} from "@/core/auth/Jw/JwMachine.ts";
import type {Account} from "@/core/auth/auth.type";

export function useJwAccount() {
    const authState = useSyncExternalStore(JwMachine.subscribe, JwMachine.getState);
    const [savedAccount, setSavedAccount] = useState<{state: typeof authState; account: Account | null} | null>(null);
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");
    const [hydrating, setHydrating] = useState(true);
    const mountedRef = useRef(true);

    useEffect(() => {
        mountedRef.current = true;
        let active = true;
        const state = JwMachine.getState();
        (async () => {
            try {
                const account = await JwMachine.loadAccount();
                if (!active) return;
                setSavedAccount({state, account});
                if (account) {
                    setUsername(account.username ?? "");
                    setPassword(account.password ?? "");
                }
            } catch (cause) {
                console.warn("读取教务账号失败", cause);
            } finally {
                if (active) setHydrating(false);
            }
        })();

        return () => {
            active = false;
            mountedRef.current = false;
        };
    }, []);

    const saveAccount = useCallback(
        async (u?: string, p?: string) => {
            const nextUsername = (u ?? username).trim();
            const nextPassword = (p ?? password).trim();
            await JwMachine.saveAccount({username: nextUsername, password: nextPassword});
            if (!mountedRef.current) return;
            setSavedAccount({state: JwMachine.getState(), account: {username: nextUsername, password: nextPassword}});
            setUsername(nextUsername);
            setPassword(nextPassword);
        },
        [username, password],
    );

    return {
        // 当前账号供查询使用；username/password 仍是账号表单的编辑值。
        account:
            "account" in authState
                ? authState.account
                : savedAccount?.state === authState
                  ? savedAccount.account
                  : null,
        username,
        setUsername,
        password,
        setPassword,
        hydrating,
        saveAccount,
    };
}
