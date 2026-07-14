# Beamer deck

The current academic presentation is:

- ai_political_intermediation_brazil.tex: editable Beamer source;
- ai_political_intermediation_brazil.pdf: compiled 56-slide deck.

The source reads figures directly from results/intermediation/figures, avoiding duplicate
image assets.

Compile from this directory with XeLaTeX:

~~~powershell
New-Item -ItemType Directory -Force build
xelatex -interaction=nonstopmode -output-directory=build ai_political_intermediation_brazil.tex
xelatex -interaction=nonstopmode -output-directory=build ai_political_intermediation_brazil.tex
Copy-Item build/ai_political_intermediation_brazil.pdf .
~~~

XeLaTeX is required because the source uses fontspec. The build/ directory is ignored
by Git.
