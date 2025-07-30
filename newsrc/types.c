#include "include/utils.h"
#include "include/types.h"

Type type_none(void) {
    return (Type){.kind = TkNone};
}

Type type_void(CONSTNESS constant, size_t index) {
    return (Type){
        .kind = TkVoid,
        .constant = constant,
        .cursors_idx = index,
    };
}

Type type_bool(CONSTNESS constant, size_t index) {
    return (Type){
        .kind = TkBool,
        .constant = constant,
        .cursors_idx = index,
    };
}

Type type_char(CONSTNESS constant, size_t index) {
    return (Type){
        .kind = TkChar,
        .constant = constant,
        .cursors_idx = index,
    };
}

Type type_string(CONSTNESS constant, size_t index) {
    return (Type){
        .kind = TkString,
        .constant = constant,
        .cursors_idx = index,
    };
}

Type type_cstring(CONSTNESS constant, size_t index) {
    return (Type){
        .kind = TkCstring,
        .constant = constant,
        .cursors_idx = index,
    };
}

Type type_integer(TypeKind kind, CONSTNESS constant, size_t index) {
    return (Type){
        .kind = kind,
        .constant = constant,
        .cursors_idx = index,
    };
}

Type type_decimal(TypeKind kind, CONSTNESS constant, size_t index) {
    return (Type){
        .kind = kind,
        .constant = constant,
        .cursors_idx = index,
    };
}

Type type_array(Array v, CONSTNESS constant, size_t index) {
    return (Type){
        .kind = TkArray,
        .constant = constant,
        .cursors_idx = index,
        .array = v,
    };
}

Type type_ptr(Type *v, CONSTNESS constant, size_t index) {
    return (Type){
        .kind = TkPtr,
        .constant = constant,
        .cursors_idx = index,
        .ptr_to = v,
    };
}

Type type_option(Option v, CONSTNESS constant, size_t index) {
    return (Type){
        .kind = TkOption,
        .constant = constant,
        .cursors_idx = index,
        .option = v,
    };
}

Type type_typedef(const char *v, CONSTNESS constant, size_t index) {
    return (Type){
        .kind = TkTypeDef,
        .constant = constant,
        .cursors_idx = index,
        .typedeff = v,
    };
}

Type type_map(const char *t) {
    if (streq(t, "void")) {
        return (Type){.kind = TkVoid};
    } else if (streq(t, "bool")) {
        return (Type){.kind = TkBool};
    } else if (streq(t, "char")) {
        return (Type){.kind = TkChar};
    } else if (streq(t, "string")) {
        return (Type){.kind = TkString};
    } else if (streq(t, "cstring")) {
        return (Type){.kind = TkCstring};
    } else if (streq(t, "i8")) {
        return (Type){.kind = TkI8};
    } else if (streq(t, "i16")) {
        return (Type){.kind = TkI16};
    } else if (streq(t, "i32")) {
        return (Type){.kind = TkI32};
    } else if (streq(t, "i64")) {
        return (Type){.kind = TkI64};
    } else if (streq(t, "isize")) {
        return (Type){.kind = TkIsize};
    } else if (streq(t, "u8")) {
        return (Type){.kind = TkU8};
    } else if (streq(t, "u16")) {
        return (Type){.kind = TkU16};
    } else if (streq(t, "u32")) {
        return (Type){.kind = TkU32};
    } else if (streq(t, "u64")) {
        return (Type){.kind = TkU64};
    } else if (streq(t, "usize")) {
        return (Type){.kind = TkUsize};
    } else if (streq(t, "f32")) {
        return (Type){.kind = TkF32};
    } else if (streq(t, "f64")) {
        return (Type){.kind = TkF64};
    }

    return (Type){.kind = TkNone};
}

const char *typekind_stringify(TypeKind t) {
    switch (t) {
        case TkTypeDef: return "TypeDef";
        case TkArray: return "Array";
        case TkChar: return "Char";
        case TkPtr: return "Ptr";
        case TkOption: return "Option";
        case TkI8: return "I8";
        case TkI16: return "I16";
        case TkI32: return "I32";
        case TkI64: return "I64";
        case TkIsize: return "Isize";
        case TkU8: return "U8";
        case TkU16: return "U16";
        case TkU32: return "U32";
        case TkU64: return "U64";
        case TkUsize: return "Usize";
        case TkF32: return "F32";
        case TkF64: return "F64";
        case TkBool: return "Bool";
        case TkVoid: return "Void";
        case TkString: return "String";
        case TkCstring: return "Cstring";
        case TkUntypedInt: return "UntypedInt";
        case TkUntypedFloat: return "UntypedFloat";
        case TkNone: return "None";
        case TkTypeId: return "TypeId";
    }
}
