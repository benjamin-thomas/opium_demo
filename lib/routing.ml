(*
  dune utop
  > Opium_demo.Routing.hello;;
*)
(*
let add_route () = Routes.(s "add" / int / int /? nil)

let sum_route () =
  Routes.(add_route () @--> fun a b -> Printf.sprintf "%d" (a + b))
;; *)

(*
let string_of_add_route = Routes.string_of_path (add_route ())
let hello = "world"
 *)

let sum () = Routes.(s "sum" / int / int /? nil)

let for_opium =
  (* "/sum/:int/:int" *)
  Routes.string_of_path (sum ())
;;

let for_browser =
  (* "/sum/1/2" *)
  Routes.sprintf (sum ()) 1 2
;;

let sum_route () : int Routes.route = Routes.(sum () @--> fun a b -> a + b)

open Lwt.Syntax

let sum_handler _req : Rock.Response.t Lwt.t =
  let open Routes in
  let cmd : unit Lwt.t = Lwt_unix.sleep 1.0 in
  let* () = cmd in
  let _res : int route = sum_route () in
  Lwt.return @@ Opium.Response.of_plain_text "TODO"
;;
