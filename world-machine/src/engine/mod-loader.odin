package engine

import "core:path/filepath"
import "core:os"
import "core:strings"
import "core:dynlib"


when ODIN_OS == .Windows {
    SHARED_LIB_EXT :: ".dll"
} else when ODIN_OS == .Linux {
    SHARED_LIB_EXT :: ".so"
} else when ODIN_OS == .Darwin {
    SHARED_LIB_EXT :: ".dylib"
} else {
    #assert(false, "Unsupported OS")
}

MODS_DIRECTORY :: "mods"

m_mod_list := [dynamic]Mod{}

@(private="file")
current_mod_id : ModID = 1 // 0 is reserved for core

load_all_mods::proc() {
    append(&m_mod_list, init_core_mod())

    walk_proc::proc(info: os.File_Info, in_err: os.Error, user_data: rawptr) -> (err: os.Error, skip_dir: bool) {
        
        
        if in_err != nil do return in_err, true
        if info.is_dir do return nil, false
        if strings.ends_with(info.fullpath, SHARED_LIB_EXT) {
            load_mod(info.fullpath, info.name, current_mod_id)
            current_mod_id += 1
        }
        return nil, false
    }

    filepath.walk(MODS_DIRECTORY, walk_proc, nil)
}

@(private="file")
load_mod::proc(mod_fullpath: string, mod_filename: string, mod_id: ModID) {
    mod_lib, lib_ok := dynlib.load_library(mod_fullpath)
    assert(lib_ok)

    mod_init_ptr, sym_ok := dynlib.symbol_address(mod_lib, "init")
    assert(sym_ok)

    mod_init_fn := transmute(proc "c" (ModID) -> Mod)(mod_init_ptr)

    mod := mod_init_fn(mod_id)
    mod.path = mod_fullpath
    append(&m_mod_list, mod)
}

init_mod_functions::proc() {
    api := ApiFunctions{
        // add_block = add_block,
        // add_entity = add_entity,
    }

    for &mod in m_mod_list {
        if mod.init_functions != nil {
            mod.init_functions(&api)
        }
    }
}

init_mod_items::proc() {
    for &mod, idx in m_mod_list {
        if mod.init_items != nil {
            current_mod_id = u64(idx)
            mod.init_items()
        }
    }
}

init_mod_blocks::proc() {
    for &mod, idx in m_mod_list {
        if mod.init_blocks != nil {
            current_mod_id = u64(idx)
            mod.init_blocks()
        }
    }
}

init_mod_entities::proc() {
    for &mod, idx in m_mod_list {
        if mod.init_entities != nil {
            current_mod_id = u64(idx)
            mod.init_entities()
        }
    }
}

get_current_mod_id::proc() -> ModID {
    return current_mod_id
}
