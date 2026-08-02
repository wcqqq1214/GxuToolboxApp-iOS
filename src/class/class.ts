import {z} from "zod";

/** 基础类，原始数据存储在 `_ori` 属性中 */
export class BaseClass<T> {
    /** 原始数据 */
    readonly _ori: T;

    constructor(ori: T) {
        this._ori = ori;
    }
}

/**
 * Zod 解析后的基础类。
 *
 * 解析后的数据存储在 `transformed` 属性中。
 *
 * @typeParam S — Zod schema 类型
 * @typeParam O — 原始数据类型，存储在 `_ori` 属性中
 *
 * @example
 * ```ts
 * const CourseZod = z.object({ kcmc: z.string(), kch: z.string() });
 *
 * class CourseClass extends BaseZodClass<typeof CourseZod, RawCourse> {}
 * const c = new CourseClass(CourseZod, rawData);
 * c.transformed.kcmc; // ✅ 解析后的数据，来自 z.infer<typeof CourseZod>
 * c._ori;             // ✅ RawCourse，来自 O
 * ```
 */
export class BaseZodClass<S extends z.ZodType<any>, O> extends BaseClass<O> {
    readonly transformed: z.infer<S>;

    constructor(schema: S, ori: O) {
        super(ori);
        this.transformed = schema.parse(ori);
    }
}
