# _plugins/codecogs_math.rb
#
# Medium import does not execute the article page JavaScript, so the runtime
# ?medium converter is invisible to Medium. This plugin creates static Medium
# export pages and rewrites rendered LaTeX blocks to image tags before Jekyll
# writes the HTML.

require "cgi"

module MediumMath
  CODECOGS_ENDPOINT = "https://latex.codecogs.com/png.image?".freeze

  module_function

  def article_page?(page)
    page.data["layout"] == "default" && !page.data["medium_export"]
  end

  def slug_for(page)
    permalink = page.data["permalink"].to_s
    parts = permalink.split("/").reject(&:empty?)
    return parts.last unless parts.empty?

    page.basename_without_ext
  end

  def medium_permalink_for(page)
    "/medium/#{slug_for(page)}/"
  end

  def canonical_path_for(page)
    page.data["permalink"].to_s.empty? ? page.url : page.data["permalink"]
  end

  def equation_url(latex)
    # Higher DPI and display style keep the imported image readable after
    # Medium reprocesses it. CodeCogs treats plus signs as literal operators, so
    # spaces must be encoded as %20 rather than CGI's application/x-www-form
    # '+' encoding.
    encoded_latex = CGI.escape(equation_latex(latex)).gsub("+", "%20")
    CODECOGS_ENDPOINT + encoded_latex
  end

  def equation_alt(latex)
    CGI.escapeHTML(latex.gsub(/\s+/, " ").strip)
  end

  def equation_latex(latex)
    normalized = latex.strip.gsub("\\$", "\\text{USD }")
    normalized = stack_plain_multiline_equation(normalized)
    "\\dpi{180} \\color{black} \\large \\displaystyle #{normalized}"
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

  def display_equation(latex)
    <<~HTML.strip
      <figure class="medium-equation">
        <img src="#{equation_url(latex)}" alt="#{equation_alt(latex)}" loading="lazy">
      </figure>
    HTML
  end

  def inline_equation(latex)
    <<~HTML.strip
      <img class="medium-inline-equation" src="#{equation_url(latex)}" alt="#{equation_alt(latex)}" loading="lazy">
    HTML
  end

  def replace_math(html)
    html = html.gsub(%r{<div class="kdmath">\s*\$\$(.*?)\$\$\s*</div>}m) do
      display_equation(Regexp.last_match(1))
    end

    html = html.gsub(%r{<script type="math/tex;\s*mode=display">\s*(.*?)\s*</script>}m) do
      display_equation(Regexp.last_match(1))
    end

    html.gsub(%r{<script type="math/tex">\s*(.*?)\s*</script>}m) do
      inline_equation(Regexp.last_match(1))
    end
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

Jekyll::Hooks.register :site, :post_read do |site|
  site.pages.select { |page| MediumMath.article_page?(page) }.each do |source_page|
    export_page = Jekyll::PageWithoutAFile.new(
      site,
      site.source,
      File.join("medium", MediumMath.slug_for(source_page)),
      "index.md"
    )

    export_page.content = source_page.content
    export_page.data = source_page.data.merge(
      "layout" => "medium",
      "medium_export" => true,
      "canonical_url" => MediumMath.canonical_path_for(source_page),
      "permalink" => MediumMath.medium_permalink_for(source_page)
    )

    site.pages << export_page
  end
end

Jekyll::Hooks.register [:pages, :documents], :post_render do |item|
  next unless item.data["medium_export"]

  item.output = MediumMath.replace_math(item.output)
  item.output = MediumMath.absolutize_image_sources(item.output, item.site)
end
