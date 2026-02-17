# frozen_string_literal: true

require "test_helper"

class Asana::MarkdownToHtmlTest < ActiveSupport::TestCase
  test "wraps output in <body> tags" do
    html = Asana::MarkdownToHtml.convert("Hello")
    assert html.start_with?("<body>")
    assert html.end_with?("</body>")
  end

  test "returns empty body for blank input" do
    assert_equal "<body></body>", Asana::MarkdownToHtml.convert("")
    assert_equal "<body></body>", Asana::MarkdownToHtml.convert(nil)
  end

  test "renders h1 and h2 as-is" do
    html = Asana::MarkdownToHtml.convert("# Heading 1\n\n## Heading 2")
    assert_includes html, "<h1>"
    assert_includes html, "<h2>"
  end

  test "downgrades h3+ to bold text" do
    html = Asana::MarkdownToHtml.convert("### Sub-heading")
    assert_not_includes html, "<h3>"
    assert_includes html, "<strong>Sub-heading</strong>"
  end

  test "renders bold and italic" do
    html = Asana::MarkdownToHtml.convert("**bold** and *italic*")
    assert_includes html, "<strong>bold</strong>"
    assert_includes html, "<em>italic</em>"
  end

  test "renders unordered lists" do
    md = "- Item one\n- Item two\n- Item three"
    html = Asana::MarkdownToHtml.convert(md)
    assert_includes html, "<ul>"
    assert_includes html, "<li>Item one</li>"
    assert_includes html, "<li>Item two</li>"
  end

  test "strips checkbox markers from list items" do
    md = "- [ ] Unchecked\n- [x] Checked\n- [X] Also checked"
    html = Asana::MarkdownToHtml.convert(md)
    assert_includes html, "<li>Unchecked</li>"
    assert_includes html, "<li>Checked</li>"
    assert_includes html, "<li>Also checked</li>"
    assert_not_includes html, "[ ]"
    assert_not_includes html, "[x]"
  end

  test "renders inline code with escaped HTML" do
    html = Asana::MarkdownToHtml.convert("Use `my_variable` here")
    assert_includes html, "<code>my_variable</code>"
  end

  test "renders links with only href attribute" do
    html = Asana::MarkdownToHtml.convert("[Click here](https://example.com)")
    assert_includes html, '<a href="https://example.com"'
    assert_includes html, "Click here</a>"
  end

  test "renders horizontal rules as self-closed" do
    html = Asana::MarkdownToHtml.convert("Above\n\n---\n\nBelow")
    assert_includes html, "<hr/>"
  end

  # --- Asana-specific constraints ---

  test "does NOT produce <p> tags (unsupported by Asana)" do
    html = Asana::MarkdownToHtml.convert("Paragraph one.\n\nParagraph two.")
    refute_match(/<\/?p>/, html)
    # Content is still present
    assert_includes html, "Paragraph one."
    assert_includes html, "Paragraph two."
  end

  test "does NOT produce <br> tags (unsupported by Asana)" do
    html = Asana::MarkdownToHtml.convert("Line one\nLine two\nLine three")
    refute_match(/<br\s*\/?>/, html)
    # Line breaks are literal newlines
    assert_includes html, "Line one\nLine two\nLine three"
  end

  test "uses <pre> for fenced code blocks" do
    md = "```ruby\nputs 'hello'\n```"
    html = Asana::MarkdownToHtml.convert(md)
    assert_includes html, "<pre>"
    assert_includes html, "puts"
  end

  test "escapes HTML entities inside inline code" do
    html = Asana::MarkdownToHtml.convert("Use the `<span>` element")
    assert_includes html, "<code>&lt;span&gt;</code>"
    assert_not_includes html, "<code><span></code>"
  end

  test "escapes HTML entities inside code blocks" do
    md = "```html\n<div class=\"test\">Hello</div>\n```"
    html = Asana::MarkdownToHtml.convert(md)
    assert_includes html, "&lt;div"
    assert_includes html, "&gt;"
    assert_not_includes html, "<div"
  end

  test "no attributes on non-<a> tags" do
    plan = "## Header\n\n**bold** text\n\n- list item"
    html = Asana::MarkdownToHtml.convert(plan)
    # Find all opening tags that are not <a>, <body>, or self-closing
    non_a_with_attrs = html.scan(/<(?!a\b|\/|body|hr)(\w+)\s+[^>]+>/)
    assert_empty non_a_with_attrs, "Found attributes on non-<a> tags: #{non_a_with_attrs.inspect}"
  end

  test "converts a realistic implementation plan" do
    plan = <<~MD
      ## Implementation Plan

      **Type:** chore

      **Estimate (Dev Days):** 0.1

      **Summary:** Remove the sparkle emoji from the subtitle.

      ## Acceptance Criteria
      - [ ] Emoji is removed
      - [ ] Page still renders correctly
    MD

    html = Asana::MarkdownToHtml.convert(plan)

    # Rich formatting present
    assert_includes html, "<h2>Implementation Plan</h2>"
    assert_includes html, "<strong>Type:</strong>"
    assert_includes html, "<strong>Estimate (Dev Days):</strong>"
    assert_includes html, "<li>Emoji is removed</li>"

    # No raw markdown artifacts
    assert_not_includes html, "**Type:**"
    assert_not_includes html, "##"
    assert_not_includes html, "- [ ]"

    # No unsupported tags
    refute_match(/<\/?p>/, html)
    refute_match(/<br\s*\/?>/, html)
  end

  test "produces valid XML for plan with HTML in code" do
    plan = <<~MD
      ## Technical Implementation

      ### Files to Modify
      - `app/page.tsx` (line 859) - Remove the `<span>` element

      ### Current Code

      ```tsx
      <span className="animate-bounce">✨</span>
      ```
    MD

    html = Asana::MarkdownToHtml.convert(plan)

    # Code content must be escaped
    assert_includes html, "<code>&lt;span&gt;</code>"
    assert_includes html, "&lt;span className="

    # No unescaped HTML tags inside code
    refute_match(/<code>.*<span.*<\/code>/m, html)

    # No unsupported tags
    refute_match(/<\/?p>/, html)
    refute_match(/<br\s*\/?>/, html)
  end

  # --- Spacing ---

  test "no blank line after h2 headings (Asana has built-in heading spacing)" do
    html = Asana::MarkdownToHtml.convert("## Header\n\nSome content")
    # Should be single \n after closing tag, not \n\n
    assert_includes html, "</h2>\nSome content"
    refute_includes html, "</h2>\n\nSome content"
  end

  test "no triple+ newline runs anywhere in output" do
    plan = <<~MD
      ## Section One

      Paragraph text.

      ### Sub-section

      More text here.

      ### Another sub-section

      Even more text.

      ## Section Two

      - List item
    MD

    html = Asana::MarkdownToHtml.convert(plan)
    refute_match(/\n{3,}/, html, "Found 3+ consecutive newlines — causes extra gaps in Asana")
  end

  test "h2 followed by list has no extra gap" do
    html = Asana::MarkdownToHtml.convert("## Criteria\n\n- Item one\n- Item two")
    assert_includes html, "</h2>\n<ul>"
    refute_includes html, "</h2>\n\n<ul>"
  end

  test "only uses Asana-supported tags" do
    plan = <<~MD
      ## Heading

      Regular paragraph with **bold** and *italic* and `code`.

      ### Sub-heading

      - List item one
      - List item two

      ---

      ```ruby
      some_code
      ```
    MD

    html = Asana::MarkdownToHtml.convert(plan)

    # Extract all tag names used
    tags = html.scan(/<\/?(\w+)[^>]*>/).flatten.uniq

    allowed = %w[body h1 h2 strong em u s code pre blockquote ol ul li a hr]
    unsupported = tags - allowed
    assert_empty unsupported, "Found unsupported tags: #{unsupported.inspect}"
  end
end
