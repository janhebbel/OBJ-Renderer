package assets

import "core:os"
import "core:strings"
import "core:fmt"
import "core:mem"

import obj "pkg:obj"

output_file_extension :: ".asset"

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

process_asset :: proc(path: string) -> bool {
        path_slice := strings.split(path, ".")
        defer delete(path_slice)
        name_without_ext := path_slice[0]
        processed_file_path := strings.concatenate({name_without_ext, output_file_extension})

        data, success := os.read_entire_file(path)
        if !success {
                fmt.println("Failed to read file %s!", path)
                return false
        }
        defer delete(data)

        model: obj.Model
        success = obj.parse(data, &model)
        if !success {
                fmt.println("Failed to parse the file %s!", path)
                return false
        }
        defer obj.release(model)

        file, err := os.open(processed_file_path, os.O_CREATE | os.O_WRONLY)
        if err != nil {
                fmt.println("Failed to create file %s!", processed_file_path)
                return false
        }
        defer os.close(file)

        bytes := mem.byte_slice(cast(rawptr)&model, size_of(model))
        bytes_written, err2 := os.write(file, bytes)
        if err2 != nil {
                fmt.println("Failed to write to %s!", processed_file_path)
                return false
        }
        assert(bytes_written == size_of(model))

        return true
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

        filename := os.args[len(os.args)-1]

        file, err := os.open(filename)
        if err != nil {
                fmt.println("Failed to open %s!", filename)
                return
        }
        defer os.close(file)

        dir_or_file_info, err2 := os.fstat(file)
        if err2 != nil {
                fmt.println("Failed to retrieve stats for %s!", filename)
                return
        }
        defer os.file_info_delete(dir_or_file_info)

        if dir_or_file_info.is_dir {
                file_infos, err3 := os.read_dir(file, 0)
                if err3 != nil {
                        fmt.println("Failed to read directory %s!", file)
                        return
                }
                defer os.file_info_slice_delete(file_infos)

                for file_info in file_infos {
                        ext := strings.split(file_info.name, ".")
                        defer delete(ext)
                        assert(len(ext) == 1 || len(ext) == 2)
                        if len(ext) >= 2 && ext[1] == "obj" {
                                path := strings.split(file_info.fullpath, ".")
                                assert(len(path) == 1 || len(path) == 2)
                                output_path := strings.concatenate({path[0], output_file_extension})

                                if !reprocess && os.exists(output_path) {
                                        continue
                                }

                                process_asset(file_info.fullpath)

                                delete(output_path)
                        }
                }
        } else {
                file_info := dir_or_file_info

                path_without_ext := strings.split(file_info.name, ".")
                assert(len(path_without_ext) == 1 || len(path_without_ext) == 2)
                output_path := strings.concatenate({path_without_ext[0], output_file_extension})
                defer delete(path_without_ext)
                defer delete(output_path)

                if !reprocess && os.exists(output_path) {
                        return
                }

                process_asset(file_info.fullpath)
        }
}
