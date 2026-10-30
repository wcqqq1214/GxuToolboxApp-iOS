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
import {Color} from "@/shared/color";
import {useRoomBuildings} from "../hooks/useRoomList";
import {useTimeClassroomQuery} from "../hooks/useTimeClassroomQuery";
import type {LogicalTerm, RoomAvailabilityResult} from "../type";
import {groupRoomBuildings} from "../utils/floor";
import {
    buildCachedDateOptions,
    groupRoomAvailabilityResultsByFreePeriodCount,
    groupRoomAvailabilityResults,
    type RoomAvailabilitySection,
} from "../utils/timeQuery";
import {PeriodRangeSelector} from "./PeriodRangeSelector";
import {getRoomAvailabilityStateColors, RoomAvailabilityRow} from "./RoomAvailabilityRow";
import {RoomPickerSheet} from "./RoomPickerSheet";

export type TimeClassroomQueryViewProps = {
    year: number;
    term: LogicalTerm;
    preferredWeek: number;
    onOpenCacheManager: () => void;
};

/**
 * 作用：按已缓存日期和节次范围查询全校空闲教室，并以时间条列表展示。
 * 修改注意：筛选区作为列表头；默认排序按楼栋分组，空闲时间排序按空闲节数分组。
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
    const sections = useMemo(
        () =>
            query.sortMode === "default"
                ? groupRoomAvailabilityResults(query.results)
                : groupRoomAvailabilityResultsByFreePeriodCount(query.results),
        [query.results, query.sortMode],
    );
    const buildingHeaderBackground = Color.mix(theme.colors.white, theme.colors.primary, 0.15).rgbaString;
    const controlBackground = Color.mix(
        theme.colors.grey5,
        theme.colors.primary,
        theme.mode === "light" ? 0.15 : 0.2,
    ).setAlpha(theme.mode === "light" ? 0.7 : 0.55).rgbaString;
    const selectedControlBackground = Color.mix(theme.colors.primary, theme.colors.grey5, 0.05).setAlpha(
        theme.mode === "light" ? 0.85 : 0.8,
    ).rgbaString;
    const errorBackground = Color(theme.colors.error).setAlpha(theme.mode === "light" ? 0.1 : 0.15).rgbaString;
    const {freeBackground, occupiedBackground, unknownBackground} = getRoomAvailabilityStateColors(
        theme.mode,
        theme.colors,
    );

    const renderResult = useCallback(
        ({item, index, section}: SectionListRenderItemInfo<RoomAvailabilityResult, RoomAvailabilitySection>) => (
            <RoomAvailabilityRow
                result={item}
                startPeriod={query.startPeriod}
                endPeriod={query.endPeriod}
                firstInSection={index === 0}
                lastInSection={index === section.data.length - 1}
            />
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
                            <View style={[styles.loadingField, {backgroundColor: controlBackground}]}>
                                {query.loading ? <ActivityIndicator size="small" color={theme.colors.primary} /> : null}
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
                            title="选择楼栋"
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
                        </View>
                        <UnPressable
                            onPress={() => setRoomSheetVisible(true)}
                            style={[styles.selectorField, {backgroundColor: controlBackground}]}>
                            <Icon name="door" size={18} color={theme.colors.grey2} />
                            <View style={styles.selectorText}>
                                <UnText size={14} numberOfLines={1}>
                                    {query.roomIds.length === 0 ? "全部教室" : `已选 ${query.roomIds.length} 间教室`}
                                </UnText>
                                <UnText size={11} color={theme.colors.grey2} numberOfLines={1}>
                                    {query.roomIds.length === 0
                                        ? "教室名称、场地类别与座位数"
                                        : "已按所选教室筛选，可继续调整"}
                                </UnText>
                            </View>
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
                                backgroundColor: controlBackground,
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
                        <View style={[styles.sortControl, {backgroundColor: controlBackground}]}>
                            <UnPressable
                                onPress={() => query.setSortMode("default")}
                                style={[
                                    styles.sortMode,
                                    query.sortMode === "default" && {
                                        backgroundColor: selectedControlBackground,
                                    },
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
                                    query.sortMode === "free" && {
                                        backgroundColor: selectedControlBackground,
                                    },
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
                        <View style={styles.legendItem}>
                            <View style={[styles.legendDot, {backgroundColor: freeBackground}]} />
                            <UnText size={11} color={theme.colors.grey2}>
                                空闲
                            </UnText>
                        </View>
                        <View style={styles.legendItem}>
                            <View style={[styles.legendDot, {backgroundColor: occupiedBackground}]} />
                            <UnText size={11} color={theme.colors.grey2}>
                                占用
                            </UnText>
                        </View>
                        <View style={styles.legendItem}>
                            <View style={[styles.legendDot, {backgroundColor: unknownBackground}]} />
                            <UnText size={11} color={theme.colors.grey2}>
                                未知
                            </UnText>
                        </View>
                    </View>

                    {!!query.error && (
                        <View style={[styles.errorCard, {backgroundColor: errorBackground}]}>
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
                                {`共 ${query.totalCount} 间教室`}
                            </UnText>
                        </View>
                    )}
                </>
            )}
        </View>
    );

    const listEmptyComponent =
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
        ) : null;
    const listFooterComponent = query.loadingMore ? (
        <View style={styles.loadMoreFooter}>
            <ActivityIndicator size="small" color={theme.colors.primary} />
            <UnText size={11} color={theme.colors.grey2}>
                正在查询...
            </UnText>
        </View>
    ) : null;

    return (
        <>
            <SectionList
                sections={sections}
                renderItem={renderResult}
                renderSectionHeader={({section}) => (
                    <View style={[styles.buildingHeader, {backgroundColor: buildingHeaderBackground}]}>
                        <UnText size={13} bold color={theme.colors.black}>
                            {section.title}
                        </UnText>
                        <UnText size={11} color={theme.colors.grey2}>
                            {`${section.data.length} 间教室`}
                        </UnText>
                    </View>
                )}
                renderSectionFooter={() => <View style={styles.sectionFooter} />}
                keyExtractor={item => String(item.room.id)}
                ListHeaderComponent={listHeader}
                ListEmptyComponent={listEmptyComponent}
                ListFooterComponent={listFooterComponent}
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
        borderRadius: 8,
        paddingHorizontal: 12,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "flex-start",
        gap: 8,
    },
    selectorField: {
        minHeight: 46,
        borderRadius: 8,
        paddingHorizontal: 12,
        flexDirection: "row",
        alignItems: "center",
        gap: 8,
    },
    selectorText: {
        flex: 1,
        gap: 1,
    },
    search: {
        height: 42,
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
        flexWrap: "wrap",
        gap: 12,
    },
    legendItem: {
        flexDirection: "row",
        alignItems: "center",
        gap: 5,
    },
    legendDot: {
        width: 11,
        height: 11,
        borderRadius: 3,
    },
    errorCard: {
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
        paddingHorizontal: 10,
        borderRadius: 8,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 8,
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
