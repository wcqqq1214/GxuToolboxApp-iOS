import {mmkv} from "@/store/mmkv.ts";
import {Schedule} from "gxu-tool-adapters/jw";

export function loadPersonalSchedule() {
    return mmkv.getObject<Schedule>("personalSchedule");
}

export function savePersonalSchedule(data: Schedule) {
    mmkv.set("personalSchedule", data);
}
