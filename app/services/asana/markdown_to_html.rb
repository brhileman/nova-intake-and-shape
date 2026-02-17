# frozen_string_literal: true

module Asana
  # Converts Markdown text to Asana-compatible XML for the `html_notes` field.
  #
  # Asana's rich text API requires **valid XML** using only these tags:
  #   <body>, <h1>, <h2>, <strong>, <em>, <u>, <s>, <code>, <pre>,
  #   <blockquote>, <ol>, <ul>, <li>, <a href="...">, <hr/>
  #
  # IMPORTANT — tags Asana does NOT support (causes 400 error):
  #   <p>, <br>, <br/>, <div>, <span>, <table>, <img>
  #
  # Line breaks are represented as literal \n characters, not <br> tags.
  # Only <a> tags may carry attributes; attributes on other tags are rejected.
  #
  # Usage:
  #   html = Asana::MarkdownToHtml.convert("## Plan\n**Type:** chore")
  #   # => "<body><h2>Plan</h2>\n<strong>Type:</strong> chore\n</body>"
  #
  class MarkdownToHtml
    # Custom Redcarpet renderer restricted to Asana-supported tags.
    class AsanaRenderer < Redcarpet::Render::HTML
      include ERB::Util  # for html_escape / h()

      def initialize(extensions = {})
        # hard_wrap: true so Redcarpet calls linebreak() on single newlines
        # instead of collapsing them into spaces.
        super(extensions.merge(hard_wrap: true))
      end

      # --- Block-level overrides ---

      # Asana does NOT support <p>. Emit text + double newline instead.
      def paragraph(text)
        "#{text}\n\n"
      end

      # Asana does NOT support <br>. Use a literal newline for line breaks.
      def linebreak
        "\n"
      end

      # Asana only supports <h1> and <h2>; render h3+ as bold text.
      # Headers use a single trailing \n — Asana renders built-in spacing
      # around heading elements, so extra blank lines cause double-gaps.
      def header(text, header_level)
        if header_level <= 2
          "<h#{header_level}>#{text}</h#{header_level}>\n"
        else
          "<strong>#{text}</strong>\n"
        end
      end

      # Asana supports <pre> for code blocks. Escape HTML entities inside.
      def block_code(code, _language)
        "<pre>#{html_escape(code.chomp)}</pre>\n"
      end

      # Horizontal rule — self-closed, no space before slash (Asana style).
      def hrule
        "<hr/>\n"
      end

      # Asana doesn't render images — return alt text or nothing.
      def image(link, title, alt_text)
        alt_text.presence || ""
      end

      # Asana doesn't support <table> — flatten to plain text lines.
      def table(header, body)
        "#{header}#{body}"
      end

      def table_row(content)
        "#{content}\n"
      end

      def table_cell(content, _alignment)
        "#{content} | "
      end

      # --- Inline overrides ---

      # Inline code with HTML entities escaped so angle brackets
      # don't break Asana's XML parser.
      def codespan(code)
        "<code>#{html_escape(code)}</code>"
      end

      # Override autolink to ensure <a> only carries href (no extra attributes).
      def autolink(link, link_type)
        "<a href=\"#{html_escape(link)}\">#{html_escape(link)}</a>"
      end

      # Regular links — only href attribute allowed.
      def link(link, title, content)
        "<a href=\"#{html_escape(link)}\">#{content}</a>"
      end
    end

    # Convert a Markdown string to Asana-compatible XML wrapped in <body>.
    # @param markdown_text [String]
    # @return [String] XML suitable for Asana's `html_notes` field
    def self.convert(markdown_text)
      return "<body></body>" if markdown_text.blank?

      # Pre-process: strip checkbox markers that Redcarpet doesn't handle
      cleaned = markdown_text
        .gsub(/^(\s*[-*])\s*\[x\]\s*/i, '\1 ')  # checked   → plain item
        .gsub(/^(\s*[-*])\s*\[ \]\s*/,   '\1 ')  # unchecked → plain item

      renderer = AsanaRenderer.new
      md = Redcarpet::Markdown.new(
        renderer,
        autolink: true,
        tables: true,
        fenced_code_blocks: true,
        strikethrough: true,
        no_intra_emphasis: true,
        space_after_headers: true
      )

      html = md.render(cleaned).strip

      # Safety net: strip any <p>, <br>, or <br/> tags that may have leaked
      # through from Redcarpet's base renderer (e.g. inside list items).
      html = html.gsub(/<\/?p>/, "")
      html = html.gsub(/<br\s*\/?>/, "\n")

      # Tighten spacing: Asana headings have built-in visual margins,
      # so a blank line right after a heading creates a double-gap.
      # Collapse to a single \n after closing heading tags.
      html = html.gsub(%r{(</h[12]>)\n{2,}}, '\1' + "\n")

      # Collapse any run of 3+ newlines to 2 (max one blank line).
      html = html.gsub(/\n{3,}/, "\n\n")

      "<body>#{html}</body>"
    end
  end
end
