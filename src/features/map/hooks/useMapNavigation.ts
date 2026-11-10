import {useCallback,useState,useRef} from "react";
import {ToastAndroid} from "react-native";
import type{MapApp,OpenMapResult} from "@/features/map/type.ts";
import {detectInstalledMapApps, MAP_APP_LABELS, openMapInApp} from "@/features/map/api/openMap.ts";
import {parseBuilding} from "@/features/map/utils/parseBuilding.ts";
import {requestMapPicker} from "@/features/map/components/MapPickerHost.tsx";


async function pickMapApp(apps:MapApp[]):Promise<MapApp|null>{
    const picked=await requestMapPicker({
        title:"请选择打开方式",
        options:apps.map(app=>({app,label:MAP_APP_LABELS[app]})),
    });
    return picked??null
}

export function useMapNavigation(){
    const [opening,setOpening]=useState(false);
    const busyRef=useRef(false);

    const openMap=useCallback(async (text:string,keyword?:string):Promise<OpenMapResult>=>{
        if(busyRef.current){
            return {ok:false,reason:"cancelled"};
        }

        const target=keyword?.trim()||parseBuilding(text)?.fullName;
        if(!target){
            ToastAndroid.show("该地点暂不支持自动在地图打开",ToastAndroid.SHORT);
            return {ok:false,reason:"unparsed"};
        }

        busyRef.current=true;
        setOpening(true);
        try{
            const apps=await detectInstalledMapApps();
            if(apps.length===0){
                ToastAndroid.show("当前未检测到地图应用，请安装后再试",ToastAndroid.SHORT);
                return {ok:false,reason:"no-app"}
            }

            const app=apps.length===1?apps[0]:await pickMapApp(apps);
            if(!app){
                return {ok:false,reason:"cancelled"};
            }

            const result=await openMapInApp(app,target);

            if(!result.ok){
                ToastAndroid.show(`无法打开${MAP_APP_LABELS[app]}，请检查是否安装`,ToastAndroid.SHORT);
            }
            return result;
        }
        finally {
            busyRef.current=false;
            setOpening(false);
        }
    },[]);
    return {opening,openMap};
}
