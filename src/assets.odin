package flightsim

import "core:os"
import "core:strings"
import "core:strconv"

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

Lexer :: struct {
    data: []u8,
    index: i32,
    end_of_file: bool,
}

Lexer_State :: enum {
    BEGIN,
    WHITESPACE,
    COMMENT,
    WORD,
    END,
}

Token_Type :: enum {
    NONE,
    FLOAT,
    INTEGER,
    IDENTIFIER,
    SLASH,
    KEYWORD_O,
    KEYWORD_V,
    KEYWORD_VT,
    KEYWORD_VN,
    KEYWORD_F,
}

Token :: struct {
    type : Token_Type,
    value : struct #raw_union {
        s: string,
        f: f64,
        i: int,
    },
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

is_alphabetic :: proc(char: u8) -> bool {
    return char >= 'a' && char <= 'z' || char >= 'A' && char <= 'Z'
}

is_numeric :: proc(char: u8) -> bool {
    return char >= '0' && char <= '9'
}

is_alphanumeric :: proc(char: u8) -> bool {
    return is_alphabetic(char) || is_numeric(char)
}

lexer_advance :: proc(lexer: ^Lexer, offset: i32 = 1) {
    lexer.index += offset
}

lexer_peek :: proc(lexer: ^Lexer) -> u8 {
    lexer.end_of_file = int(lexer.index) == len(lexer.data) - 1
    return lexer.data[lexer.index]
}

lexer_consume :: proc(lexer: ^Lexer) -> u8 {
    c := lexer_peek(lexer)
    lexer_advance(lexer)
    return c
}

lexer_get_word :: proc(lexer: ^Lexer) -> string {
    start, end : i32 = lexer.index, 0
    for !is_whitespace(lexer_peek(lexer)) {
        lexer_advance(lexer)
    }
    end = lexer.index
    //lexer_advance(lexer, end - start)
    return transmute(string)(lexer.data[start:end])
}

lexer_skip :: proc(lexer: ^Lexer, func: proc(char: u8) -> bool, mod: bool) {
    for mod == func(lexer_peek(lexer)) {
        lexer_advance(lexer)
    }
}

is_obj_identifier :: proc(str: string) -> bool {
    if len(str) == 0 {
        return false
    }
    
    is_identifier: bool
    is_identifier = is_alphabetic(str[0])
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
    
    is_float = '+' == str[0] || '-' == str[0] || is_numeric(str[0])
    if '.' == str[0] {
        point_count += 1
        is_float = true
    }
    
    for i := 1; i < len(str); i += 1 {
        if '.' == str[i] {
            point_count += 1
            is_float &= (point_count == 1)
        } else {
            is_float &= is_numeric(str[i])
        }
    }
    
    return is_float
}

is_obj_integer :: proc(str: string) -> bool {
    if len(str) == 0 {
        return false
    }
    
    is_int: bool
    if '+' == str[0] || '-' == str[0] || is_numeric(str[0]) {
        is_int = true
    }
    
    for i := 1; i < len(str); i += 1 {
        is_int &= is_numeric(str[i])
    }
    
    return is_int
}

obj_parse :: proc(data: []u8) -> (model: Model, success: bool) {
    // 
    // LEXING
    // 
    tokens : [dynamic]Token
    defer delete(tokens)
    reserve(&tokens, size_of(Token) * 1024)
    
    lexer := Lexer{data, 0, false}
    state : Lexer_State = .BEGIN
    for !lexer.end_of_file {
        switch state {
        case .BEGIN: 
            if is_whitespace(lexer_peek(&lexer)) {
                state = .WHITESPACE
            } else if is_alphanumeric(lexer_peek(&lexer)) {
                state = .WORD
            } else if '#' == lexer_peek(&lexer) {
                state = .COMMENT
            } else {
                assert(false, "Unrecognized character.")
                return model, false
            }
            
        case .WHITESPACE:
            lexer_skip(&lexer, is_whitespace, true)
            state = .BEGIN
            
        case .COMMENT:
            lexer_skip(&lexer, is_end_of_line, false)
            lexer_skip(&lexer, is_end_of_line, true)
            state = .BEGIN
            
        case .WORD:
            word := lexer_get_word(&lexer)
            type : Token_Type
            if 0 == strings.compare("o", word) {
                type = .KEYWORD_O
            } else if 0 == strings.compare("v", word) {
                type = .KEYWORD_V
            } else if 0 == strings.compare("vt", word) {
                type = .KEYWORD_VT
            } else if 0 == strings.compare("vn", word) {
                type = .KEYWORD_VN
            } else if 0 == strings.compare("f", word) {
                type = .KEYWORD_F
            }
            append(&tokens, Token{type, {}})
            
            token: Token
            #partial switch type {
            case .KEYWORD_O: 
                lexer_skip(&lexer, is_spacing, true)
                word = lexer_get_word(&lexer)
                
                if !is_obj_identifier(word) {
                    assert(false, "Expected an identifier.")
                    return model, false
                }
                
                token.type = .IDENTIFIER
                token.value.s = word
                append(&tokens, token)
                
            case .KEYWORD_V:
                for i := 0; i < 4; i += 1 {
                    lexer_skip(&lexer, is_spacing, true)
                    word = lexer_get_word(&lexer)
                    
                    if !is_obj_float(word) {
                        if i >= 3 { break }
                        
                        assert(false, "Expected a float.")
                        return model, false
                    }
                    
                    token.type = .FLOAT
                    token.value.f = strconv.atof(word)
                    append(&tokens, token)
                }
                
            case .KEYWORD_VT:
                for i := 0; i < 3; i += 1 {
                    lexer_skip(&lexer, is_spacing, true)
                    word = lexer_get_word(&lexer)
                    
                    if !is_obj_float(word) {
                        if i >= 1 { break }
                        
                        assert(false, "Expected a float.")
                        return model, false
                    }
                    
                    token.type = .FLOAT
                    token.value.f = strconv.atof(word)
                    append(&tokens, token)
                }
                
            case .KEYWORD_VN:
                for i := 0; i < 3; i += 1 {
                    lexer_skip(&lexer, is_spacing, true)
                    word = lexer_get_word(&lexer)
                    
                    if !is_obj_float(word) {
                        assert(false, "Expected a float.")
                        return model, false
                    }
                    
                    token.type = .FLOAT
                    token.value.f = strconv.atof(word)
                    append(&tokens, token)
                }
                
            case .KEYWORD_F:
                for i := 0; i < 3; i += 1 {
                    lexer_skip(&lexer, is_spacing, true)
                    word = lexer_get_word(&lexer)
                    
                    words, err := strings.split(word, "/", context.temp_allocator)
                    if err != nil {
                        assert(false, "Out of memory.")
                        return model, false
                    }
                    
                    if len(words) <= 0 {
                        assert(false, "No indices in face descriptor element. Format is v/vt/vn.")
                        return model, false
                    } else if len(words) > 3 {
                        assert(false, "Too many indices in face descriptor element. Format is v/vt/vn.")
                        return model, false
                    }
                    
                    for w in words {
                        if !is_obj_integer(w) {
                            assert(false, "Error while parsing f statement: Expected integer. Format is v/vt/vn.")
                            return model, false
                        }
                        
                        token.type = .INTEGER
                        token.value.i = strconv.atoi(w)
                        append(&tokens, token)
                    }
                }
                
                lexer_skip(&lexer, is_spacing, true)
                if !is_end_of_line(lexer_peek(&lexer)) {
                    assert(false, "Expected end of line. Only triangles supported for now.")
                    return model, false
                }
                
            case:
                assert(false, "Expected a keyword token type.")
                return model, false
            }
            
            state = .END
            
        case .END:
            lexer_skip(&lexer, is_spacing, true)
            if !is_end_of_line(lexer_consume(&lexer)) {
                assert(false, "Expected end of line character.")
                return model, false
            }
            lexer_skip(&lexer, is_end_of_line, true)
            
            state = .BEGIN
        }
        
        free_all(context.temp_allocator) 
    }
    return model, true
}

load_model :: proc(filename: string) -> (model: Model, success: bool) {
    data := os.read_entire_file_from_filename(filename) or_return
    defer delete(data)
    return obj_parse(data)
}
