import type {CustomEvent, CustomEventOccurrence} from "../type/customEvent";

/** 解析教学周输入，支持 1-8,10,12；拒绝空项、倒序范围和超出学期的周次。 */
export function parseTeachingWeeks(text: string, weekCount: number): number[] {
    const weeks = new Set<number>();
    for (const token of text.replace(/，/g, ",").split(",")) {
        const match = token.trim().match(/^(\d+)(?:\s*-\s*(\d+))?$/);
        if (!match) throw new Error("教学周格式示例：1-8,10,12");
        const from = Number(match[1]);
        const to = Number(match[2] ?? match[1]);
        if (from < 1 || to < from || to > weekCount) throw new Error(`教学周须在 1—${weekCount} 之间`);
        for (let week = from; week <= to; week++) weeks.add(week);
    }
    return [...weeks].sort((a, b) => a - b);
}

/** 将当前学期的实验课按教学周展开，直接使用所选节次生成课表项。 */
export function expandCustomEvents(
    events: readonly CustomEvent[],
    year: number,
    term: number,
    weekCount: number,
): CustomEventOccurrence[] {
    return events
        .filter(event => event.year === year && event.term === term)
        .flatMap(event =>
            event.weeks
                .filter(week => week <= weekCount)
                .map(week => ({
                    id: `custom:${event.id}:${week}`,
                    eventId: event.id,
                    week,
                    day: event.weekday as CustomEventOccurrence["day"],
                    begin: event.begin as CustomEventOccurrence["begin"],
                    end: event.end as CustomEventOccurrence["end"],
                    title: event.title,
                    subtitle: "实验课",
                    location: event.location,
                    teacher: event.teacher,
                    kind: "custom" as const,
                })),
        );
}
