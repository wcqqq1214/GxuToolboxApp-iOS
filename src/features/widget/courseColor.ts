const PRESET_COLORS: `#${string}`[] = [
    "#007AFF",
    "#34C759",
    "#FF9500",
    "#AF52DE",
    "#5856D6",
    "#FF3B30",
    "#FF2D55",
    "#00C7BE",
];

function getHashCode(value: string): number {
    let hash = 0;
    for (let index = 0; index < value.length; index++) {
        hash = (hash * 31 + value.charCodeAt(index)) % 2147483647;
    }
    return hash;
}

export function getColorForCourse(courseName: string): `#${string}` {
    const index = getHashCode(courseName) % PRESET_COLORS.length;
    return PRESET_COLORS[index];
}
