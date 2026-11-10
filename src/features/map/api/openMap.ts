import {Linking} from "react-native";
import type {MapApp,OpenMapResult} from "@/features/map/type.ts";
import {buildMapUrl} from "@/features/map/utils/mapUrl.ts";

export const MAP_APP_LABELS:Record<MapApp, string>={
    amap:"高德地图",
    baidu:"百度地图"
};

const MAP_APP_ORDER:MapApp[]=["amap","baidu"];
const PROBE_KEYWORD="广西大学";

async function canOpenMapApp(app:MapApp):Promise<boolean>{
    try{
        return await Linking.canOpenURL(buildMapUrl(app,PROBE_KEYWORD));
    }
    catch {
        return false;
    }
}

export async function detectInstalledMapApps():Promise<MapApp[]>{
    const results=await Promise.all(
        MAP_APP_ORDER.map(async app=>((await canOpenMapApp(app))?app:null)),
    );
    return results.filter((app):app is MapApp=> app!==null);
}

export async function openMapInApp(app:MapApp,keyword:string):Promise<OpenMapResult>{
    const url=buildMapUrl(app,keyword);

    try {
        await Linking.openURL(url);
        return {ok:true,app};
    }
    catch (error){
        console.log(`[map]打开${app}失败`,error);
        return {ok:false,reason:"open-failed"};
    }
}
