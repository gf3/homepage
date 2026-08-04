(* Specialized curriculum vitae page that lists experience. *)

open Yocaml

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
