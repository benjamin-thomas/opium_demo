(*

  Quickly test the endpoints by copy/pasting the following:

for PATH_ in dog cat "dog/1" "cat/1";do curl -w " => %{http_code}\\n" localhost:4000/$PATH_;done && \
echo "---" && \
for VERB in GET POST PUT DELETE;do curl -w " => %{http_code}\\n" -X $VERB localhost:4000/dog/1;done && \
http localhost:4000/person/John/99/pg && \
http localhost:4000/person/John/99/sqlite && \
http POST localhost:4000/person name="Jane Doe" age:=98
*)

open Opium

module Person = struct
  type t = { name : string; age : int }

  let yojson_of_t t = `Assoc [ ("name", `String t.name); ("age", `Int t.age) ]

  let t_of_yojson yojson =
    match yojson with
    | `Assoc [ ("name", `String name); ("age", `Int age) ] -> { name; age }
    | _ -> failwith "invalid person json"
  ;;
end

module Q = struct
  open Caqti_request.Infix
  open Caqti_type.Std

  let person =
    let encode { Person.name; age } = Ok (name, age) in
    let decode (name, age) = Ok { Person.name; age } in
    let rep = tup2 string int in
    custom ~encode ~decode rep
  ;;

  let select_person =
    (unit ->? person)
    @@ "SELECT fname || ' ' || lname AS name, age FROM person WHERE id < 99 \
        LIMIT 1"
  ;;
end

let select_person (module Db : Caqti_lwt.CONNECTION) =
  Db.find_opt Q.select_person ()
;;

let create_pool conn_str =
  Caqti_lwt.connect_pool ~max_size:3 (Uri.of_string conn_str) |> function
  | Ok pool -> pool
  | Error err -> failwith (Caqti_error.show err)
;;

let pg_pool = create_pool "postgresql://localhost:5432/opium_demo"

let sqlite_pool =
  let conn_str = Printf.sprintf "sqlite3://%s/db.sqlite" (Unix.getcwd ()) in
  create_pool conn_str
;;

type error = Database_error of string

(* Helper method to map Caqti errors to our own error type.
   val or_error : ('a, [> Caqti_error.t ]) result Lwt.t -> ('a, error) result Lwt.t *)
let or_error m =
  match%lwt m with
  | Ok a -> Ok a |> Lwt.return
  | Error e -> Error (Database_error (Caqti_error.show e)) |> Lwt.return
;;

let not_found _req = Response.of_plain_text ~status:`Not_found "" |> Lwt.return

module MethodMap = Map.Make (struct
  type t = Method.t

  let compare a b = compare a b
end)

let routed_handler routes req =
  match MethodMap.find_opt req.Request.meth routes with
  | None -> Lwt.return (Response.make ~status:`Method_not_allowed ())
  | Some router -> (
      match Routes.match' router ~target:req.Request.target with
      | Routes.NoMatch -> not_found req
      | FullMatch r -> r req
      | MatchWithTrailingSlash r ->
          (* This branch indicates that incoming request's path finishes with a
             trailing slash. If you app needs to distinguish trailing slashes
             (/a/b vs /a/b/), this is where you'd write something to handle the
             use-case *)
          r req)
;;

let get_many_dogs () =
  Routes.route
    Routes.(s "dog" /? nil)
    (fun _ -> Lwt.return @@ Response.of_plain_text "GET many dogs")
;;

let get_one_dog () =
  Routes.route
    Routes.(s "dog" / int /? nil)
    (fun id _req ->
      Lwt.return
      @@ Response.of_plain_text
      @@ Printf.sprintf "GET one dog (ID=%d)" id)
;;

let post_one_dog () =
  Routes.route
    Routes.(s "dog" / int /? nil)
    (fun id _req ->
      Lwt.return
      @@ Response.of_plain_text
      @@ Printf.sprintf "POST one dog (ID=%d)" id)
;;

let put_one_dog () =
  Routes.route
    Routes.(s "dog" / int /? nil)
    (fun id _req ->
      Lwt.return
      @@ Response.of_plain_text
      @@ Printf.sprintf "PUT one dog (ID=%d)" id)
;;

let delete_one_dog () =
  Routes.route
    Routes.(s "dog" / int /? nil)
    (fun id _req ->
      Lwt.return
      @@ Response.of_plain_text
      @@ Printf.sprintf "DELETE one dog (ID=%d)" id)
;;

let delete_many_dog () =
  Routes.route
    Routes.(s "dog" /? nil)
    (fun _ -> Lwt.return @@ Response.of_plain_text "DELETE many dogs")
;;

let get_many_cats () =
  Routes.route
    Routes.(s "cat" /? nil)
    (fun _ -> Lwt.return @@ Response.of_plain_text "GET many cats")
;;

let get_one_cat () =
  Routes.route
    Routes.(s "cat" / int /? nil)
    (fun id _req ->
      Lwt.return
      @@ Response.of_plain_text
      @@ Printf.sprintf "GET one cat (ID=%d)" id)
;;

let dog_routes =
  [ (`GET,    [ get_many_dogs ()
              ; get_one_dog ()
              ]
    )
  ; (`POST,   [ post_one_dog () ])
  ; (`PUT,    [ put_one_dog (); put_one_dog () ])
  ; (`DELETE, [ delete_many_dog (); delete_one_dog () ])
  ] [@@ocamlformat "disable"]

let cat_routes =
  [ (`GET,    [ get_many_cats ()
              ; get_one_cat ()
              ]
    )
  ; (`POST,   [])
  ; (`PUT,    [])
  ; (`DELETE, [])
  ] [@@ocamlformat "disable"]

(*
  http localhost:4000/person/John/99/pg <-- query postgresql database
  http localhost:4000/person/John/99/sq <-- query sqlite database
  http localhost:4000/person/John/99/whatever <-- query sqlite database (FIXME: clean this up)
*)
let search_person () =
  Routes.(route (s "person" / str / int / str /? nil))
  @@ fun name age db _req ->
  let () = Logs.info (fun m -> m "Searching person: %s" name) in
  let _p1 = Person.yojson_of_t { name; age } in
  let pool =
    if db = "pg" then
      pg_pool
    else
      sqlite_pool
  in
  let%lwt (res : (Person.t option, error) result) =
    Caqti_lwt.Pool.use select_person pool |> or_error
  in
  match res with
  | Error (Database_error err) ->
      Lwt.return
      @@ Response.of_plain_text
      @@ Printf.sprintf "Oh noes, got an error! (%s)" err
  | Ok None -> Lwt.return @@ Response.of_plain_text "Oops, person not found!"
  | Ok (Some p) ->
      let p2 = Person.yojson_of_t p in
      Lwt.return @@ Response.of_json @@ p2
;;

let post_person () : (Rock.Request.t -> Rock.Response.t Lwt.t) Routes.route =
  Routes.(route (s "person" /? nil)) @@ fun req ->
  let open Lwt.Syntax in
  let+ json = Request.to_json_exn req in
  let person = Person.t_of_yojson json in
  Logs.info (fun m -> m "Received person: %s" person.name)
  ; Response.of_json (`Assoc [ ("message", `String "Person saved") ])
;;

let person_routes =
  [ (`GET,  [ search_person () ])
  ; (`POST, [ post_person () ])
  ] [@@ocamlformat "disable"]

let merge_routes =
  List.fold_left
    (fun acc routes ->
      List.fold_left
        (fun acc (meth, routes) ->
          let curr_routes =
            try List.assoc meth acc with
            | Not_found -> []
          in
          (meth, routes @ curr_routes) :: List.remove_assoc meth acc)
        acc routes)
    []
;;

let build_router =
  List.fold_left
    (fun meth_map (meth, handlers) ->
      MethodMap.add meth (Routes.one_of handlers) meth_map)
    MethodMap.empty
;;

let all_resources_routes =
  merge_routes [ dog_routes; cat_routes; person_routes ]
;;

let handle_routes req =
  routed_handler (build_router @@ all_resources_routes) req
;;

let log_level = Some Logs.Debug

let set_logger () =
  Logs.set_reporter (Logs_fmt.reporter ())
  ; Logs.set_level log_level
;;

(*
  TODO: maybe see this tutorial:
    https://shonfeder.gitlab.io/ocaml_webapp
*)

let () =
  set_logger ()
  ; print_newline ()
  ; App.empty |> App.all "**" handle_routes |> App.run_command
;;
