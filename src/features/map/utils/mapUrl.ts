import {MapApp} from "@/features/map/type.ts";

const SOURCE_APPLICATION="gxujwt";

type QueryValue=string|number|undefined;

function buildQuery(params:Record<string,QueryValue >):string{
    return Object.entries(params)
        .filter(([,value])=>value!==undefined)
        .map(([key,value])=>`${key}=${encodeURIComponent(String(value))}`).join("&");
}

function assertNever(value: never): never {
    throw new Error(`unsupported map app: ${String(value)}`);
}

export function buildMapUrl(app:MapApp,keyword:string):string{
    const trimmed=keyword.trim();
   switch (app){
       case "amap":
           return `androidamap://poi?${buildQuery({
               sourceApplication: SOURCE_APPLICATION,
               keywords: trimmed,
               dev: 0,
           })}`
       case "baidu":
           return `baidumap://map/place/search?${buildQuery({
               query: trimmed,
               src: SOURCE_APPLICATION,
           })}`;
       default:return assertNever(app);
   }
}
