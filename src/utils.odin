package flightsim

import win32 "core:sys/windows"

frequency: win32.LARGE_INTEGER

get_time :: proc() -> f64 {
        if frequency == 0 {
                win32.QueryPerformanceFrequency(&frequency)
        }

        counter: win32.LARGE_INTEGER
        win32.QueryPerformanceCounter(&counter)

        return cast(f64)counter / cast(f64)frequency
}
