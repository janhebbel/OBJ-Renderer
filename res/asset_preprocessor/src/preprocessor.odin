package assets

import "core:os"
import "core:strings"
import "core:fmt"

import obj "pkg:obj"

output_file_extension :: "asset"

// path_get_filename :: proc(path: string) -> string {
//         start, end: int = 0, 0
//         for char, index in path {
//                 if char == '\\' || char == '/' {
//                         start = index + 1
//                 }
//                 else if char == '.' {
//                         end = index - 1
//                 }
//         }
//         return path[start:end]
// }

print_usage :: proc() {
        fmt.println("Usage: assetpp [options] [path].")
        fmt.println("Possible options are:")
        fmt.println("    --reprocess - reprocess all specified files instead of skipping them")
}

process_asset :: proc(path: string) {
        path_without_extension := strings.split(path, ".")[0]
        processed_file_path := strings.concatenate({path_without_extension, output_file_extension})
        if os.exists(processed_file_path) { // skip file if processed version already exists
                return
        }

        data, success := os.read_entire_file(path)
        if !success {
                fmt.println("Failed to read file %s!", path)
                return
        }
        defer delete(data)

        model: obj.Model
        success = obj.parse(data, &model)
        if !success {
                fmt.println("Failed to parse the file %s!", path)
                return
        }
        defer obj.release(model)

        file, err := os.open(processed_file_path, os.O_CREATE | os.O_WRONLY)
        if err != nil {
                fmt.println("Failed to create file %s!", processed_file_path)
                return
        }
        defer os.close(file)
}

main :: proc() {
        if len(os.args) <= 1 {
                fmt.println("At least one path to a file needs to specified.\n")
                print_usage()
                return
        }

        reprocess := false

        for i in 1..<len(os.args)-1 {
                switch(os.args[i]) {
                case "--reprocess":
                        reprocess = true
                }
        }

        file := os.args[len(os.args)-1]

        fh, err := os.open(file)
        if err != nil {
                fmt.println("Failed to open %s!", file)
                return
        }
        defer os.close(fh)

        file_infos, err2 := os.read_dir(fh, 0)
        if err2 != nil {
                fmt.println("Failed to read directory %s!", file)
                return
        }

        for file_info in file_infos {
                ext := strings.split(file_info.name, ".")
                assert(len(ext) == 1 || len(ext) == 2)
                if len(ext) >= 2 && ext[1] == "obj" {
                        // check if equivalent processed file exists already and skip, unless reprocess is specified
                }
        }
}
