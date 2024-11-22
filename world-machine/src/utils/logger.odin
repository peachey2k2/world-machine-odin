package utils

import "core:time"
import "core:os"
import "core:fmt"
import "core:strings"


ENABLE_BENCHMARKS :: #config(ENABLE_BENCHMARKS, false)

MAXIMUM_KEPT_LOGS := 10

log_file_handle : os.Handle

LogLevel::enum {
    BENCHMARK,
    INFO,
    WARNING,
    ERROR,
}

init_logger::proc() {
    if !os.is_dir("logs") {
        os.make_directory("logs", 0o755)
    } else {
        logs_dir, err := os.open("logs", os.O_RDONLY)
        if err != nil {
            fmt.printf("Error opening logs directory: %s\n", err)
            os.exit(1)
        }
        
        files : []os.File_Info
        files, err = os.read_dir(logs_dir, MAXIMUM_KEPT_LOGS*2)
        if err != nil {
            fmt.printf("Error reading logs directory: %s\n", err)
            os.exit(1)
        }

        for file in files {
            if strings.has_prefix(file.name, "log-") && strings.has_suffix(file.name, ".txt") {
                os.remove(file.fullpath)
            }
        }

        os.file_info_slice_delete(files)
    }

    now := time.now()
    timestamp := [time.MIN_YY_DATE_LEN + time.MIN_HMS_LEN + 1]u8{}

    time.to_string_dd_mm_yy(now, timestamp[:time.MIN_YY_DATE_LEN])
    time.to_string_hms(now, timestamp[time.MIN_YY_DATE_LEN+1:])
    timestamp[time.MIN_YY_DATE_LEN] = '_'

    filename := strings.concatenate([]string{"logs/log-", string(timestamp[:]), ".txt"})
    defer delete(filename)

    err : os.Error
    log_file_handle, err = os.open(filename, os.O_CREATE | os.O_RDWR, 0o644)
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
    defer { strings.builder_destroy(log_msg); free(log_msg) }
    fmt.sbprintln(log_msg, ..msg)

    full_message := strings.concatenate([]string{timestamp, " ", log_level, " ", strings.to_string(log_msg^)})
    defer delete(full_message)

    bytes_written, err := os.write(
        log_file_handle,
        transmute([]u8) full_message
    )
    if err != nil {
        fmt.printf("Error writing to log file: %s\n", err)
    }
}

assert_and_log::proc(cond: bool, msg: ..any) {
    if !cond {
        log(.ERROR, ..msg)
        os.exit(1)
    }
}

when ENABLE_BENCHMARKS {

    BenchmarkObject::struct {
        name : string,
        start : time.Tick
    }

    bench_start::proc(name: string) -> (^BenchmarkObject) {
        bm := new(BenchmarkObject)
        bm.name = name
        bm.start = time.tick_now()
        return bm
    }

    bench_end::proc(b: ^BenchmarkObject) {
        elapsed := time.tick_since(b.start)
        log(.BENCHMARK, b.name, "took", elapsed)
        free(b)
    }

    @(deferred_out=bench_end)
    bench::#force_inline proc(name: string) -> ^BenchmarkObject {
        return bench_start(name)
    }

} else {

    bench_start::#force_inline proc(name: string) -> (rawptr) {
        return nil
    }

    @(disabled=true)
    bench_end::#force_inline proc(b: rawptr) {
    }
    
    @(disabled=true)
    bench::#force_inline proc(name: string) {
    }
}

