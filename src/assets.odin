package flightsim

import "core:fmt"
import "core:os"
import "core:strconv"

Vertex :: struct {
        position: [4]f32,
        uv: [3]f32,
        normal: [3]f32,
}

Model :: struct {
        vertex_array: [dynamic]Vertex,
        index_array: [dynamic]u32,
        vertex_count: i32,
        index_count: i32,
}

Tokenizer :: struct {
        data: []u8,
        char: u8,
        offset: i32,
        end_of_file: bool,
}

Token_Kind :: enum {
        Float,
        Integer,
        Identifier,
        Slash,
        Keywords_Begin,
                V,
                VT,
                VN,
                F,
                O,
        Keywords_End,
        End,
        Count,
}

Token :: struct {
        kind : Token_Kind,
        value : []u8,
}

is_end_of_line :: proc(char: u8) -> bool {
        return char == '\n' || char == '\r'
}

is_spacing :: proc(char: u8) -> bool {
        return char == ' ' || char == '\t' || char == '\v' || char == '\f'
}

is_whitespace :: proc(char: u8) -> bool {
        return is_end_of_line(char) || is_spacing(char)
}

is_letter :: proc(char: u8) -> bool {
        return char >= 'a' && char <= 'z' || char >= 'A' && char <= 'Z'
}

is_digit :: proc(char: u8) -> bool {
        return char >= '0' && char <= '9'
}

is_alphanumeric :: proc(char: u8) -> bool {
        return is_letter(char) || is_digit(char)
}

advance_char :: proc(t: ^Tokenizer) {
        t.offset += 1
        
        if int(t.offset) >= len(t.data) {
                t.end_of_file = true
                return
        }
        
        t.char = t.data[t.offset]
}

undo_char :: proc(t: ^Tokenizer) {
        t.offset -= 1
        
        if int(t.offset) < 0 {
                assert(false, "This shouldn't happen.")
                t.offset = 0
        }
        
        t.char = t.data[t.offset]
}

scan_identifier :: proc(t: ^Tokenizer) -> []u8 {
        offset := t.offset
        
        for !t.end_of_file && (is_letter(t.char) || is_digit(t.char) || t.char == '_' || t.char == '.' || t.char == '-') {
                advance_char(t)
        }
        
        return t.data[offset:t.offset]
}

scan_number :: proc(t: ^Tokenizer) -> (kind: Token_Kind, s: []u8) {
        offset := t.offset
        
        decimal_points := 0
        for i := 0; !t.end_of_file && (is_digit(t.char) || t.char == '.' || t.char == '+' || t.char == '-'); i += 1 {
                decimal_points += t.char == '.'
                
                if (decimal_points > 1) || (i > 0 && (t.char == '+' || t.char == '-')){
                        undo_char(t)
                        break
                }
                
                advance_char(t)
        }
        
        assert(decimal_points == 0 || decimal_points == 1)
        kind = decimal_points == 1 ? .Float : .Integer
        
        return kind, t.data[offset:t.offset]
}

scan_comment :: proc(t: ^Tokenizer) {
        for !is_end_of_line(t.char) {
                advance_char(t)
        }
        for is_end_of_line(t.char) {
                advance_char(t)
        }
}

// TODO: this is not up to date; compare scan_identifier
is_obj_identifier :: proc(str: string) -> bool {
        if len(str) == 0 {
                return false
        }
        
        is_identifier: bool
        is_identifier = is_letter(str[0])
        for i := 1; i < len(str); i += 1 {
                is_identifier &= is_alphanumeric(str[i])
        }
        return is_identifier
}

is_obj_float :: proc(str: string) -> bool {
        if len(str) == 0 {
                return false
        }
        
        is_float: bool
        point_count := 0
        
        is_float = '+' == str[0] || '-' == str[0] || is_digit(str[0])
        if '.' == str[0] {
                point_count += 1
                is_float = true
        }
        
        for i := 1; i < len(str); i += 1 {
                if '.' == str[i] {
                        point_count += 1
                        is_float &= (point_count == 1)
                } else {
                        is_float &= is_digit(str[i])
                }
        }
        
        return is_float
}

is_obj_integer :: proc(str: string) -> bool {
        if len(str) == 0 {
                return false
        }
        
        is_int: bool
        if '+' == str[0] || '-' == str[0] || is_digit(str[0]) {
                is_int = true
        }
        
        for i := 1; i < len(str); i += 1 {
                is_int &= is_digit(str[i])
        }
        
        return is_int
}

keywords := [?]string{
        "v",
        "vt",
        "vn",
        "f",
        "o",
}
#assert(len(keywords) == cast(int)(Token_Kind.Keywords_End - Token_Kind.Keywords_Begin) - 1, 
        "The keywords slice does not contain all keywords")

Parser :: struct {
        tokens: []Token,
        tok: Token,
        index: i32,
}

advance_token :: proc(p: ^Parser) {
        p.index += 1
        if int(p.index) < len(p.tokens) {
                p.tok = p.tokens[p.index]
        }
}

expect :: proc(p: ^Parser, kind: Token_Kind, min: int, max: int) -> bool {
        for i in 0..<max {
                if p.tok.kind == kind {
                        advance_token(p)
                } else {
                        if i < min {
                                fmt.println("Error while parsing: Expected token of kind %d.", kind)
                                assert(false)
                                return false
                        }
                }
        }
        return true
}

get_index :: proc(model: ^Model, vertex: ^Vertex) -> int {
        for v, i in model.vertex_array {
                if v == vertex^ {
                        return i
                }
        }
        return -1
}

parse_obj :: proc(data: []u8) -> (model: Model, success: bool) {
        // 
        // TOKENIZATION
        // 
        t := Tokenizer{data, data[0], 0, false}
        
        tokens := make([dynamic]Token, 0, 4096)
        defer delete(tokens)
        
        attrib_counts := [len(keywords)]int{}
        
        line_count := 0
        
        for !t.end_of_file {
                token := Token{}
                switch c := t.char; true {
                case is_letter(c):
                        s := scan_identifier(&t)
                        
                        token.kind = .Identifier
                        token.value = s
                        
                        check_for_keyword: for i := 0; i < len(keywords); i += 1 {
                                if keywords[i] == string(s) {
                                        attrib_counts[i] += 1
                                        token.kind = .Keywords_Begin + cast(Token_Kind)(1 + i)
                                        assert(token.kind < .Keywords_End)
                                        break check_for_keyword
                                }
                        }
                        
                        append(&tokens, token)
                        
                case is_digit(c), c == '.', c == '+', c == '-':
                        kind, s := scan_number(&t)
                        token.kind = kind
                        token.value = s
                        
                        append(&tokens, token)
                        
                case c == '/':
                        token.kind = .Slash
                        token.value = t.data[t.offset:t.offset+1]
                        
                        append(&tokens, token)
                        
                        advance_char(&t)
                        
                case c == '#':
                        advance_char(&t)
                        scan_comment(&t)
                        
                case is_end_of_line(c):
                        line_count += 1
                        advance_char(&t)
                        if is_end_of_line(t.char) {
                                advance_char(&t)
                        }
                        
                case is_whitespace(c):
                        advance_char(&t)
                        
                case:
                        fmt.println("Error while parsing: Unrecognized symbol at line %d.", line_count)
                        assert(false)
                        return model, false
                }
        }
        append(&tokens, Token{.End, {}})
        
        //
        // PARSING
        //
        p := Parser{tokens[:], tokens[0], 0}
        
        keywords_begin := cast(int)Token_Kind.Keywords_End - 1
        positions := make([dynamic][4]f32, 0, attrib_counts[keywords_begin - cast(int)Token_Kind.V])
        tex_coords := make([dynamic][3]f32, 0, attrib_counts[keywords_begin - cast(int)Token_Kind.VT])
        normals := make([dynamic][3]f32, 0, attrib_counts[keywords_begin - cast(int)Token_Kind.VN])
        defer delete(normals)
        defer delete(tex_coords)
        defer delete(positions)
        
        model.vertex_array = make([dynamic]Vertex)
        model.index_array = make([dynamic]u32)

        for p.tok.kind != .End {
                if p.tok.kind <= .Keywords_Begin || p.tok.kind >= .Keywords_End {
                        fmt.println("Error while parsing: Expected a keyword.")
                        assert(false)
                        return model, false
                }
                assert(.Keywords_Begin < p.tok.kind && p.tok.kind < .Keywords_End)
                
                kind := p.tok.kind
                advance_token(&p)
                
                #partial switch kind {
                case .V:
                        // parse v
                        position := [4]f32{}
                        for i in 0..<4 {
                                if p.tok.kind == .Float {
                                        position[i] = cast(f32)strconv.atof(transmute(string)p.tok.value)
                                        advance_token(&p)
                                } else {
                                        if i < 3 {
                                                fmt.println("Error while parsing: Expected token of kind Float.")
                                                assert(false)
                                                return model, false
                                        }
                                }
                        }
                        append(&positions, position)
                        
                case .VT:
                        // parse vt
                        tex_coord := [3]f32{}
                        for i in 0..<3 {
                                if p.tok.kind == .Float {
                                        tex_coord[i] = cast(f32)strconv.atof(transmute(string)p.tok.value)
                                        advance_token(&p)
                                } else {
                                        if i < 1 {
                                                fmt.println("Error while parsing: Expected token of kind Float.")
                                                assert(false)
                                                return model, false
                                        }
                                }
                        }
                        append(&tex_coords, tex_coord)
                        
                case .VN:
                        // parse vn
                        normal := [3]f32{}
                        for i in 0..<3 {
                                if p.tok.kind == .Float {
                                        normal[i] = cast(f32)strconv.atof(transmute(string)p.tok.value)
                                        advance_token(&p)
                                } else {
                                        fmt.println("Error while parsing: Expected token of kind Float.")
                                        assert(false)
                                        return model, false
                                }
                        }
                        append(&normals, normal)
                        
                case .F:
                        // parse f
                        poly_count := 0
                        pidx, uvidx, nidx: i32 = 0, 0, 0
                        for p.tok.kind == .Integer && p.tok.kind != .End {
                                poly_count += 1

                                if poly_count > 3 {
                                        fmt.println("Error while parsing: Only triangle meshes supported for now.")
                                        assert(false)
                                        return model, false
                                }

                                if p.tok.kind == .Integer {
                                        pidx = cast(i32)strconv.atoi(transmute(string)p.tok.value)
                                        advance_token(&p)
                                } else {
                                        fmt.println("Error while parsing: Expected a token of kind Integer.")
                                        assert(false)
                                        return model, false
                                }

                                if p.tok.kind == .Slash {
                                        advance_token(&p)
                                        if p.tok.kind == .Integer {
                                                uvidx = cast(i32)strconv.atoi(transmute(string)p.tok.value)
                                                advance_token(&p)
                                                if p.tok.kind == .Slash {
                                                        advance_token(&p)
                                                        if p.tok.kind == .Integer {
                                                                nidx = cast(i32)strconv.atoi(transmute(string)p.tok.value)
                                                                advance_token(&p)
                                                        } else {
                                                                fmt.println("Error while parsing: Expected a token of kind Integer.")
                                                                assert(false)
                                                                return model, false
                                                        }
                                                }
                                        } else if p.tok.kind == .Slash {
                                                advance_token(&p)
                                                if p.tok.kind == .Integer {
                                                        nidx = cast(i32)strconv.atoi(transmute(string)p.tok.value)
                                                        advance_token(&p)
                                                } else {
                                                        fmt.println("Error while parsing: Expected a token of kind Integer.")
                                                        assert(false)
                                                        return model, false
                                                }
                                        } else {
                                                fmt.println("Error while parsing: Expected a token of kind Integer or Slash.")
                                                assert(false)
                                                return model, false
                                        }
                                }

                                vertex := Vertex{positions[pidx-1], tex_coords[uvidx-1], normals[nidx-1]}
                                index := get_index(&model, &vertex)
                                if index < 0 {
                                        append(&model.index_array, cast(u32)len(model.vertex_array))
                                        append(&model.vertex_array, vertex)
                                } else {
                                        append(&model.index_array, cast(u32)index)
                                }
                        }

                        if poly_count != 3 {
                                fmt.println("Error while parsing: Only triangle meshes supported for now.")
                                assert(false)
                                return model, false
                        }
                   
                case .O:
                        if p.tok.kind != .Identifier {
                                fmt.println("Error while parsing: Expected token of kind Identifier.")
                                assert(false)
                                return model, false
                        }
                        // TODO
                        advance_token(&p)
                        
                case:
                        fmt.println("Error while parsing: Unexpected token.")
                        assert(false)
                        return model, false
                }
        }
        
        return model, true
}

load_model :: proc(filename: string) -> (model: Model, success: bool) {
        data := os.read_entire_file_from_filename(filename) or_return
        defer delete(data)
        return parse_obj(data)
}
