open Mirage

(* If the Unix `MODE` is set, the choice of configuration changes:
   MODE=crunch (or nothing): use static filesystem via crunch
   MODE=fat: use FAT and block device (run ./make-fat-images.sh) *)
let mode =
  try match String.lowercase (Unix.getenv "FS") with
    | "fat" -> `Fat
    | _     -> `Crunch
  with Not_found -> `Crunch

let fat_ro dir =
  kv_ro_of_fs (fat_of_files ~dir ())

(* In Unix mode, use the passthrough filesystem for files to avoid a huge
   crunch build time *)
let static =
  match mode, get_mode () with
  | `Fat,    _     -> fat_ro "../static"
  | `Crunch, `Xen  -> crunch "../static"
  | `Crunch, `Unix -> direct_kv_ro "../static"

let net =
  try match Sys.getenv "NET" with
    | "direct" -> `Direct
    | "socket" -> `Socket
    | _        -> `Direct
  with Not_found -> `Direct

let dhcp =
  try match Sys.getenv "DHCP" with
    | "" -> false
    | _  -> true
  with Not_found -> false

let stack console =
  match net, dhcp with
  | `Direct, true  -> direct_stackv4_with_dhcp console tap0
  | `Direct, false -> direct_stackv4_with_default_ipv4 console tap0
  | `Socket, _     -> socket_stackv4 console [Ipaddr.V4.any]

let port =
  try match Sys.getenv "PORT" with
    | "" -> 8080
    | s  -> int_of_string s
  with Not_found -> 8080

let server =
  http_server port (stack default_console)

let main =
  let libraries = [ "cow.syntax"; "cowabloga" ] in
  let packages = [ "cow";"cowabloga" ] in
  foreign ~libraries ~packages "Server.Main"
    (console @-> kv_ro @-> http @-> job)

let () =
  register "tutorial" [
    main $ default_console $ static $ server
  ]
