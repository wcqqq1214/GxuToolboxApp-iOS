/** 首选页大小；后端升级后可一次取回一个节次的全部教室。 */
export const PAGE_SIZE = 10_000;

/** 单次节次查询最多翻页数，兼容后端仍按较小分页返回的情况。 */
export const MAX_PAGES = 10;

/** 一周 7 天。 */
export const DAYS = 7;

/** 一天 13 个节次。 */
export const PERIODS = 13;

/** 周 pager / 缓存页固定展示 1–20 周。 */
export const MAX_WEEKS = 20;

/** 两次缓存「开始」之间的最小间隔。 */
export const COOLDOWN_MS = 60_000;

/** 教室维表批量 upsert 的行数（7 列 × 100，避开旧 SQLite 999 参数上限）。 */
export const ROOM_BATCH_SIZE = 100;

/** 空闲节次批量插入的行数（6 列 × 100）。 */
export const SLOT_BATCH_SIZE = 100;

/** 第一屏/缓存页共用的选择状态。 */
export const MMKV_SELECTION_KEY = "emptyClassroomSelection";

/** 最近一次缓存开始时间（跨重启保留冷却）。 */
export const MMKV_LAST_CACHE_STARTED_AT_KEY = "emptyClassroom:lastCacheStartedAt";

/**
 * 是否按补课/调休做日期重映射。
 * 空闲教室按教学周原始数据展示，暂不做补课日重映射；上线前需人工核对。
 */
export const EMPTY_CLASSROOM_NEED_SHIFT = false;

/** 每条空闲节次记录的估算字节数。 */
export const SLOT_ROW_BYTES = 38;

/** 每间教室元数据的估算字节数。 */
export const ROOM_ROW_BYTES = 130;
