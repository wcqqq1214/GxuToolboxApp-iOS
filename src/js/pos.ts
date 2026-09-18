import {BuildingList, IPos} from "@/type/pos.ts";
import {Linking, ToastAndroid} from "react-native";
import {requestMapPicker, type MapPickerOption} from "@/features/map/components/MapPickerHost.tsx";
import {urlWithParams} from "@/core/http.ts";

const sourceApplication = "gxujwt";
type MapApp = "amap" | "baidu";

type AvailableMaps = {
    amap: string | null;
    baidu: string | null;
};

function getKeyword(pos: IPos | string) {
    return typeof pos === "string" ? pos : pos.fullName;
}

function buildAmapUrl(keyword: string) {
    return urlWithParams("androidamap://poi", {sourceApplication: sourceApplication, keywords: keyword, dev: 0});
}

function buildBaiduUrl(keyword: string) {
    return urlWithParams("baidumap://map/place/search", {query: keyword, src: sourceApplication});
}

function buildAmapProbeUrl() {
    return "androidamap://";
}

function buildBaiduProbeUrl() {
    return "baidumap://";
}

async function canOpenAnyUrl(urls: string[]) {
    for (const url of urls) {
        const canOpen = await Linking.canOpenURL(url).catch(() => false);
        if (canOpen) {
            return true;
        }
    }
    return false;
}

async function getAvailableMaps(keyword: string): Promise<AvailableMaps> {
    const amapUrl = buildAmapUrl(keyword);
    const baiduUrl = buildBaiduUrl(keyword);

    const [amapAvailable, baiduAvailable] = await Promise.all([
        canOpenAnyUrl([amapUrl, buildAmapProbeUrl(), "androidamap://poi"]),
        canOpenAnyUrl([baiduUrl, buildBaiduProbeUrl(), "baidumap://map/place/search"]),
    ]);

    return {
        amap: amapAvailable ? amapUrl : null,
        baidu: baiduAvailable ? baiduUrl : null,
    };
}

async function tryOpenMap(url: string, app: MapApp, showToast = true) {
    try {
        await Linking.openURL(url);
        return true;
    }
    catch (e) {
        console.error(e);
        if (showToast) {
            const appName = app === "amap" ? "高德地图" : "百度地图";
            ToastAndroid.show(`无法打开${appName}，请检查是否安装`, ToastAndroid.SHORT);
        }
        return false;
    }
}

function chooseInstalledMapApp(availableMaps: AvailableMaps): Promise<MapApp | null> {
    const options: MapPickerOption[] = [];

    if (availableMaps.amap) {
        options.push({
            app: "amap" as const,
            label: "高德地图",
        });
    }

    if (availableMaps.baidu) {
        options.push({
            app: "baidu" as const,
            label: "百度地图",
        });
    }

    return requestMapPicker({
        title: "选择要打开的方式",
        options,
    }) ?? Promise.resolve(null);
}

export const Pos = {
    parseStr: (str: string): IPos | null => {
        if (!str) {
            return null;
        }
        // 1. 优先使用 test 规则匹配（兼容 "6A-102"、"西3-408" 等场地编号格式）
        for (const pos of BuildingList) {
            if (
                (typeof pos.test === "function" && pos.test(str)) ||
                (pos.test instanceof RegExp && "test" in pos.test && pos.test.test(str))
            ) {
                return pos;
            }
        }
        // 2. 回退：按楼栋别名 / 名称做子串匹配（兼容 "西三教3-406" 这类带楼栋名的格式）
        for (const pos of BuildingList) {
            if (pos.simpleName.some(alias => alias.length > 0 && str.includes(alias)) || str.includes(pos.name)) {
                return pos;
            }
        }
        return null;
    },
    searchInMap: async (pos: IPos | string) => {
        if (!pos) {
            return false;
        }
        const keyword = getKeyword(pos);
        const availableMaps = await getAvailableMaps(keyword);
        const hasAmap = !!availableMaps.amap;
        const hasBaidu = !!availableMaps.baidu;

        try {
            if (!hasAmap && !hasBaidu) {
                ToastAndroid.show("当前未检测到地图应用，请安装后再试", ToastAndroid.SHORT);
                return false;
            }

            const selectedApp = await chooseInstalledMapApp(availableMaps);

            if (!selectedApp) {
                return false;
            }

            if (selectedApp === "amap" && availableMaps.amap) {
                return await tryOpenMap(availableMaps.amap, "amap");
            }

            if (selectedApp === "baidu" && availableMaps.baidu) {
                return await tryOpenMap(availableMaps.baidu, "baidu");
            }

            ToastAndroid.show("无法打开所选地图", ToastAndroid.SHORT);
            return false;
        }
        catch (e) {
            console.error(e);
            ToastAndroid.show("无法打开地图，请稍后重试", ToastAndroid.SHORT);
            return false;
        }
    },
    parseAndSearchInMap: (str: string) => {
        if (!str) {
            return;
        }
        const pos = Pos.parseStr(str);
        if (pos !== null) {
            Pos.searchInMap(pos).then(opened => {
                if (opened) {
                    ToastAndroid.show("正在跳转至地图", ToastAndroid.SHORT);
                }
            }).catch(e => {
                console.error(e);
                ToastAndroid.show("打开失败", ToastAndroid.SHORT);
            });
        }
        else {
            ToastAndroid.show("该地点尚未支持自动在地图打开", ToastAndroid.SHORT);
        }
    },
};
