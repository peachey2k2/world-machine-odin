package utils

import "core:time"
import "core:os"
import "core:fmt"
import "core:strings"


ENABLE_BENCHMARKS :: #config(ENABLE_BENCHMARKS, false)

log_file_handle : os.Handle

LogLevel::enum {
    BENCHMARK,
    INFO,
    WARNING,
    ERROR,
}

init_logger::proc() {
    now := time.now()
    timestamp := [time.MIN_YY_DATE_LEN + time.MIN_HMS_LEN + 1]u8{}

    time.to_string_dd_mm_yy(now, timestamp[:time.MIN_YY_DATE_LEN])
    time.to_string_hms(now, timestamp[time.MIN_YY_DATE_LEN+1:])
    timestamp[time.MIN_YY_DATE_LEN] = '_'

    err : os.Error
    log_file_handle, err = os.open(strings.concatenate([]string{"logs/log-", string(timestamp[:]), ".txt"}), os.O_CREATE | os.O_RDWR, 0o644)
    if err != nil {
        fmt.printf("Error opening log file: %s\n", err)
        os.exit(1)
    }

    defer_deinit(deinit_logger)
    log(.INFO, "Initialized logger. Hello again :D")
}

deinit_logger::proc() {
    log(.INFO, "Deinitilizing logger... Goodbye :)")
    os.close(log_file_handle)
}

log::proc(level:LogLevel, msg:..any) {
    now := time.now()
    buf := [time.MIN_HMS_LEN]u8{}
    timestamp := time.time_to_string_hms(now, buf[:])

    log_level := ""
    switch level {
        case .BENCHMARK: log_level = "[BENCH]"
        case .INFO: log_level = "[INFO]"
        case .WARNING: log_level = "[WARN]"
        case .ERROR: log_level = "[ERROR]"
    }

    log_msg := new(strings.Builder)
    fmt.sbprintln(log_msg, ..msg)
    bytes_written, err := os.write(
        log_file_handle,
        transmute([]u8) strings.concatenate([]string{timestamp, " ", log_level, " ", strings.to_string(log_msg^)})
    )
    if err != nil {
        fmt.printf("Error writing to log file: %s\n", err)
    }
    // fmt.printf("%d\n", bytes_written)
    // fmt.println(log_msg)
}

when ENABLE_BENCHMARKS {

    BenchmarkObject::struct {
        name : string,
        start : time.Tick
    }


    bench_start::proc(name:string) -> (^BenchmarkObject) {
        bm := new(BenchmarkObject)
        bm.name = name
        bm.start = time.tick_now()
        return bm
    }

    bench_end::proc(b:^BenchmarkObject) {
        elapsed := time.tick_since(b.start)
        hrs, mins, secs, ns := time.precise_clock(elapsed)
        log(.BENCHMARK,
            b.name, "took",
            hrs, "hrs,", mins, "mins,", secs, "secs,", ns, "ns."
        )
    }

} else {

    bench_start::proc(name:string) -> (^any) {
        return nil
    }

    bench_end::proc(b:^any) {
    }
    
}

