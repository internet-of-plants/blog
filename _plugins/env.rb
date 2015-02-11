class Jekyll::Site
  attr_accessor :env
end

class Env < Jekyll::Generator
  priority :highest
  def generate(site)
    site.env = ENV['JEKYLL_ENV'] || 'development'
    site.config['env'] = site.env
  end
end
