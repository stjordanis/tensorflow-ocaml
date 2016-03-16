open Core.Std
exception Not_supported of string

let value_exn = function
  | None -> raise (Not_supported "value_exn")
  | Some value -> value

let ops_file = "gen_ops/ops.pb"
let output_file = "generated_ops"

let read_type types (arg : Op_def_piqi.op_def_arg_def) =
  match arg.type_attr with
  | Some type_attr ->
    let alpha =
      let type_attr = String.uncapitalize type_attr in
      if type_attr = "type"
      then "'type'"
      else "'" ^ type_attr
    in
    begin
      match List.Assoc.find types type_attr with
      | None -> alpha
      | Some types ->
        String.concat types ~sep:" | "
        |> fun types -> Printf.sprintf "([< %s ] as %s)" types alpha
    end
  | None ->
    match arg.type_ with
    | Some `dt_float -> "[ `float ]"
    | Some `dt_double -> "[ `double ]"
    | Some _ -> raise (Not_supported "unknown output type")
    | None -> raise (Not_supported "no output type")

let extract_types (attrs : Op_def_piqi.op_def_attr_def list) =
  List.filter_map attrs (fun (attr : Op_def_piqi.op_def_attr_def) ->
    match attr.name, attr.type_ with
    | Some name, Some "type" ->
      let allowed_values =
        match attr.allowed_values with
        | None -> []
        | Some allowed_values ->
          match allowed_values.list with
          | None -> []
          | Some allowed_values ->
            List.filter_map allowed_values.type_ (fun typ ->
              match typ with
              | `dt_float -> Some "`float"
              | `dt_double -> Some "`double"
              | _ -> None)
      in
      if allowed_values = []
      then None
      else Some (name, allowed_values)
    | _ -> None)

let gen_mli ops =
  let out_channel = open_out (Printf.sprintf "%s.mli" output_file) in
  let handle_one_op (op : Op_def_piqi.Op_def.t) =
    let buffer = Buffer.create 128 in
    let p s =
      Printf.ksprintf (fun line ->
        Buffer.add_string buffer line;
        Buffer.add_char buffer '\n') s
    in
    let name = value_exn op.name in
    try
      let types = extract_types op.attr in
      let input_types = List.map op.input_arg ~f:(read_type types) in
      let output_type =
        match op.output_arg with
        | [] -> "[ `unit ]"
        | _ :: _ :: _ -> raise (Not_supported "multiple outputs")
        | [ output_arg ] -> read_type types output_arg
      in
      p "val %s" (String.uncapitalize name);
      p "  :  ?name:string";
      List.iter input_types ~f:(fun typ -> p "  -> %s Node.t" typ);
      p "  -> %s Node.t" output_type;
      p "";
      Buffer.output_buffer out_channel buffer
    with
    | Not_supported str ->
      Printf.printf "Error reading op %s: %s.\n%!" name str
  in
  List.iter ops ~f:handle_one_op;
  close_out out_channel

let gen_ml _ops = ()

let run () =
  let ops =
    open_in ops_file
    |> Piqirun.init_from_channel
    |> Op_def_piqi.parse_op_list
    |> fun op_list -> op_list.op
  in
  Printf.printf "Found %d ops.\n%!" (List.length ops);
  gen_mli ops;
  gen_ml ops

let () = run ()
