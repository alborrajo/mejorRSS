require 'nokogiri'
require 'open-uri'
require 'cgi'

class ScrappedElement
    @category
    @updated
    @title
    @link

    attr_accessor :category, :updated, :title, :link
    
    def buildRSS maker        
        case category
        when "PELÍCULAS:"
            finalTitle = @title
            finalLink = get_movie(@link)
        when "SERIES:"
            finalTitle = @title
            finalLink = get_serie(@link, @title)
        else
            #TODO: Actually get the torrent
            finalTitle = @title + " (UNSUPPORTED)"
            finalLink = @link
        end
    
        maker.items.new_item do |item|
            item.updated = @updated
            item.title = finalTitle
            item.link = finalLink.to_s
        end
    end


    private
    def get_torrent link, section
        doc = Nokogiri::HTML(URI.open(link))
        torrentName = doc.css("div#contenido_descarga table tr td table tr td table tr td i").text
        
        # Get the torrent link
        return URI.join(link, "/uploads/torrents/#{section}/#{torrentName}")
    end
    
    private
    def get_movie link
        # Transform URL to avoid doing an extra GET step and obtain torrent name directly
        queryParams = CGI.parse link.query
        link.query = URI.encode_www_form({
            "sec"=>"descargas",
            "ap"=>"contar",
            "tabla"=>"peliculas",
            "id"=>queryParams["id"],
            "link_bajar"=>"1"
        })
        
        return get_torrent(link, "peliculas")
    end
    
    private
    def get_episode title_with_episode
        # Serie: Episode -> ["Serie", "Episode"] -> return "Episode"
        return title_with_episode.split(": ")[1]
    
        # Non contempalted special cases:
        #   Separator in serie title
        #       The: Serie: Episode
        #   Separator in the episode
        #       Serie: The: Episode
        #   Separator in both
        #       The: Serie: The: Episode
        # I don't even know how to deal with this, but it happens
    end
    
    private
    def get_serie link, title_with_episode
        episode = get_episode(title_with_episode)
        
        # Look for <a> that contains the episode string
        doc = Nokogiri::HTML(URI.open(link))
        href = doc.xpath("//div[@id = 'main_table_center_center1']//a[text()='#{episode}']/@href")
    
        # Get episode ID from the href
        episodeID = href.to_s[/\/serie-episodio-descargar-torrent-([[:digit:]]+)-.*/,1]
        
        # Build episode download page URI and get torrent link
        link = URI.join(link, "/secciones.php?sec=descargas&ap=contar&tabla=series&id=#{episodeID}")
        return get_torrent(link, "series")
    end
end