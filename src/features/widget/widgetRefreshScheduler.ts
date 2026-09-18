import {NativeModules} from "react-native";

interface WidgetRefreshSchedulerModule {
    schedule(triggerAtMillis: number): void;
    cancel(): void;
}

const nativeScheduler = NativeModules.WidgetRefreshScheduler as WidgetRefreshSchedulerModule | undefined;

export function scheduleNextWidgetRefresh(triggerAtMillis: number | null) {
    if (triggerAtMillis === null) {
        nativeScheduler?.cancel();
        return;
    }
    nativeScheduler?.schedule(triggerAtMillis);
}
