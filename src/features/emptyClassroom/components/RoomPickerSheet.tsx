import {useEffect, useMemo, useRef, useState, type ReactNode} from "react";
import {ActivityIndicator, ScrollView, StyleSheet, TextInput, View} from "react-native";
import {Button, useTheme} from "@rneui/themed";
import {Flex, Icon, UnBottomSheet, UnPressable, UnText, vh} from "@/components/un-ui";
import {Color} from "@/shared/color";
import {useBuildingRooms, useRoomBuildings, useRoomSearch} from "../hooks/useRoomList";
import type {RoomRecord} from "../type";
import {
    type BuildingSummaryGroup,
    groupRoomBuildings,
    groupRoomSearchResults,
    groupRoomsByFloor,
    type FloorGroup,
} from "../utils/floor";

export type RoomPickerSheetProps = {
    visible: boolean;
    onClose: () => void;
    selectedRoomId: number | null;
    onSelect?: (room: RoomRecord) => void;
    /** 多选模式下列表点击只切换勾选，不立即关闭。 */
    multiple?: boolean;
    selectedRoomIds?: readonly number[];
    onConfirmMultiple?: (roomIds: number[]) => void;
    /** 教室里没有任何持久化数据时，跳转缓存管理的入口。 */
    onOpenCacheManager?: () => void;
};

/** 逐级下钻层级：楼栋 → 楼层 → 教室。 */
type PickerLevel = "building" | "floor" | "room";

const OTHER_FLOOR_KEY = "other";
const EMPTY_ROOM_IDS: readonly number[] = [];

function floorKeyOf(floor: number | null): string {
    return floor === null ? OTHER_FLOOR_KEY : String(floor);
}

function roomSubtitle(room: RoomRecord): string {
    return [room.placeType, room.seatCount !== null ? `${room.seatCount} 座位` : ""].filter(Boolean).join(" · ");
}

function buildingSubtitle(group: BuildingSummaryGroup): string {
    return `${group.roomCount} 间教室`;
}

/**
 * 作用：按楼栋 → 楼层 → 教室逐级下钻的教室选择底部弹层。
 * 修改注意：
 * - 首层只查询楼栋和教室数，进入楼栋后才读取该楼栋教室；
 * - 空楼栋、无法识别楼层的分组分别显示“其他楼栋”“其他楼层”，并固定置顶；
 * - 行必须用 room.id / building 原值作为 key；
 * - BottomSheet 内部已经是 ScrollView，不再嵌套 VirtualizedList。
 */
export function RoomPickerSheet(props: RoomPickerSheetProps) {
    const {
        visible,
        selectedRoomId,
        onSelect,
        multiple = false,
        selectedRoomIds = EMPTY_ROOM_IDS,
        onConfirmMultiple,
        onClose,
        onOpenCacheManager,
    } = props;
    const {theme} = useTheme();
    const buildingState = useRoomBuildings({enabled: visible});
    const [keyword, setKeyword] = useState("");
    const [level, setLevel] = useState<PickerLevel>("building");
    const [buildingName, setBuildingName] = useState<string | null>(null);
    const [floorKey, setFloorKey] = useState<string | null>(null);
    const [draftRoomIds, setDraftRoomIds] = useState<Set<number>>(() => new Set(selectedRoomIds));
    const roomsState = useBuildingRooms({
        building: level === "building" ? null : buildingName,
        enabled: visible,
    });
    const searchState = useRoomSearch({
        query: keyword,
        building: level === "building" ? undefined : (buildingName ?? undefined),
        enabled: visible,
    });
    const listRef = useRef<ScrollView>(null);

    // 每次打开/关闭都回到楼栋层并清空搜索，避免残留上一轮的下钻位置。
    useEffect(() => {
        setKeyword("");
        setLevel("building");
        setBuildingName(null);
        setFloorKey(null);
        setDraftRoomIds(new Set(selectedRoomIds));
    }, [selectedRoomIds, visible]);

    // 切换层级或搜索条件后回到列表顶部。
    useEffect(() => {
        listRef.current?.scrollTo({y: 0, animated: false});
    }, [visible, level, buildingName, floorKey, keyword]);

    const buildings = useMemo(() => groupRoomBuildings(buildingState.buildings), [buildingState.buildings]);
    const floors = useMemo(() => groupRoomsByFloor(roomsState.rooms), [roomsState.rooms]);
    const searchSections = useMemo(() => groupRoomSearchResults(searchState.rooms), [searchState.rooms]);
    const query = keyword.trim().toLowerCase();
    const searching = query.length > 0;

    const currentBuilding = useMemo(() => {
        if (buildingName === null) return null;
        return buildings.find(group => group.building === buildingName) ?? null;
    }, [buildingName, buildings]);

    const currentFloor = useMemo<FloorGroup | null>(() => {
        if (floorKey === null) return null;
        const floor = floorKey === OTHER_FLOOR_KEY ? null : Number(floorKey);
        return floors.find(group => group.floor === floor) ?? null;
    }, [floorKey, floors]);

    const activeLevel: PickerLevel =
        level === "building" || !currentBuilding ? "building" : level === "room" && !currentFloor ? "floor" : level;

    const filteredBuildings = useMemo(
        () => (query ? buildings.filter(group => group.title.toLowerCase().includes(query)) : buildings),
        [buildings, query],
    );
    const openBuilding = (group: BuildingSummaryGroup) => {
        setBuildingName(group.building);
        setFloorKey(null);
        setLevel("floor");
        setKeyword("");
    };
    const openFloor = (group: FloorGroup) => {
        setFloorKey(floorKeyOf(group.floor));
        setLevel("room");
        setKeyword("");
    };
    const backToBuildings = () => {
        setBuildingName(null);
        setFloorKey(null);
        setLevel("building");
        setKeyword("");
    };
    const backToFloors = () => {
        setFloorKey(null);
        setLevel("floor");
        setKeyword("");
    };
    const selectRoom = (room: RoomRecord) => {
        if (multiple) {
            setDraftRoomIds(current => {
                const next = new Set(current);
                if (next.has(room.id)) next.delete(room.id);
                else next.add(room.id);
                return next;
            });
            return;
        }
        onSelect?.(room);
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
            backgroundColor: Color(theme.colors.grey5)
                .setAlpha(theme.mode === "light" ? 0.7 : 0.55)
                .rgbaString,
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
        sectionHeader: {
            paddingHorizontal: 16,
            paddingVertical: 8,
            backgroundColor: theme.colors.grey5,
            borderBottomWidth: StyleSheet.hairlineWidth,
            borderBottomColor: theme.colors.grey4,
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
        loadingInline: {
            flexDirection: "row",
            alignItems: "center",
            justifyContent: "center",
            gap: 8,
            paddingVertical: 20,
        },
        footer: {
            paddingHorizontal: 16,
            paddingVertical: 10,
            borderTopWidth: StyleSheet.hairlineWidth,
            borderTopColor: theme.colors.grey4,
            gap: 8,
        },
        selectedSummary: {
            textAlign: "center",
        },
        footerActions: {
            flexDirection: "row",
            gap: 8,
        },
        footerAction: {
            flex: 1,
        },
    });

    const renderRoomRow = (room: RoomRecord, subtitle: string) => {
        const selected = multiple ? draftRoomIds.has(room.id) : room.id === selectedRoomId;
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
                    {multiple ? (
                        <Icon
                            name={selected ? "checkbox-outline" : "checkbox-blank-outline"}
                            size={22}
                            color={selected ? theme.colors.primary : theme.colors.grey2}
                        />
                    ) : (
                        selected && <Icon name="check" size={18} color={theme.colors.primary} />
                    )}
                </Flex>
            </UnPressable>
        );
    };

    const renderBuildingRows = (groups: BuildingSummaryGroup[]) =>
        groups.map(group => (
            <UnPressable key={group.building || "other"} style={styles.row} onPress={() => openBuilding(group)}>
                <Flex justify="space-between" align="center" gap={8}>
                    <Flex direction="column" align="flex-start" flex={1} gap={2}>
                        <UnText size={15} bold>
                            {group.title}
                        </UnText>
                        <UnText size={11} color={theme.colors.grey2}>
                            {buildingSubtitle(group)}
                        </UnText>
                    </Flex>
                    <Icon name="chevron-right" size={18} color={theme.colors.grey2} />
                </Flex>
            </UnPressable>
        ));

    let listContent: ReactNode = null;
    if (searching && searchState.loading) {
        listContent = (
            <View style={styles.loadingInline}>
                <ActivityIndicator color={theme.colors.primary} />
                <UnText size={13} color={theme.colors.grey2}>
                    正在搜索教室...
                </UnText>
            </View>
        );
    } else if (searching && searchState.error) {
        listContent = (
            <View style={styles.empty}>
                <UnText size={13} color={theme.colors.error} style={styles.emptyText}>
                    {searchState.error}
                </UnText>
                <Button type="clear" title="重试" onPress={searchState.reload} />
            </View>
        );
    } else if (searching) {
        const buildingMatches = activeLevel === "building" ? filteredBuildings : [];
        listContent =
            buildingMatches.length > 0 || searchSections.length > 0 ? (
                <>
                    {buildingMatches.length > 0 && (
                        <>
                            <View style={styles.sectionHeader}>
                                <UnText size={12} bold color={theme.colors.grey2}>
                                    楼栋
                                </UnText>
                            </View>
                            {renderBuildingRows(buildingMatches)}
                        </>
                    )}
                    {searchSections.map(section => (
                        <View key={section.key}>
                            <View style={styles.sectionHeader}>
                                <Flex justify="space-between" align="center" gap={8}>
                                    <UnText size={12} bold color={theme.colors.grey2}>
                                        {section.title}
                                    </UnText>
                                    <UnText size={11} color={theme.colors.grey3}>
                                        {`${section.rooms.length} 间`}
                                    </UnText>
                                </Flex>
                            </View>
                            {section.rooms.map(room => renderRoomRow(room, roomSubtitle(room)))}
                        </View>
                    ))}
                </>
            ) : null;
    } else if (activeLevel === "building") {
        listContent = (
            <>
                <View style={styles.summary}>
                    <UnText size={12} color={theme.colors.grey2}>
                        {`共 ${buildings.length} 栋 · ${buildingState.buildings.reduce(
                            (total, building) => total + building.roomCount,
                            0,
                        )} 间教室`}
                    </UnText>
                </View>
                {renderBuildingRows(buildings)}
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
                        {currentBuilding.title}
                    </UnText>
                </View>
                {roomsState.loading ? (
                    <View style={styles.loadingInline}>
                        <ActivityIndicator color={theme.colors.primary} />
                        <UnText size={13} color={theme.colors.grey2}>
                            正在加载该楼栋教室...
                        </UnText>
                    </View>
                ) : roomsState.error ? (
                    <View style={styles.empty}>
                        <UnText size={13} color={theme.colors.error} style={styles.emptyText}>
                            {roomsState.error}
                        </UnText>
                        <Button type="clear" title="重试" onPress={roomsState.reload} />
                    </View>
                ) : floors.length > 0 ? (
                    floors.map(floorGroup => (
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
                    ))
                ) : (
                    <UnText size={14} color={theme.colors.grey2} style={styles.emptyText}>
                        该楼栋没有教室数据
                    </UnText>
                )}
            </>
        );
    } else if (currentBuilding && currentFloor) {
        listContent = (
            <>
                <UnPressable style={styles.backRow} onPress={backToFloors}>
                    <Flex inline align="center" gap={4}>
                        <Icon name="chevron-left" size={18} color={theme.colors.primary} />
                        <UnText size={13} color={theme.colors.primary}>
                            {`${currentBuilding.title} · ${currentFloor.title}`}
                        </UnText>
                    </Flex>
                </UnPressable>
                {currentFloor.rooms.map(room => renderRoomRow(room, roomSubtitle(room)))}
            </>
        );
    }

    const initialLoading = !searching && buildingState.loading && buildings.length === 0;
    const initialError = !searching && !!buildingState.error && buildings.length === 0;
    const noBuildings = !searching && !buildingState.loading && !buildingState.error && buildings.length === 0;
    const noSearchResults = searching && !searchState.loading && !searchState.error && !listContent;

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
                    placeholder={activeLevel === "building" ? "搜索楼栋或教室" : "搜索本楼栋教室或场地类别"}
                    placeholderTextColor={theme.colors.grey3}
                    style={styles.search}
                    autoCorrect={false}
                    returnKeyType="search"
                />
            </View>
            {initialLoading || noBuildings || initialError || noSearchResults ? (
                <View style={styles.empty}>
                    {initialLoading ? (
                        <>
                            <ActivityIndicator color={theme.colors.primary} />
                            <UnText size={13} color={theme.colors.grey2}>
                                正在读取楼栋...
                            </UnText>
                        </>
                    ) : initialError ? (
                        <>
                            <UnText size={13} color={theme.colors.error} style={styles.emptyText}>
                                {buildingState.error}
                            </UnText>
                            <Button type="clear" title="重试" onPress={buildingState.reload} />
                        </>
                    ) : noBuildings ? (
                        <>
                            <UnText size={14} style={styles.emptyText}>
                                尚未缓存教室数据，请先在缓存管理中缓存至少一天
                            </UnText>
                            {onOpenCacheManager && (
                                <Button type="clear" title="去缓存管理" onPress={onOpenCacheManager} />
                            )}
                        </>
                    ) : (
                        <UnText size={14} color={theme.colors.grey2} style={styles.emptyText}>
                            {searching ? "没有匹配的教室或场地类别" : "没有匹配的楼栋"}
                        </UnText>
                    )}
                </View>
            ) : (
                <ScrollView ref={listRef} style={styles.list} keyboardShouldPersistTaps="handled" nestedScrollEnabled>
                    {listContent}
                </ScrollView>
            )}
            {multiple && (
                <View style={styles.footer}>
                    <UnText size={12} color={theme.colors.grey2} style={styles.selectedSummary}>
                        {draftRoomIds.size === 0 ? "未选择教室时查询全部教室" : `已选择 ${draftRoomIds.size} 间教室`}
                    </UnText>
                    <View style={styles.footerActions}>
                        <Button
                            type="clear"
                            title="清除选择"
                            disabled={draftRoomIds.size === 0}
                            onPress={() => setDraftRoomIds(new Set())}
                            containerStyle={styles.footerAction}
                        />
                        <Button
                            title="确认教室筛选"
                            onPress={() => {
                                onConfirmMultiple?.([...draftRoomIds]);
                                onClose();
                            }}
                            containerStyle={styles.footerAction}
                        />
                    </View>
                </View>
            )}
        </UnBottomSheet>
    );
}
