(* Specialized curriculum vitae page that lists experience. *)

open Yocaml

(* An experience item for a CV. *)
module Experience = struct
  let entity_name = "Experience"

  type t =
    { role : string
    ; company : string
    ; skills : string list
    ; start_date : Archetype.Datetime.t
    ; end_date : Archetype.Datetime.t option
    }

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
end

(* Used to fetch experience for the CV. *)
module Experiences = struct
  let sort_by_date ?(increasing = false) experiences =
    List.sort
      (fun (a, _) (b, _) ->
         let r = Datetime.compare (Experience.date a) (Experience.date b) in
         if increasing then r else ~-r)
      experiences

  let fetch
        (module P : Required.DATA_PROVIDER)
        ?increasing
        ?(filter = fun x -> x)
        ?(on = `Source)
        ~where
        path
    =
    let open Task in
    Pipeline.fetch
      ~only:`Files
      ~where
      ~on
      (fun file ->
         let open Eff in
         let+ metadata, content =
           Eff.read_file_with_metadata (module P) (module Experience) ~on file
         in
         metadata, Yocaml_markdown.from_string_to_html content)
      path
    >>| fun experiences -> experiences |> sort_by_date ?increasing |> filter
end

type t =
  { page : Archetype.Page.t
  ; experiences : (Experience.t * string) list
  }

let entity_name = "CV"
let neutral = Metadata.required entity_name
let with_page ~page ~experiences = { page; experiences }

let normalize { page; experiences } =
  Archetype.Page.normalize page
  @ Data.
      [ ( "experiences"
        , list_of
            (fun (exp, body) ->
               record (("body", string body) :: Experience.normalize exp))
            experiences )
      ; "has_experiences", bool (experiences <> [])
      ]
