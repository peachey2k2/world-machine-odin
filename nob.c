#define NOB_IMPLEMENTATION // include implementation (duh)
#define NOB_STRIP_PREFIX // strip `nob_` prefix

#include "nob.h"


// --------------------|  Constants/Macros  |--------------------

#define WMAC_SOURCE         "./world-machine/src"
#define WMAC_VENDOR         "./world-machine/extra-vendor"
#define WMAC_DESTINATION    "./bin"
#define WMAC_EXECUTABLE     WMAC_DESTINATION"/out"
// const char *WMAC_DEPENDENCIES = "./bin/deps.json"

#define WMAC_COLLECTIONS    "-collection:src=./world-machine/src", \
                            "-collection:res=./world-machine/res", \
                            "-collection:extra-vendor=./world-machine/vendor"

#define VENDOR "./world-machine/vendor"

// #define VERBOSE_TIMINGS
#define WARNINGS_AS_ERRORS
#define AGGRESSIVE_OPTIMIZATION


// --------------------|  Function Declarations  |--------------------

void build();
void run();
void check();
void clean();
void build_vendor();
void clean_vendor();

void show_help();

void add_func(void (*fn)());
char* concat(const char *s1, const char *s2);
bool call_for_func(const char *dir, bool (*cond)(const char*), void (*fn)(const char*), bool wanted_output, bool call_for_dirs);
bool call_for_suffix(const char *dir, const char *suffix, void (*fn)(const char*), bool call_for_dirs);
bool call_for_all(const char *dir, void (*fn)(const char*), bool call_for_dirs);
void cmd_print(Cmd cmd);
void delete_file(const char *path);


// --------------------|  Macros  |--------------------

#define ifeq(str1_, str2_) if (strcmp((str1_), (str2_)) == 0)
#define for_range(i_, start_, end_) for ((i_) = (start_); (i_) < (end_); ++(i_))

#define cmd_immediate(...) /**********************************************/ \
    da_append_many(                                                         \
        &immediate_cmd,                                                     \
        ((const char*[]){__VA_ARGS__}),                                     \
        (sizeof((const char*[]){__VA_ARGS__})/sizeof(const char*))          \
    );                                                                      \
    if (!cmd_run_sync(immediate_cmd)) exit(1);                              \
    immediate_cmd.count = 0                                                 \


// --------------------|  Types  |--------------------

typedef struct Func {
    void (*fn)();
    struct Func *next;
} Func;


// --------------------|  Globals  |--------------------

Func *funcs = NULL;
Func *funcs_last = NULL;

Cmd immediate_cmd = {0};

char** passed_args = NULL;
int passed_args_count = 0;

bool debug = false;
bool sanitize_address = false;
bool sanitize_memory = false;
bool sanitize_thread = false;
bool benchmarks = false;


// --------------------|  Build Functions  |--------------------

int main(int argc, char **argv) {
    nob_minimal_log_level = NOB_WARNING;
    NOB_GO_REBUILD_URSELF(argc, argv);
    
    mkdir_if_not_exists("bin");

    if (argc == 1) {
        printf("No arguments given.\nUse `./nob help` for info.\n");
        return 0;
    }

    int i = 0;
    for_range(i, 1, argc) {
        char* arg = argv[i];

        // argument passthrough
        ifeq(arg, "--") {
            passed_args = argv + i + 1;
            passed_args_count = argc - i - 1;
            break;
        }

        // commands
        else ifeq(arg, "help") {
            show_help();
            return 0;
        }
        else ifeq(arg, "run") {
            add_func(run);
        }
        else ifeq(arg, "build") {
            add_func(build);
        }
        else ifeq(arg, "check") {
            add_func(check);
        }
        else ifeq(arg, "clean") {
            add_func(clean);
        }
        else ifeq(arg, "build-vendor") {
            add_func(build_vendor);
        }
        else ifeq(arg, "clean-vendor") {
            add_func(clean_vendor);
        }

        // options
        else ifeq(arg, "-dbg") {
            debug = true;
        }
        else ifeq(arg, "-asan") {
            sanitize_address = true;
        }
        else ifeq(arg, "-msan") {
            sanitize_memory = true;
        }
        else ifeq(arg, "-tsan") {
            sanitize_thread = true;
        }
        else ifeq(arg, "-bench") {
            benchmarks = true;
        }
    }

    while (funcs != NULL) {
        Func *cur = funcs;
        cur->fn();
        funcs = cur->next;
        free(cur);
    }

    return 0;
}

void build() {
    Cmd cmd = {0};
    cmd_append(&cmd,
        "odin",
        "build",
        WMAC_SOURCE,
        "-out:"WMAC_EXECUTABLE,
        WMAC_COLLECTIONS,
        // "-extra-linker-flags:-L"VENDOR"/cimgui"
    );

    if (sanitize_memory)  cmd_append(&cmd, "-sanitize:memory");
    if (sanitize_address) cmd_append(&cmd, "-sanitize:address");
    if (sanitize_thread)  cmd_append(&cmd, "-sanitize:thread");

    #ifdef VERBOSE_TIMINGS
    cmd_append(&cmd, "-show-more-timings");
    #else
    cmd_append(&cmd, "-show-timings");
    #endif

    #ifdef WARNINGS_AS_ERRORS
    cmd_append(&cmd, "-warnings-as-errors");
    #endif

    if (debug) {
        cmd_append(&cmd, "-debug");
    } else {
        cmd_append(&cmd, "-disable-assert",
        #ifdef AGGRESSIVE_OPTIMIZATION
        "-o:aggressive"
        #else
        "-o:speed"
        #endif
        );
    }

    if (benchmarks) {
        cmd_append(&cmd, "-define:ENABLE_BENCHMARKS=true");
    }

    int i = 0;
    for_range(i, 0, passed_args_count) {
        cmd_append(&cmd, passed_args[i]);
    }

    cmd_print(cmd); 
    if(!cmd_run_sync(cmd)) exit(1);
    cmd_free(cmd);

    printf("[✓] Build successful.\n");
}

void run() {
    cmd_immediate(WMAC_EXECUTABLE);

    printf("[✓] Run successful.\n");
}

void check() {
    cmd_immediate(
        "odin",
        "check",
        WMAC_SOURCE,
        WMAC_COLLECTIONS
    );
    printf("[✓] Syntax check passed.\n");
}

void clean() {
    if (!call_for_all(WMAC_DESTINATION, delete_file, false)) {
        printf("[✗] Clean failed.\n");
        exit(1);
    }

    printf("[✓] Clean successful.\n");
}

void build_vendor() {
    // clean_vendor();
    // cmd_immediate("make", "static", "-C", VENDOR"/cimgui", "CXXFLAGS=-O2 -fno-exceptions -fno-rtti -fno-threadsafe-statics");
    // copy_file(VENDOR"/cimgui/libcimgui.a", WMAC_VENDOR"/imgui/libcimgui.a");
    // clean_vendor();
    // cmd_immediate("make", "static", "-C", VENDOR"/cimgui", "CXXFLAGS=-O2 -fno-exceptions -fno-rtti -fno-threadsafe-statics -g");
    // copy_file(VENDOR"/cimgui/libcimgui.a", WMAC_VENDOR"/imgui/libcimgui-debug.a");
    // printf("[✓] Vendor libraries built.\n");
}

void clean_vendor() {
    // cmd_immediate("make", "clean", "-C", VENDOR"/cimgui");
    // printf("[✓] Vendor libraries cleaned.\n");
}

void show_help() {
    printf(
        "Usage: ./nob [commands] [options]\n"
        "Note that you can use multiple commands.\n"
        "Example: ./nob build run (Builds and runs the project)\n"
        "\n"
        "Commands:\n"
        "  build     Build the project\n"
        "  run       Run the project\n"
        "  check     Check the syntax of the project\n"
        "  clean     Clean the project\n"
        "  help      Show this help message\n"
        "\n"
        "Build options:\n"
        "  -dbg      Enable debug mode and disable asserts\n"
        "  -asan     Enable address sanitizer\n"
        "  -msan     Enable memory sanitizer\n"
        "  -tsan     Enable thread sanitizer\n"
        "  -bench    Enable benchmarks\n"
        "  --        Passes all arguments after it to the Odin compiler\n"
        "\n"
    );
}


// --------------------|  Helper Functions  |--------------------

void add_func(void (*fn)()) {
    Func *func = malloc(sizeof(Func));
    func->fn = fn;
    func->next = NULL;

    // check if function is already added
    Func *cur = funcs;
    while (cur != NULL) {
        if (cur->fn == fn) {
            return;
        }
        cur = cur->next;
    }

    // append function to list
    if (funcs == NULL) {
        funcs = func;
    } else {
        funcs_last->next = func;
    }
    funcs_last = func;
}

char* concat(const char *s1, const char *s2) {
    char *result = malloc(strlen(s1) + strlen(s2) + 1);
    strcpy(result, s1);
    strcat(result, s2);
    return result;
}

// scans directory at `path` recursively, runs `fn` on each file with `suffix`
// `wanted_output` determines at what output of `cond` to run `fn` (true/false)
// `call_for_dirs` determines whether to run `fn` on directories
bool call_for_func(const char *path, bool (*cond)(const char*), void (*fn)(const char*), bool wanted_output, bool call_for_dirs) {
    bool result = true;
    Nob_File_Paths children = {0};
    Nob_String_Builder src_sb = {0};
    size_t temp_checkpoint = nob_temp_save();

    Nob_File_Type type = nob_get_file_type(path);
    if (type < 0) return false;

    switch (type) {
        case NOB_FILE_DIRECTORY: {
            if (!nob_read_entire_dir(path, &children)) nob_return_defer(false);

            for (size_t i = 0; i < children.count; ++i) {
                if (strcmp(children.items[i], ".") == 0) continue;
                if (strcmp(children.items[i], "..") == 0) continue;

                src_sb.count = 0;
                nob_sb_append_cstr(&src_sb, path);
                nob_sb_append_cstr(&src_sb, "/");
                nob_sb_append_cstr(&src_sb, children.items[i]);
                nob_sb_append_null(&src_sb);

                if (!call_for_func(src_sb.items, cond, fn, wanted_output, call_for_dirs)) {
                    nob_return_defer(false);
                }

                if (call_for_dirs && (cond(src_sb.items) == wanted_output)) {
                    fn(src_sb.items);
                }
            }
        } break;

        case NOB_FILE_REGULAR: {
            String_View path_sv = sv_from_cstr(path);
            if (cond(path) == wanted_output) {
                fn(path);
            }
        } break;

        case NOB_FILE_SYMLINK: {
            nob_log(NOB_WARNING, "TODO: Copying symlinks is not supported yet");
        } break;

        case NOB_FILE_OTHER: {
            nob_log(NOB_ERROR, "Unsupported type of file %s", path);
            nob_return_defer(false);
        } break;

        default: NOB_UNREACHABLE("nob_copy_directory_recursively");
    }

defer:
    nob_temp_rewind(temp_checkpoint);
    nob_da_free(src_sb);
    nob_da_free(children);
    return result;
}

bool call_for_suffix(const char *dir, const char *suffix, void (*fn)(const char*), bool call_for_dirs) {
    return call_for_func(dir, (bool (*)(const char*))sv_end_with, fn, true, call_for_dirs);
}

bool _function_that_always_returns_true(const char *path) { return true; }

bool call_for_all(const char *dir, void (*fn)(const char*), bool call_for_dirs) {
    return call_for_func(dir, _function_that_always_returns_true, fn, true, call_for_dirs);
}

void cmd_print(Cmd cmd) {
    int i = 0;
    for_range(i, 0, cmd.count) printf("%s ", cmd.items[i]); printf("\n");
}

// Deletes file at `path`. Can be used as a callback for `call_for_*` functions. 
void delete_file(const char *path) {
    if (remove(path) != 0) {
        printf("[✗] Failed to remove file: %s\nPerhaps a permission issue?", path);
        exit(1);
    }
}

