# _plugins/codecogs_math.rb
#
# Keep authored markdown readable on GitHub while giving the Jekyll site a
# normal KaTeX rendering path. The generated HTML starts with CodeCogs image
# fallbacks and replaces them with KaTeX when the article page loads.

require "base64"
require "cgi"

module MathFallbacks
  CODECOGS_ENDPOINT = "https://latex.codecogs.com/png.image?".freeze

  module_function

  def article_page?(item)
    item.data["layout"] == "default"
  end

  def normalize_latex_source(latex)
    CGI.unescapeHTML(latex.to_s.strip)
  end

  def encoded_latex(latex)
    CGI.escapeHTML(Base64.strict_encode64(normalize_latex_source(latex)))
  end

  def plain_text_equation(latex)
    text = normalize_latex_source(latex).dup
    text = text.gsub("\\$", "USD ")
    text = text.gsub(/\\text\{([^{}]*)\}/, "\\1")
    text = text.gsub(/\\begin\{[^{}]*\}|\\end\{[^{}]*\}/, " ")
    text = text.gsub(/\\left|\\right|\\quad|\\displaystyle|\\large|\\color\{[^{}]*\}|\\dpi\{[^{}]*\}/, " ")
    text = text.gsub(/\\times/, " x ")
    text = text.gsub(/\\approx/, " approx ")
    text = text.gsub(/\\frac\{([^{}]*)\}\{([^{}]*)\}/, "\\1 / \\2")
    text = text.gsub(/\\+/, " ")
    text = text.gsub(/[{}]/, "")
    text.gsub(/\s+/, " ").strip
  end

  def equation_alt(latex)
    CGI.escapeHTML(plain_text_equation(latex))
  end

  def equation_latex(latex)
    normalized = normalize_latex_source(latex).gsub("\\$", "\\text{USD }")
    normalized = stack_plain_multiline_equation(normalized)
    "\\dpi{180} \\color{black} \\displaystyle #{normalized}"
  end

  def stack_plain_multiline_equation(latex)
    lines = latex.lines.map(&:strip).reject(&:empty?)
    return latex if lines.length < 2
    return latex if latex.include?("\\begin{")

    if lines[1].match?(/\A:?=/)
      rows = ["#{lines[0]} &#{lines[1]}"]
      rows += lines.drop(2).map { |line| "&\\quad #{line}" }
      return "\\begin{aligned} #{rows.join(' \\\\ ')} \\end{aligned}"
    end

    "\\begin{gathered} #{lines.join(' \\\\ ')} \\end{gathered}"
  end

  def equation_url(latex)
    encoded = CGI.escape(equation_latex(latex)).gsub("+", "%20")
    CODECOGS_ENDPOINT + encoded
  end

  def katex_fallback_equation(latex)
    <<~HTML.strip
      <div class="kdmath katex-fallback-equation" data-latex-b64="#{encoded_latex(latex)}" data-display="true">
        <img src="#{equation_url(latex)}" alt="#{equation_alt(latex)}" loading="lazy">
      </div>
    HTML
  end

  def katex_fallback_inline_equation(latex)
    <<~HTML.strip
      <span class="katex-fallback-inline" data-latex-b64="#{encoded_latex(latex)}" data-display="false"><img src="#{equation_url(latex)}" alt="#{equation_alt(latex)}" loading="lazy"></span>
    HTML
  end

  def replace_literal_inline_math(html)
    html.gsub(%r{\\\((.+?)\\\)}m) do
      yield Regexp.last_match(1)
    end
  end

  def replace_math_with_katex_fallbacks(html)
    html = html.gsub(%r{<div class="kdmath">\s*\$\$(.*?)\$\$\s*</div>}m) do
      katex_fallback_equation(Regexp.last_match(1))
    end

    html = html.gsub(%r{<script type="math/tex;\s*mode=display">\s*(.*?)\s*</script>}m) do
      katex_fallback_equation(Regexp.last_match(1))
    end

    html = html.gsub(%r{<script type="math/tex">\s*(.*?)\s*</script>}m) do
      katex_fallback_inline_equation(Regexp.last_match(1))
    end

    replace_literal_inline_math(html) { |latex| katex_fallback_inline_equation(latex) }
  end

  def absolutize_image_sources(html, site)
    site_url = site.config["url"].to_s.sub(%r{/+\z}, "")
    baseurl = site.config["baseurl"].to_s
    site_root = [site_url, baseurl].join.sub(%r{/+\z}, "")

    html.gsub(%r{(<img\b[^>]*\bsrc=")(/(?!/)[^"]*)(")}i) do
      path = Regexp.last_match(2)
      absolute =
        if !baseurl.empty? && path.start_with?("#{baseurl}/")
          "#{site_url}#{path}"
        else
          "#{site_root}#{path}"
        end

      "#{Regexp.last_match(1)}#{absolute}#{Regexp.last_match(3)}"
    end
  end
end

Jekyll::Hooks.register [:pages, :documents], :post_render do |item|
  next unless MathFallbacks.article_page?(item)

  item.output = MathFallbacks.replace_math_with_katex_fallbacks(item.output)
  item.output = MathFallbacks.absolutize_image_sources(item.output, item.site)
end
