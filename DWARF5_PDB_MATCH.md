Let’s line up DWARF v5 (used by ELF toolchains like clang/gcc + gdb/lldb) and PDB / CodeView (used by MSVC + the Windows debugging stack) and see how each of your “hard” cases gets encoded.

I'll structure each construct like this:

* **DWARF 5:** which DIEs (`DW_TAG_*`) and attributes (`DW_AT_*`) show up
* **PDB / CodeView:** which type records (`LF_*`) or symbol records (`S_*`) show up, how they connect through type indices and field lists.
  When I describe PDB, I’ll cite the CodeView layout info from Microsoft’s published `cvinfo.h` and from reverse-engineered docs. Those explain that PDB stores types in the TPI (Type Info) stream as variable-length "type records", each one starting with a `(length, leaf-kind)` header, and referenced by a monotonically assigned *type index* starting at 0x1000. ([GitHub][1])

---

## 0. Mental model / glossary

### DWARF 5

* Everything is a **DIE** (Debugging Information Entry) in a tree.
* A DIE has a **tag** like `DW_TAG_structure_type`, `DW_TAG_union_type`, `DW_TAG_member`, `DW_TAG_array_type`, etc.
* It carries attributes like:

  * `DW_AT_name` (spelling)
  * `DW_AT_type` (points to another DIE for the field’s/element’s type)
  * `DW_AT_byte_size` / `DW_AT_bit_size`
  * layout info (`DW_AT_data_member_location`, `DW_AT_bit_offset`, `DW_AT_data_bit_offset`, etc.)
* Children of a type DIE describe its members, subranges, template params, etc.

DWARF directly mirrors *source-level nesting*:
a local `struct` declared inside a function literally appears as a child DIE of that function’s `DW_TAG_subprogram`.

### PDB / CodeView

* All concrete types live in the **TPI stream** as CodeView **type records**.
* Every record has:

  ```text
  u16 length;
  u16 kind;   // leaf kind, like LF_UNION, LF_STRUCTURE, LF_ARRAY, etc.
  ...payload...
  ```

  and that record gets a monotonically increasing **type index** (TI) starting at 0x1000. Types only refer "backwards": a record at TI N can only point to < N. ([GitHub][1])
* User-defined types (struct/union/class/etc.) don’t inline all members.
  Instead they point to an `LF_FIELDLIST` record, which is basically a packed list of field entries (`LF_MEMBER`, `LF_BITFIELD`, base classes, etc.) describing members, offsets, access, etc. ([GitHub][1])
* A union / struct / class record also encodes member count, byte size, properties (sealed, forward ref, etc.), and the UDT name. You can see a union example (“union u { union u *u; }”) reconstructed from raw CodeView records in the doc, where:

  * TI 0x1002 is `LF_UNION` (forward ref),
  * TI 0x1003 is `LF_POINTER` to that union,
  * TI 0x1004 is `LF_FIELDLIST` with an `LF_MEMBER` named `u` at offset 0 referencing that pointer,
  * TI 0x1005 is the real `LF_UNION` definition that points at that `LF_FIELDLIST` and has size 8. ([GitHub][1])
* Symbols (locals, params, blocks, etc.) live in **module symbol streams** and use `S_*` records like `S_GPROC32`, `S_BLOCK32`, `S_LOCAL`, etc., nested by lexical scope. ([GitHub][1])

Now let’s go construct by construct.

---

## 1. Bitfield members

### DWARF 5

A bitfield inside a struct/class is still emitted as a `DW_TAG_member` DIE (the same tag as a normal data member), but with extra attributes:

* `DW_AT_bit_size`: how many bits this field occupies.
* Position info:

  * Older style: `DW_AT_bit_offset` gives the bit position (from the containing allocation unit, endianness-sensitive).
  * DWARF5 added `DW_AT_data_bit_offset` to make the meaning less ABI-dependent.
* `DW_AT_type`: the *declared* base type (`unsigned int`, `char`, etc.).
* `DW_AT_data_member_location`: byte offset of the storage unit that contains the bitfield.

So DWARF models a bitfield as “a member that happens to have only N bits starting at bit K of the storage at byte offset B.”

### PDB / CodeView

Inside an `LF_FIELDLIST`, normal fields use `LF_MEMBER`, which gives you:

```c
typedef struct lfMember {
    unsigned short leaf;      // LF_MEMBER
    CV_fldattr_t   attr;      // access, etc.
    CV_typ_t       index;     // TI of the member's type
    ...encoded offset...
    ...name...
} lfMember;
```

The field list is literally a packed sequence of these entries (and friends) and is referenced by the parent UDT’s `LF_UNION`, `LF_STRUCTURE`, etc. ([GitHub][1])

For C/C++ bitfields specifically, CodeView uses a dedicated `LF_BITFIELD` record in place of `LF_MEMBER`.
`LF_BITFIELD` encodes:

* the underlying integer type TI,
* bit length,
* bit position within the storage unit,
* then the member name.

So conceptually it’s the same mapping as DWARF:

* base integer type
* bit width
* starting bit offset
* (synthetic) byte offset comes from where that bitfield lives in the struct layout.

Practical difference:

* DWARF expresses bitfields as attributes on a generic `DW_TAG_member`.
* PDB expresses them as a *different leaf kind* (`LF_BITFIELD`) inside the `LF_FIELDLIST`, rather than overloading `LF_MEMBER`.

---

## 2. Unions

### DWARF 5

A union is a `DW_TAG_union_type` DIE.

* `DW_AT_name`: the union tag or typedef name (if any).
* `DW_AT_byte_size`: size = max(size of all members).
* Children: each alternative member is a `DW_TAG_member` DIE.

  * Each member:

    * `DW_AT_name`
    * `DW_AT_type` (the type of that arm)
    * `DW_AT_data_member_location` **usually 0**, because in C/C++ all union arms start at offset 0.
* Anonymous members (if `union { int x; short y; };`) just omit `DW_AT_name` on the `DW_TAG_member`.

So in DWARF, a union is “like a struct but every member’s offset is 0.”

### PDB / CodeView

Unions are `LF_UNION` (and newer toolchains have `LF_UNION2`, which is basically the same layout but with slightly different packing / property fields).
A simplified shape (from CodeView docs / cvinfo.h):

* Header `(length, leaf=LF_UNION)`
* Fields:

  * member count
  * TI of the `LF_FIELDLIST` for this union
  * property flags (sealed, forward ref, etc.)
  * byte size (as a numeric leaf)
  * union name (zero-terminated / decorated)
  * sometimes a "unique name" (mangled, like `.??_C@...`) for link-time identity in MSVC. ([GitHub][1])

The `LF_FIELDLIST` referenced by that union then contains one entry per arm, typically `LF_MEMBER` entries with offset 0, plus any nested types.

**Self-recursive union example, straight from the CodeView dump:**

```c
union u {
    union u *u;
};
```

is encoded as:

* TI 0x1002: `LF_UNION` forward ref “u”.
* TI 0x1003: `LF_POINTER` to TI 0x1002.
* TI 0x1004: `LF_FIELDLIST` → one `LF_MEMBER` named `u`, offset 0, type TI 0x1003.
* TI 0x1005: final `LF_UNION` “u”, size = 8, fieldlist = TI 0x1004.
  That is literally how the doc reconstructs it. ([GitHub][1])

That matches DWARF’s idea: all union arms are conceptually “at offset 0”, and recursive types are handled through forward references.

---

## 3. Anonymous struct inside a union

(Example)

```c
union U {
    struct { int a; int b; };  // anonymous struct "embedded" in union
    uint64_t raw;
};
```

### DWARF 5

Typical emission (Clang/GCC style):

* `DW_TAG_union_type` for `U`.
* Child #1: a `DW_TAG_member` DIE *with no `DW_AT_name`*, `DW_AT_type` = some `DW_TAG_structure_type` DIE, `DW_AT_data_member_location` = 0 (because it’s part of a union).

  * That `DW_TAG_structure_type` child DIE will have its own children `DW_TAG_member` for `a` and `b`, each with a byte offset like 0, 4, etc.
* Child #2: another `DW_TAG_member` for `raw`.

Debuggers treat “nameless member whose type is a struct” specially and flatten `a`/`b` into `U`’s namespace for expression evaluation. There’s also often a `DW_AT_artificial` flag on the nameless proxy `DW_TAG_member` for the anonymous aggregate.

So DWARF encodes:

* union U

  * member (artificial, unnamed) of type <anon struct>

    * members a, b
  * member raw

### PDB / CodeView

MSVC’s PDB needs to express two things:

1. The union `U` itself (an `LF_UNION` record)
2. A nested unnamed struct arm at offset 0 that contributes `a` and `b`.

In CodeView terms:

* The `LF_UNION` for `U` points to an `LF_FIELDLIST`.
* That field list can contain not only `LF_MEMBER` and `LF_BITFIELD`, but also entries that reference nested UDTs. CodeView has special leaves like `LF_NESTTYPE` / `LF_NESTTYPEEX` for “this class/struct/union contains a nested type T under name X”.
* For anonymous aggregates MSVC usually synthesizes some internal name (like `__unnamed` or a unique “<unnamed-tag>”) in that `LF_STRUCTURE`/`LF_CLASS` record, and then puts the *fields a/b* inside that nested structure’s own `LF_FIELDLIST`.
  Then the union’s own `LF_FIELDLIST` will contain either:

  * an `LF_MEMBER` at offset 0 whose type TI is that anonymous struct TI, or
  * an `LF_NESTTYPE` entry pointing at that TI with a compiler-generated name.

Either way, semantically it matches DWARF: “one union arm is a struct that starts at offset 0, whose members are `a` and `b`.”

So both formats model:

* a real anonymous aggregate type node
* referenced as a field of the union at offset 0
* debugger later flattens it.

---

## 4. Recursively embedded struct / self-referential types

Classic C:

```c
struct Node {
    int value;
    struct Node *next;
};
```

### DWARF 5

DWARF supports forward declarations:

* First it can emit a `DW_TAG_structure_type` DIE for `Node` with `DW_AT_declaration` set (a “forward decl”, no members yet).
* Then it emits a pointer type DIE (`DW_TAG_pointer_type`) whose `DW_AT_type` points to that forward-declared `Node`.
* Finally it emits the full `DW_TAG_structure_type` DIE for `Node` (same `DW_AT_name`, but *no* `DW_AT_declaration`) with children:

  * `DW_TAG_member` "value": `DW_AT_type` = `int`, `DW_AT_data_member_location` = 0
  * `DW_TAG_member` "next": `DW_AT_type` = the pointer DIE, `DW_AT_data_member_location` = 8 (on 64-bit)

The important part is the pointer DIE can point at a not-yet-finalized struct DIE because DWARF lets you reference any DIE via its DIE reference attribute.

### PDB / CodeView

Exact same idea, but using CodeView type indices:

From the CodeView reconstruction of `union u { union u *u; }`, you can see MSVC emits:

* a forward ref `LF_UNION` with the name `u` (marked `FORWARD REF`),
* then a pointer type (`LF_POINTER`) whose element type is that forward ref TI,
* then an `LF_FIELDLIST` that uses that pointer TI,
* then a *real* `LF_UNION` definition that references the `LF_FIELDLIST` and gives the final size. ([GitHub][1])

Structs work the same way:

* `LF_STRUCTURE` or `LF_CLASS` first appears as a forward ref (property flag `FORWARD REF`, count=0, size=0),
* code then creates `LF_POINTER` to that TI,
* later the compiler emits a full `LF_STRUCTURE` with actual members and size,
* and updates field lists accordingly.

So:

* DWARF: forward-declare DIE with `DW_AT_declaration`, pointer refers to that.
* CodeView/PDB: forward-ref `LF_STRUCTURE` / `LF_UNION` with a property bit, emit pointer to that TI, then later emit the “real” definition with same UDT name and correct size, and a field list TI.

---

## 5. Arrays

### DWARF 5

Arrays are `DW_TAG_array_type` DIEs.
Key pieces:

* `DW_AT_type`: element type DIE.
* Child DIE(s): `DW_TAG_subrange_type`.

  * Each subrange has bounds: `DW_AT_lower_bound` / `DW_AT_upper_bound`, or a `DW_AT_count`.
  * Multidimensional arrays = multiple `DW_TAG_subrange_type` children in order.

So `int a[10]` becomes:

* `DW_TAG_array_type`

  * `DW_AT_type` -> base type `int`
  * child `DW_TAG_subrange_type` with `DW_AT_lower_bound` = 0, `DW_AT_count` = 10 (or upper_bound = 9)

### PDB / CodeView

Arrays are `LF_ARRAY` records in the TPI stream.
High-level fields (as defined in CodeView / cvinfo.h style docs):

* element type TI
* index type TI (the integer type used for subscripts, usually `int` / `unsigned long long` depending on arch)
* a numeric leaf giving the total number of elements (or total size in bytes, depending on flavor)
* a name string (pretty-printed name of the array type)

In other words, CodeView flattens “array-ness” into one record that says:

> element type = TI_X
> index type = TI_Y
> count/bytes = N
> pretty-name = "int[10]"

DWARF instead models the array as a container DIE with one or more subrange DIEs.

---

## 6. Templates (C++)

### DWARF 5

DWARF has first-class template parameter DIEs:

* `DW_TAG_template_type_parameter`

  * `DW_AT_name`: parameter name (`T`)
  * `DW_AT_type`: the substituted type argument (e.g. `int`)
* `DW_TAG_template_value_parameter`

  * `DW_AT_name`: parameter name (`N`)
  * `DW_AT_type`: the parameter’s type (`int`)
  * `DW_AT_const_value`: the concrete non-type argument (like `42`)
* Compilers emit these as children of the instantiated class DIE (`DW_TAG_class_type` / `DW_TAG_structure_type`) or the instantiated function DIE (`DW_TAG_subprogram`).

So for `MyVec<int, 42>`:

* You’ll see a `DW_TAG_class_type` named `"MyVec<int, 42>"`, often with a `DW_AT_linkage_name` (mangled `_Z...`) for uniqueness.
* Under it, you’ll see one `DW_TAG_template_type_parameter` (name=`T`, type=`int`) and one `DW_TAG_template_value_parameter` (name=`N`, const=42).

### PDB / CodeView

MSVC bakes template instantiations mostly as *regular* UDTs (`LF_CLASS`, `LF_STRUCTURE`, etc.) where:

* the UDT `name` is already the fully instantiated mangled name and also often a demangled pretty name,
* plus a “unique name” string (the fully decorated MSVC mangled name) stored in the same record for later lookup. You can see CodeView union/class records carrying both a “class name” and a “unique name = .?ATu@@ ...” in the dump. ([GitHub][1])

Template arguments themselves are carried two ways:

* The mangled unique name encodes them (MSVC-style mangling).
* CodeView also has records like `LF_ARGLIST`, `LF_TEMPLATE`, `LF_TEMPLATEPARAM`, etc., that let the debugger enumerate template parameters symbolically. (These show up especially for class templates and function templates in newer PDBs.)

So:

* DWARF: explicit per-parameter DIE children with `DW_TAG_template_*`.
* PDB: template instantiations are essentially “normal” UDT type records whose *name/unique name* already bakes in `<T,N>`. Additional template parameter info may appear as auxiliary CodeView type records (`LF_ARGLIST`, `LF_TEMPLATEPARAM`, etc.) referenced by the UDT’s type index.

---

## 7. “Local defined” types vs “static / file-scope” types and visibility

You asked about “local defined or static type.” I’ll break that into two debugger questions:

1. A type that’s declared **inside a function body** (block scope UDT / typedef).
2. A normal file-scope UDT that just isn’t externally visible.

### DWARF 5

DWARF is lexical.

* A `struct Local { ... };` declared *inside* `foo()` ends up as a `DW_TAG_structure_type` DIE **nested under** the `DW_TAG_subprogram` DIE for `foo`.

  * That subprogram DIE itself is nested under whatever CU (`DW_TAG_compile_unit`) you’re in.
* All its members, etc., live right there under that nested `DW_TAG_structure_type`.
* Because of nesting, debuggers can enforce “you can only name this type while stopped in (or lexically inside) foo().”
* A file-scope-but-internal (i.e. not exported) type is still a `DW_TAG_structure_type` under the CU, just without `DW_AT_external`. If the compiler considers it “not externally visible”, `DW_AT_external` is false.

So DWARF literally encodes scope with physical nesting.

### PDB / CodeView

PDB splits *types* and *symbols*:

* The **type record** (e.g. `LF_STRUCTURE` / `LF_UNION`) for that local `struct Local` still gets written into the global TPI stream and assigned a type index. CodeView type records don’t have direct “this only lives inside foo” lexical scoping; they’re just globally indexed. ([GitHub][1])

* But **the *name binding*** of that type gets emitted as a *symbol* inside the function’s lexical block in the module symbol stream.

  Concretely:

  * Functions are described with `S_GPROC32` / `S_LPROC32`, which open a lexical block. They give you function range, parent pointer, etc. ([GitHub][1])
  * Inner lexical scopes are described with `S_BLOCK32` symbols. Each `S_BLOCK32` has a parent pointer and its own range. Locals (variables) are described with things like `S_LOCAL` plus their live ranges (`S_DEFRANGE_*`). ([GitHub][1])
  * User-defined types (typedefs, `struct Local { ... };`, etc.) can appear as `S_UDT`-style records in that same scope, which map a source-level name (`Local`) to the global type index (TI) of the `LF_STRUCTURE` that actually describes its layout.

In other words:

* DWARF: scope is inherent because the *type DIE itself* lives lexically inside the function DIE.
* PDB: the *layout/type info* always sits in the global type stream, but a *symbol record inside the function’s scope* says “here, within this lexical block, the name `Local` refers to TI 0x1234.”

For “static” at file scope (i.e. internal linkage variables or types only visible in that .cpp):

* DWARF: same CU, `DW_AT_external` = false on vars; types just sit in that CU’s namespace.
* PDB: the variable shows up as `S_LDATA32` (local static data) instead of `S_GDATA32` (global data) in the module symbol stream; the underlying type of that object is still just a TI from the TPI stream. (This is analogous to how locals use `S_LOCAL`, but for statics there’s a dedicated symbol record flavor in PDB land; same idea of “symbol record binds a name + storage + TI to a scope”.) ([GitHub][1])

---

## Summary cheat sheet

**Bitfield**

* DWARF: `DW_TAG_member` + `DW_AT_bit_size` + bit offset attrs.
* PDB: `LF_BITFIELD` entry in the `LF_FIELDLIST`, with base type TI, bit length, bit position.

**Union**

* DWARF: `DW_TAG_union_type`, kids are `DW_TAG_member` all at offset 0.
* PDB: `LF_UNION` / `LF_UNION2` record with size, properties, points to an `LF_FIELDLIST` full of members at offset 0; supports forward refs and recursive unions. ([GitHub][1])

**Anonymous struct inside union**

* DWARF: unnamed `DW_TAG_member` of the union whose `DW_AT_type` is an internal anonymous `DW_TAG_structure_type`; members of that inner struct become effectively visible in the union.
* PDB: union’s `LF_FIELDLIST` includes an entry whose type TI is an internal anonymous `LF_STRUCTURE`/`LF_CLASS`, usually given a synthesized name; debuggers flatten.

**Recursive / self-embedded**

* DWARF: forward-declare `DW_TAG_structure_type` (`DW_AT_declaration`), emit pointer-to-it, then later emit full definition.
* PDB: emit `LF_STRUCTURE` / `LF_UNION` with `FORWARD REF` first, emit `LF_POINTER` to that TI, later emit the full definition `LF_STRUCTURE`/`LF_UNION` with the real field list and byte size, just like the documented `union u { union u *u; }` example. ([GitHub][1])

**Array**

* DWARF: `DW_TAG_array_type` + child `DW_TAG_subrange_type`(s) with bounds.
* PDB: `LF_ARRAY` record with element TI, index-type TI, and count/size as a numeric leaf (CodeView encodes integers and sizes as “numeric leaves” which are compact variable-length integers). ([GitHub][1])

**Template**

* DWARF: explicit `DW_TAG_template_type_parameter` / `DW_TAG_template_value_parameter` DIEs as children of the instantiated class/function DIE, with concrete types / values.
* PDB: template instantiations are just normal UDT records (`LF_CLASS`, `LF_STRUCTURE`, `LF_UNION`) whose “name” and “unique name” already include the instantiated template arguments (demangled + MSVC-mangled). Additional per-parameter info can show up in CodeView template-related leaves (`LF_ARGLIST`, `LF_TEMPLATEPARAM`, etc.). ([GitHub][1])

**Local / static scope types & names**

* DWARF: local types literally live lexically under the `DW_TAG_subprogram` of the function that defined them, so scope is implicit in the DIE tree.
* PDB: the layout/type itself is in the *global* TPI stream as an `LF_STRUCTURE` / `LF_UNION`, but function / block scope is modeled by `S_GPROC32` / `S_BLOCK32` / `S_LOCAL` / `S_UDT`-style symbol records in the module symbol stream, which say “in this lexical range, name X refers to TI Y”. ([GitHub][1])

Bottom line: DWARF encodes “what is it, where does it live, and how is it scoped?” in one tree.
PDB splits it: TPI stream says “what is it (layout/type record)”, symbol streams say “where is the name visible, and where does the storage live, during execution.”

[1]: https://github.com/PascalBeyer/PDB-Documentation "GitHub - PascalBeyer/PDB-Documentation: Complete documentation for Microsofts debug information container format."
