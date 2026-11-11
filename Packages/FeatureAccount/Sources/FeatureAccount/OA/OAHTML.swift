import Foundation

enum OAHTML {
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
