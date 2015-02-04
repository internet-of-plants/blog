require 'pp'

module AuthorsInjector
  class Generator < Jekyll::Generator
    def generate(site)
      site.posts.each do |post|
        inject_authors(post, site)
      end
    end


    # posts - Jekyll::Post
    # site - Jekyll::Site
    def inject_authors(post, site)
      data = post.data
      if !data['author'].nil? && !data['authors'].nil?
        error "You cannot specify both 'author' and 'authors'", post
      end

      if !data['author'].nil?
        data['authors'] = [data['author']]
      end

      data['authors'] = data['authors'].map do |author|
        author_data = site_authors(post)[author]
        if author_data.nil?
          error "Could not find author named '#{author}'", post
        end
        author_data['primary'] = false
        author_data
      end

      data['authors'][0]['primary'] = true
      data['author'] = data['authors'][0]

      pp post.data
    end

    def site_authors(post)
      authors = post.site.config['authors']
      if authors.nil? or authors.length < 1
        error "At least one author must be defined in _config.yml", post
      end
      authors
    end

    def error(msg, post)
      raise "#{msg}\nPost: #{post.path}"
    end

  end
end
