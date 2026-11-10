/** 按网格时间将连通的重叠块分配到不同列；节次端点包含在占用范围内。 */
export function layoutScheduleBlocks<T extends {begin: number; end: number}>(items: readonly T[]) {
    const groups: T[][] = [];
    for (const item of [...items].sort((a, b) => a.begin - b.begin || a.end - b.end)) {
        const previous = groups[groups.length - 1];
        if (previous && previous.some(block => block.end >= item.begin)) previous.push(item);
        else groups.push([item]);
    }
    return groups.flatMap(group => {
        const ends: number[] = [];
        const positions = group.map(item => {
            let column = ends.findIndex(end => end < item.begin);
            if (column < 0) column = ends.length;
            ends[column] = item.end;
            return {item, column};
        });
        return positions.map(position => ({...position, columnCount: ends.length}));
    });
}
