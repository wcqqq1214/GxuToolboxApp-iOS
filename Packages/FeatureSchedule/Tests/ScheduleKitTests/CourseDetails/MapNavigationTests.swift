import Foundation
import Testing
@testable import ScheduleKit

struct MapNavigationTests {
    @Test func urlsFollowRNMapUrl() throws {
        // RN `buildMapUrl`：关键词 trim，逐项 encodeURIComponent；高德带 sourceApplication，百度带 src
        let amap = try #require(MapApp.amap.url(keyword: " 广西大学西校园第三教学楼 "))
        #expect(amap.absoluteString == "iosamap://poi?sourceApplication=gxujwt&name=%E5%B9%BF%E8%A5%BF%E5%A4%A7%E5%AD%A6%E8%A5%BF%E6%A0%A1%E5%9B%AD%E7%AC%AC%E4%B8%89%E6%95%99%E5%AD%A6%E6%A5%BC&dev=0")
        let baidu = try #require(MapApp.baidu.url(keyword: "广西大学"))
        #expect(baidu.absoluteString == "baidumap://map/place/search?query=%E5%B9%BF%E8%A5%BF%E5%A4%A7%E5%AD%A6&src=gxujwt")
        let apple = try #require(MapApp.apple.url(keyword: "6A 教学楼&x=1"))
        #expect(URLComponents(url: apple, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "6A 教学楼&x=1")
        #expect(apple.host == "maps.apple.com")
    }

    @Test func planFollowsRNOpenMap() {
        let both: [MapApp] = [.apple, .amap]
        // 解析不到：不打开
        #expect(MapOpenPlan.make(keyword: nil, parsedFullName: nil, installed: both) == .unparsed)
        #expect(MapOpenPlan.make(keyword: "  ", parsedFullName: nil, installed: both) == .unparsed)
        // 直接给的关键词优先于解析结果（体育学院）
        #expect(MapOpenPlan.make(keyword: " 广西大学西校园综合体育馆 ", parsedFullName: "广西大学西校园第三教学楼", installed: both)
            == .open(keyword: "广西大学西校园综合体育馆", apps: both))
        // 没有给关键词就用解析出的楼名全称
        #expect(MapOpenPlan.make(keyword: nil, parsedFullName: "广西大学西校园第三教学楼", installed: [.apple])
            == .open(keyword: "广西大学西校园第三教学楼", apps: [.apple]))
        // 没有地图应用
        #expect(MapOpenPlan.make(keyword: nil, parsedFullName: "x", installed: []) == .noApp)
        // 先判断解析，再判断地图应用（RN 顺序）
        #expect(MapOpenPlan.make(keyword: nil, parsedFullName: nil, installed: []) == .unparsed)
    }

    @Test func messagesMatchRN() {
        #expect(MapOpenPlan.unparsedMessage == "该地点暂不支持自动在地图打开")
        #expect(MapOpenPlan.noAppMessage == "当前未检测到地图应用，请安装后再试")
        #expect(MapOpenPlan.openFailedMessage(.amap) == "无法打开高德地图，请检查是否安装")
    }
}
