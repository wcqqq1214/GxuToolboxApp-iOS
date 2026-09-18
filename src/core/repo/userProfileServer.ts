import {userProfileRepo} from "@/core/repo/userProfileRepo.ts";
import {getProfile} from "@/features/backend/api/profile.ts";

// 30天
const PROFILE_TTL = 30 * 24 * 60 * 60 * 1000;

export async function syncInfo(account: string) {
    const local = await userProfileRepo.get(account);

    if (local && Date.now() - local.updated_at < PROFILE_TTL) {
        return local;
    }

    return forceSync();
}

async function forceSync() {
    const profile = await getProfile();
    if (!profile || !profile.student_id) {
        throw new Error("后端未返回有效的个人信息");
    }
    await userProfileRepo.upsert(profile);

    return profile;
}
