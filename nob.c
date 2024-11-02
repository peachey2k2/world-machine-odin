#define NOB_IMPLEMENTATION // include implementation (duh)
#define NOB_STRIP_PREFIX // strip `nob_` prefix

#include "nob.h"
#include <string.h> // strcmp

// --------------------|  Function Declarations  |--------------------

void build();
void run();
void check();

void add_func(void (*fn)());
char* concat(const char *s1, const char *s2);
bool rwildcard(const char *dir, const char *ext, void (*fn)(const char*));


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


// --------------------|  Structs  |--------------------

typedef struct Func{
    void (*fn)();
    struct Func *next;
} Func;


// --------------------|  Constants  |--------------------

const char *WMAC_SOURCE = "./world-machine/src";
const char *WMAC_DEST = "./bin/out";

const int BUFFER_SIZE = 256;


// --------------------|  Globals  |--------------------

Func *funcs = NULL;
Func *funcs_last = NULL;

Cmd immediate_cmd = {0};


// --------------------|  Build Functions  |--------------------

int main(int argc, char **argv) {
    NOB_GO_REBUILD_URSELF(argc, argv);

    if (argc == 1) {
        printf("Usage: nob [help|run|build|check]\n");
        return 0;
    }

    int i = 0;
    for_range(i, 1, argc) {
        char* arg = argv[i];

        ifeq(arg, "help") {
            printf("TODO:\n");
            return 0;
        }
        ifeq(arg, "run") {
            add_func(build);
            add_func(run);
        }
        ifeq(arg, "build") {
            add_func(build);
        }
        ifeq(arg, "check") {
            add_func(check);
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
    cmd_immediate(
        "odin",
        "build",
        WMAC_SOURCE,
        concat("-out:", WMAC_DEST)
    );
    printf("[✓] Build successful.\n");
}

void run() {
    cmd_immediate(WMAC_DEST);
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

