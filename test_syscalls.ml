open Printf
open Syscalls

let read_syscall_num = 0n
let open_syscall_num = 2n
let close_syscall_num = 3n

(* let's say our 'page' containing the filename is mapped at 0x1000 *)
let filename_memory_location = 0x1000

let rec supply_syscall_footprint memory state extents = 
  (* This represents whatever process you go through to
     acquire the footprint data from the simulator *)
  let supply_one_footprint extent = begin
      assert ((Nativeint.to_int extent.base) >= filename_memory_location);
      assert (Nativeint.to_int (Nativeint.add extent.base extent.length)
              <= filename_memory_location + (Bigarray.Array1.dim memory));
      {
        base = extent.base;
        length = extent.length;
        data = Some (Bigarray.Array1.sub memory ((Nativeint.to_int extent.base) - filename_memory_location)
                                   (Nativeint.to_int extent.length))
      }
                                    end in
  match Syscalls.continue_syscall state (List.map supply_one_footprint extents) with
  | Finished (retval, write_extents) -> Finished (retval, write_extents)
  | MoreDataNeeded (state, extents) -> supply_syscall_footprint memory state extents


let do_one_syscall memory env num args =
  let result = Syscalls.start_syscall env num args in
  match result with 
  | MoreDataNeeded (state, extents) ->
     (match supply_syscall_footprint memory state extents with
     | MoreDataNeeded (_, _) -> assert false
     | x -> x)
  | x -> x

let string_to_bigarray s =
  let bigarr = Bigarray.Array1.create Bigarray.char Bigarray.c_layout ((String.length s) + 1) in begin
      for i = 0 to (String.length s) - 1 do
        bigarr.{i} <- s.[i]
      done;
      bigarr.{(String.length s)} <- '\000';
      bigarr
    end
  
let string_from_bigarray arr =
  let s = String.make (Bigarray.Array1.dim arr) '\000' in begin
      for i = 0 to (Bigarray.Array1.dim arr) - 1 do
        s.[i] <- arr.{i}
      done;
      s
    end


let extent_to_string extent =
  sprintf "(extent: base = 0x%nx, length = 0x%nx, data = %S)" extent.base extent.length
          (match extent.data with
           | None -> "[]"
           | Some data -> string_from_bigarray data)


let extent_list_to_string extent_list =
  String.concat "" ["["; (String.concat ", " (List.map (fun extent -> extent_to_string extent) extent_list)); "]"]


let main =
  if (Array.length Sys.argv) <> 3 then
    failwith "usage: ocaml_test_syscalls spec.idl file_to_read"
  else let footprints = Sys.argv.(1) in
       let filename = Sys.argv.(2) in
       match Syscalls.load_footprints_from_file footprints with
       | None -> failwith "*** couldn't open footprints"
       | Some env -> begin
           print_endline "*** Got footprints." ;
           printf "*** %s is the filename\n" filename;    
           let memory = (string_to_bigarray filename) in begin
               let open_args = [| Nativeint.of_int filename_memory_location |] in
               match do_one_syscall memory env open_syscall_num open_args with
               | MoreDataNeeded (_, _) -> assert false
               | Finished (fd, _) -> begin
                   printf "Got FD retval from open(): %nd\n" fd;
                   match do_one_syscall memory env read_syscall_num [| fd; 1n; 10n |] with
                   | MoreDataNeeded (_, _) -> assert false
                   | Finished (read_length, write_extents) -> begin
                       printf "*** Read %nd bytes of 10 from fd %nd: %s\n"
                              read_length fd (extent_list_to_string write_extents);
                       printf "Closing it\n";
                       do_one_syscall memory env close_syscall_num [| fd |]
                     end
                 end
             end
         end
                       
