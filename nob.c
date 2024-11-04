#define NOB_IMPLEMENTATION // include implementation (duh)
#define NOB_STRIP_PREFIX // strip `nob_` prefix

#include "nob.h"


// --------------------|  Constants/Macros  |--------------------

const char *WMAC_SOURCE = "./world-machine/src";
const char *WMAC_DEST = "./bin/out";

#define ADDRESS_SANITIZER
// #define MEMORY_SANITIZER
// #define THREAD_SANITIZER

// #define VERBOSE_TIMINGS
#define WARNINGS_AS_ERRORS


// --------------------|  Function Declarations  |--------------------

void build();
void run();
void check();
void clean();

void show_help();

void add_func(void (*fn)());
char* concat(const char *s1, const char *s2);
bool rwildcard(const char *dir, const char *ext, void (*fn)(const char*));
void cmd_print(Cmd cmd);


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
    immediate_cmd.count = 0;                                                \


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


// --------------------|  Build Functions  |--------------------

int main(int argc, char **argv) {
    nob_minimal_log_level = NOB_WARNING;
    NOB_GO_REBUILD_URSELF(argc, argv);
    
    mkdir_if_not_exists("bin");

    if (argc == 1) {
        printf("No arguments given. Use `./nob build` to build.\n");
        return 0;
    }

    int i = 0;
    for_range(i, 1, argc) {
        char* arg = argv[i];

        ifeq(arg, "--") {
            passed_args = argv + i + 1;
            passed_args_count = argc - i - 1;
            break;
        }
        else ifeq(arg, "help") {
            printf("TODO:\n");
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

        else ifeq(arg, "-dbg") {
            debug = true;
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
        concat("-out:", WMAC_DEST)
    );

    #ifdef MEMORY_SANITIZER
    cmd_append(&cmd, "-sanitize:memory");
    #endif

    #ifdef ADDRESS_SANITIZER
    cmd_append(&cmd, "-sanitize:address");
    #endif

    #ifdef THREAD_SANITIZER
    cmd_append(&cmd, "-sanitize:thread");
    #endif

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
        cmd_append(&cmd, "-disable-assert");
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
    cmd_immediate(WMAC_DEST);

    printf("[✓] Run successful.\n");
}

void check() {
    cmd_immediate(
        "odin",
        "check",
        WMAC_SOURCE
    );
    printf("[✓] Syntax check passed.\n");
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

bool rwildcard(const char *path, const char *suffix, void (*fn)(const char*)) {
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

                if (!rwildcard(src_sb.items, suffix, fn)) {
                    nob_return_defer(false);
                }
            }
        } break;

        case NOB_FILE_REGULAR: {
            String_View path_sv = sv_from_cstr(path);
            if (sv_end_with(path_sv, suffix)) {
                fn(path);
                nob_return_defer(false);
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

void cmd_print(Cmd cmd) {
    int i = 0;
    for_range(i, 0, cmd.count) printf("%s ", cmd.items[i]); printf("\n");
}

