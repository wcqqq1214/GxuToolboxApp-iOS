type IsUnion<T, U = T> = T extends any ? ([U] extends [T] ? false : true) : never;

/**
 * 根据对象字段值分发到不同处理函数，类似类型安全的switch。
 * 当 T 为联合类型时，handler 中 obj 自动窄化到对应分支；非联合类型时保持 T。
 *
 * @example
 * type Event = {type: 'click'; x: number} | {type: 'keydown'; key: string};
 * const e: Event = {type: 'click', x: 10};
 * const result = switchByField(e, 'type', {
 *   click: (ev) => ev.x,      // ev 窄化为 {type: 'click'; x: number}
 *   keydown: (ev) => ev.key,  // ev 窄化为 {type: 'keydown'; key: string}
 * });
 */
export function switchByField<
    T,
    K extends keyof T,
    V extends T[K] & (string | number | symbol),
    R = never,
>(
    obj: T | null | undefined,
    key: K,
    handlers: {[Key in V]: (
        obj: IsUnion<T> extends true ? Extract<T, Partial<Record<K, Key>>> : T,
        keyValue: Key,
    ) => any},
    onNullish?: () => R,
): ReturnType<(typeof handlers)[V]> | R {
    if (obj == null) {
        if (onNullish) return onNullish();
        throw new Error(`switchByField: obj is ${String(obj)}`);
    }
    const keyValue = obj[key] as unknown as V;
    const handler = handlers[keyValue];
    if (!handler) {
        throw new Error(`switchByField: no handler for ${String(key)}=${String(keyValue)}`);
    }
    return handler(obj as any, keyValue);
}

/**
 * 检查一个项目是否是可合并的对象
 * @param item 要检查的项目
 * @returns {boolean} 如果项目是对象则返回 true，否则返回 false
 */
function isObject(item: any): item is Record<string, any> {
    return item && typeof item === "object" && !Array.isArray(item);
}

/**
 * 深层次合并两个对象。
 * @param target 目标对象
 * @param source 源对象
 * @returns {object} 合并后的新对象
 */
export function deepMerge<T extends object, U extends object>(target: T, source: U): T & U {
    const output = {...target} as T & U;

    if (isObject(target) && isObject(source)) {
        Object.keys(source).forEach(key => {
            const targetValue = (target as any)[key];
            const sourceValue = (source as any)[key];

            if (isObject(targetValue) && isObject(sourceValue)) {
                (output as any)[key] = deepMerge(targetValue, sourceValue);
            } else {
                (output as any)[key] = sourceValue;
            }
        });
    }

    return output;
}
