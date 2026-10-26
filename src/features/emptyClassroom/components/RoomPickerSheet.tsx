import {useEffect, useMemo, useState} from "react";
import {ActivityIndicator, SectionList, StyleSheet, TextInput, View} from "react-native";
import {Button, useTheme} from "@rneui/themed";
import {Flex, Icon, UnBottomSheet, UnPressable, UnText, vh} from "@/components/un-ui";
import {useRoomList} from "../hooks/useRoomList";
import type {LogicalTerm, RoomRecord} from "../type";

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

type RoomSection = {
    title: string;
    data: RoomRecord[];
};

function roomSubtitle(room: RoomRecord): string {
    return [room.placeType, room.seatCount !== null ? `${room.seatCount} 座` : ""].filter(Boolean).join(" · ");
}

/**
 * 作用：按楼栋分组的教室选择底部弹层，支持按教室名/楼栋/场地类别搜索。
 * 修改注意：
 * - 数据只在 visible=true 时通过 useRoomList 懒加载；
 * - 行必须用 room.id 作为 key（楼层+名称不是稳定主键）；
 * - SectionList 与外层 BottomSheet ScrollView 都需要 keyboardShouldPersistTaps="handled"，
 *   否则键盘打开时第一次点击会被吞。
 */
export function RoomPickerSheet(props: RoomPickerSheetProps) {
    const {visible, year, term, selectedRoomId, onSelect, onClose, onOpenCacheManager} = props;
    const {theme} = useTheme();
    const {rooms, loading, error, reload} = useRoomList({year, term, enabled: visible});
    const [keyword, setKeyword] = useState("");

    useEffect(() => {
        if (!visible) setKeyword("");
    }, [visible]);

    const sections = useMemo<RoomSection[]>(() => {
        const query = keyword.trim().toLowerCase();
        const filtered = query
            ? rooms.filter(room =>
                  [room.name, room.building, room.placeType].some(value => value.toLowerCase().includes(query)),
              )
            : rooms;

        const grouped = new Map<string, RoomRecord[]>();
        for (const room of filtered) {
            const list = grouped.get(room.building);
            if (list) list.push(room);
            else grouped.set(room.building, [room]);
        }
        return [...grouped.entries()].map(([title, data]) => ({title, data}));
    }, [rooms, keyword]);

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
        sectionHeader: {
            paddingHorizontal: 16,
            paddingVertical: 6,
            backgroundColor: theme.colors.grey5,
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
                    placeholder="搜索教室名或楼栋"
                    placeholderTextColor={theme.colors.grey3}
                    style={styles.search}
                    autoCorrect={false}
                    returnKeyType="search"
                />
            </View>
            <SectionList
                style={styles.list}
                sections={sections}
                keyExtractor={item => String(item.id)}
                keyboardShouldPersistTaps="handled"
                stickySectionHeadersEnabled
                initialNumToRender={24}
                renderSectionHeader={({section}) => (
                    <View style={styles.sectionHeader}>
                        <UnText size={13} bold color={theme.colors.grey2}>
                            {section.title}
                        </UnText>
                    </View>
                )}
                renderItem={({item}) => {
                    const selected = item.id === selectedRoomId;
                    return (
                        <UnPressable
                            style={[styles.row, selected && styles.rowSelected]}
                            onPress={() => {
                                onSelect(item);
                                onClose();
                            }}>
                            <Flex justify="space-between" gap={8}>
                                <Flex direction="column" align="flex-start" flex={1} gap={2}>
                                    <UnText size={15} bold={selected}>
                                        {item.name}
                                    </UnText>
                                    {!!roomSubtitle(item) && (
                                        <UnText size={11} color={theme.colors.grey2}>
                                            {roomSubtitle(item)}
                                        </UnText>
                                    )}
                                </Flex>
                                {selected && <Icon name="check" size={18} color={theme.colors.primary} />}
                            </Flex>
                        </UnPressable>
                    );
                }}
                ListEmptyComponent={
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
                }
            />
        </UnBottomSheet>
    );
}
