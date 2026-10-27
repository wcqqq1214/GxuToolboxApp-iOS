import journal from "./meta/_journal.json";
import m0000 from "./0000_zippy_bulldozer.sql";
import m0001 from "./0001_dizzy_callisto.sql";
import m0002 from "./0002_magenta_warstar.sql";
import m0003 from "./0003_ambitious_mojo.sql";

export default {
    journal,
    migrations: {
        m0000,
        m0001,
        m0002,
        m0003,
    },
};
