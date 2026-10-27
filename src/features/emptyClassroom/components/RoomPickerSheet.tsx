import {useEffect, useMemo, useRef, useState, type ReactNode} from "react";
import {ActivityIndicator, ScrollView, StyleSheet, TextInput, View} from "react-native";
import {Button, useTheme} from "@rneui/themed";
import {Flex, Icon, UnBottomSheet, UnPressable, UnText, vh} from "@/components/un-ui";
import {useRoomList} from "../hooks/useRoomList";
import type {LogicalTerm, RoomRecord} from "../type";
import {groupRoomsByBuilding, type BuildingGroup, type FloorGroup} from "../utils/floor";

export type RoomPickerSheetProps = {
    visible: boolean;
    onClose: () => void;
    year: number;
    term: LogicalTerm;
    selectedRoomId: number | null;
    onSelect: (room: RoomRecord) => void;
    /** 本学期没有任何教室数据时，跳转缓存管理的入口。 */
    onOpenCacheManager?: () => void;
};

/** 逐级下钻层级：楼栋 → 楼层 → 教室。 */
type PickerLevel = "building" | "floor" | "room";

/** 搜索时展平用的教室索引，附带所在楼栋与楼层标题。 */
type IndexedRoom = {
    room: RoomRecord;
    building: string;
    floorTitle: string;
};

const OTHER_FLOOR_KEY = "other";

function floorKeyOf(floor: number | null): string {
    return floor === null ? OTHER_FLOOR_KEY : String(floor);
}

function roomSubtitle(room: RoomRecord): string {
    return [room.placeType, room.seatCount !== null ? `${room.seatCount} 座位` : ""].filter(Boolean).join(" · ");
}

/** 搜索结果行需要展示完整位置：楼栋 · 楼层 · 场地类别 · 座位。 */
function searchRoomSubtitle(entry: IndexedRoom): string {
    return [
        entry.building,
        entry.floorTitle,
        entry.room.placeType,
        entry.room.seatCount !== null ? `${entry.room.seatCount} 座位` : "",
    ]
        .filter(Boolean)
        .join(" · ");
}

function buildingSubtitle(group: BuildingGroup): string {
    return [
        `${group.floorCount} 层`,
        `${group.rooms.length} 间教室`,
        group.unknownFloorCount > 0 ? `其他 ${group.unknownFloorCount} 间` : "",
    ]
        .filter(Boolean)
        .join(" · ");
}

/**
 * 作用：按楼栋 → 楼层 → 教室逐级下钻的教室选择底部弹层，支持全库搜索。
 * 修改注意：
 * - 数据只在 visible=true 时通过 useRoomList 懒加载；
 * - 行必须用 room.id 作为 key（楼层+名称不是稳定主键）；
 * - 不要用 SectionList/FlatList：RNEUI BottomSheet 内部已经是 ScrollView，
 *   再嵌套 VirtualizedList 会触发 "VirtualizedLists should never be nested" 警告；
 * - 内层 ScrollView 与外层 BottomSheet ScrollView 都需要 keyboardShouldPersistTaps="handled"，
 *   否则键盘打开时第一次点击会被吞。
 */
export function RoomPickerSheet(props: RoomPickerSheetProps) {
    const {visible, year, term, selectedRoomId, onSelect, onClose, onOpenCacheManager} = props;
    const {theme} = useTheme();
    const {rooms, loading, error, reload} = useRoomList({year, term, enabled: visible});
    const [keyword, setKeyword] = useState("");
    const [level, setLevel] = useState<PickerLevel>("building");
    const [buildingName, setBuildingName] = useState<string | null>(null);
    const [floorKey, setFloorKey] = useState<string | null>(null);
    const listRef = useRef<ScrollView>(null);

    // 每次打开/关闭都回到楼栋层并清空搜索，避免残留上一轮的下钻位置。
    useEffect(() => {
        setKeyword("");
        setLevel("building");
        setBuildingName(null);
        setFloorKey(null);
    }, [visible]);

    // 切换层级或搜索条件后回到列表顶部；列表未挂载（加载/空态）时 ref 为空，直接跳过。
    useEffect(() => {
        listRef.current?.scrollTo({y: 0, animated: false});
    }, [visible, level, buildingName, floorKey, keyword]);

    const groups = useMemo(() => groupRoomsByBuilding(rooms), [rooms]);
    const indexedRooms = useMemo<IndexedRoom[]>(
        () =>
            groups.flatMap(group =>
                group.floors.flatMap(floorGroup =>
                    floorGroup.rooms.map(room => ({
                        room,
                        building: group.building,
                        floorTitle: floorGroup.title,
                    })),
                ),
            ),
        [groups],
    );

    const query = keyword.trim().toLowerCase();
    const searching = query.length > 0;
    const searchResults = useMemo(() => {
        if (!query) return [];
        return indexedRooms.filter(({room, building, floorTitle}) =>
            [room.name, room.placeType, building, floorTitle, floorTitle.replace(/\s+/g, "")].some(value =>
                value.toLowerCase().includes(query),
            ),
        );
    }, [indexedRooms, query]);

    const currentBuilding = useMemo(() => {
        if (buildingName === null) return null;
        return groups.find(group => group.building === buildingName) ?? null;
    }, [groups, buildingName]);

    const currentFloor = useMemo<FloorGroup | null>(() => {
        if (!currentBuilding || floorKey === null) return null;
        const floor = floorKey === OTHER_FLOOR_KEY ? null : Number(floorKey);
        return currentBuilding.floors.find(group => group.floor === floor) ?? null;
    }, [currentBuilding, floorKey]);

    // 数据刷新后当前层级可能失效，按可用数据回退，避免空白页。
    const activeLevel: PickerLevel =
        level === "building" || !currentBuilding ? "building" : level === "room" && !currentFloor ? "floor" : level;

    const openBuilding = (group: BuildingGroup) => {
        setBuildingName(group.building);
        setFloorKey(null);
        setLevel("floor");
    };
    const openFloor = (group: FloorGroup) => {
        setFloorKey(floorKeyOf(group.floor));
        setLevel("room");
    };
    const backToBuildings = () => {
        setBuildingName(null);
        setFloorKey(null);
        setLevel("building");
    };
    const backToFloors = () => {
        setFloorKey(null);
        setLevel("floor");
    };
    const selectRoom = (room: RoomRecord) => {
        onSelect(room);
        onClose();
    };

    const styles = StyleSheet.create({
        container: {
            flex: 1,
            height: vh(70),
            padding: 0,
        },
        header: {
            paddingHorizontal: 16,
            paddingTop: 12,
            paddingBottom: 8,
            gap: 10,
        },
        search: {
            height: 40,
            borderRadius: 8,
            paddingHorizontal: 12,
            fontSize: 14,
            color: theme.colors.black,
            backgroundColor: theme.colors.grey5,
        },
        list: {
            flex: 1,
        },
        summary: {
            paddingHorizontal: 16,
            paddingVertical: 6,
            backgroundColor: theme.colors.grey5,
        },
        levelHeader: {
            paddingHorizontal: 16,
            paddingVertical: 6,
            backgroundColor: theme.colors.grey5,
        },
        backRow: {
            paddingHorizontal: 16,
            paddingVertical: 10,
            borderBottomWidth: StyleSheet.hairlineWidth,
            borderBottomColor: theme.colors.grey4,
        },
        row: {
            paddingHorizontal: 16,
            paddingVertical: 10,
            borderBottomWidth: StyleSheet.hairlineWidth,
            borderBottomColor: theme.colors.grey4,
        },
        rowSelected: {
            backgroundColor: theme.colors.grey5,
        },
        empty: {
            padding: 24,
            alignItems: "center",
            gap: 10,
        },
        emptyText: {
            textAlign: "center",
            lineHeight: 20,
        },
    });

    /** 教室行复用现有样式：名称 + 场地类别 · N 座位，选中项右侧打勾。 */
    const renderRoomRow = (room: RoomRecord, subtitle: string) => {
        const selected = room.id === selectedRoomId;
        return (
            <UnPressable
                key={room.id}
                style={[styles.row, selected && styles.rowSelected]}
                onPress={() => selectRoom(room)}>
                <Flex justify="space-between" align="center" gap={8}>
                    <Flex direction="column" align="flex-start" flex={1} gap={2}>
                        <UnText size={15} bold={selected}>
                            {room.name}
                        </UnText>
                        {!!subtitle && (
                            <UnText size={11} color={theme.colors.grey2}>
                                {subtitle}
                            </UnText>
                        )}
                    </Flex>
                    {selected && <Icon name="check" size={18} color={theme.colors.primary} />}
                </Flex>
            </UnPressable>
        );
    };

    let listContent: ReactNode = null;
    if (searching) {
        listContent = searchResults.map(entry => renderRoomRow(entry.room, searchRoomSubtitle(entry)));
    } else if (activeLevel === "building") {
        listContent = (
            <>
                <View style={styles.summary}>
                    <UnText size={12} color={theme.colors.grey2}>
                        {`共 ${groups.length} 栋 · ${rooms.length} 间教室`}
                    </UnText>
                </View>
                {groups.map(group => (
                    <UnPressable key={group.building} style={styles.row} onPress={() => openBuilding(group)}>
                        <Flex justify="space-between" align="center" gap={8}>
                            <Flex direction="column" align="flex-start" flex={1} gap={2}>
                                <UnText size={15} bold>
                                    {group.building}
                                </UnText>
                                <UnText size={11} color={theme.colors.grey2}>
                                    {buildingSubtitle(group)}
                                </UnText>
                            </Flex>
                            <Icon name="chevron-right" size={18} color={theme.colors.grey2} />
                        </Flex>
                    </UnPressable>
                ))}
            </>
        );
    } else if (activeLevel === "floor" && currentBuilding) {
        listContent = (
            <>
                <UnPressable style={styles.backRow} onPress={backToBuildings}>
                    <Flex inline align="center" gap={4}>
                        <Icon name="chevron-left" size={18} color={theme.colors.primary} />
                        <UnText size={13} color={theme.colors.primary}>
                            全部楼栋
                        </UnText>
                    </Flex>
                </UnPressable>
                <View style={styles.levelHeader}>
                    <UnText size={13} bold color={theme.colors.grey2}>
                        {currentBuilding.building}
                    </UnText>
                </View>
                {currentBuilding.floors.map(floorGroup => (
                    <UnPressable
                        key={floorKeyOf(floorGroup.floor)}
                        style={styles.row}
                        onPress={() => openFloor(floorGroup)}>
                        <Flex justify="space-between" align="center" gap={8}>
                            <Flex direction="column" align="flex-start" flex={1} gap={2}>
                                <UnText size={15} bold>
                                    {floorGroup.title}
                                </UnText>
                                <UnText size={11} color={theme.colors.grey2}>
                                    {`${floorGroup.rooms.length} 间教室`}
                                </UnText>
                            </Flex>
                            <Icon name="chevron-right" size={18} color={theme.colors.grey2} />
                        </Flex>
                    </UnPressable>
                ))}
            </>
        );
    } else if (currentBuilding && currentFloor) {
        listContent = (
            <>
                <UnPressable style={styles.backRow} onPress={backToFloors}>
                    <Flex inline align="center" gap={4}>
                        <Icon name="chevron-left" size={18} color={theme.colors.primary} />
                        <UnText size={13} color={theme.colors.primary}>
                            {`${currentBuilding.building} · ${currentFloor.title}`}
                        </UnText>
                    </Flex>
                </UnPressable>
                {currentFloor.rooms.map(room => renderRoomRow(room, roomSubtitle(room)))}
            </>
        );
    }

    const hasContent = searching ? searchResults.length > 0 : groups.length > 0;

    return (
        <UnBottomSheet
            isVisible={visible}
            onBackdropPress={onClose}
            containerStyle={styles.container}
            scrollViewProps={{scrollEnabled: false, keyboardShouldPersistTaps: "handled"}}>
            <View style={styles.header}>
                <UnText size={18} bold>
                    选择教室
                </UnText>
                <TextInput
                    value={keyword}
                    onChangeText={setKeyword}
                    placeholder="搜索教室名、楼栋、楼层或场地类别"
                    placeholderTextColor={theme.colors.grey3}
                    style={styles.search}
                    autoCorrect={false}
                    returnKeyType="search"
                />
            </View>
            {!hasContent ? (
                <View style={styles.empty}>
                    {loading ? (
                        <>
                            <ActivityIndicator color={theme.colors.primary} />
                            <UnText size={13} color={theme.colors.grey2}>
                                正在加载教室列表...
                            </UnText>
                        </>
                    ) : error ? (
                        <>
                            <UnText size={13} color={theme.colors.error} style={styles.emptyText}>
                                {error}
                            </UnText>
                            <Button type="clear" title="重试" onPress={reload} />
                        </>
                    ) : rooms.length === 0 ? (
                        <>
                            <UnText size={14} style={styles.emptyText}>
                                本学期已缓存的周次中没有教室数据，请先在缓存管理中缓存至少一周
                            </UnText>
                            {onOpenCacheManager && (
                                <Button type="clear" title="去缓存管理" onPress={onOpenCacheManager} />
                            )}
                        </>
                    ) : (
                        <UnText size={14} color={theme.colors.grey2} style={styles.emptyText}>
                            没有匹配的教室
                        </UnText>
                    )}
                </View>
            ) : (
                <ScrollView ref={listRef} style={styles.list} keyboardShouldPersistTaps="handled" nestedScrollEnabled>
                    {listContent}
                </ScrollView>
            )}
        </UnBottomSheet>
    );
}
