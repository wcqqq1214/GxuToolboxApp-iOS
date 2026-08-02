import {AuthStateMap} from "@/core/auth/auth.type.ts";

export type AuthState<A> =
    | {status: AuthStateMap.NoAccount}
    | {status: AuthStateMap.HasAccountNotAuthenticated; account: A}
    | {status: AuthStateMap.Authenticated; account: A};
export interface AuthAdapter<A> {
    loadAccount: () => Promise<A | null>;
    saveAccount: (account: A) => Promise<unknown>;
    clearAccount: () => Promise<unknown>;
    testToken: () => Promise<boolean>;
    loginWithAccount: (account: A) => Promise<boolean>;
}

export interface AuthMachine<A> {
    refreshToken: () => Promise<AuthState<A>>;
    getState: () => AuthState<A>;
    loadAccount: () => Promise<A | null>;
    saveAccount: (account: A) => Promise<unknown>;
    clearAccount: () => Promise<AuthState<A>>;
    loginWithAccount: (account: A) => Promise<AuthState<A>>;
    loginWithStoredAccount: () => Promise<AuthState<A>>;
    setState: (state: AuthState<A>) => AuthState<A>;
    subscribe: (listener: (state: AuthState<A>) => void) => () => void;
}

export function createAuthCore<A>(adapter: AuthAdapter<A>): AuthMachine<A> {
    let currentState: AuthState<A> = {status: AuthStateMap.NoAccount};
    let pendingAuth: Promise<AuthState<A>> | null = null;
    const listeners = new Set<(state: AuthState<A>) => void>();

    function setState(nextState: AuthState<A>) {
        currentState = nextState;
        listeners.forEach(listener => listener(nextState));
        return nextState;
    }

    function subscribe(listener: (state: AuthState<A>) => void) {
        listeners.add(listener);
        return () => {
            listeners.delete(listener);
        };
    }

    async function refreshToken() {
        if (pendingAuth) {
            return pendingAuth;
        }

        pendingAuth = (async () => {
            try {
                const account = await adapter.loadAccount();
                if (!account) {
                    return setState({status: AuthStateMap.NoAccount});
                }
                let ok = false;

                // 先测Token是否过期
                try {
                    ok = await adapter.testToken();
                } catch (e) {
                    console.error(e);
                }
                if (ok) {
                    return setState({status: AuthStateMap.Authenticated, account});
                }

                // 如果Token过期，尝试重新登录
                try {
                    ok = await adapter.loginWithAccount(account);
                } catch (e) {
                    console.error(e);
                    ok = false;
                }
                if (ok) {
                    return setState({status: AuthStateMap.Authenticated, account});
                }

                // 如果重新登录失败，标记
                return setState({status: AuthStateMap.HasAccountNotAuthenticated, account});
            } finally {
                pendingAuth = null;
            }
        })();

        return pendingAuth;
    }

    function getState() {
        return currentState;
    }

    async function loadAccount() {
        return adapter.loadAccount();
    }

    async function saveAccount(account: A) {
        return adapter.saveAccount(account);
    }

    async function clearAccount() {
        await adapter.clearAccount();
        return setState({status: AuthStateMap.NoAccount});
    }

    async function loginWithAccount(account: A) {
        if (pendingAuth) {
            return pendingAuth;
        }

        pendingAuth = (async () => {
            try {
                let ok = false;
                try {
                    ok = await adapter.loginWithAccount(account);
                } catch (e) {
                    console.warn("login failed", e);
                }

                return setState(
                    ok
                        ? {status: AuthStateMap.Authenticated, account}
                        : {status: AuthStateMap.HasAccountNotAuthenticated, account},
                );
            } finally {
                pendingAuth = null;
            }
        })();

        return pendingAuth;
    }

    async function loginWithStoredAccount() {
        const account = await adapter.loadAccount();
        if (!account) {
            return setState({status: AuthStateMap.NoAccount});
        }
        return loginWithAccount(account);
    }

    return {
        refreshToken,
        getState,
        loadAccount,
        saveAccount,
        clearAccount,
        loginWithAccount,
        loginWithStoredAccount,
        setState,
        subscribe,
    };
}
