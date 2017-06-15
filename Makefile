README.md: README.jmd
	julia --e 'using Weave; weave("$<", out_path="$@", doctype="github")'
