import React from "react";
import TestRenderer, {act} from "react-test-renderer";
import {useCustomEvents} from "../useCustomEvents";
import {customEventRepo} from "../../repo/customEventRepo";
import type {CustomEvent, CustomEventInput} from "../../type/customEvent";

jest.mock("../../repo/customEventRepo", () => ({
    customEventRepo: {list: jest.fn(), save: jest.fn(), remove: jest.fn()},
}));

let renderer: TestRenderer.ReactTestRenderer;
let latest: ReturnType<typeof useCustomEvents>;
const input: CustomEventInput = {
    title: "实验课",
    location: "",
    teacher: "",
    notes: "",
    year: 2026,
    term: 1,
    weeks: [1],
    weekday: 1,
    begin: 1,
    end: 2,
};
const first: CustomEvent = {...input, id: 1};
function Probe({owner}: {owner: string}) {
    latest = useCustomEvents(owner);
    return null;
}

beforeEach(() => {
    jest.clearAllMocks();
    (customEventRepo.list as jest.Mock).mockResolvedValue([first]);
});
afterEach(async () => {
    await act(async () => renderer?.unmount());
});

it("新增、更新、删除成功后同步列表，失败保留原数据", async () => {
    await act(async () => {
        renderer = TestRenderer.create(<Probe owner="jw:a" />);
    });
    (customEventRepo.save as jest.Mock).mockResolvedValue({...input, id: 2});
    await act(async () => {
        expect(await latest.save(input)).toBe(true);
    });
    expect(latest.events.map(event => event.id)).toEqual([1, 2]);
    (customEventRepo.save as jest.Mock).mockRejectedValueOnce(new Error("disk full"));
    await act(async () => {
        expect(await latest.save(input, 1)).toBe(false);
    });
    expect(latest.events).toHaveLength(2);
    await act(async () => {
        await latest.remove(2);
    });
    expect(latest.events).toEqual([first]);
    expect(customEventRepo.remove).toHaveBeenCalledWith("jw:a", 2);
});

it("切换账号后丢弃旧查询结果", async () => {
    let resolveOld!: (events: CustomEvent[]) => void;
    (customEventRepo.list as jest.Mock).mockReturnValueOnce(
        new Promise(resolve => {
            resolveOld = resolve;
        }),
    );
    await act(async () => {
        renderer = TestRenderer.create(<Probe owner="jw:a" />);
    });
    (customEventRepo.list as jest.Mock).mockResolvedValueOnce([]);
    await act(async () => {
        renderer.update(<Probe owner="jw:b" />);
    });
    await act(async () => {
        resolveOld([first]);
    });
    expect(latest.events).toEqual([]);
});

it("双击保存只提交一次，旧账号未完成的写入不会进入新账号列表", async () => {
    await act(async () => {
        renderer = TestRenderer.create(<Probe owner="jw:a" />);
    });
    let resolveSave!: (event: CustomEvent) => void;
    (customEventRepo.save as jest.Mock).mockReturnValueOnce(
        new Promise(resolve => {
            resolveSave = resolve;
        }),
    );
    let pending!: Promise<boolean>;
    await act(async () => {
        pending = latest.save(input);
        expect(await latest.save(input)).toBe(false);
    });
    expect(customEventRepo.save).toHaveBeenCalledTimes(1);
    (customEventRepo.list as jest.Mock).mockResolvedValueOnce([]);
    await act(async () => {
        renderer.update(<Probe owner="jw:b" />);
    });
    await act(async () => {
        resolveSave({...input, id: 2});
        await pending;
    });
    expect(latest.events).toEqual([]);
    expect(latest.saving).toBe(false);
});

it("保存过程中切换账号再返回时重新读取完整列表", async () => {
    await act(async () => {
        renderer = TestRenderer.create(<Probe owner="jw:a" />);
    });
    let resolveSave!: (event: CustomEvent) => void;
    (customEventRepo.save as jest.Mock).mockReturnValueOnce(
        new Promise(resolve => {
            resolveSave = resolve;
        }),
    );
    let pending!: Promise<boolean>;
    await act(async () => {
        pending = latest.save(input);
    });
    (customEventRepo.list as jest.Mock).mockResolvedValueOnce([]);
    await act(async () => {
        renderer.update(<Probe owner="jw:b" />);
    });
    await act(async () => {
        renderer.update(<Probe owner="jw:a" />);
    });
    const added = {...input, id: 2};
    (customEventRepo.list as jest.Mock).mockResolvedValueOnce([first, added]);
    await act(async () => {
        resolveSave(added);
        await pending;
    });
    expect(latest.events).toEqual([first, added]);
});
