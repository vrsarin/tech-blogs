# _plugins/codecogs_math.rb
#
# Converts block LaTeX equations ($$...$$) to CodeCogs SVG <img> tags at
# Jekyll build time.  The resulting <img> elements:
#   • render on GitHub Pages as crisp, resolution-independent SVGs
#   • scale responsively with container width (max-width:100%)
#   • survive Medium import as real image elements pointing at CodeCogs
#
# CodeCogs rendering endpoint:
#   https://latex.codecogs.com/svg.image?$$raw-latex$$
# The LaTeX is passed as-is; only HTML-escaped for the src attribute.

# LaTeX → CodeCogs conversion is now handled at runtime via JavaScript.
# The ?medium URL parameter triggers client-side rendering in default.html.
# This file is intentionally a no-op.
