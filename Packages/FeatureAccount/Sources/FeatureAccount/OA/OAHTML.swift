import Foundation

/// OA 文件正文（`fileBody`）的排版：给 HTML 片段补上自适应宽度、段落间距、表格和深浅色样式。
enum OAHTML {
    /// 没有任何块级标签的正文按纯文本处理：换行是普通的 `\n`，HTML 会把它们折成空格，整篇挤成一段，
    /// 所以这种正文要加 `white-space: pre-wrap` 保留换行和缩进。有块级标签的正文照 HTML 渲染，
    /// 否则标签之间的源码换行会变成多余的空行
    static func isPlainText(_ body: String) -> Bool {
        body.range(of: #"<\s*(p|br|div|table|ul|ol|li|h[1-6]|section|article|blockquote|pre)\b"#, options: [.regularExpression, .caseInsensitive]) == nil
    }

    static func wrap(_ body: String) -> String {
        let bodyClass = isPlainText(body) ? "plain" : "rich"
        return """
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root{color-scheme:light dark}
        body{font:-apple-system-body;font-size:17px;line-height:1.7;margin:0;padding:12px 16px 32px;word-wrap:break-word;overflow-wrap:anywhere}
        body.plain{white-space:pre-wrap}
        p{margin:0 0 .8em}
        img,video{max-width:100%;height:auto}
        table{max-width:100%;border-collapse:collapse}
        td,th{border:1px solid rgba(128,128,128,.5);padding:6px 8px}
        div,table,td,p{max-width:100%}
        </style>
        </head><body class="\(bodyClass)">\(body)</body></html>
        """
    }
}
