(* An experience item for a CV. *)

open Yocaml

type t =
  { role : string
  ; company : string
  ; skills : string list
  ; start_date : Archetype.Datetime.t
  ; end_date : Archetype.Datetime.t option
  }

let entity_name = "Experience"
let neutral = Metadata.required entity_name

let validate =
  let open Data.Validation in
  record (fun fields ->
    let+ role = required fields "role" string
    and+ company = required fields "company" string
    and+ skills = required fields "skills" (list_of string)
    and+ start_date = required fields "start_date" Datetime.validate
    and+ end_date = optional fields "end_date" Datetime.validate in
    { role; company; skills; start_date; end_date })

let normalize { role; company; skills; start_date; end_date } =
  Data.
    [ "role", string role
    ; "company", string company
    ; "skills", list_of string skills
    ; "start_date", Datetime.normalize start_date
    ; "end_date", option Datetime.normalize end_date
    ; "has_end_date", bool (Option.is_some end_date)
    ]

let to_data t = Data.record (normalize t)
let date t = t.start_date
