# frozen_string_literal: true

module MarkdownHelper
  # Render markdown text to HTML
  # @param text [String] The markdown text to render
  # @return [String] HTML output
  def render_markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener" }
    )

    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      superscript: true,
      no_intra_emphasis: true,
      space_after_headers: true
    )

    markdown.render(text).html_safe
  end
end
