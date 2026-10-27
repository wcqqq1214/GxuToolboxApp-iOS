import type {RoomBuildingSummary, RoomRecord} from "../type";

export const OTHER_BUILDING_TITLE = "其他楼栋";
export const OTHER_FLOOR_TITLE = "其他楼层";

/** 楼层分组；“其他楼层”用 floor=null 表示。 */
export type FloorGroup = {
    /** 识别出的楼层；null 表示无法从教室名识别楼层。 */
    floor: number | null;
    /** 展示标题，例如 “3 层” / “其他楼层”。 */
    title: string;
    /** 该楼层下的教室，已按名称排序。 */
    rooms: RoomRecord[];
};

/** 带展示标题的楼栋摘要；空楼栋名统一显示为“其他楼栋”。 */
export type BuildingSummaryGroup = RoomBuildingSummary & {
    building: string;
    title: string;
    isOther: boolean;
};

/** 全库教室搜索结果中的“楼栋 · 楼层”区域。 */
export type RoomSearchSection = {
    key: string;
    building: string;
    buildingTitle: string;
    floor: number | null;
    floorTitle: string;
    title: string;
    rooms: RoomRecord[];
};

const MIN_FLOOR = 1;
const MAX_FLOOR = 30;

/** 把全角数字 ０-９ 规范化为半角，便于后续正则匹配。 */
function normalizeFullWidthDigits(value: string): string {
    return value.replace(/[０-９]/g, char => String.fromCharCode(char.charCodeAt(0) - 0xfee0));
}

/** 转义正则特殊字符，保证楼栋名按字面量匹配。 */
function escapeRegExp(value: string): string {
    return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * 去掉教室名中出现的楼栋名（字面量、忽略大小写），避免楼栋编号被误当房间号。
 * 例如 building="教10" 时 "教10-报告厅" 变成 "-报告厅"，不再把 10 识别成楼层。
 */
function stripBuildingName(text: string, building?: string): string {
    if (!building) return text;
    const normalizedBuilding = normalizeFullWidthDigits(building).trim();
    if (!normalizedBuilding) return text;
    return text.replace(new RegExp(escapeRegExp(normalizedBuilding), "gi"), "").trim();
}

function isValidFloor(value: number): boolean {
    return Number.isInteger(value) && value >= MIN_FLOOR && value <= MAX_FLOOR;
}

/**
 * 优先识别显式楼层（“3层”“3F”）。
 * 返回 undefined 表示没有显式楼层标记；显式值超出 1–30 时返回 null，不再回退到房间号。
 * 紧跟在 B/b/负 后面的数字（地下层，如 B1层、负1层）不按地上楼层处理。
 */
function matchExplicitFloor(text: string): number | null | undefined {
    const pattern = /(\d{1,2})\s*(层|[Ff](?![A-Za-z]))/g;
    let sawUnderground = false;
    let match: RegExpExecArray | null;
    while ((match = pattern.exec(text)) !== null) {
        const previous = match.index > 0 ? text[match.index - 1] : "";
        if (previous === "B" || previous === "b" || previous === "负") {
            sawUnderground = true;
            continue;
        }
        const floor = Number(match[1]);
        return isValidFloor(floor) ? floor : null;
    }
    return sawUnderground ? null : undefined;
}

/**
 * 从最后一个 2–4 位连续数字串（房间号）推断楼层。
 * 3 位取首位（101→1，203→2），4 位取前两位（1001→10）；
 * 以 0 开头的编号取第二位（0501→5，01→1）。
 */
function inferFloorFromRoomNumber(text: string): number | null {
    const runs = text.match(/\d+/g);
    if (!runs) return null;

    // 取最后一个长度 2–4 的连续数字串；1 位数字和超长串不参与。
    const candidate = [...runs].reverse().find(run => run.length >= 2 && run.length <= 4);
    if (!candidate) return null;

    let floor: number;
    if (candidate.length === 2 || candidate.length === 3) {
        floor = candidate[0] === "0" ? Number(candidate[1]) : Number(candidate[0]);
    } else {
        floor = candidate[0] === "0" ? Number(candidate[1]) : Number(candidate.slice(0, 2));
    }
    return isValidFloor(floor) ? floor : null;
}

/**
 * 作用：从教室名识别楼层。
 * 入参：roomName 教室名；building 楼栋名，会先从教室名中剔除，避免楼栋编号被误当楼层。
 * 出参：1–30 的楼层；无法识别返回 null（归入“其他教室”）。
 * 规则：先规范化全角数字并去掉楼栋名；优先匹配“X层/XF”，否则取最后一个 2–4 位房间号推断。
 * 修改注意：不要把楼栋名里的数字当楼层（例如 building="教10" 时“教10-203”必须识别为 2 层）。
 */
export function detectFloor(roomName: string, building?: string): number | null {
    const text = stripBuildingName(normalizeFullWidthDigits(roomName).trim(), building);
    if (!text) return null;

    const explicitFloor = matchExplicitFloor(text);
    if (explicitFloor !== undefined) return explicitFloor;
    return inferFloorFromRoomNumber(text);
}

/** 按中文名称排序；数字按数值比较（教2 < 教10）。 */
function compareName(left: string, right: string): number {
    return left.localeCompare(right, "zh-Hans-CN", {numeric: true});
}

function floorTitle(floor: number | null): string {
    return floor === null ? OTHER_FLOOR_TITLE : `${floor} 层`;
}

/**
 * 作用：整理首层楼栋摘要。
 * 出参：“其他楼栋”固定置顶，其余按中文数字名称升序。
 */
export function groupRoomBuildings(summaries: RoomBuildingSummary[]): BuildingSummaryGroup[] {
    return summaries
        .map(summary => {
            const isOther = summary.building.trim().length === 0;
            return {
                ...summary,
                title: isOther ? OTHER_BUILDING_TITLE : summary.building,
                isOther,
            };
        })
        .sort((left, right) => {
            if (left.isOther) return right.isOther ? 0 : -1;
            if (right.isOther) return 1;
            return compareName(left.title, right.title);
        });
}

/**
 * 作用：把单个楼栋的教室按楼层分组。
 * 出参：楼层数字升序；无法识别的“其他楼层”固定置顶。
 */
export function groupRoomsByFloor(rooms: RoomRecord[]): FloorGroup[] {
    const roomsByFloor = new Map<number | null, RoomRecord[]>();
    for (const room of [...rooms].sort((left, right) => compareName(left.name, right.name))) {
        const floor = detectFloor(room.name, room.building);
        const list = roomsByFloor.get(floor);
        if (list) list.push(room);
        else roomsByFloor.set(floor, [room]);
    }

    return [...roomsByFloor.entries()]
        .sort(([left], [right]) => {
            if (left === null) return right === null ? 0 : -1;
            if (right === null) return 1;
            return left - right;
        })
        .map(([floor, floorRooms]) => ({
            floor,
            title: floorTitle(floor),
            rooms: floorRooms,
        }));
}

/**
 * 作用：把全库教室搜索结果按楼栋、楼层整理为区域列表。
 * 出参：“其他楼栋”“其他楼层”分别置顶，其余按名称和楼层数字升序。
 */
export function groupRoomSearchResults(rooms: RoomRecord[]): RoomSearchSection[] {
    const roomsByBuilding = new Map<string, RoomRecord[]>();
    for (const room of rooms) {
        const group = roomsByBuilding.get(room.building);
        if (group) group.push(room);
        else roomsByBuilding.set(room.building, [room]);
    }

    const buildingGroups = groupRoomBuildings(
        [...roomsByBuilding].map(([building, buildingRooms]) => ({
            building,
            roomCount: buildingRooms.length,
        })),
    );

    return buildingGroups.flatMap(buildingGroup =>
        groupRoomsByFloor(roomsByBuilding.get(buildingGroup.building) ?? []).map(floorGroup => ({
            key: JSON.stringify([buildingGroup.building, floorGroup.floor]),
            building: buildingGroup.building,
            buildingTitle: buildingGroup.title,
            floor: floorGroup.floor,
            floorTitle: floorGroup.title,
            title: `${buildingGroup.title} · ${floorGroup.title}`,
            rooms: floorGroup.rooms,
        })),
    );
}
