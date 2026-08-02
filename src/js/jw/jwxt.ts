import {http} from "@/core/http.ts";
import {AxiosResponse} from "axios";

export const jwxt = {
    getReschedulingNews: async (isRead = 1): Promise<AxiosResponse> => {
        return await http.post("/xtgl/index_cxDbsy.html?doType=query", {
            sfyy: isRead,
            flag: 1,
            _search: false,
            "queryModel.showCount": 150,
            "queryModel.currentPage": 1,
        });
    },
};
