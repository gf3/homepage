# Homepage

## Getting setup

```sh
opam update
opam switch create . --deps-only --with-dev-setup -y
```

Updating the opam file or mli headers:

```sh
dune build
```

Updating dependencies:

```sh
opam install . --deps-only --with-dev-setup -y
```

## Running

Run the app with dune:

```sh
dune exec bin/homepage.exe
```
