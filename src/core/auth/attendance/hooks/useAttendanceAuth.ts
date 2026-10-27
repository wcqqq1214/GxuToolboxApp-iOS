import {useCallback, useEffect, useRef, useState} from "react";
import {Account, AuthStateMap} from "@/core/auth/auth.type.ts";
import {attendanceMachine} from "@/core/auth/attendance/attendanceMachine.ts";
import {AuthState} from "@/core/auth/createAuthCore.ts";
import {attendanceAuthApi} from "@/core/auth/attendance/attendanceAuthApi.ts";
import {mmkv} from "@/store/mmkv";

export function useAttendanceAuth() {
    const [authState, setAuthState] = useState<AuthState<Account>>(attendanceMachine.getState());
    const [loading, setLoading] = useState(false);
    const inFlightRef = useRef(false);
    const [captchaUri, setCaptchaUri] = useState<string>("");
    const [captchaCode, setCaptchaCode] = useState<string>("");
    const [captchaLoading, setCaptchaLoading] = useState<boolean>(false);
    const [challengeToken, setChallengeToken] = useState<string | null>(null);

    const refreshCaptcha = useCallback(async () => {
        // 图片与 token 是同一次 challenge，刷新开始后旧组合立即失效。
        setCaptchaUri("");
        setCaptchaCode("");
        setChallengeToken(null);
        setCaptchaLoading(true);
        try {
            const captcha = await attendanceAuthApi.getCaptcha();

            if (!captcha.challengeToken) {
                throw new Error("验证码会话创建失败，请重试");
            }

            setCaptchaUri(captcha.imageUrl);
            setCaptchaCode(captcha.text ?? "");
            setChallengeToken(captcha.challengeToken);

            return captcha;
        } finally {
            setCaptchaLoading(false);
        }
    }, []);

    useEffect(() => {
        const unsubscribe = attendanceMachine.subscribe(setAuthState);
        setAuthState(attendanceMachine.getState());
        return unsubscribe;
    }, []);

    const refreshState = useCallback(async () => {
        const state = await attendanceMachine.refreshToken();
        setAuthState(state);
        return state;
    }, []);

    const login = useCallback(
        async (username: string, password: string, code: string) => {
            if (inFlightRef.current) return;

            if (!challengeToken) {
                throw new Error("验证码已失效，请刷新验证码");
            }

            inFlightRef.current = true;
            setLoading(true);

            const account = {username, password};

            try {
                const session = await attendanceAuthApi.login({
                    username,
                    password,
                    captchaCode: code,
                    ticket: challengeToken,
                });

                await attendanceMachine.saveAccount(account);

                mmkv.set("attendanceSession", session);

                setChallengeToken(null);

                const state = attendanceMachine.setState({
                    status: AuthStateMap.Authenticated,
                    account,
                });
                // void attendanceApi.getMenuData().catch(() => undefined);
                return {state, session};
            } catch (error) {
                // 验证码 challenge 在登录尝试后不再复用。
                setChallengeToken(null);
                attendanceMachine.setState({
                    status: AuthStateMap.HasAccountNotAuthenticated,
                    account,
                });

                throw error;
            } finally {
                inFlightRef.current = false;
                setLoading(false);
            }
        },
        [challengeToken],
    );

    return {
        authState,
        loading,
        login,
        refreshState,
        setAuthState,
        refreshCaptcha,
        captchaLoading,
        captchaUri,
        captchaCode,
        setCaptchaCode,
    };
}
