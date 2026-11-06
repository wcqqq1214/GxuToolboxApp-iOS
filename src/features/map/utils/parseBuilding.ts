import {BuildingList} from "@/features/map/data/buildings.ts";
import  type {Building} from "@/features/map/type.ts";

function normalize(text:string):string|undefined{
    return text.replace(/\s+/g," ").trim();
}

function matchByMatcher(text:string):Building| null{
    // const s= BuildingList.find(b=>b.name===text||b.fullName===text);
    // return s?.name??s?.fullName??undefined;
    for(const building of BuildingList){
        const matcher=building.matcher;
        if(!matcher){
            continue;
        }
        matcher.lastIndex=0;
        if(matcher.test(text)){
            return building;
        }
    }
    return null;
}

function matchByFullName(text:string):Building|null{
    return BuildingList.find(building=>text.includes(building.fullName)||text.includes(building.name))??null;
}

function matchByAlias(text:string):Building|null{
    let best:Building|null=null;
    let bestLength=0;

    for(const building of BuildingList){
        for(const alias of building.simpleName){
            if(alias.length<=bestLength||!text.includes(alias)){
                continue;
            }
            best=building;
            bestLength=alias.length;
        }
    }
    return best;
}

export function parseBuilding(raw:string):Building|null{
    const text=normalize(raw);
    if(!text)return null;
    return matchByMatcher(text)??matchByFullName(text)??matchByAlias(text)??null;
}
