import React, {useState} from "react";
import {ActivityIndicator, Alert, ScrollView, View, useWindowDimensions} from "react-native";
import {Input, useTheme} from "@rneui/themed";
import {Picker} from "@react-native-picker/picker";
import {Icon, UnPressable, UnText} from "@/components/un-ui";
import Flex from "@/components/un-ui/Flex";
import {Color} from "@/shared/color";
import type {useCustomEvents} from "../../hooks/useCustomEvents";
import {customEventSchema, type CustomEvent, type CustomEventInput} from "../../type/customEvent";
import {parseTeachingWeeks} from "../../utils/customEvents";

interface Props {
    query: ReturnType<typeof useCustomEvents>;
    year: number;
    term: 1 | 2;
    weekCount: number;
    initialEventId?: number;
}

/** 管理本地实验课；草稿只在确认保存时提交，取消编辑返回列表。 */
export function CustomEventsSheet({query, year, term, weekCount, initialEventId}: Props) {
    const {theme} = useTheme();
    const {height} = useWindowDimensions();
    const [editing, setEditing] = useState<number | "new" | null>(initialEventId ?? null);
    const selected = query.events.find(event => event.id === editing);
    const [message, setMessage] = useState("");

    return (
        <ScrollView
            keyboardShouldPersistTaps="handled"
            style={{maxHeight: height * 0.8}}
            contentContainerStyle={{paddingBottom: 20}}>
            <Flex inline justify="space-between" gap={12} style={{marginBottom: 16}}>
                <UnText size={22} bold>
                    {editing === null ? "我的实验课" : editing === "new" ? "添加实验课" : "编辑实验课"}
                </UnText>
                {editing === null && (
                    <UnPressable
                        accessibilityRole="button"
                        disabled={query.loading || query.saving}
                        onPress={() => {
                            setMessage("");
                            setEditing("new");
                        }}
                        style={{
                            padding: 8,
                            borderRadius: 999,
                            backgroundColor: Color(theme.colors.primary).setAlpha(theme.mode === "light" ? 0.12 : 0.22)
                                .rgbaString,
                        }}>
                        <Icon name="plus" size={20} color={theme.colors.primary} />
                    </UnPressable>
                )}
            </Flex>
            {query.loading && <ActivityIndicator color={theme.colors.primary} />}
            {!!query.error && (
                <UnPressable
                    onPress={() => {
                        query.refresh();
                    }}
                    disabled={query.saving}>
                    <UnText color={theme.colors.error} style={{marginBottom: 12}}>
                        {query.error}，点击重试
                    </UnText>
                </UnPressable>
            )}
            {!!message && (
                <UnText color={theme.colors.grey2} style={{marginBottom: 12}}>
                    {message}
                </UnText>
            )}
            {editing !== null &&
                !query.loading &&
                (editing !== "new" && !selected ? (
                    <UnPressable onPress={() => setEditing(null)}>
                        <UnText>该实验课已删除，返回列表</UnText>
                    </UnPressable>
                ) : (
                    <CustomEventForm
                        key={editing}
                        event={selected}
                        year={year}
                        term={term}
                        weekCount={weekCount}
                        saving={query.saving}
                        onCancel={() => setEditing(null)}
                        onSave={async input => {
                            if (await query.save(input, selected?.id)) {
                                setEditing(null);
                                setMessage("实验课已保存");
                            }
                        }}
                    />
                ))}
            {editing === null && !query.loading && query.events.length === 0 && (
                <UnText color={theme.colors.grey2}>还没有实验课，点击右上角添加。</UnText>
            )}
            {editing === null &&
                query.events.map(event => (
                    <View
                        key={event.id}
                        style={{
                            padding: 12,
                            marginBottom: 10,
                            borderRadius: 12,
                            backgroundColor: Color(theme.colors.primary).setAlpha(theme.mode === "light" ? 0.08 : 0.15)
                                .rgbaString,
                        }}>
                        <UnPressable
                            onPress={() => {
                                setMessage("");
                                setEditing(event.id);
                            }}
                            disabled={query.saving}>
                            <UnText size={16} bold>
                                {event.title}
                            </UnText>
                            <UnText size={12} color={theme.colors.grey2} style={{marginTop: 4}}>
                                {event.year} 学年第 {event.term} 学期 · 第 {event.weeks.join(",")} 周 · 周
                                {"一二三四五六日"[event.weekday - 1]} · {event.begin}—{event.end} 节
                            </UnText>
                            {!!event.location && (
                                <UnText size={13} style={{marginTop: 4}}>
                                    {event.location}
                                </UnText>
                            )}
                            {!!event.notes && (
                                <UnText size={13} color={theme.colors.grey2} style={{marginTop: 4}}>
                                    {event.notes}
                                </UnText>
                            )}
                        </UnPressable>
                        <Flex inline justify="space-between" style={{marginTop: 10}}>
                            <UnPressable
                                onPress={() => setEditing(event.id)}
                                disabled={query.saving}
                                style={{padding: 6}}>
                                <UnText color={theme.colors.primary}>编辑</UnText>
                            </UnPressable>
                            <UnPressable
                                disabled={query.saving}
                                style={{padding: 6}}
                                onPress={() =>
                                    Alert.alert("删除实验课", `确定删除“${event.title}”及其所有重复安排？`, [
                                        {text: "取消", style: "cancel"},
                                        {
                                            text: "删除",
                                            style: "destructive",
                                            onPress: () => {
                                                query.remove(event.id);
                                            },
                                        },
                                    ])
                                }>
                                <UnText color={theme.colors.error}>删除</UnText>
                            </UnPressable>
                        </Flex>
                    </View>
                ))}
        </ScrollView>
    );
}

interface FormProps {
    event?: CustomEvent;
    year: number;
    term: 1 | 2;
    weekCount: number;
    saving: boolean;
    onCancel: () => void;
    onSave: (input: CustomEventInput) => Promise<void>;
}

/** 收集实验课草稿，使用教学周、星期和节次确定安排。 */
function CustomEventForm({event, year, term, weekCount, saving, onCancel, onSave}: FormProps) {
    const {theme} = useTheme();
    const [title, setTitle] = useState(event?.title ?? "");
    const [location, setLocation] = useState(event?.location ?? "");
    const [teacher, setTeacher] = useState(event?.teacher ?? "");
    const [notes, setNotes] = useState(event?.notes ?? "");
    const [weeks, setWeeks] = useState(event?.weeks.join(",") ?? "1");
    const [weekday, setWeekday] = useState(event?.weekday ?? 1);
    const [begin, setBegin] = useState(event?.begin ?? 1);
    const [end, setEnd] = useState(event?.end ?? 2);
    const [error, setError] = useState("");
    const eventYear = event?.year ?? year;
    const eventTerm = event?.term ?? term;

    async function submit() {
        setError("");
        try {
            const input = customEventSchema.safeParse({
                title,
                location,
                teacher,
                notes,
                year: eventYear,
                term: eventTerm,
                weeks: parseTeachingWeeks(weeks, eventYear === year && eventTerm === term ? weekCount : 53),
                weekday,
                begin,
                end,
            });
            if (!input.success) {
                setError(input.error.issues[0].message);
                return;
            }
            await onSave(input.data);
        } catch (cause) {
            setError(cause instanceof Error ? cause.message : "请检查实验课信息");
        }
    }

    return (
        <View>
            <Input label="实验课名称" value={title} onChangeText={setTitle} maxLength={100} editable={!saving} />
            <UnText size={13} color={theme.colors.grey2} style={{marginBottom: 12}}>
                {eventYear} 学年第 {eventTerm} 学期
            </UnText>
            <Input
                label="教学周"
                placeholder="例如 1-8,10,12"
                value={weeks}
                onChangeText={setWeeks}
                editable={!saving}
            />
            <UnText size={13} color={theme.colors.grey2}>
                星期
            </UnText>
            <Picker
                enabled={!saving}
                selectedValue={weekday}
                onValueChange={setWeekday}
                style={{color: theme.colors.black}}>
                {Array.from("一二三四五六日").map((day, index) => (
                    <Picker.Item key={day} value={index + 1} label={`星期${day}`} />
                ))}
            </Picker>
            <UnText size={13} color={theme.colors.grey2}>
                开始节次
            </UnText>
            <Picker
                enabled={!saving}
                selectedValue={begin}
                onValueChange={value => {
                    setBegin(value);
                    setEnd(previous => Math.max(previous, value));
                }}
                style={{color: theme.colors.black}}>
                {Array.from({length: 13}, (_, index) => (
                    <Picker.Item key={index} value={index + 1} label={`第 ${index + 1} 节`} />
                ))}
            </Picker>
            <UnText size={13} color={theme.colors.grey2}>
                结束节次
            </UnText>
            <Picker enabled={!saving} selectedValue={end} onValueChange={setEnd} style={{color: theme.colors.black}}>
                {Array.from({length: 14 - begin}, (_, index) => (
                    <Picker.Item key={index} value={begin + index} label={`第 ${begin + index} 节`} />
                ))}
            </Picker>
            {!!event && (
                <UnText size={12} color={theme.colors.grey2} style={{marginBottom: 12}}>
                    修改会应用到此实验课的所有教学周。
                </UnText>
            )}
            <Input label="地点（选填）" value={location} onChangeText={setLocation} editable={!saving} />
            <Input label="教师（选填）" value={teacher} onChangeText={setTeacher} editable={!saving} />
            <Input label="备注（选填）" multiline value={notes} onChangeText={setNotes} editable={!saving} />
            {!!error && (
                <UnText color={theme.colors.error} style={{marginBottom: 12}}>
                    {error}
                </UnText>
            )}
            <Flex inline gap={12}>
                <UnPressable disabled={saving} onPress={onCancel} style={{padding: 12}}>
                    <UnText color={theme.colors.grey2}>取消</UnText>
                </UnPressable>
                <UnPressable
                    accessibilityRole="button"
                    disabled={saving}
                    onPress={() => {
                        submit();
                    }}
                    style={{
                        paddingHorizontal: 20,
                        paddingVertical: 12,
                        borderRadius: 999,
                        backgroundColor: Color(theme.colors.primary).setAlpha(theme.mode === "light" ? 0.12 : 0.22)
                            .rgbaString,
                    }}>
                    <UnText bold color={theme.colors.primary}>
                        {saving ? "正在保存…" : "保存实验课"}
                    </UnText>
                </UnPressable>
            </Flex>
        </View>
    );
}
