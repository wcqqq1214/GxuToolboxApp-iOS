import {useCallback, useMemo, useState} from "react";
import {
    ActivityIndicator,
    SectionList,
    StyleSheet,
    TextInput,
    View,
    type SectionListRenderItemInfo,
} from "react-native";
import {Button, useTheme} from "@rneui/themed";
import moment from "moment";
import {Icon, UnMultiSelect, UnPressable, UnText} from "@/components/un-ui";
import {UnDateTimePicker} from "@/components/un-ui/UnDateTimePicker";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay";
import {useRoomBuildings} from "../hooks/useRoomList";
import {useTimeClassroomQuery} from "../hooks/useTimeClassroomQuery";
import type {LogicalTerm, RoomAvailabilityResult, TimeQuerySortMode} from "../type";
import {groupRoomBuildings} from "../utils/floor";
import {
    buildCachedDateOptions,
    groupRoomAvailabilityResults,
    type RoomAvailabilitySection,
} from "../utils/timeQuery";
import {PeriodRangeSelector} from "./PeriodRangeSelector";
import {RoomAvailabilityRow} from "./RoomAvailabilityRow";
import {RoomPickerSheet} from "./RoomPickerSheet";

export type TimeClassroomQueryViewProps = {
    year: number;
    term: LogicalTerm;
    preferredWeek: number;
    onOpenCacheManager: () => void;
};

function sortModeLabel(mode: TimeQuerySortMode): string {
    return mode === "default" ? "默认排序" : "空闲时间";
}

/**
 * 作用：按已缓存日期和节次范围查询全校空闲教室，并以时间条列表展示。
 * 修改注意：筛选区作为 SectionList 的 ListHeaderComponent，结果按楼栋分组并黏滞标题，避免嵌套纵向滚动。
 */
export function TimeClassroomQueryView(props: TimeClassroomQueryViewProps) {
    const {year, term, preferredWeek, onOpenCacheManager} = props;
    const {theme} = useTheme();
    const {startDay, ready} = useStartDay(year, term);
    const query = useTimeClassroomQuery({year, term, preferredWeek, enabled: year > 0 && ready});
    const buildingsState = useRoomBuildings({enabled: year > 0 && ready});
    const [roomSheetVisible, setRoomSheetVisible] = useState(false);

    const buildings = useMemo(() => groupRoomBuildings(buildingsState.buildings), [buildingsState.buildings]);
    const dates = useMemo(
        () =>
            !ready || query.selectedWeek === null
                ? []
                : buildCachedDateOptions(startDay, query.selectedWeek, query.completedDays),
        [query.completedDays, query.selectedWeek, ready, startDay],
    );
    const buildingOptions = useMemo(
        () =>
            buildings.map(group => ({
                value: group.building,
                label: group.title,
                description: `${group.roomCount} 间教室`,
            })),
        [buildings],
    );
    const selectedDate = dates.find(date => date.day === query.selectedDay && date.cached);
    const cachedDates = dates.filter(date => date.cached);
    const noCachedWeeks = ready && !query.loading && query.snapshots.length === 0;
    const sections = useMemo(() => groupRoomAvailabilityResults(query.results), [query.results]);

    const renderResult = useCallback(
        ({item}: SectionListRenderItemInfo<RoomAvailabilityResult, RoomAvailabilitySection>) => (
            <RoomAvailabilityRow result={item} startPeriod={query.startPeriod} endPeriod={query.endPeriod} />
        ),
        [query.endPeriod, query.startPeriod],
    );

    const listHeader = (
        <View style={styles.headerContent}>
            {!ready || (query.loading && query.snapshots.length === 0) ? (
                <View style={styles.statusCard}>
                    <ActivityIndicator color={theme.colors.primary} />
                    <UnText size={13} color={theme.colors.grey2}>
                        正在读取缓存周...
                    </UnText>
                </View>
            ) : noCachedWeeks ? (
                <View style={[styles.statusCard, {backgroundColor: theme.colors.grey5}]}>
                    <UnText size={15} bold>
                        本学期还没有缓存数据
                    </UnText>
                    <UnText size={12} color={theme.colors.grey2} align="center">
                        缓存至少一天后，才能按日期和节次查询空闲教室
                    </UnText>
                    <Button type="clear" title="去缓存管理" onPress={onOpenCacheManager} />
                </View>
            ) : (
                <>
                    <View style={styles.filterSection}>
                        <View style={styles.filterTitleRow}>
                            <UnText size={13} bold>
                                日期
                            </UnText>
                            <UnText size={11} color={theme.colors.grey2}>
                                仅可选择已缓存日期
                            </UnText>
                        </View>
                        {selectedDate ? (
                            <UnDateTimePicker
                                value={moment(selectedDate.dateKey).valueOf()}
                                mode="single"
                                onlyDate
                                minDate={cachedDates[0]?.dateKey}
                                maxDate={cachedDates[cachedDates.length - 1]?.dateKey}
                                enabledDates={cachedDates.map(date => date.dateKey)}
                                onChange={value => query.setDay(moment(value).isoWeekday())}
                            />
                        ) : (
                            <View style={[styles.loadingField, {backgroundColor: theme.colors.grey5}]}>
                                {query.loading ? (
                                    <ActivityIndicator size="small" color={theme.colors.primary} />
                                ) : null}
                                <UnText size={13} color={theme.colors.grey2}>
                                    {query.loading ? "正在读取缓存日期..." : "该周没有已缓存日期"}
                                </UnText>
                            </View>
                        )}
                    </View>

                    <View style={styles.filterSection}>
                        <View style={styles.filterTitleRow}>
                            <UnText size={13} bold>
                                楼栋
                            </UnText>
                            {buildingsState.loading && <ActivityIndicator size="small" color={theme.colors.primary} />}
                        </View>
                        <UnMultiSelect
                            options={buildingOptions}
                            selectedValues={query.buildingFilters}
                            onChange={query.setBuildings}
                            emptyLabel="全部楼栋"
                            title="选择楼栋（可多选）"
                            disabled={!ready || buildingsState.loading}
                        />
                        {!!buildingsState.error && (
                            <UnText size={11} color={theme.colors.error}>
                                {buildingsState.error}
                            </UnText>
                        )}
                    </View>

                    <View style={styles.filterSection}>
                        <View style={styles.filterTitleRow}>
                            <UnText size={13} bold>
                                教室
                            </UnText>
                            <UnText size={11} color={theme.colors.grey2}>
                                不选择时查询全部教室
                            </UnText>
                        </View>
                        <UnPressable
                            onPress={() => setRoomSheetVisible(true)}
                            style={[
                                styles.selectorField,
                                {borderColor: theme.colors.grey4, backgroundColor: theme.colors.grey5},
                            ]}>
                            <Icon name="door" size={18} color={theme.colors.grey2} />
                            <UnText size={14} numberOfLines={1} style={styles.selectorText}>
                                {query.roomIds.length === 0 ? "全部教室" : `已选 ${query.roomIds.length} 间教室`}
                            </UnText>
                            <Icon name="chevron-right" size={18} color={theme.colors.grey2} />
                        </UnPressable>
                    </View>

                    <TextInput
                        value={query.keyword}
                        onChangeText={query.setKeyword}
                        placeholder="搜索教室名称或场地类别"
                        placeholderTextColor={theme.colors.grey3}
                        autoCorrect={false}
                        returnKeyType="search"
                        style={[
                            styles.search,
                            {
                                color: theme.colors.black,
                                backgroundColor: theme.colors.grey5,
                                borderColor: theme.colors.grey4,
                            },
                        ]}
                    />

                    <PeriodRangeSelector
                        startPeriod={query.startPeriod}
                        endPeriod={query.endPeriod}
                        onChangeRange={query.setPeriodRange}
                    />

                    <View style={styles.sortRow}>
                        <UnText size={13} bold>
                            排序
                        </UnText>
                        <View style={[styles.sortControl, {borderColor: theme.colors.grey4}]}>
                            <UnPressable
                                onPress={() => query.setSortMode("default")}
                                style={[
                                    styles.sortMode,
                                    query.sortMode === "default" && {backgroundColor: theme.colors.primary},
                                ]}>
                                <UnText
                                    size={12}
                                    bold={query.sortMode === "default"}
                                    color={query.sortMode === "default" ? theme.colors.white : theme.colors.grey2}>
                                    默认
                                </UnText>
                            </UnPressable>
                            <UnPressable
                                onPress={() => query.setSortMode("free")}
                                style={[
                                    styles.sortMode,
                                    query.sortMode === "free" && {backgroundColor: theme.colors.primary},
                                ]}>
                                <UnText
                                    size={12}
                                    bold={query.sortMode === "free"}
                                    color={query.sortMode === "free" ? theme.colors.white : theme.colors.grey2}>
                                    空闲时间
                                </UnText>
                            </UnPressable>
                            <UnPressable
                                disabled={query.sortMode !== "free"}
                                onPress={query.toggleSortDirection}
                                style={[styles.sortDirection, {opacity: query.sortMode === "free" ? 1 : 0.35}]}
                                accessibilityLabel={`空闲时间${query.sortDirection === "desc" ? "降序" : "升序"}，点击翻转`}>
                                <Icon
                                    name={query.sortDirection === "desc" ? "arrow-down" : "arrow-up"}
                                    size={17}
                                    color={theme.colors.primary}
                                />
                            </UnPressable>
                        </View>
                    </View>

                    <View style={styles.legendRow}>
                        <View style={[styles.legendDot, {backgroundColor: theme.colors.success}]} />
                        <UnText size={11} color={theme.colors.grey2}>
                            绿色=空闲，空白=有课/占用
                        </UnText>
                    </View>

                    {!!query.error && (
                        <View style={[styles.errorCard, {borderColor: theme.colors.error}]}>
                            <UnText size={12} color={theme.colors.error} style={styles.errorText}>
                                {`查询失败：${query.error}`}
                            </UnText>
                            <Button size="sm" type="clear" title="重试" onPress={query.reload} />
                        </View>
                    )}

                    {query.selectedDay === null && !query.loading && !query.error && (
                        <View style={[styles.statusCard, {backgroundColor: theme.colors.grey5}]}>
                            <UnText size={13} color={theme.colors.grey2} align="center">
                                该周没有已缓存日期，请选择其他周或继续缓存
                            </UnText>
                            <Button type="clear" title="去缓存管理" onPress={onOpenCacheManager} />
                        </View>
                    )}

                    {query.selectedDay !== null && (
                        <View style={styles.resultHeading}>
                            <UnText size={13} bold>
                                查询结果
                            </UnText>
                            <UnText size={11} color={theme.colors.grey2}>
                                {`${sortModeLabel(query.sortMode)}${
                                    query.sortMode === "free"
                                        ? query.sortDirection === "desc"
                                            ? " · 空闲多优先"
                                            : " · 空闲少优先"
                                        : ""
                                } · ${query.hasMore ? "已加载 " : ""}${query.results.length} 间`}
                            </UnText>
                        </View>
                    )}
                </>
            )}
        </View>
    );

    return (
        <>
            <SectionList
                sections={sections}
                renderItem={renderResult}
                renderSectionHeader={({section}) => (
                    <View style={[styles.buildingHeader, {backgroundColor: theme.colors.background}]}>
                        <UnText size={13} bold color={theme.colors.primary}>
                            {section.title}
                        </UnText>
                    </View>
                )}
                renderSectionFooter={() => <View style={styles.sectionFooter} />}
                keyExtractor={item => String(item.room.id)}
                ListHeaderComponent={listHeader}
                ListEmptyComponent={
                    query.selectedDay !== null && !query.loading && !query.error ? (
                        <View style={[styles.emptyCard, {backgroundColor: theme.colors.grey5}]}>
                            <Icon name="magnify-close" size={28} color={theme.colors.grey3} />
                            <UnText size={14} bold align="center">
                                没有符合条件的空闲教室
                            </UnText>
                            <UnText size={12} color={theme.colors.grey2} align="center">
                                可以扩大节次范围或清除搜索关键词
                            </UnText>
                        </View>
                    ) : query.loading ? (
                        <View style={styles.loadingFooter}>
                            <ActivityIndicator color={theme.colors.primary} />
                            <UnText size={12} color={theme.colors.grey2}>
                                正在查询...
                            </UnText>
                        </View>
                    ) : null
                }
                ListFooterComponent={
                    query.selectedDay !== null && !query.loading && query.results.length > 0 ? (
                        <View style={styles.loadMoreFooter}>
                            {query.loadingMore && <ActivityIndicator size="small" color={theme.colors.primary} />}
                            <UnText size={11} color={theme.colors.grey2}>
                                {query.loadingMore
                                    ? "正在加载下一页..."
                                    : query.hasMore
                                      ? `已加载 ${query.results.length} 间，继续上滑加载`
                                      : `已加载全部 ${query.results.length} 间`}
                            </UnText>
                        </View>
                    ) : null
                }
                stickySectionHeadersEnabled
                onEndReached={query.loadMore}
                onEndReachedThreshold={0.4}
                contentContainerStyle={styles.listContent}
                keyboardShouldPersistTaps="handled"
                showsVerticalScrollIndicator={false}
            />

            <RoomPickerSheet
                visible={roomSheetVisible}
                onClose={() => setRoomSheetVisible(false)}
                selectedRoomId={null}
                multiple
                selectedRoomIds={query.roomIds}
                onConfirmMultiple={query.setRoomIds}
                onOpenCacheManager={onOpenCacheManager}
            />
        </>
    );
}

const styles = StyleSheet.create({
    listContent: {
        paddingHorizontal: 16,
        paddingTop: 4,
        paddingBottom: 28,
    },
    headerContent: {
        gap: 12,
        paddingBottom: 10,
    },
    filterSection: {
        gap: 6,
    },
    filterTitleRow: {
        minHeight: 20,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 8,
    },
    loadingField: {
        height: 40,
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 12,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "flex-start",
        gap: 8,
    },
    selectorField: {
        height: 40,
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 12,
        flexDirection: "row",
        alignItems: "center",
        gap: 8,
    },
    selectorText: {
        flex: 1,
    },
    search: {
        height: 42,
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 12,
        fontSize: 14,
    },
    sortRow: {
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 8,
    },
    sortControl: {
        height: 40,
        borderWidth: 1,
        borderRadius: 8,
        flexDirection: "row",
        alignItems: "stretch",
        overflow: "hidden",
    },
    sortMode: {
        minWidth: 52,
        paddingHorizontal: 7,
        alignItems: "center",
        justifyContent: "center",
    },
    sortDirection: {
        width: 30,
        alignItems: "center",
        justifyContent: "center",
    },
    legendRow: {
        flexDirection: "row",
        alignItems: "center",
        gap: 6,
    },
    legendDot: {
        width: 11,
        height: 11,
        borderRadius: 3,
        opacity: 0.7,
    },
    errorCard: {
        borderWidth: 1,
        borderRadius: 8,
        paddingLeft: 10,
        flexDirection: "row",
        alignItems: "center",
    },
    errorText: {
        flex: 1,
        lineHeight: 17,
    },
    statusCard: {
        minHeight: 104,
        borderRadius: 10,
        padding: 14,
        alignItems: "center",
        justifyContent: "center",
        gap: 8,
    },
    resultHeading: {
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 8,
        marginTop: 2,
    },
    buildingHeader: {
        paddingTop: 8,
        paddingBottom: 5,
        paddingHorizontal: 2,
    },
    sectionFooter: {
        height: 8,
    },
    emptyCard: {
        minHeight: 140,
        borderRadius: 10,
        padding: 16,
        alignItems: "center",
        justifyContent: "center",
        gap: 6,
    },
    loadingFooter: {
        minHeight: 84,
        alignItems: "center",
        justifyContent: "center",
        gap: 7,
    },
    loadMoreFooter: {
        minHeight: 42,
        alignItems: "center",
        justifyContent: "center",
    },
});
