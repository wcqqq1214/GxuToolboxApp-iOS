import {createMMKV} from "react-native-mmkv";

export const mmkvStorage = createMMKV();

export const mmkv = {
  getString(key: string): string | undefined {
    return mmkvStorage.getString(key);
  },

  getNumber(key: string): number | undefined {
    return mmkvStorage.getNumber(key);
  },

  getBoolean(key: string): boolean | undefined {
    return mmkvStorage.getBoolean(key);
  },

  getObject<T>(key: string): T | undefined {
    const raw = mmkvStorage.getString(key);
    if (!raw) return undefined;
    try {
      return JSON.parse(raw) as T;
    } catch {
      return undefined;
    }
  },

  set(key: string, value: string | number | boolean | object): void {
    if (typeof value === "string") {
      mmkvStorage.set(key, value);
    } else if (typeof value === "number") {
      mmkvStorage.set(key, value);
    } else if (typeof value === "boolean") {
      mmkvStorage.set(key, value);
    } else {
      mmkvStorage.set(key, JSON.stringify(value));
    }
  },

  remove(key: string): void {
    mmkvStorage.remove(key);
  },

  clearAll(): void {
    mmkvStorage.clearAll();
  },

  getAllKeys(): string[] {
    return mmkvStorage.getAllKeys();
  },
};