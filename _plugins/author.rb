module Jekyll
  class AuthorTag < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text.strip
    end

    def render(context)
      @context = context

      site_authors = context.registers[:site].config['authors']
      if site_authors.nil? or site_authors.length < 1
        error "At least one author must be defined in _config.yml"
      end

      author_id = find_page_property(context, 'author')
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
      raise "#{msg}\nPost: #{find_page_property(@context, 'path')}"
    end

    def find_page_property(context, property)
      # This works on the homepage where the "post" object is iterated over in a Liquid
      # for-loop in order to generate the list of posts
      for_loop = context.scopes.find { |x| x.has_key? 'forloop' }
      if(!for_loop.nil?)
        # Horrible hack so that find_page_property can be used for the path as well.
        # Pages (i.e. the else block) have a path property set, but "Post" objects do not.
        if(property == 'path' && for_loop['post'].data[property].nil?)
          for_loop['post'].name
        else
          for_loop['post'].data[property]
        end
      else
        # This works if we are in a post context, i.e. context.register[:page] has an author
        # configured
        context.registers[:page][property]
      end
    end


  end
end

Liquid::Template.register_tag('author', Jekyll::AuthorTag)
