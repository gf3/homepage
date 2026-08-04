(** A little thought. **)

open Yocaml

type t =
  { date : Datetime.t
  ; og_image : string
  }

let entity_name = "Thweet"
let neutral = Metadata.required entity_name

let validate =
  let open Data.Validation in
  record (fun fields ->
    let+ date = required fields "date" Datetime.validate
    and+ og_image = optional_or ~default:"" fields "og_image" string in
    { date; og_image })

let normalize { date; og_image } =
  Data.
    [ "date", Datetime.normalize date
    ; "og_image", string og_image
    ]

let to_data t = Data.record (normalize t)
let date t = t.date
let og_image t = t.og_image
