import {Button} from "@rneui/themed";
import {useWebView} from "@/hooks/app.ts";
import {DEFAULT_DOC, toolDocs} from "./toolDocs.ts";

type HelpButtonProps = {
    docKey?: string; // 页面标题，用于查对应文档
    uri?: string; // 直接指定网址，优先级最高
    title?: string; // 打开的网页标题
};

export function HelpButton({docKey, uri, title}: HelpButtonProps) {
    const {openInWeb} = useWebView();
    const finalUri = uri ?? (docKey ? toolDocs[docKey] : undefined) ?? DEFAULT_DOC;
    const finalTitle = title ?? docKey ?? "使用文档";

    return (
        <Button
            type="clear"
            containerStyle={{marginLeft: 2, padding: 0}}
            onPress={() => {
                openInWeb(finalTitle, {uri: finalUri});
            }}>
            ?
        </Button>
    );
}
