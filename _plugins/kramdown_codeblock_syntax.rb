require 'kramdown'
#require 'pygments'

module Kramdown
  module Converter
    class Html < Base

      def convert_codeblock(el, indent)
        attr = el.attr.dup
        attr["class"] ||= ""
        attr["class"] += " highlight"

        lang = detect_code_language!(el)
        lang ||= 'text'

        highlighted_code = pygmentize(el.value, lang)
        "#{' '*indent}<div#{html_attributes(attr)}><pre>#{highlighted_code}#{' '*indent}</pre></div>\n"
      end

      # Code language is set by adding a :<language>: line to the beginning of
      # the code block, where <language> could be ruby, for example.
      # If such a line is detected, it is removed from the highlighted output
      def detect_code_language!(el)
        code = el.value.split("\n")
        first_line = code.shift
        if first_line =~ /^:([^:]+):$/
          el.value = code.join("\n")
          $1
        end
      end

      def pygmentize(code, lang)
        if lang
          # Pygments.highlight(code,
          #   :lexer => lang,
          #   :options => { :startinline => true, :encoding => 'utf-8', :nowrap => true })
        else
          escape_html(code)
        end
      end

    end
  end
end

