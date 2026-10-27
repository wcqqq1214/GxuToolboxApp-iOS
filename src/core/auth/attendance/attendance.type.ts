export interface AttendanceSession {
    token: string;
    calendarId: number;
    userId: number;
}

export interface AttendanceLoginInput {
    username: string;
    password: string;
    captchaCode: string;
    ticket: string;
}
