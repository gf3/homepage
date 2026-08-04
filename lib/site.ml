(** Site-wide configuration read from [content/site.yml] and exposed under the [site.*] namespace in templates. **)

open Yocaml

type t =
  { name : string
  ; author : string
  ; email : string
  ; url : string
  ; description : string
  ; lang : string
  ; og_image : string
  }

let entity_name = "Site"
let neutral = Metadata.required entity_name

let validate =
  let open Data.Validation in
  record (fun fields ->
    let+ name = required fields "name" string
    and+ author = required fields "author" string
    and+ email = required fields "email" string
    and+ url = required fields "url" string
    and+ description = required fields "description" string
    and+ lang = optional_or ~default:"en-CA" fields "lang" string
    and+ og_image = optional_or ~default:"" fields "og_image" string in
    { name; author; email; url; description; lang; og_image })

let normalize { name; author; email; url; description; lang; og_image } =
  Data.
    [ "name", string name
    ; "author", string author
    ; "email", string email
    ; "url", string url
    ; "description", string description
    ; "lang", string lang
    ; "og_image", string og_image
    ]

let to_data s = Data.record (normalize s)
let name s = s.name
let author s = s.author
let email s = s.email
let url s = s.url
let description s = s.description
let lang s = s.lang
let og_image s = s.og_image
