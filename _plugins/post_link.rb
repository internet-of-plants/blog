module Jekyll
  module Tags

    class PostLink < Liquid::Tag
      def initialize(tag_name, post, tokens)
        super

        @post, *title = post.strip.split(' ')
        @title = title.join(' ')
      end

      def render(context)
        site = context.registers[:site]

        site.posts.docs.each do |p|
          if @post == File.basename(p.path, p.extname)
            return "<a href=\"#{ p.url }\">#{ @title ? @title : p.data['title'] }</a>"
          end
        end

        raise ArgumentError.new <<-eos
Could not find post "#{@orig_post}" in tag 'post_link'.

Make sure the post exists and the name and date is correct.
eos
      end
    end
  end
end

Liquid::Template.register_tag('postlink', Jekyll::Tags::PostLink)
