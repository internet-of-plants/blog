module Jekyll
  class AuthorTag < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super

      @text = text.strip
    end

    def render(context)
      @context = context

      require 'pp'

      site_authors = context.registers[:site].config['authors']
      if site_authors.nil? or site_authors.length < 1
        error "At least one author must be defined in _config.yml"
      end

      author_id = find_author_id(context)
      if author_id.nil? or !author_id.is_a? String
        error "Author (in post-settings) must be set to an author name defined in _config.yml"
      end

      author = site_authors[author_id]
      if author.nil?
        error "Could not find author with name '#{author}'. Authors are defined in _config.yml"
      end

      author[@text] || "Author property not found: #{@text}"
    end


    def error(msg)
      path = @context.registers[:page]['path']
      raise "#{msg}\nPost: #{path}"
    end

    def find_author_id(context)
      # This works if we are in a post context, i.e. context.register[:page] has an author
      # configured
      author_id = context.registers[:page]['author']

      # This works on the homepage where the "post" object is iterated over in a Liquid
      # for-loop in order to generate the list of posts
      author_id ||= context.scopes.find { |x| x.has_key? 'forloop' }['post'].data['author']
    end

  end
end

Liquid::Template.register_tag('author', Jekyll::AuthorTag)
