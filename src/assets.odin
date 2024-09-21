package flightsim

import "core:fmt"
import "core:os"

Vertex :: struct {
    position: [4]f32,
    uv: [2]f32,
    normal: [3]f32,
}

Model :: struct {
    vertex_array: ^Vertex,
    index_array: ^u32,
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
    
    for !t.end_of_file && (is_letter(t.char) || is_digit(t.char)) {
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

obj_parse :: proc(data: []u8) -> (model: Model, success: bool) {
    // 
    // LEXING
    // 
    tokens : [dynamic]Token
    defer delete(tokens)
    reserve(&tokens, size_of(Token) * 1024)
    
    t := Tokenizer{data, data[0], 0, false}
    
    for !t.end_of_file {
        token := Token{}
        switch c := t.char; true {
        case is_letter(c):
            s := scan_identifier(&t)
            
            token.kind = .Identifier
            token.value = s
            
            check_for_keyword: for i := 0; i < len(keywords); i += 1 {
                if keywords[i] == string(s) {
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
            
        case is_whitespace(c):
            advance_char(&t)
            
        case:
            fmt.println("Unrecognized symbol.")
            return model, false
        }
    }
    
    return model, true
}

load_model :: proc(filename: string) -> (model: Model, success: bool) {
    data := os.read_entire_file_from_filename(filename) or_return
    defer delete(data)
    return obj_parse(data)
}
