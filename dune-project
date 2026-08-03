(lang dune 3.22)

(name homepage)

(version dev)

(generate_opam_files)

(source
 (github gf3/homepage))

(license MIT)

(authors "Gianni Chiappetta <gianni@okgreat.ca>")

(maintainers "Gianni Chiappetta <gianni@okgreat.ca>")

(package
 (name homepage)
 (allow_empty)
 (synopsis "My internet website.")
 (description "A dangerous place to idle.")
 (depends
  (ocaml
   (>= 5.4.1))
  (yocaml
   (>= 3.0.0))
  (yocaml_unix
   (>= 3.0.0))
  cmarkit
  hilite
  (yocaml_yaml (>= 3.0.0))
  (yocaml_markdown (>= 3.0.0))
  (yocaml_jingoo (>= 3.0.0))
  (yocaml_syndication (>= 3.0.0))
  ;; Dev setup
  (utop :with-dev-setup)
  (ocamlformat :with-dev-setup)
  (ocp-indent :with-dev-setup)
  (merlin :with-dev-setup)
  (ocaml-lsp-server :with-dev-setup)))
