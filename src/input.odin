package flightsim

@(private="file")
key_down := [256]bool{}
@(private="file")
key_was_down := [256]bool{}

key_event :: proc "c" (key: rune, down: bool) {
        key_was_down[key] = key_down[key]
        key_down[key] = down
}

update_key_was_down :: proc() {
        for _, key in key_down {
                key_event(cast(rune)key, key_down[key])
        }
}

clear_keyboard_state :: proc "c" () {
        for _, key in key_down {
                key_down[key] = false
                key_was_down[key] = false
        }
}

is_down :: proc(key: rune) -> bool {
        return key_down[key]
}

is_down_once :: proc(key: rune) -> bool {
        return (key_down[key] && !key_was_down[key])
}
