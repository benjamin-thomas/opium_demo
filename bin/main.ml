(*

  Quickly test the endpoints by copy/pasting the following:

  for PATH_ in dog cat "dog/1" "cat/1";do curl -w " => %{http_code}\\n" localhost:4000/$PATH_;done
  for VERB in GET POST PUT DELETE;do curl -w " => %{http_code}\\n" -X $VERB localhost:4000/dog/1;done
*)

open Opium

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

let all_resources_routes = merge_routes [ dog_routes; cat_routes ]

let handle_routes req =
  routed_handler (build_router @@ all_resources_routes) req
;;

let () = App.empty |> App.all "**" handle_routes |> App.run_command
