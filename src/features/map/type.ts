export type MapApp="amap"|"baidu";

export type BuildingType= "教学楼"|"学院"|"食堂"|"校门"|"综合性建筑"|"体育场"|"店铺"|"宿舍"|"快递驿站"|"其他";

export interface Building{
    type:BuildingType;
    name:string;
    fullName:string;
    simpleName:string[];
    matcher?:RegExp;
}

export type OpenMapFailReason= |"unparsed"|"no-app"|"cancelled"|"open-failed";

export type OpenMapResult= |{ok:true;app:MapApp} |{ok:false;reason:OpenMapFailReason};
