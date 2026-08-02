import {StyleSheet} from "react-native";

export const formStyles = StyleSheet.create({
    label: {
        fontSize: 16,
        fontWeight: "600",
        marginTop: 22,
        marginBottom: 4,
    },
    error: {
        color: "red",
        fontSize: 12,
        marginTop: 2,
    },
});

export const inputStyles = StyleSheet.create({
    input: {
        borderWidth: StyleSheet.hairlineWidth,
        borderColor: "#888",
        borderRadius: 8,
        paddingHorizontal: 8,
        fontSize: 16,
        height: 55,
        justifyContent: "center",
        textAlignVertical: "center",
    },
});
