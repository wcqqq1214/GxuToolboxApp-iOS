import {createAuthCore} from "@/core/auth/createAuthCore.ts";
import {JwAuthClient} from "@/core/auth/Jw/JwAuthClient.ts";
import {Account, AuthStateMap} from "@/core/auth/auth.type.ts";
import {userMgr} from "@/js/mgr/user.ts";

async function loginJw(account: Account): Promise<boolean> {
    const {username, password} = account;
    return JwAuthClient.login(username, password);
}

export const JwMachine = createAuthCore<Account>({
    async loadAccount() {
        const account = await userMgr.jw.getAccount();
        if (!account?.username || !account?.password) return null;
        return {username: account.username, password: account.password};
    },
    async saveAccount(account) {
        return userMgr.jw.storeAccount(account.username, account.password);
    },
    async clearAccount() {
        return userMgr.jw.storeAccount("", "");
    },
    async testToken() {
        return JwAuthClient.testTokenRaw();
    },
    async loginWithAccount(account) {
        return loginJw(account);
    },
});

export async function ensureJwAuthenticated(): Promise<boolean> {
    const state = await JwMachine.refreshToken();
    return state.status === AuthStateMap.Authenticated;
}
