module Name : sig
  type t
  val make_fresh : name:string -> t
  val to_string : t -> string
end = struct
  type t = string

  let cnt = ref 0
  let make_fresh ~name =
    incr cnt;
    Printf.sprintf "%s-%d" name !cnt

  let to_string t = t
end

module Type = struct
  type _ t =
    | Unit : [ `unit ] t
    | Float : [ `float ] t
    | Double : [ `double ] t
    | Int32 : [ `int32 ] t

  type p = P : _ t -> p

  let to_dt_type = function
    | P Unit -> assert false
    | P Float -> `dt_float
    | P Double -> `dt_double
    | P Int32 -> `dt_int32

  let of_dt_type = function
    | `dt_float -> Some (P Float)
    | `dt_double -> Some (P Double)
    | `dt_int32 -> Some (P Int32)
    | _ -> None
end

type attr =
  | String of string
  | Int of int
  | Float of float
  | Bool of bool
  | Type of Type.p
  | List of attr list

type 'a t =
  { name : Name.t
  ; op_name : string
  ; output_type : 'a Type.t
  ; inputs : p list
  ; attributes : (string * attr) list
  }
and p = P : _ t -> p